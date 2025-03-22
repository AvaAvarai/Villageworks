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
            local speed = builder:getMovementSpeed(game)
            local arrived = Utils.moveToward(builder, builder.targetX, builder.targetY, speed, dt)
            
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

    -- Get the UI module to access building queues
    local UI = require("ui")
    
    -- First check if there are any queued buildings for this village
    if UI.hasQueuedBuildings(village.id) then
        local nextBuildingType = UI.getNextQueuedBuilding(village.id)
        
        if nextBuildingType and Utils.canAfford(game.resources, Config.BUILDING_TYPES[nextBuildingType].cost) then
            -- Find a good location for the building
            local buildX, buildY = Utils.randomPositionAround(village.x, village.y, 30, Config.MAX_BUILD_DISTANCE)
            
            -- Create the task
            self.task = {
                x = buildX,
                y = buildY,
                type = nextBuildingType
            }
            
            -- Deduct resources
            Utils.deductResources(game.resources, Config.BUILDING_TYPES[nextBuildingType].cost)
            
            -- Set target location and state
            self.targetX = buildX
            self.targetY = buildY
            self.state = "moving"
            self.progress = 0
            
            -- Decrement the building from the queue
            UI.decrementBuildingQueue(village.id, nextBuildingType)
            
            return -- Task found, exit the function
        end
    end
    
    -- If no queued buildings, check for road needs
    if #village.needsRoads > 0 and game.resources.wood >= 10 and game.resources.stone >= 5 then
        -- Take the highest priority road need
        local roadNeed = village.needsRoads[1]
        
        -- Check if this road is already being built
        local roadBeingBuilt = false
        for _, road in ipairs(game.roads) do
            if not road.isComplete then
                if (road.startVillageId == village.id and 
                    Utils.distance(road.endX, road.endY, roadNeed.x, roadNeed.y) < 10) or
                   (road.endVillageId == village.id and 
                    Utils.distance(road.startX, road.startY, roadNeed.x, roadNeed.y) < 10) then
                    roadBeingBuilt = true
                    break
                end
            end
        end
        
        if not roadBeingBuilt then
            -- Create a new road
            local endVillageId = nil
            if roadNeed.type == "village" then
                endVillageId = roadNeed.target.id
            end
            
            local newRoad = require("entities/road").new(
                village.x, village.y,
                roadNeed.x, roadNeed.y,
                village.id,
                endVillageId,
                0 -- 0% progress
            )
            
            table.insert(game.roads, newRoad)
            
            -- Assign this builder to build the road
            self.currentRoad = newRoad
            self.state = "building_road"
            return
        end
    end
    
    -- Check if there are any unfinished roads that need building
    if #game.roads > 0 then
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