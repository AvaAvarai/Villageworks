local Config = require("config")
local Utils = require("utils")

local Trader = {}
Trader.__index = Trader

function Trader.new(x, y, marketId, villageId)
    local trader = setmetatable({
        id = Utils.generateId(),
        x = x,
        y = y,
        speed = Config.VILLAGER_SPEED * 0.8, -- Slightly slower than villagers
        marketId = marketId,     -- The home market this trader belongs to
        villageId = villageId,   -- The home village ID
        targetX = nil,           -- Target X coordinate for movement
        targetY = nil,           -- Target Y coordinate for movement
        targetMarketId = nil,    -- Target foreign market ID
        targetVillageId = nil,   -- Target foreign village ID
        state = "seeking_market", -- Current trader state
        travelDistance = 0,      -- Total distance traveled
        rewardMultiplier = 0.2,  -- Money earned per unit of distance traveled
        journeyCount = 0,        -- Number of successful journeys completed
        lastPos = {x = x, y = y}, -- Last position (for calculating distance)
        tradingTimer = 0,        -- Timer for trading at a market
        tradingTime = 5,         -- How long to spend at a market
        
        -- Visual properties
        hasVisitedForeignMarket = false, -- Whether they've visited a foreign market
        currentPath = nil,
        pathTargetX = nil,
        pathTargetY = nil,
        currentPathIndex = 1,
    }, Trader)
    
    print("Created new trader with ID: " .. trader.id .. " at position: " .. x .. ", " .. y)
    print("Trader belongs to market " .. marketId .. " in village " .. villageId)
    
    return trader
end

-- Update all traders
function Trader.update(traders, game, dt)
    for i = #traders, 1, -1 do
        local trader = traders[i]
        
        -- Calculate distance traveled since last update
        local distanceMoved = Utils.distance(trader.x, trader.y, trader.lastPos.x, trader.lastPos.y)
        trader.travelDistance = trader.travelDistance + distanceMoved
        
        -- Update last position
        trader.lastPos.x = trader.x
        trader.lastPos.y = trader.y
        
        -- Process based on current state
        if trader.state == "seeking_market" then
            -- Find a foreign market building
            if not trader.targetMarketId then
                trader:findForeignMarket(game)
            else
                -- Make sure target market still exists
                local targetMarket = trader:getTargetMarket(game)
                if not targetMarket then
                    -- Target market was destroyed - find a new one
                    trader.targetMarketId = nil
                    trader:findForeignMarket(game)
                else
                    -- Move toward target market building
                    trader:moveTowardsTarget(game, dt)
                    
                    -- Check if reached target market
                    if Utils.distance(trader.x, trader.y, targetMarket.x, targetMarket.y) < 10 then
                        trader.state = "trading"
                        trader.tradingTimer = trader.tradingTime
                        trader.hasVisitedForeignMarket = true
                    end
                end
            end
        elseif trader.state == "trading" then
            -- Spend time trading at the market
            trader.tradingTimer = trader.tradingTimer - dt
            
            -- Add a timeout to avoid getting stuck in trading state
            if trader.tradingTimer <= 0 then
                -- If at foreign market, prepare to return home
                if trader.hasVisitedForeignMarket and trader.targetMarketId ~= trader.marketId then
                    trader.state = "returning_home"
                    -- Clear target so we'll set home market as target
                    trader.targetMarketId = nil
                    trader.targetVillageId = nil
                else
                    -- Done trading at home market, prepare for next journey
                    trader:completeTrade(game)
                end
            end
        elseif trader.state == "returning_home" then
            -- Find home market
            if not trader.targetMarketId then
                trader.targetMarketId = trader.marketId
                trader.targetVillageId = trader.villageId
            end
            
            -- Make sure home market still exists
            local homeMarket = trader:getHomeMarket(game)
            if not homeMarket then
                -- Home market was destroyed - remove trader
                table.remove(traders, i)
                goto continue
            end
            
            -- Move toward home market building
            trader:moveTowardsTarget(game, dt)
            
            -- Check if reached home market
            if Utils.distance(trader.x, trader.y, homeMarket.x, homeMarket.y) < 10 then
                -- If trader is returning from a foreign market with goods,
                -- complete the trade immediately
                if trader.hasVisitedForeignMarket then
                    trader:completeTrade(game)
                else
                    -- Otherwise, just switch to trading state at home
                    trader.state = "trading"
                    trader.tradingTimer = trader.tradingTime
                end
            end
        end
        
        -- If the market building this trader belongs to no longer exists, remove the trader
        if not trader:getHomeMarket(game) then
            table.remove(traders, i)
        end
        
        ::continue::
    end
