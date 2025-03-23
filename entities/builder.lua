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
        pathIndex = 1, -- Current position in the road path
        -- New properties for pathfinding
        path = nil,    -- Calculated path to target
        currentPathIndex = 1, -- Current position in the path
        needsPathRecalculation = false -- Flag to recalculate path
    }, Builder)
    
    return builder
end

function Builder.update(builders, game, dt)
    for i, builder in ipairs(builders) do
        if builder.state == "idle" then
            -- Look for building tasks if no current task
            builder:findTask(game)
        elseif builder.state == "moving" then
            -- Check if we need to calculate a path
            if not builder.path or builder.needsPathRecalculation then
                builder:calculatePath(game, builder.targetX, builder.targetY)
                builder.needsPathRecalculation = false
            end
            
            -- Move along the calculated path
            local arrived = builder:moveAlongPath(game, dt)
            
            if arrived then
                builder.state = "building"
                builder.path = nil -- Clear the path when arrived
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
                        -- Check if we need to clear forest first
                        local currentTileType = game.map:getTileType(tileToBuild.x, tileToBuild.y)
                        local isForest = currentTileType == game.map.TILE_FOREST
                        
                        -- Set tile to road
                        game.map:setTileType(tileToBuild.x, tileToBuild.y, game.map.TILE_ROAD)
                        
                        -- Deduct resources for this segment of road
                        local woodUsed = Config.ROAD_COST_PER_UNIT.wood * game.map.tileSize
                        local stoneUsed = Config.ROAD_COST_PER_UNIT.stone * game.map.tileSize
                        
                        -- If clearing forest, get additional wood and spend more time
                        if isForest then
                            -- Get wood from clearing forest
                            game.resources.wood = game.resources.wood + Config.FOREST_WOOD_YIELD
                            
                            -- Forest clearing slows down road building
                            tilesBuilt = tilesBuilt + 0.5 -- Building through forest is slower
                        else
                            tilesBuilt = tilesBuilt + 1
                        end
                        
                        game.resources.wood = math.max(0, game.resources.wood - woodUsed)
                        game.resources.stone = math.max(0, game.resources.stone - stoneUsed)
                        
                        -- Move to next tile
                        builder.pathIndex = builder.pathIndex + 1
                        
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
            -- Check if there's a planned position in the queue
            local plannedPosition = nil
            local buildQueue = UI.getBuildingQueue(village.id)
            
            if buildQueue and buildQueue.plannedPositions then
                for _, position in ipairs(buildQueue.plannedPositions) do
                    if position.type == nextBuildingType then
                        plannedPosition = position
                        break
                    end
                end
            end
            
            local buildX, buildY
            
            if plannedPosition then
                -- Use the pre-planned position if available
                buildX, buildY = plannedPosition.x, plannedPosition.y
                
                -- Verify that the planned position is still valid
                local isValid = game.map:isWithinBounds(buildX, buildY) and
                                game.map:canBuildAt(buildX, buildY) and
                                game.map:isPositionClearOfBuildings(buildX, buildY, game)
                                
                -- For fishing huts, also check water adjacency
                if nextBuildingType == "fishing_hut" then
                    isValid = isValid and game.map:isAdjacentToWater(buildX, buildY)
                end
                
                -- For mines, check mountain adjacency
                if nextBuildingType == "mine" then
                    isValid = isValid and game.map:isAdjacentToMountain(buildX, buildY)
                end
                
                -- If position is no longer valid, ignore it and find a new one
                if not isValid then
                    buildX, buildY = nil, nil
                end
            end
            
            -- If no valid planned position, find a suitable location dynamically
            if not buildX or not buildY then
                local attempt = 0
                local maxAttempts = 30 -- Increased attempts for finding special locations
                
                -- Special case for finding lumberyard location near forests
                if nextBuildingType == "lumberyard" then
                    buildX, buildY = self:findNearForestPosition(game, village.x, village.y)
                    
                    if buildX and buildY then
                        -- Found a good spot near forest
                        local isValidPosition = game.map:canBuildAt(buildX, buildY) and 
                                            game.map:isPositionClearOfBuildings(buildX, buildY, game)
                        if not isValidPosition then
                            buildX, buildY = nil, nil -- Position not valid for building
                        end
                    end
                -- Special case for finding mine location near mountains
                elseif nextBuildingType == "mine" then
                    buildX, buildY = game.map:findNearestMountainEdge(village.x, village.y)
                    
                    if buildX and buildY then
                        -- Found a good spot near mountain
                        local isValidPosition = game.map:canBuildAt(buildX, buildY) and 
                                            game.map:isPositionClearOfBuildings(buildX, buildY, game) and
                                            game.map:isAdjacentToMountain(buildX, buildY)
                        if not isValidPosition then
                            buildX, buildY = nil, nil -- Position not valid for building
                        end
                    end
                end
                
                -- If not a special building or couldn't find special position, use normal placement
                if not buildX or not buildY then
                    repeat
                        buildX, buildY = Utils.randomPositionAround(village.x, village.y, 30, Config.MAX_BUILD_DISTANCE, game.map)
                        attempt = attempt + 1
                        
                        -- Check if the position is valid (not on water, not overlapping other buildings)
                        local isValidPosition = game.map:canBuildAt(buildX, buildY) and 
                                                game.map:isPositionClearOfBuildings(buildX, buildY, game)
                        
                        -- Special check for fishing huts - must be adjacent to water
                        if nextBuildingType == "fishing_hut" then
                            if not (isValidPosition and game.map:isAdjacentToWater(buildX, buildY)) then
                                -- Location not suitable for fishing hut
                                buildX = nil
                            end
                        -- Special check for mines - must be adjacent to mountains
                        elseif nextBuildingType == "mine" then
                            if not (isValidPosition and game.map:isAdjacentToMountain(buildX, buildY)) then
                                -- Location not suitable for mine
                                buildX = nil
                            end
                        else
                            -- For normal buildings, just check standard requirements
                            if not isValidPosition then
                                -- Location not suitable
                                buildX = nil
                            end
                        end
                    until (buildX ~= nil or attempt >= maxAttempts)
                end
                
                -- If we couldn't find a suitable spot after max attempts
                if buildX == nil then
                    if nextBuildingType == "fishing_hut" then
                        -- For fishing huts, find a spot adjacent to water that doesn't overlap
                        buildX, buildY = self:findNonOverlappingWaterEdge(game, village.x, village.y)
                    elseif nextBuildingType == "mine" then
                        -- For mines, find a spot adjacent to mountains that doesn't overlap
                        buildX, buildY = self:findNonOverlappingMountainEdge(game, village.x, village.y)
                    elseif nextBuildingType == "lumberyard" then
                        -- For lumberyards, try harder to find a spot near forest
                        buildX, buildY = self:findNonOverlappingForestPosition(game, village.x, village.y)
                        
                        -- If still can't find a forest position, use any buildable position
                        if not buildX then
                            buildX, buildY = self:findNonOverlappingBuildPosition(game, village.x, village.y)
                        end
                    else
                        -- For regular buildings, find any suitable spot
                        buildX, buildY = self:findNonOverlappingBuildPosition(game, village.x, village.y)
                    end
                end
            end
            
            -- If still no valid position, give up on this task
            if not buildX then 
                -- Return resources since we can't build
                Utils.addResources(game.resources, Config.BUILDING_TYPES[nextBuildingType].cost)
                -- Remove from queue
                UI.decrementBuildingQueue(village.id, nextBuildingType)
                -- Show message about failure
                if nextBuildingType == "fishing_hut" then
                    UI.showMessage("Cannot build fishing hut: No suitable water-adjacent locations found")
                elseif nextBuildingType == "mine" then
                    UI.showMessage("Cannot build mine: No suitable mountain-adjacent locations found")
                else
                    UI.showMessage("Cannot build " .. nextBuildingType .. ": No suitable location found")
                end
                return 
            end
            
            -- Create the task
            self.task = {
                x = buildX,
                y = buildY,
                type = nextBuildingType
            }
            
            -- Set building coordinates for the builder to track (for overlap prevention)
            self.buildingX = buildX
            self.buildingY = buildY
            
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

