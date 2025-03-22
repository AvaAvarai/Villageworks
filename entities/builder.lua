local Config = require("config")
local Utils = require("utils")

local Builder = {}
Builder.__index = Builder

function Builder.new(x, y, villageId)
    local builder = setmetatable({
        id = Utils.generateId(),
        x = x,
        y = y,
        villageId = villageId,
        task = nil,
        progress = 0,
        state = "idle", -- idle, moving, building, building_road
        targetX = nil,
        targetY = nil,
        currentRoad = nil
    }, Builder)
    
    return builder
end

function Builder.update(builders, game, dt)
    for i, builder in ipairs(builders) do
        if builder.state == "idle" then
            -- Look for building tasks if no current task
            builder:findTask(game)
        elseif builder.state == "moving" then
            -- Move to building site
            local arrived = Utils.moveToward(builder, builder.targetX, builder.targetY, Config.BUILDER_SPEED, dt)
            
            if arrived then
                builder.state = "building"
            end
        elseif builder.state == "building" then
            -- Build the structure
            builder.progress = builder.progress + dt
            local buildingType = Config.BUILDING_TYPES[builder.task.type]
            
            if builder.progress >= buildingType.buildTime then
                -- Building is complete
                builder:completeBuilding(game)
            end
        elseif builder.state == "building_road" then
            -- Building a road
            local road = builder.currentRoad
            if road then
                -- Calculate movement along the road path
                local roadLength = road.length
                local segmentLength = Config.ROAD_BUILD_SPEED * dt
                local progressIncrement = segmentLength / roadLength
                
                -- Update road progress
                road.buildProgress = road.buildProgress + progressIncrement
                
                -- Update builder position along the road
                builder.x = road.startX + (road.endX - road.startX) * road.buildProgress
                builder.y = road.startY + (road.endY - road.startY) * road.buildProgress
                
                -- Check if road is complete
                if road.buildProgress >= 1 then
                    road.buildProgress = 1
                    road.isComplete = true
                    builder.state = "idle"
                    builder.currentRoad = nil
                    builder.progress = 0
                end
                
                -- Deduct resources for this segment of road
                local woodUsed = Config.ROAD_COST_PER_UNIT.wood * segmentLength
                local stoneUsed = Config.ROAD_COST_PER_UNIT.stone * segmentLength
                
                game.resources.wood = math.max(0, game.resources.wood - woodUsed)
                game.resources.stone = math.max(0, game.resources.stone - stoneUsed)
            else
                -- No road assigned, reset state
                builder.state = "idle"
            end
        end
    end
end