end

-- Find a foreign market (in a different village)
function Trader:findForeignMarket(game)
    local bestMarket = nil
    local bestScore = -1
    local totalMarkets = 0
    local foreignMarkets = 0
    
    print("Trader is trying to find a foreign market")
    print("Trader's home village: " .. game:getVillageName(self.villageId))
    
    -- Find a market in a different village
    for _, building in ipairs(game.buildings) do
        if building.type == "market" then
            totalMarkets = totalMarkets + 1
            
            -- Skip our own market
            if building.id == self.marketId then
                print("Found our own market, skipping")
                goto continue
            end
            
            print("Checking market in village: " .. game:getVillageName(building.villageId))
            foreignMarkets = foreignMarkets + 1
            
            local distance = Utils.distance(self.x, self.y, building.x, building.y)
            
            -- Prefer markets that are connected by roads
            local homeVillage = self:getHomeVillage(game)
            local targetVillage = self:getVillageById(game, building.villageId)
            
            -- Check if villages are connected (for safer travel)
            local isConnected = homeVillage and targetVillage and 
                                homeVillage:isConnectedTo(targetVillage, game)
            
            print("Distance to this market: " .. distance .. (isConnected and " (connected)" or " (not connected)"))
            
            -- Calculate a score based on distance and connection
            local maxDistance = Config.WORLD_WIDTH / 2
            
            -- Distance score so farther markets get higher scores
            local distanceScore = math.min(distance, maxDistance) / maxDistance
            
            -- Calculate final score - higher is better
            local score = distanceScore
            
            print("Market score: " .. score .. " (higher is better)")
            
            -- Remember the market with the best score
            if score > bestScore then
                bestMarket = building
                bestScore = score
                self.targetVillageId = building.villageId
                print("New best market: " .. game:getVillageName(building.villageId) .. " with score " .. score)
            end
            
            ::continue::
        end
    end
    
    print("Found " .. totalMarkets .. " total markets, " .. foreignMarkets .. " foreign markets")
    
    -- If found a market, set it as target
    if bestMarket then
        self.targetMarketId = bestMarket.id
        print("Selected target market in " .. game:getVillageName(self.targetVillageId) .. " with best score " .. bestScore)
    else
        -- If no foreign market, circle around home and wait for more markets to be built
        self.targetMarketId = self.marketId
        self.state = "returning_home"
        
        -- Find the home village
        local homeVillage = self:getHomeVillage(game)
        if homeVillage then
            -- Set a destination to wander around the village
            local angle = math.random() * 2 * math.pi
            local radius = 50 + math.random() * 30
            self.targetX = homeVillage.x + math.cos(angle) * radius
            self.targetY = homeVillage.y + math.sin(angle) * radius
        end
        
        print("No foreign markets found - will wander near home market")
    end
end

-- Get the trader's home village
function Trader:getHomeVillage(game)
    for _, village in ipairs(game.villages) do
        if village.id == self.villageId then
            return village
        end
    end
    return nil
end

-- Get a village by ID
function Trader:getVillageById(game, villageId)
    for _, village in ipairs(game.villages) do
        if village.id == villageId then
            return village
        end
    end
    return nil
end

-- Get the target market building
function Trader:getTargetMarket(game)
    for _, building in ipairs(game.buildings) do
        if building.id == self.targetMarketId then
            return building
        end
    end
    return nil
end

-- Get the home market building
function Trader:getHomeMarket(game)
    for _, building in ipairs(game.buildings) do
        if building.id == self.marketId then
            return building
        end
    end
    return nil
end

