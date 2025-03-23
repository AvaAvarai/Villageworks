local Config = require("config")
local Utils = require("utils")

local Villager = {}
Villager.__index = Villager

function Villager.new(x, y, villageId, homeBuilding)
    local villager = setmetatable({
        id = Utils.generateId(),
        x = x,
        y = y,
        villageId = villageId,
        homeBuilding = homeBuilding,
        workplace = nil,
        state = "seeking_work", -- seeking_work, going_to_work, working, returning_home, transporting, building, moving_to_build
        targetX = nil,
        targetY = nil,
        workTimer = 0,
        speed = Config.VILLAGER_SPEED,
        
        -- Resource transport
        carriedResource = nil,
        resourceAmount = 0,
        homeVillage = nil,
        
        -- Pathfinding properties
        path = nil,    -- Calculated path to target
        currentPathIndex = 1, -- Current position in the path
        needsPathRecalculation = false, -- Flag to recalculate path
        
        -- Lumberyard specific properties
        forestTargetX = nil,
        forestTargetY = nil,
        
        -- Builder specific properties
        buildTask = nil,
        buildProgress = 0,
        targetBuilding = nil,
        currentRoad = nil,
        roadPathIndex = 1
    }, Villager)
    
    return villager
end

function Villager.update(villagers, game, dt)
    for i, villager in ipairs(villagers) do
        -- If villager doesn't have home village reference, try to find it
        if not villager.homeVillage then
            for _, village in ipairs(game.villages) do
                if village.id == villager.villageId then
                    villager.homeVillage = village
                    break
                end
            end
        end
        
        -- Update villager based on current state
        if villager.state == "idle" or villager.state == "seeking_work" then
            -- Look for work or building tasks
            villager:findWork(game)
        elseif villager.state == "moving_to_work" or villager.state == "going_to_work" then
            -- Move to target
            if not villager.path or villager.needsPathRecalculation then
                villager:calculatePath(game, villager.targetX, villager.targetY)
                villager.needsPathRecalculation = false
            end
            
            -- Follow the path to work
            local arrived = villager:moveAlongPath(game, dt)
            
            if arrived then
                -- Arrived at workplace
                villager.state = "working"
                villager.path = nil
            end
        elseif villager.state == "working" then
            -- Update workplace production timers
            local productionBuilding = villager.targetBuilding
            if productionBuilding then
                -- Check if this building still exists
                local buildingExists = false
                for _, building in ipairs(game.buildings) do
                    if building.id == productionBuilding.id then
                        buildingExists = true
                        break
                    end
                end
                
                if buildingExists then
                    -- Building still exists, continue working
                    -- Logic for resource production is handled in the building update function
                else
                    -- Building was destroyed, go back to looking for work
                    villager.state = "idle"
                    villager.targetBuilding = nil
                    villager.workingInVillageId = nil
                end
            else
                -- No target building, go back to idle state
                villager.state = "idle"
                villager.workingInVillageId = nil
            end
        elseif villager.state == "transporting" then
            -- Move toward village with resources
            if not villager.path or villager.needsPathRecalculation then
                -- First check if there's a direct valid path
                local path = game.map:findPathAvoidingWater(villager.x, villager.y, villager.targetX, villager.targetY)
                
                -- If no valid path found, set the target to the villager's current position to avoid leaving map
                if not path or #path == 0 then
                    -- Can't find path, just go back to working
                    villager.state = "working"
                    villager.carriedResource = nil
                    villager.resourceAmount = 0
                    
                    -- Show error message
                    local UI = require("ui")
                    UI.showMessage("Villager couldn't find path to transport resources")
                else
                    -- Make sure target coordinates are within map bounds
                    local mapWidth = game.map.width * game.map.tileSize
                    local mapHeight = game.map.height * game.map.tileSize
                    
                    villager.targetX = math.max(0, math.min(villager.targetX, mapWidth))
                    villager.targetY = math.max(0, math.min(villager.targetY, mapHeight))
                    
                    villager:calculatePath(game, villager.targetX, villager.targetY)
                    villager.needsPathRecalculation = false
                end
            end
            
            -- Move along the calculated path only if we have a valid path
            if villager.path and #villager.path > 0 then
                local arrived = villager:moveAlongPath(game, dt)
                
                if arrived then
                    -- Arrived at village, deposit resources
                    if villager.carriedResource and villager.resourceAmount > 0 then
                        -- Add resources to global storage
                        game.resources[villager.carriedResource] = game.resources[villager.carriedResource] + villager.resourceAmount
                        
                        -- Clear carried resources
                        villager.carriedResource = nil
                        villager.resourceAmount = 0
                    end
                    
                    -- ALWAYS go back to work at the original workplace
                    if villager.targetBuilding then
                        -- Go back to workplace
                        villager.state = "going_to_work"
                        villager.targetX = villager.targetBuilding.x
                        villager.targetY = villager.targetBuilding.y
                        villager.path = nil -- Force recalculation of path
                        villager:calculatePath(game, villager.targetX, villager.targetY)
                    else
                        -- Only if somehow we don't have a target building, seek new work
                        villager.state = "seeking_work"
                    end
                end
            else
                -- No valid path, revert to working if we have a workplace
                if villager.targetBuilding then
                    villager.state = "working"
                else
                    villager.state = "seeking_work"
                end
                villager.carriedResource = nil
                villager.resourceAmount = 0
            end
        elseif villager.state == "returning_home" then
            -- Check if we need to calculate a path
            if not villager.path or villager.needsPathRecalculation then
                villager:calculatePath(game, villager.targetX, villager.targetY)
                villager.needsPathRecalculation = false
            end
            
            -- Move along the calculated path
            local arrived = villager:moveAlongPath(game, dt)
            
            if arrived then
                -- Rest for a bit then go back to work
                villager.workTimer = villager.workTimer - 10 -- Rest reduces work timer
                if villager.workTimer <= 0 then
                    villager.workTimer = 0
                    villager.state = "going_to_work"
                    villager.targetX = villager.workplace.x
                    villager.targetY = villager.workplace.y
                end
                
                villager.path = nil -- Clear the path
            end
        elseif villager.state == "moving_to_build" then
            -- Check if we need to calculate a path
            if not villager.path or villager.needsPathRecalculation then
                villager:calculatePath(game, villager.targetX, villager.targetY)
                villager.needsPathRecalculation = false
            end
            
            -- Move along the calculated path
            local arrived = villager:moveAlongPath(game, dt)
            
            if arrived then
                villager.state = "building"
                villager.path = nil -- Clear the path when arrived
            end
        elseif villager.state == "building" then
            -- Build the structure
            villager.buildProgress = villager.buildProgress + dt
            
            if villager.buildTask.type == "build_road" then
                -- Building a road
                if villager.buildProgress >= villager.buildTask.totalWorkNeeded then
                    -- Complete the road
                    local map = require("map")
                    map:completePlannedRoad(villager.buildTask.tileX, villager.buildTask.tileY)
                    
                    -- Reset builder state
                    villager.buildTask = nil
                    villager.state = "seeking_work"
                    villager.buildProgress = 0
                end
            else
                -- Building a normal structure
                local buildingType = Config.BUILDING_TYPES[villager.buildTask.type]
                
                if villager.buildProgress >= buildingType.buildTime then
                    -- Building is complete
                    villager:completeBuilding(game)
                end
            end
        elseif villager.state == "building_road" then
            -- Building a road
            local road = villager.currentRoad
            if road and road.path and #road.path > 0 then
                -- Calculate road building speed
                local buildSpeed = Config.ROAD_BUILD_SPEED * dt
                local tilesBuilt = 0
                local maxTilesBuildable = math.ceil(buildSpeed / game.map.tileSize)
                
                -- Build tiles along the path
                while villager.roadPathIndex <= #road.path and tilesBuilt < maxTilesBuildable do
                    local tileToBuild = road.path[villager.roadPathIndex]
                    
                    -- Convert tile coordinates to world coordinates for builder position
                    local tileWorldX, tileWorldY = game.map:tileToWorld(tileToBuild.x, tileToBuild.y)
                    
                    -- Move builder to tile position
                    local arrived = Utils.moveToward(villager, tileWorldX, tileWorldY, Config.VILLAGER_SPEED, dt)
                    
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
                        villager.roadPathIndex = villager.roadPathIndex + 1
                        
                        -- Update road progress
                        road.buildProgress = villager.roadPathIndex / #road.path
                    else
                        -- If not arrived at current tile, break the loop
                        break
                    end
                end
                
                -- Check if road is complete
                if villager.roadPathIndex > #road.path then
                    road.buildProgress = 1
                    road.isComplete = true
                    
                    -- Ensure all road tiles are properly set on the map
                    road:updateMapTiles(game.map)
                    
                    villager.state = "seeking_work"
                    villager.currentRoad = nil
                    villager.roadPathIndex = 1
                    villager.buildProgress = 0
                end
            else
                -- No road path assigned, reset state
                villager.state = "seeking_work"
                villager.roadPathIndex = 1
            end
        end
        
        -- Check for path recalculation
        if villager.needsPathRecalculation and villager.targetX and villager.targetY then
            villager:calculatePath(game, villager.targetX, villager.targetY)
            villager.needsPathRecalculation = false
        end
    end
