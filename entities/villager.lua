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
        
        -- Update based on current state
        if villager.state == "seeking_work" then
            -- Find a workplace that needs workers
            villager:findWork(game)
        elseif villager.state == "going_to_work" then
            -- Check if we need to calculate a path
            if not villager.path or villager.needsPathRecalculation then
                villager:calculatePath(game, villager.targetX, villager.targetY)
                villager.needsPathRecalculation = false
            end
            
            -- Move along the calculated path
            local arrived = villager:moveAlongPath(game, dt)
            
            if arrived then
                villager.state = "working"
                villager.workTimer = 0
                villager.path = nil -- Clear the path
            end
        elseif villager.state == "working" then
            -- Working at workplace
            villager.workTimer = villager.workTimer + dt
            
            -- Special handling for lumberyards - they need to go to forest tiles
            if villager.workplace and villager.workplace.type == "lumberyard" then
                -- First time working at a lumberyard, find a nearby forest
                if not villager.forestTargetX and villager.workTimer < 0.5 then
                    -- Find a forest tile nearby
                    local forestX, forestY = game.map:findNearestForestTile(
                        villager.workplace.x, villager.workplace.y, 
                        Config.LUMBERYARD_HARVEST_RADIUS
                    )
                    
                    if forestX and forestY then
                        -- Save the forest target
                        villager.forestTargetX = forestX
                        villager.forestTargetY = forestY
                        villager.targetX = forestX
                        villager.targetY = forestY
                        villager.state = "going_to_forest" -- New state for moving to forest
                        villager.path = nil -- Force recalculation
                        villager.needsPathRecalculation = true
                    else
                        -- No forest found, reset work timer but stay in working state
                        -- Will try again on next update
                        villager.workTimer = 0
                    end
                end
            elseif villager.workTimer >= Config.RESOURCE_EXTRACT_TIME then
                -- After working for extraction time, transport resources back to village
                -- Determine which resource to carry based on workplace
                local workplace = villager.workplace
                if workplace and workplace.type ~= "house" then
                    local buildingInfo = Config.BUILDING_TYPES[workplace.type]
                    if buildingInfo and buildingInfo.resource then
                        villager.carriedResource = buildingInfo.resource
                        
                        -- Determine resource amount based on whether there's a road connection
                        local villageX = villager.homeVillage and villager.homeVillage.x or 0
                        local villageY = villager.homeVillage and villager.homeVillage.y or 0
                        local hasRoadConnection = require("entities/road").areConnected(
                            game.roads, 
                            workplace.x, workplace.y,
                            villageX, villageY
                        )
                        
                        -- More efficient with roads
                        if hasRoadConnection then
                            villager.resourceAmount = math.ceil(Config.RESOURCE_CARRY_CAPACITY * Config.RESOURCE_BONUS_WITH_ROAD)
                        else
                            villager.resourceAmount = Config.RESOURCE_CARRY_CAPACITY
                        end
                        
                        -- Set target to home village for resource transport
                        if villager.homeVillage then
                            villager.targetX = villager.homeVillage.x
                            villager.targetY = villager.homeVillage.y
                            villager.state = "transporting"
                        else
                            -- Reset if no valid village
                            villager.state = "seeking_work"
                        end
                    end
                else
                    -- Reset for non-resource workplaces
                    villager.workTimer = 0
                    villager.state = "seeking_work"
                end
            end
        elseif villager.state == "going_to_forest" then
            -- Moving to a forest tile to harvest it
            -- Check if we need to calculate a path
            if not villager.path or villager.needsPathRecalculation then
                villager:calculatePath(game, villager.targetX, villager.targetY)
                villager.needsPathRecalculation = false
            end
            
            -- Move along the calculated path
            local arrived = villager:moveAlongPath(game, dt)
            
            if arrived then
                -- Arrived at the forest tile, harvest it
                local tileX, tileY = game.map:worldToTile(villager.targetX, villager.targetY)
                local harvested = game.map:harvestForestTile(tileX, tileY)
                
                if harvested > 0 then
                    -- Successfully harvested, carry wood back to village
                    villager.carriedResource = "wood"
                    villager.resourceAmount = harvested
                    
                    -- Clear forest target
                    villager.forestTargetX = nil
                    villager.forestTargetY = nil
                    
                    -- Set target to home village for resource transport
                    if villager.homeVillage then
                        villager.targetX = villager.homeVillage.x
                        villager.targetY = villager.homeVillage.y
                        villager.state = "transporting"
                    else
                        -- Reset if no valid village
                        villager.state = "seeking_work"
                    end
                else
                    -- Forest not found or already harvested
                    -- Go back to workplace and reset
                    villager.forestTargetX = nil
                    villager.forestTargetY = nil
                    
                    if villager.workplace then
                        villager.targetX = villager.workplace.x
                        villager.targetY = villager.workplace.y
                        villager.state = "going_to_work"
                    else
                        villager.state = "seeking_work"
                    end
                end
                
                villager.path = nil -- Clear the path
            end
        elseif villager.state == "transporting" then
            -- Check if we need to calculate a path
            if not villager.path or villager.needsPathRecalculation then
                villager:calculatePath(game, villager.targetX, villager.targetY)
                villager.needsPathRecalculation = false
            end
            
            -- Move along the calculated path
            local arrived = villager:moveAlongPath(game, dt)
            
            if arrived and villager.carriedResource and villager.resourceAmount > 0 then
                -- Deliver resources to village 
                if game.resources[villager.carriedResource] then
                    game.resources[villager.carriedResource] = game.resources[villager.carriedResource] + villager.resourceAmount
                    
                    -- Also generate some money based on resource type
                    local resourceValue = 0
                    if villager.carriedResource == "food" then resourceValue = 1
                    elseif villager.carriedResource == "wood" then resourceValue = 2
                    elseif villager.carriedResource == "stone" then resourceValue = 3
                    end
                    
                    game.money = game.money + resourceValue
                end
                
                -- Reset carried resources
                villager.carriedResource = nil
                villager.resourceAmount = 0
                
                -- Special handling for lumberyard workers - find new forest
                if villager.workplace and villager.workplace.type == "lumberyard" then
                    -- Reset forest target so we find a new one
                    villager.forestTargetX = nil
                    villager.forestTargetY = nil
                    
                    -- Return to workplace and look for a new forest
                    villager.targetX = villager.workplace.x
                    villager.targetY = villager.workplace.y
                    villager.state = "going_to_work"
                    villager.workTimer = 0 -- Force immediate forest search when arrive
                else
                    -- Return to workplace for non-lumberyard workers
                    if villager.workplace then
                        villager.targetX = villager.workplace.x
                        villager.targetY = villager.workplace.y
                        villager.state = "going_to_work"
                    else
                        villager.state = "seeking_work"
                    end
                end
                
                villager.path = nil -- Clear the path
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
    end
end

function Villager:findWork(game)
    -- Find closest building with job openings
    local closestBuilding = nil
    local minDistance = math.huge
    
    for _, building in ipairs(game.buildings) do
        if building.type ~= "house" and 
           building.villageId == self.villageId and 
           #building.workers < building.workersNeeded then
            
            local dist = Utils.distance(self.x, self.y, building.x, building.y)
            if dist < minDistance then
                minDistance = dist
                closestBuilding = building
            end
        end
    end
    
    if closestBuilding then
        -- Assign work
        if closestBuilding:assignWorker(self) then
            self.workplace = closestBuilding
            self.targetX = closestBuilding.x
            self.targetY = closestBuilding.y
            self.state = "going_to_work"
        end
    else
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

-- Calculate path to destination avoiding water
function Villager:calculatePath(game, destX, destY)
    -- Find a path avoiding water
    local tilePath = game.map:findPathAvoidingWater(self.x, self.y, destX, destY)
    
    -- Convert tile path to world coordinates
    self.path = game.map:pathToWorldCoordinates(tilePath)
    self.currentPathIndex = 1
    
    -- If no path found, try finding a nearby accessible location
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
            return false
        end
    end
    
    return true
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

return Villager 