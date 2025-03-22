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
        currentRoad = nil,
        pathIndex = 1 -- Current position in the road path
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
            if road and road.path and #road.path > 0 then
                -- Calculate road building speed
                local buildSpeed = Config.ROAD_BUILD_SPEED * dt
                local tilesBuilt = 0
                local maxTilesBuildable = math.ceil(buildSpeed / game.map.tileSize)
                
                -- Build tiles along the path
                while builder.pathIndex <= #road.path and tilesBuilt < maxTilesBuildable do
                    local tileToBuild = road.path[builder.pathIndex]
                    
                    -- Convert tile coordinates to world coordinates for builder position
                    local tileWorldX, tileWorldY = game.map:tileToWorld(tileToBuild.x, tileToBuild.y)
                    
                    -- Move builder to tile position
                    local arrived = Utils.moveToward(builder, tileWorldX, tileWorldY, Config.BUILDER_SPEED, dt)
                    
                    if arrived then
                        -- Set tile to road
                        game.map:setTileType(tileToBuild.x, tileToBuild.y, game.map.TILE_ROAD)
                        
                        -- Deduct resources for this segment of road
                        local woodUsed = Config.ROAD_COST_PER_UNIT.wood * game.map.tileSize
                        local stoneUsed = Config.ROAD_COST_PER_UNIT.stone * game.map.tileSize
                        
                        game.resources.wood = math.max(0, game.resources.wood - woodUsed)
                        game.resources.stone = math.max(0, game.resources.stone - stoneUsed)
                        
                        -- Move to next tile
                        builder.pathIndex = builder.pathIndex + 1
                        tilesBuilt = tilesBuilt + 1
                        
                        -- Update road progress
                        road.buildProgress = builder.pathIndex / #road.path
                    else
                        -- If not arrived at current tile, break the loop
                        break
                    end
                end
                
                -- Check if road is complete
                if builder.pathIndex > #road.path then
                    road.buildProgress = 1
                    road.isComplete = true
                    
                    -- Ensure all road tiles are properly set on the map
                    road:updateMapTiles(game.map)
                    
                    builder.state = "idle"
                    builder.currentRoad = nil
                    builder.pathIndex = 1
                    builder.progress = 0
                end
            else
                -- No road path assigned, reset state
                builder.state = "idle"
                builder.pathIndex = 1
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
            -- Find a good location for the building that's not on water
            local buildX, buildY
            local attempt = 0
            local maxAttempts = 20
            
            repeat
                buildX, buildY = Utils.randomPositionAround(village.x, village.y, 30, Config.MAX_BUILD_DISTANCE, game.map)
                attempt = attempt + 1
            until (game.map:canBuildAt(buildX, buildY) or attempt >= maxAttempts)
            
            -- If we couldn't find a buildable spot after max attempts, find closest buildable area
            if not game.map:canBuildAt(buildX, buildY) then
                buildX, buildY = game.map:findNearestBuildablePosition(buildX, buildY)
                
                -- If still no valid position, give up on this task
                if not buildX then return end
            end
            
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
            -- Check if there's a valid path for the road
            local endVillageId = nil
            if roadNeed.type == "village" then
                endVillageId = roadNeed.target.id
            end
            
            -- Use the path from roadNeed if it exists
            local path = roadNeed.path
            
            if path then
                local newRoad = require("entities/road").new(
                    village.x, village.y,
                    roadNeed.x, roadNeed.y,
                    village.id,
                    endVillageId,
                    0, -- 0% progress
                    path -- Add the path to the road
                )
                
                table.insert(game.roads, newRoad)
                
                -- Assign this builder to build the road
                self.currentRoad = newRoad
                self.state = "building_road"
                self.pathIndex = 1
                
                -- Remove this road need
                table.remove(village.needsRoads, 1)
                return
            end
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

-- Check if builder is on a road tile
function Builder:isOnRoad(game)
    local tileType = game.map:getTileTypeAtWorld(self.x, self.y)
    return tileType == game.map.TILE_ROAD
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