-- Helper method to find a non-overlapping position near water for fishing huts
function Builder:findNonOverlappingWaterEdge(game, startX, startY)
    local maxSearchRadius = 300
    local searchStep = 15
    local maxPositionsToCheck = 30
    local positionsChecked = 0
    
    -- Search in expanding circles
    for radius = 30, maxSearchRadius, searchStep do
        -- Try multiple angles at this radius
        for angle = 0, 2 * math.pi, math.pi / 8 do
            local x = startX + math.cos(angle) * radius
            local y = startY + math.sin(angle) * radius
            
            -- Check if the location is suitable for a fishing hut
            local canBuildHere = game.map:isWithinBounds(x, y) and 
                                 game.map:canBuildAt(x, y) and
                                 game.map:isAdjacentToWater(x, y) and
                                 game.map:isPositionClearOfBuildings(x, y, game)
            
            if canBuildHere then
                return x, y
            end
            
            positionsChecked = positionsChecked + 1
            if positionsChecked >= maxPositionsToCheck then
                break
            end
        end
        
        if positionsChecked >= maxPositionsToCheck then
            break
        end
    end
    
    -- If we couldn't find a position in the circular search,
    -- try to find the nearest water edge directly and check surrounding positions
    local waterEdgeX, waterEdgeY = game.map:findNearestWaterEdge(startX, startY)
    
    if waterEdgeX and waterEdgeY then
        -- Check points around the water edge
        for radius = 5, 40, 5 do
            for angle = 0, 2 * math.pi, math.pi / 6 do
                local x = waterEdgeX + math.cos(angle) * radius
                local y = waterEdgeY + math.sin(angle) * radius
                
                local canBuildHere = game.map:isWithinBounds(x, y) and 
                                     game.map:canBuildAt(x, y) and
                                     game.map:isAdjacentToWater(x, y) and
                                     game.map:isPositionClearOfBuildings(x, y, game)
                
                if canBuildHere then
                    return x, y
                end
            end
        end
    end
    
    return nil, nil  -- No suitable position found