end

function Villager:findWork(game)
    -- First check for building tasks - highest priority
    if self:findBuildTask(game) then
        return true
    end
    
    -- Find closest building that needs workers
    local closestBuilding = nil
    local shortestDistance = math.huge
    
    for _, building in ipairs(game.buildings) do
        -- Check if building needs workers
        if building.type ~= "house" and #building.workers < building.workersNeeded then
            local distance = Utils.distance(self.x, self.y, building.x, building.y)
            
            if distance < shortestDistance then
                shortestDistance = distance
                closestBuilding = building
            end
        end
    end
    
    -- If found a building, go to work there
    if closestBuilding then
        self.state = "going_to_work"
        self.targetX = closestBuilding.x
        self.targetY = closestBuilding.y
        self.targetBuilding = closestBuilding
        
        -- Add this villager to the building's worker list
        table.insert(closestBuilding.workers, self)
        
        return true
    end
    
    -- No work available, wander around village
    if math.random() < 0.02 then
        local village = self.homeVillage
        
        if village then
            self.targetX, self.targetY = Utils.randomPositionAround(village.x, village.y, 10, 50)
            self.state = "going_to_work" -- reuse the movement state
        end
    end
    
    return false
end

-- Check if villager is on a road
function Villager:isOnRoad(game)
    local nearestRoad, distance = require("entities/road").findNearestRoad(game.roads, self.x, self.y, 10)
    return nearestRoad ~= nil
