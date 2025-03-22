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
        state = "idle", -- idle, moving, building
        targetX = nil,
        targetY = nil
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
    
    -- Roll chance to start building
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
    love.graphics.setColor(0.8, 0.8, 0)
    love.graphics.circle("fill", self.x, self.y, 5)
    
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
end

return Builder 