-- Move towards the current target
function Trader:moveTowardsTarget(game, dt)
    -- Get the target market building
    local targetMarket = self:getTargetMarket(game)
    if not targetMarket then
        -- Market might have been removed, find a new one
        self.targetMarketId = nil
        self.currentPath = nil
        return
    end
    
    -- Set the current target to the market's position
    self.targetX = targetMarket.x
    self.targetY = targetMarket.y
    
    -- Ensure game.map exists before trying to use it
    if not game.map then
        return
    end
    
    -- Check if we need to calculate a new path
    if not self.currentPath or #self.currentPath == 0 or
       (self.pathTargetX ~= self.targetX or self.pathTargetY ~= self.targetY) then
        
        -- Calculate a new path using A* algorithm
        -- Ensure positions are valid before pathfinding
        if not self.x or not self.y or not self.targetX or not self.targetY then
            return
        end
        
        local tilePath = game.map:findPathAvoidingWater(self.x, self.y, self.targetX, self.targetY, true, true)
        if tilePath then
            self.currentPath = game.map:pathToWorldCoordinates(tilePath)
            self.pathTargetX = self.targetX
            self.pathTargetY = self.targetY
            self.currentPathIndex = 1
        else
            -- No path found, try direct movement as fallback
            self.currentPath = nil
        end
    end
    
    -- If we have a valid path, follow it
    if self.currentPath and #self.currentPath > 0 and self.currentPathIndex and self.currentPathIndex <= #self.currentPath then
        -- Get the next waypoint
        local waypoint = self.currentPath[self.currentPathIndex]
        if not waypoint or not waypoint.x or not waypoint.y then
            -- Path waypoint is invalid, recalculate path
            self.currentPath = nil
            return
        end
        
        -- Move towards the current waypoint
        local dx = waypoint.x - self.x
        local dy = waypoint.y - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        -- If waypoint reached, move to the next one
        if dist < 5 then
            self.currentPathIndex = self.currentPathIndex + 1
            -- If we reached the end of the path, clear it
            if self.currentPathIndex > #self.currentPath then
                self.currentPath = nil
            end
            return
        end
        
        -- Normalize direction vector
        dx = dx / dist
        dy = dy / dist
        
        -- Check if on a road for speed boost
        local onRoad = false
        for _, road in ipairs(game.roads or {}) do
            -- Check if near road path
            if Utils.isPointNearLine(self.x, self.y, road.startX, road.startY, road.endX, road.endY, 10) then
                onRoad = true
                break
            end
        end
        
        -- Apply road speed multiplier if on a road
        local moveSpeed = self.speed
        if onRoad then
            moveSpeed = moveSpeed * Config.ROAD_SPEED_MULTIPLIER
        end
        
        -- Move towards the waypoint
        self.x = self.x + dx * moveSpeed * dt
        self.y = self.y + dy * moveSpeed * dt
    else
        -- No path found or direct movement fallback
        -- Calculate direction to target
        local dx = self.targetX - self.x
        local dy = self.targetY - self.y
        local dist = math.sqrt(dx*dx + dy*dy)
        
        -- If we've reached the target, stop moving
        if dist < 5 then
            return
        end
        
        -- Normalize direction vector
        dx = dx / dist
        dy = dy / dist
        
        -- Check if on a road for speed boost
        local onRoad = false
        for _, road in ipairs(game.roads or {}) do
            -- Check if near road path
            if Utils.isPointNearLine(self.x, self.y, road.startX, road.startY, road.endX, road.endY, 10) then
                onRoad = true
                break
            end
        end
        
        -- Apply road speed multiplier if on a road
        local moveSpeed = self.speed
        if onRoad then
            moveSpeed = moveSpeed * Config.ROAD_SPEED_MULTIPLIER
        end
        
        -- Calculate next position
        local nextX = self.x + dx * moveSpeed * dt
        local nextY = self.y + dy * moveSpeed * dt
        
        -- Check if next position is on water or mountain
        if game.map then
            local nextTileType = game.map:getTileTypeAtWorld(nextX, nextY)
            
            -- Don't move onto water or mountains
            if nextTileType == game.map.TILE_WATER or nextTileType == game.map.TILE_MOUNTAIN then
                -- Force recalculation of path
                self.currentPath = nil
                
                -- Try getting a path with A* again
                local tilePath = game.map:findPathAvoidingWater(self.x, self.y, self.targetX, self.targetY)
                if tilePath then
                    self.currentPath = game.map:pathToWorldCoordinates(tilePath)
                    self.pathTargetX = self.targetX
                    self.pathTargetY = self.targetY
                    self.currentPathIndex = 1
                    return -- Will use path next update
                end
                
                -- No path found, try basic obstacle avoidance
                local canMoveHorizontal = game.map:getTileTypeAtWorld(self.x + dx * moveSpeed * dt, self.y) ~= game.map.TILE_WATER and
                                          game.map:getTileTypeAtWorld(self.x + dx * moveSpeed * dt, self.y) ~= game.map.TILE_MOUNTAIN
                
                local canMoveVertical = game.map:getTileTypeAtWorld(self.x, self.y + dy * moveSpeed * dt) ~= game.map.TILE_WATER and
                                        game.map:getTileTypeAtWorld(self.x, self.y + dy * moveSpeed * dt) ~= game.map.TILE_MOUNTAIN
                
                -- Move along one axis if possible
                if canMoveHorizontal then
                    self.x = self.x + dx * moveSpeed * dt
                end
                
                if canMoveVertical then
                    self.y = self.y + dy * moveSpeed * dt
                end
                
                return
            end
        end
        
        -- Move towards target if terrain is passable
        self.x = nextX
        self.y = nextY
    end
end