end

-- Helper method to find a non-overlapping position for regular buildings
function Builder:findNonOverlappingBuildPosition(game, startX, startY)
    local maxSearchRadius = 200
    local searchStep = 15
    local maxPositionsToCheck = 40
    local positionsChecked = 0
    
    -- Search in expanding circles
    for radius = 30, maxSearchRadius, searchStep do
        -- Try multiple angles at this radius
        for angle = 0, 2 * math.pi, math.pi / 8 do
            local x = startX + math.cos(angle) * radius
            local y = startY + math.sin(angle) * radius
            
            -- Check if the location is suitable for a building
            local canBuildHere = game.map:isWithinBounds(x, y) and 
                                 game.map:canBuildAt(x, y) and
                                 game.map:isPositionClearOfBuildings(x, y, game)
            
            if canBuildHere then
                return x, y
            end
            
            positionsChecked = positionsChecked + 1
            if positionsChecked >= maxPositionsToCheck then
                break
            end
        end
        
        if positionsChecked >= maxPositionsToCheck then
            break
        end
    end
    
    -- If we couldn't find a position in the circular search,
    -- try a grid-based search in village's vicinity
    for y = startY - maxSearchRadius, startY + maxSearchRadius, 30 do
        for x = startX - maxSearchRadius, startX + maxSearchRadius, 30 do
            -- Skip positions too far from village
            local distance = Utils.distance(startX, startY, x, y)
            if distance <= Config.MAX_BUILD_DISTANCE then
                local canBuildHere = game.map:isWithinBounds(x, y) and 
                                     game.map:canBuildAt(x, y) and
                                     game.map:isPositionClearOfBuildings(x, y, game)
                
                if canBuildHere then
                    return x, y
                end
            end
        end
    end
    
    return nil, nil  -- No suitable position found
end

-- Find a suitable location to place a building
function Builder.findBuildingLocation(builder, game, buildingType)
    -- Try to find suitable location
    local village = nil
    for _, v in ipairs(game.villages) do
        if v.id == builder.villageId then
            village = v
            break
        end
    end
    
    if not village then return nil, nil end
    
    local maxAttempts = 50
    local attempts = 0
    local foundPosition = false
    local buildX, buildY
    
    -- Try to find a valid position
    while attempts < maxAttempts and not foundPosition do
        -- Random position near village within building distance
        local angle = math.random() * math.pi * 2
        local distance = math.random(30, Config.MAX_BUILD_DISTANCE * 0.8)
        
        buildX = village.x + math.cos(angle) * distance
        buildY = village.y + math.sin(angle) * distance
        
        -- Check if position is valid
        local isValidPosition = game.map:isWithinBounds(buildX, buildY) and
                                game.map:canBuildAt(buildX, buildY) and
                                game.map:isPositionClearOfBuildings(buildX, buildY, game)
        
        -- Special case for fishing huts: must be adjacent to water
        if buildingType == "fishing_hut" then
            foundPosition = isValidPosition and game.map:isAdjacentToWater(buildX, buildY)
        else
            foundPosition = isValidPosition
        end
        
        attempts = attempts + 1
    end
    
    -- If we couldn't find a good spot, try more specialized search methods
    if not foundPosition then
        if buildingType == "fishing_hut" then
            -- For fishing huts, try to find a spot near water
            -- Using a builder instance for these method calls
            local builderInstance = Builder.new(village.x, village.y, village.id)
            buildX, buildY = builderInstance:findNonOverlappingWaterEdge(game, village.x, village.y)
        else
            -- For other buildings, try a more systematic search
            -- Using a builder instance for these method calls
            local builderInstance = Builder.new(village.x, village.y, village.id)
            buildX, buildY = builderInstance:findNonOverlappingBuildPosition(game, village.x, village.y)
        end
    end
    
    return buildX, buildY