function Builder:findTask(game)
    -- First try to find the village this builder belongs to
    local village = nil
    for _, v in ipairs(game.villages) do
        if v.id == self.villageId then
            village = v
            break
        end
    end
    
    if not village then return end
    
    -- Check if there are any roads that need building
    if math.random() < Config.ROAD_BUILD_PRIORITY and #game.roads > 0 then
        -- Look for incomplete roads
        local nearestRoad = nil
        local minDistance = math.huge
        
        for _, road in ipairs(game.roads) do
            if not road.isComplete and road.startVillageId == self.villageId then
                -- Calculate position along the road based on current progress
                local roadX = road.startX + (road.endX - road.startX) * road.buildProgress
                local roadY = road.startY + (road.endY - road.startY) * road.buildProgress
                
                local distance = Utils.distance(self.x, self.y, roadX, roadY)
                if distance < minDistance then
                    minDistance = distance
                    nearestRoad = road
                end
            end
        end
        
        if nearestRoad and game.resources.wood >= 10 and game.resources.stone >= 5 then
            -- Start building this road
            self.currentRoad = nearestRoad
            self.state = "building_road"
            return
        end
    end
    
    -- Roll chance to start building a structure
    if math.random() < Config.BUILDER_BUILD_CHANCE then
        -- Choose what to build based on village needs
        local buildingType
        
        -- Priority 1: House if needed
        if village.needsHousing and Utils.canAfford(game.resources, Config.BUILDING_TYPES.house.cost) then
            buildingType = "house"
        else
            -- Priority 2: Resources needed by village
            local possibleBuildings = {}
            for _, buildingName in ipairs(village.needsResources) do
                if Utils.canAfford(game.resources, Config.BUILDING_TYPES[buildingName].cost) then
                    table.insert(possibleBuildings, buildingName)
                end
            end
            
            if #possibleBuildings > 0 then
                buildingType = possibleBuildings[math.random(#possibleBuildings)]
            elseif Utils.canAfford(game.resources, Config.BUILDING_TYPES.house.cost) then
                -- Priority 3: Default to house
                buildingType = "house"
            else
                -- Priority 4: Any affordable building
                local affordableBuildings = {}
                for type, info in pairs(Config.BUILDING_TYPES) do
                    if Utils.canAfford(game.resources, info.cost) then
                        table.insert(affordableBuildings, type)
                    end
                end
                
                if #affordableBuildings > 0 then
                    buildingType = affordableBuildings[math.random(#affordableBuildings)]
                end
            end
        end
        
        if buildingType then
            -- Find a location to build
            local buildX, buildY = Utils.randomPositionAround(village.x, village.y, 30, Config.MAX_BUILD_DISTANCE)
            
            -- Create the task
            self.task = {
                x = buildX,
                y = buildY,
                type = buildingType
            }
            
            -- Deduct resources
            Utils.deductResources(game.resources, Config.BUILDING_TYPES[buildingType].cost)
            
            -- Set target location and state
            self.targetX = buildX
            self.targetY = buildY
            self.state = "moving"
            self.progress = 0
            
            -- Create a road from village to building site
            if math.random() < 0.3 then
                local newRoad = require("entities/road").new(
                    village.x, village.y,
                    buildX, buildY,
                    self.villageId,
                    nil,
                    0
                )
                table.insert(game.roads, newRoad)
            end
        end
    end
end

function Builder:completeBuilding(game)
    -- Create the new building
    local BuildingModule = require("entities/building")
    local newBuilding = BuildingModule.new(
        self.task.x,
        self.task.y,
        self.task.type,
        self.villageId
    )
    
    table.insert(game.buildings, newBuilding)
    
    -- Reset builder state
    self.task = nil
    self.progress = 0
    self.state = "idle"
    self.targetX = nil
    self.targetY = nil
end

function Builder:draw()
    -- Builder color
    love.graphics.setColor(0.8, 0.8, 0)
    
    -- Draw builder differently based on state
    if self.state == "building_road" then
        -- Road builder
        love.graphics.setColor(0.9, 0.7, 0.1)
        love.graphics.circle("fill", self.x, self.y, 5)
        love.graphics.setColor(0.3, 0.3, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", self.x, self.y, 6)
        love.graphics.setLineWidth(1)
    else
        -- Regular builder
        love.graphics.circle("fill", self.x, self.y, 5)
    end
    
    -- Draw build progress if building
    if self.state == "building" then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.print(string.format("%.1f", self.progress), self.x + 10, self.y)
    end
    
    -- Draw line to target if moving or building
    if self.targetX and self.targetY then
        love.graphics.setColor(0.8, 0.8, 0, 0.5)
        love.graphics.line(self.x, self.y, self.targetX, self.targetY)
    end
    
    -- Draw state indicator
    local stateColors = {
        idle = {0.8, 0.8, 0.2},
        moving = {0.8, 0.5, 0.2},
        building = {0.2, 0.7, 0.2},
        building_road = {0.7, 0.7, 0.2}
    }
    
    if stateColors[self.state] then
        love.graphics.setColor(stateColors[self.state])
        love.graphics.circle("fill", self.x, self.y - 7, 2)
    end
end

-- Check if builder is on a road
function Builder:isOnRoad(game)
    local nearestRoad, distance = require("entities/road").findNearestRoad(game.roads, self.x, self.y, 10)
    return nearestRoad ~= nil
end

-- Get movement speed for the builder (faster on roads)
function Builder:getMovementSpeed(game)
    if self:isOnRoad(game) then
        return Config.BUILDER_SPEED * Config.ROAD_SPEED_MULTIPLIER
    else
        return Config.BUILDER_SPEED
    end
end

return Builder 