end

-- Get movement speed for the villager (faster on roads)
function Villager:getMovementSpeed(game)
    local baseSpeed = Config.VILLAGER_SPEED
    
    -- If villager is building, use builder speed
    if self.state == "building" or self.state == "building_road" or self.state == "moving_to_build" then
        baseSpeed = Config.BUILDER_SPEED
    end
    
    if self:isOnRoad(game) then
        return baseSpeed * Config.ROAD_SPEED_MULTIPLIER
    else
        return baseSpeed
    end
end

-- Calculate path to a destination
function Villager:calculatePath(game, destX, destY)
    -- Make sure destination is within map bounds
    if not game.map:isWithinBounds(destX, destY) then
        -- Destination is off-map, adjust to nearest valid position
        local mapWidth = game.map.width * game.map.tileSize
        local mapHeight = game.map.height * game.map.tileSize
        
        destX = math.max(0, math.min(destX, mapWidth))
        destY = math.max(0, math.min(destY, mapHeight))
    end
    
    -- Use the map's pathfinding function to find a path that avoids water and mountains
    local path = game.map:findPathAvoidingWater(self.x, self.y, destX, destY)
    
    if not path or #path == 0 then
        -- Could not find a path, return to idle state
        self.path = nil
        return false
    end
    
    -- Convert the path to world coordinates
    self.path = game.map:pathToWorldCoordinates(path)
    self.currentPathIndex = 1
    
    return self.path ~= nil
end