end

-- Calculate path to destination avoiding water
function Builder:calculatePath(game, destX, destY)
    -- Find a path avoiding water
    local tilePath = game.map:findPathAvoidingWater(self.x, self.y, destX, destY)
    
    -- Convert tile path to world coordinates
    self.path = game.map:pathToWorldCoordinates(tilePath)
    self.currentPathIndex = 1
    
    -- If no path found, show warning
    if not self.path then
        -- Try finding a buildable position near the destination
        local nearestX, nearestY = game.map:findNearestBuildablePosition(destX, destY)
        if nearestX and nearestY then
            -- Try path to nearest buildable position
            tilePath = game.map:findPathAvoidingWater(self.x, self.y, nearestX, nearestY)
            self.path = game.map:pathToWorldCoordinates(tilePath)
            self.currentPathIndex = 1
            
            -- Update target to the nearest buildable position
            self.targetX = nearestX
            self.targetY = nearestY
        end
        
        -- If still no path, unable to reach destination
        if not self.path then
            require("ui").showMessage("Builder can't find a path to destination, avoiding water")
            return false
        end
    end
    
    return true
end

-- Move along the calculated path
function Builder:moveAlongPath(game, dt)
    -- If no path or we're at the end of the path, we're done
    if not self.path or self.currentPathIndex > #self.path then
        return true -- Arrived at destination
    end
    
    -- Get current waypoint
    local currentWaypoint = self.path[self.currentPathIndex]
    
    -- Move toward current waypoint
    local speed = self:getMovementSpeed(game)
    local arrived = Utils.moveToward(self, currentWaypoint.x, currentWaypoint.y, speed, dt)
    
    if arrived then
        -- Move to next waypoint
        self.currentPathIndex = self.currentPathIndex + 1
        
        -- If we've reached the end of the path, we're done
        if self.currentPathIndex > #self.path then
            return true
        end
    end
    
    return false -- Not arrived at final destination yet
end

-- Helper method to check if a position has forests nearby
function Builder:hasNearbyForests(game, x, y, radius)
    radius = radius or 100 -- Default check radius
    local tileRadius = math.ceil(radius / game.map.tileSize)
    local tileX, tileY = game.map:worldToTile(x, y)
    
    -- Check surrounding tiles for forests
    local forestCount = 0
    for dy = -tileRadius, tileRadius do
        for dx = -tileRadius, tileRadius do
            local checkX, checkY = tileX + dx, tileY + dy
            if checkX >= 1 and checkY >= 1 and checkX <= game.map.width and checkY <= game.map.height then
                -- Calculate distance to check for circular radius
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= tileRadius then
                    if game.map:getTileType(checkX, checkY) == game.map.TILE_FOREST then
                        forestCount = forestCount + 1
                    end
                end
            end
        end
    end
    
    return forestCount >= 5 -- Need at least 5 forest tiles nearby
end

-- Find a position near forest for lumberyard
function Builder:findNearForestPosition(game, startX, startY)
    local maxSearchRadius = 250 -- How far to search from village
    local searchStep = 20
    local bestPosition = nil
    local bestScore = 0
    
    -- Search in expanding circles
    for radius = 40, maxSearchRadius, searchStep do
        for angle = 0, 2 * math.pi, math.pi / 8 do
            local x = startX + math.cos(angle) * radius
            local y = startY + math.sin(angle) * radius
            
            -- Check if this position is valid
            if game.map:isWithinBounds(x, y) and 
               game.map:canBuildAt(x, y) and
               game.map:isPositionClearOfBuildings(x, y, game) then
                
                -- Count nearby forest tiles
                local tileRadius = 4 -- Check in 4 tile radius
                local tileX, tileY = game.map:worldToTile(x, y)
                local forestCount = 0
                
                for dy = -tileRadius, tileRadius do
                    for dx = -tileRadius, tileRadius do
                        local checkX, checkY = tileX + dx, tileY + dy
                        if checkX >= 1 and checkY >= 1 and 
                           checkX <= game.map.width and checkY <= game.map.height then
                            -- Calculate distance for circular radius
                            local dist = math.sqrt(dx*dx + dy*dy)
                            if dist <= tileRadius and 
                               game.map:getTileType(checkX, checkY) == game.map.TILE_FOREST then
                                forestCount = forestCount + 1
                            end
                        end
                    end
                end
                
                -- Calculate score based on forest count and distance to village
                local distanceScore = 1 - (radius / maxSearchRadius) -- Closer is better
                local forestScore = forestCount / 20 -- More forests are better
                local totalScore = (forestScore * 0.8) + (distanceScore * 0.2) -- Forest count matters more
                
                if forestCount >= 3 and totalScore > bestScore then
                    bestScore = totalScore
                    bestPosition = {x = x, y = y}
                end
            end
        end
    end
    
    if bestPosition then
        return bestPosition.x, bestPosition.y
    end
    
    return nil, nil
