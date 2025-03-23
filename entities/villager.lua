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
        state = "seeking_work", -- seeking_work, going_to_work, working, returning_home, transporting
        targetX = nil,
        targetY = nil,
        workTimer = 0,
        
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
        forestTargetY = nil
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
        if villager.state == "idle" then
            -- Look for work
            villager:findWork(game)
        elseif villager.state == "moving_to_work" or villager.state == "going_to_work" then
            -- Move to target
            if villager.path then
                villager:followPath(dt, game.map)
            else
                local arrived = Utils.moveToward(villager, villager.targetX, villager.targetY, villager.speed, dt)
                if arrived then
                    if villager.targetBuilding then
                        -- Arrived at workplace
                        villager.state = "working"
                    else
                        -- Was just wandering, go back to idle
                        villager.state = "idle"
                    end
                end
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
        end
        
        -- Check for path recalculation
        if villager.needsPathRecalculation and villager.targetX and villager.targetY then
            villager:calculatePath(game, villager.targetX, villager.targetY)
            villager.needsPathRecalculation = false
        end
    end
end

function Villager:findWork(game)
    -- Look for work in connected villages
    if self:lookForWorkInConnectedVillages(game) then
        return
    end
    
    -- No work available, wander around village
    if math.random() < 0.02 then
        local village = nil
        for _, v in ipairs(game.villages) do
            if v.id == self.villageId then
                village = v
                break
            end
        end
        
        if village then
            self.targetX, self.targetY = Utils.randomPositionAround(village.x, village.y, 10, 50)
            self.state = "going_to_work" -- reuse the movement state
        end
    end
end

-- Check if villager is on a road
function Villager:isOnRoad(game)
    local nearestRoad, distance = require("entities/road").findNearestRoad(game.roads, self.x, self.y, 10)
    return nearestRoad ~= nil
end

-- Get movement speed for the villager (faster on roads)
function Villager:getMovementSpeed(game)
    if self:isOnRoad(game) then
        return Config.VILLAGER_SPEED * Config.ROAD_SPEED_MULTIPLIER
    else
        return Config.VILLAGER_SPEED
    end
end

-- Calculate path to a destination
function Villager:calculatePath(game, destX, destY)
    -- Use the map's pathfinding function to find a path that avoids water and mountains
    local path = game.map:findPathAvoidingWater(self.x, self.y, destX, destY)
    
    -- Convert the path to world coordinates
    self.path = game.map:pathToWorldCoordinates(path)
    self.currentPathIndex = 1
    
    return self.path ~= nil
end

-- Move along the calculated path
function Villager:moveAlongPath(game, dt)
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
        going_to_forest = {0.6, 0.4, 0.2} -- Brown for forest harvesting
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

-- Follow a precalculated path
function Villager:followPath(dt, map)
    if not self.path or #self.path == 0 or not self.currentPathIndex then
        -- No valid path, reset path vars
        self.path = nil
        self.currentPathIndex = nil
        return false
    end
    
    -- Get the current waypoint
    local currentWaypoint = self.path[self.currentPathIndex]
    local waypointX, waypointY = map:tileToWorld(currentWaypoint.x, currentWaypoint.y)
    
    -- Move toward the current waypoint
    local arrived = Utils.moveToward(self, waypointX, waypointY, self.speed, dt)
    
    if arrived then
        -- Move to the next waypoint
        self.currentPathIndex = self.currentPathIndex + 1
        
        -- If we've reached the end of the path
        if self.currentPathIndex > #self.path then
            -- Clear the path
            self.path = nil
            self.currentPathIndex = nil
            return true -- Arrived at destination
        end
    end
    
    return false -- Still following the path
end

return Villager 