-- Move along the calculated path
function Villager:moveAlongPath(game, dt)
    -- If no path or we're at the end of the path, we're done
    if not self.path or #self.path == 0 or not self.currentPathIndex then
        return true -- Arrived at destination
    end
    
    -- Safety check - if currentPathIndex is out of bounds, reset it
    if self.currentPathIndex > #self.path then
        self.currentPathIndex = 1
    end
    
    -- Get current waypoint
    local currentWaypoint = self.path[self.currentPathIndex]
    
    -- Safety check - if waypoint is nil, return true (can't continue)
    if not currentWaypoint then
        return true
    end
    
    -- Safety check - ensure waypoint is within map bounds
    local mapWidth = game.map.width * game.map.tileSize
    local mapHeight = game.map.height * game.map.tileSize
    currentWaypoint.x = math.max(0, math.min(currentWaypoint.x, mapWidth))
    currentWaypoint.y = math.max(0, math.min(currentWaypoint.y, mapHeight))
    
    -- Move toward current waypoint
    local speed = self:getMovementSpeed(game)
    local arrived = Utils.moveToward(self, currentWaypoint.x, currentWaypoint.y, speed, dt)
    
    -- Make sure villager stays within map bounds
    self.x = math.max(0, math.min(self.x, mapWidth))
    self.y = math.max(0, math.min(self.y, mapHeight))
    
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

function Villager:draw()
    -- Base color for villager
    love.graphics.setColor(0.2, 0.6, 0.9)
    
    -- Draw carried resources if transporting
    if self.state == "transporting" and self.carriedResource then
        -- Draw villager with resource
        love.graphics.circle("fill", self.x, self.y, 4)
        
        -- Draw resource indicator
        if self.carriedResource == "food" then
            love.graphics.setColor(0.2, 0.8, 0.2)
        elseif self.carriedResource == "wood" then
            love.graphics.setColor(0.6, 0.4, 0.2)
        elseif self.carriedResource == "stone" then
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        
        love.graphics.circle("fill", self.x, self.y - 6, 2)
        love.graphics.print(self.resourceAmount, self.x + 5, self.y - 8)
    elseif self.state == "building" or self.state == "building_road" then
        -- Draw builder
        love.graphics.setColor(0.8, 0.8, 0)
        love.graphics.circle("fill", self.x, self.y, 4)
        
        -- Draw build progress
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.print(string.format("%.1f", self.buildProgress), self.x + 8, self.y - 8)
    else
        -- Regular villager
        love.graphics.circle("fill", self.x, self.y, 4)
    end
    
    -- Draw line to target if moving
    if self.targetX and self.targetY then
        love.graphics.setColor(0.2, 0.6, 0.9, 0.3)
        love.graphics.line(self.x, self.y, self.targetX, self.targetY)
    end
    
    -- Draw small indicator of state
    local stateColors = {
        seeking_work = {1, 0, 0},
        going_to_work = {1, 0.5, 0},
        working = {0, 1, 0},
        returning_home = {0, 0, 1},
        transporting = {1, 1, 0},
        going_to_forest = {0.6, 0.4, 0.2}, -- Brown for forest harvesting
        building = {0.8, 0.8, 0}, -- Yellow for building
        moving_to_build = {0.9, 0.6, 0.1}, -- Orange for moving to build
        building_road = {0.7, 0.7, 0.2} -- Yellow-green for road building
    }
    
    if stateColors[self.state] then
        love.graphics.setColor(stateColors[self.state])
        love.graphics.circle("fill", self.x, self.y - 6, 2)
    end
    
    -- Show special indicator for lumberyard workers
    if self.workplace and self.workplace.type == "lumberyard" then
        love.graphics.setColor(0.5, 0.3, 0.1)
        love.graphics.rectangle("fill", self.x - 2, self.y - 8, 4, 2)
    end
end

-- Look for work in connected villages
function Villager:lookForWorkInConnectedVillages(game)
    -- First find the village this villager belongs to
    local homeVillage = nil
    for _, v in ipairs(game.villages) do
        if v.id == self.villageId then
            homeVillage = v
            break
        end
    end
    
    if not homeVillage then return end
    
    -- Get all villages connected to the home village
    local connectedVillages = homeVillage:getConnectedVillages(game)
    
    -- Include the home village itself
    table.insert(connectedVillages, homeVillage)
    
    -- Look for buildings that need workers in all connected villages
    for _, village in ipairs(connectedVillages) do
        -- Find buildings in this village that need workers
        for _, building in ipairs(game.buildings) do
            -- Check if building belongs to this village
            if building.villageId == village.id then
                if building.type ~= "house" and #building.workers < building.workersNeeded then
                    -- Check if building is within range of our current village
                    local distance = Utils.distance(self.x, self.y, building.x, building.y)
                    
                    -- Check if this building is close enough or if we can travel via roads
                    local canReach = false
                    
                    if village.id == self.villageId then
                        -- If this is our home village, we can always reach buildings in it
                        canReach = true
                    elseif distance < Config.MAX_WORKER_RANGE then
                        -- If building is close enough, we can reach it directly
                        canReach = true
                    else
                        -- We need to check if villages are connected by roads
                        if self:canReachViaRoads(homeVillage, village, game) then
                            canReach = true
                        end
                    end
                    
                    if canReach then
                        -- Assign this villager to work at this building
                        self.state = "moving_to_work"
                        self.targetX = building.x
                        self.targetY = building.y
                        self.targetBuilding = building
                        
                        -- Add this villager to the building's worker list
                        table.insert(building.workers, self)
                        
                        -- If we're working in a different village, track that
                        self.workingInVillageId = village.id
                        
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Check if a villager can reach a building in another village via roads
function Villager:canReachViaRoads(homeVillage, targetVillage, game)
    -- If villages are the same, always reachable
    if homeVillage.id == targetVillage.id then
        return true
    end
    
    -- Check direct road connection
    return homeVillage:isConnectedTo(targetVillage, game)
end

-- Complete a building when construction is finished
function Villager:completeBuilding(game)
    -- Create the new building
    local BuildingModule = require("entities/building")
    local newBuilding = BuildingModule.new(
        self.buildTask.x,
        self.buildTask.y,
        self.buildTask.type,
        self.villageId
    )
    
    table.insert(game.buildings, newBuilding)
    
    -- Reset builder state
    self.buildTask = nil
    self.buildProgress = 0
    self.state = "seeking_work"
    self.targetX = nil
    self.targetY = nil
end

-- Look for building tasks to handle
function Villager:findBuildTask(game)
    -- First try to find tasks from the global task list - closest task first
    if game.builderTasks and #game.builderTasks > 0 then
        local bestTaskIndex = nil
        local bestDistance = math.huge
        
        -- Find the closest task
        for i, task in ipairs(game.builderTasks) do
            local distance = Utils.distance(self.x, self.y, task.x, task.y)
            if distance < bestDistance then
                bestTaskIndex = i
                bestDistance = distance
            end
        end
        
        -- If found a task, assign it to this villager
        if bestTaskIndex then
            self.buildTask = game.builderTasks[bestTaskIndex]
            table.remove(game.builderTasks, bestTaskIndex)
            
            -- Set target location and state
            self.targetX = self.buildTask.x
            self.targetY = self.buildTask.y
            self.state = "moving_to_build"
            self.buildProgress = 0
            self.needsPathRecalculation = true
            
            return true -- Task found
        end
    end
    
    -- Check for building queues in any village - find closest village first
    local UI = require("ui")
    local closestVillage = nil
    local closestDistance = math.huge
    
    -- Find the closest village
    for _, village in ipairs(game.villages) do
        local distance = Utils.distance(self.x, self.y, village.x, village.y)
        
        if distance < closestDistance and UI.hasQueuedBuildings(village.id) then
            closestDistance = distance
            closestVillage = village
        end
    end
    
    -- If found a village with queued buildings
    if closestVillage then
        local nextBuildingType = UI.getNextQueuedBuilding(closestVillage.id)
        
        if nextBuildingType and Utils.canAfford(game.resources, Config.BUILDING_TYPES[nextBuildingType].cost) then
            -- Find a position to build
            local buildX, buildY = self:findBuildingLocation(game, nextBuildingType, closestVillage)
            
            -- If found a valid position, create the task
            if buildX and buildY then
                -- Create the task
                self.buildTask = {
                    x = buildX,
                    y = buildY,
                    type = nextBuildingType,
                    villageId = closestVillage.id
                }
                
                -- Deduct resources
                Utils.deductResources(game.resources, Config.BUILDING_TYPES[nextBuildingType].cost)
                
                -- Set target location and state
                self.targetX = buildX
                self.targetY = buildY
                self.state = "moving_to_build"
                self.buildProgress = 0
                self.needsPathRecalculation = true
                
                -- Decrement the building from the queue
                UI.decrementBuildingQueue(closestVillage.id, nextBuildingType)
                
                return true
            else
                -- No valid position, return resources
                Utils.addResources(game.resources, Config.BUILDING_TYPES[nextBuildingType].cost)
                UI.decrementBuildingQueue(closestVillage.id, nextBuildingType)
                
                UI.showMessage("Cannot build " .. nextBuildingType .. ": No suitable location found")
            end
        end
    end
    
    -- Check for road needs - find closest unbuilt road
    local nearestRoad = nil
    local minDistance = math.huge
    
    for _, road in ipairs(game.roads) do
        if not road.isComplete then
            -- Calculate position along the road based on current progress
            local roadX = road.startX + (road.endX - road.startX) * road.buildProgress
            local roadY = road.startY + (road.endY - road.startY) * road.buildProgress
            
            local distance = Utils.distance(self.x, self.y, roadX, roadY)
            if distance < minDistance and game.resources.wood >= 10 and game.resources.stone >= 5 then
                minDistance = distance
                nearestRoad = road
            end
        end
    end
    
    if nearestRoad then
        -- Start building this road
        self.currentRoad = nearestRoad
        self.state = "building_road"
        self.roadPathIndex = math.floor(#nearestRoad.path * nearestRoad.buildProgress) + 1
        return true
    end
    
    return false -- No building task found
end

-- Find a suitable location to place a building
function Villager:findBuildingLocation(game, buildingType, targetVillage)
    local village = targetVillage
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
        elseif buildingType == "mine" then
            foundPosition = isValidPosition and game.map:isAdjacentToMountain(buildX, buildY)
        elseif buildingType == "lumberyard" then
            -- Lumberyards should be near forest
            foundPosition = isValidPosition and self:hasNearbyForests(game, buildX, buildY, 100)
        else
            foundPosition = isValidPosition
        end
        
        attempts = attempts + 1
    end
    
    -- If we couldn't find a good spot, try more specialized search methods
    if not foundPosition then
        if buildingType == "fishing_hut" then
            -- For fishing huts, try to find a spot near water
            buildX, buildY = self:findNonOverlappingWaterEdge(game, village.x, village.y)
        elseif buildingType == "mine" then 
            -- For mines, find position next to mountain
            buildX, buildY = self:findNonOverlappingMountainEdge(game, village.x, village.y)
        elseif buildingType == "lumberyard" then
            -- For lumberyards, find position near forest
            buildX, buildY = self:findNonOverlappingForestPosition(game, village.x, village.y)
        else
            -- For other buildings, try a more systematic search
            buildX, buildY = self:findNonOverlappingBuildPosition(game, village.x, village.y)
        end
    end
    
    return buildX, buildY
end

-- Helper method to check if a position has forests nearby
function Villager:hasNearbyForests(game, x, y, radius)
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

-- Helper method to find a non-overlapping position near water for fishing huts
function Villager:findNonOverlappingWaterEdge(game, startX, startY)
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
    
    -- If we couldn't find a position, try finding the nearest water edge directly
    local waterEdgeX, waterEdgeY = game.map:findNearestWaterEdge(startX, startY)
    
    if waterEdgeX and waterEdgeY then
        -- If it's buildable, return it
        if game.map:canBuildAt(waterEdgeX, waterEdgeY) and 
           game.map:isPositionClearOfBuildings(waterEdgeX, waterEdgeY, game) then
            return waterEdgeX, waterEdgeY
        end
    end
    
    return nil, nil  -- No suitable position found
end

-- Helper method to find a non-overlapping position for regular buildings
function Villager:findNonOverlappingBuildPosition(game, startX, startY)
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
    
    return nil, nil  -- No suitable position found
end

-- Find a position adjacent to mountains
function Villager:findNonOverlappingMountainEdge(game, startX, startY)
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
            
            -- Check if the location is suitable for a mine
            local canBuildHere = game.map:isWithinBounds(x, y) and 
                                 game.map:canBuildAt(x, y) and
                                 game.map:isAdjacentToMountain(x, y) and
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
    
    return nil, nil  -- No suitable position found
end

-- Find a position near forest for lumberyard
function Villager:findNonOverlappingForestPosition(game, startX, startY)
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

-- Add a helper function to ensure all worker types handle resource transport consistently
function Villager:transportResourceToVillage(game, resourceType, amount)
    -- Only transport if we have resources to carry
    if amount <= 0 then return false end
    
    -- Find the nearest village to deliver resources to
    local nearestVillage = nil
    local shortestDistance = math.huge
    
    -- Look through all villages to find the nearest one
    for _, village in ipairs(game.villages) do
        local distance = Utils.distance(self.x, self.y, village.x, village.y)
        if distance < shortestDistance then
            shortestDistance = distance
            nearestVillage = village
        end
    end
    
    -- If we found a village, set up to transport resources there
    if nearestVillage then
        self.state = "transporting"
        self.targetX = nearestVillage.x
        self.targetY = nearestVillage.y
        self.carriedResource = resourceType
        self.resourceAmount = amount
        self.path = nil -- Force path recalculation
        self.needsPathRecalculation = true
        return true
    end
    
    return false
end

return Villager