-- Complete a trade and earn money based on distance traveled
function Trader:completeTrade(game)
    -- Always go back to seeking market after trading at home
    -- This ensures traders check for new markets periodically
    self.state = "seeking_market"
    self.targetMarketId = nil
    self.targetVillageId = nil
    
    -- Only process journey rewards if trader visited a foreign market
    if self.hasVisitedForeignMarket then
        -- Increment journey count
        self.journeyCount = self.journeyCount + 1
        
        -- Calculate money earned based on distance traveled
        local moneyEarned = math.floor(self.travelDistance * self.rewardMultiplier)
        
        -- Add money to the game's treasury
        game.money = game.money + moneyEarned
        
        -- Increase the reward multiplier with each journey (capped at 0.5)
        self.rewardMultiplier = math.min(0.5, self.rewardMultiplier + 0.01)
        
        -- Get the names of home and target villages for the message
        local homeVillageName = game:getVillageName(self.villageId)
        local targetVillageName = "unknown"
        if self.targetVillageId then
            targetVillageName = game:getVillageName(self.targetVillageId)
        end
        
        -- Display a message with journey count and market info
        local UI = require("ui")
        UI.showMessage("Trader returned to " .. homeVillageName .. " market with $" .. moneyEarned .. " (Journey #" .. self.journeyCount .. ")")
        
        -- Reset trader for the next journey
        self.travelDistance = 0
        self.hasVisitedForeignMarket = false
    end
end

-- Draw the trader
function Trader:draw()
    -- Draw trader as a gold dot with a "caravan" look
    
    -- Draw trader base (larger to be more visible)
    if self.hasVisitedForeignMarket then
        -- Gold/yellow color when carrying profits
        love.graphics.setColor(1, 0.8, 0.2)
    else
        -- Light blue/silver when seeking market
        love.graphics.setColor(0.3, 0.6, 1.0)
    end
    
    -- Draw trader body (make it even larger for better visibility)
    love.graphics.circle("fill", self.x, self.y, 12)
    
    -- Draw a small "hat" or "caravan" marker to distinguish from villagers
    if self.hasVisitedForeignMarket then
        -- Golden hat/bag when returning with profits
        love.graphics.setColor(1, 0.9, 0.3)
    else
        -- Brown/tan hat/bag when traveling to market
        love.graphics.setColor(0.8, 0.6, 0.4)
    end
    
    -- Draw triangle on top like a hat or caravan (larger for visibility)
    love.graphics.polygon("fill", 
        self.x - 8, self.y - 8,
        self.x + 8, self.y - 8,
        self.x, self.y - 18
    )
    
    -- Add outline for better visibility
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", self.x, self.y, 12)
    love.graphics.polygon("line", 
        self.x - 8, self.y - 8,
        self.x + 8, self.y - 8,
        self.x, self.y - 18
    )
    love.graphics.setLineWidth(1)
    
    -- Draw a money symbol above the trader if they've visited a foreign market
    if self.hasVisitedForeignMarket then
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.print("$", self.x - 4, self.y - 25)
    end
    
    -- Draw the path if we have one (for debugging)
    if self.currentPath and #self.currentPath > 0 and self.currentPathIndex and self.currentPathIndex <= #self.currentPath then
        love.graphics.setColor(0, 0.8, 0.8, 0.3)
        love.graphics.setLineWidth(2)
        
        -- Draw line from trader to first waypoint
        local waypoint = self.currentPath[self.currentPathIndex]
        if waypoint and waypoint.x and waypoint.y then
            love.graphics.line(self.x, self.y, waypoint.x, waypoint.y)
            
            -- Draw remaining path
            for i = self.currentPathIndex, #self.currentPath - 1 do
                local current = self.currentPath[i]
                local next = self.currentPath[i+1]
                if current and next and current.x and current.y and next.x and next.y then
                    love.graphics.line(current.x, current.y, next.x, next.y)
                end
            end
        end
        
        love.graphics.setLineWidth(1)
    else
        -- Draw line to target if moving and no path
        if self.targetX and self.targetY then
            love.graphics.setColor(1, 0.8, 0.2, 0.5)
            love.graphics.setLineWidth(2)
            love.graphics.line(self.x, self.y, self.targetX, self.targetY)
            love.graphics.setLineWidth(1)
        end
    end
    
    -- Draw small indicator of state
    local stateColors = {
        seeking_market = {1, 0.8, 0},
        trading = {0, 1, 0},
        returning_home = {0, 0.8, 1}
    }
    
    if stateColors[self.state] then
        love.graphics.setColor(stateColors[self.state])
        love.graphics.circle("fill", self.x, self.y - 18, 4)
    end
end

return Trader 