end

-- Helper method to find a non-overlapping position near forest for lumberyards
function Builder:findNonOverlappingForestPosition(game, startX, startY)
    local maxSearchRadius = 300
    local searchStep = 15
    local maxPositionsToCheck = 40
    local positionsChecked = 0
    local bestPosition = nil
    local bestForestCount = 0
    
    -- Search in expanding circles
    for radius = 40, maxSearchRadius, searchStep do
        -- Try multiple angles at this radius
        for angle = 0, 2 * math.pi, math.pi / 8 do
            local x = startX + math.cos(angle) * radius
            local y = startY + math.sin(angle) * radius
            
            -- Check if the location is suitable 
            local canBuildHere = game.map:isWithinBounds(x, y) and 
                                 game.map:canBuildAt(x, y) and
                                 game.map:isPositionClearOfBuildings(x, y, game)
            
            if canBuildHere then
                -- Count forest tiles in vicinity
                local forestCount = 0
                local tileRadius = 4 -- Check in 4 tile radius
                local tileX, tileY = game.map:worldToTile(x, y)
                
                for dy = -tileRadius, tileRadius do
                    for dx = -tileRadius, tileRadius do
                        local checkX, checkY = tileX + dx, tileY + dy
                        if checkX >= 1 and checkY >= 1 and 
                           checkX <= game.map.width and checkY <= game.map.height then
                            -- Calculate distance for circular radius
                            local dist = math.sqrt(dx*dx + dy*dy)
                            if dist <= tileRadius and 
                               game.map:getTileType(checkX, checkY) == game.map.TILE_FOREST then
                                forestCount = forestCount + 1
                            end
                        end
                    end
                end
                
                -- Keep track of best position
                if forestCount > bestForestCount then
                    bestForestCount = forestCount
                    bestPosition = {x = x, y = y}
                end
                
                -- If we found a good position with at least 3 forest tiles, return it
                if forestCount >= 3 then
                    return x, y
                end
            end
            
            positionsChecked = positionsChecked + 1
            if positionsChecked >= maxPositionsToCheck then
                break
            end
        end
        
        if positionsChecked >= maxPositionsToCheck then
            break
        end
    end
    
    -- Return the best position we found, even if it's not ideal
    if bestPosition and bestForestCount > 0 then
        return bestPosition.x, bestPosition.y
    end
    
    return nil, nil  -- No suitable position found
end

-- Find a position adjacent to mountains that does not overlap with other buildings
function Builder:findNonOverlappingMountainEdge(game, startX, startY)
    -- First try to use the map's built-in function to find a mountain edge
    local x, y = game.map:findNearestMountainEdge(startX, startY)
    
    if not x or not y then
        return nil, nil -- No mountain edge found
    end
    
    -- Check if this position overlaps with existing buildings
    if not game.map:isPositionClearOfBuildings(x, y, game) then
        -- Try to find an alternative position in expanding circles
        local maxRadius = Config.MAX_BUILD_DISTANCE
        local stepSize = 20
        
        for radius = stepSize, maxRadius, stepSize do
            for angle = 0, 2*math.pi, math.pi/8 do
                local testX = startX + radius * math.cos(angle)
                local testY = startY + radius * math.sin(angle)
                
                -- Check if this position is valid
                if game.map:isWithinBounds(testX, testY) and 
                   game.map:canBuildAt(testX, testY) and
                   game.map:isAdjacentToMountain(testX, testY) and
                   game.map:isPositionClearOfBuildings(testX, testY, game) then
                    return testX, testY
                end
            end
        end
        
        return nil, nil -- No alternative position found
    end
    
    return x, y
end

return Builder 