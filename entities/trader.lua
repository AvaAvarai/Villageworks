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
        wasOnRoad = false,
    }, Trader)
    
    print("Created new trader with ID: " .. trader.id .. " at position: " .. x .. ", " .. y)
    print("Trader belongs to market " .. marketId .. " in village " .. villageId)
    
    return trader
end

-- Update all traders
function Trader.update(traders, game, dt)
    -- TRACK ROAD CHANGES
    if not game.lastRoadCount then
        game.lastRoadCount = #(game.roads or {})
    end
    
    -- Check if roads changed
    local currentRoadCount = #(game.roads or {})
    local roadsChanged = (game.lastRoadCount ~= currentRoadCount)
    game.lastRoadCount = currentRoadCount
    
    -- If roads changed, force all traders to recalculate paths
    if roadsChanged then
        print("Roads changed - forcing traders to recalculate paths")
        for _, t in ipairs(traders) do
            if t.movementInfo then
                t.movementInfo.lastUpdateDist = nil -- Force recalculation
            end
        end
    end
    
    for i = #traders, 1, -1 do
        local trader = traders[i]
        
        -- Calculate distance traveled since last update
        local distanceMoved = Utils.distance(trader.x, trader.y, trader.lastPos.x, trader.lastPos.y)
        trader.travelDistance = trader.travelDistance + distanceMoved
        
        -- Update last position
        trader.lastPos.x = trader.x
        trader.lastPos.y = trader.y
        
        -- FORCE RE-CHECK FOR MARKETS EVERY 5 SECONDS
        if not trader.marketCheckTimer then
            trader.marketCheckTimer = 0
        end
        
        trader.marketCheckTimer = trader.marketCheckTimer + dt
        if trader.marketCheckTimer > 5 then
            trader.marketCheckTimer = 0
            trader.checkedForMarkets = false -- Reset this flag to force recheck
        end
        
        -- Check if there are any foreign markets
        if not trader.checkedForMarkets then
            trader.checkedForMarkets = true
            
            -- Count foreign markets
            local foreignMarketCount = 0
            local homeVillage = trader:getHomeVillage(game)
            
            if homeVillage then
                for _, building in ipairs(game.buildings) do
                    if building.type == "market" and building.id ~= trader.marketId then
                        -- SIMPLIFIED CONNECTION CHECK - just verify both villages exist
                        local targetVillage = trader:getVillageById(game, building.villageId)
                        if targetVillage then
                            -- Consider all other markets as potential targets
                            foreignMarketCount = foreignMarketCount + 1
                            print("Trader " .. trader.id .. " found foreign market in " .. game:getVillageName(targetVillage.id))
                        end
                    end
                end
            end
            
            -- Set flag if no markets to visit
            trader.noForeignMarkets = (foreignMarketCount == 0)
            
            -- If trader was waiting but now has markets, reset state
            if not trader.noForeignMarkets and trader.tradingTimer == math.huge then
                trader.tradingTimer = trader.tradingTime
                print("Trader " .. trader.id .. " detected new foreign market - will start trading")
            end
            
            if trader.noForeignMarkets then
                print("Trader " .. trader.id .. " has no foreign markets to visit - staying at home")
                trader.state = "trading"
                trader.tradingTimer = math.huge -- Stay trading forever
            end
        end
        
        -- FORCE TRADERS TO START SEEKING MARKET IF IDLE
        if not trader.noForeignMarkets and trader.state == "trading" and not trader.hasVisitedForeignMarket and trader.tradingTimer <= 0 then
            trader.state = "seeking_market"
            trader.targetMarketId = nil
            print("Trader " .. trader.id .. " forced to start seeking market")
        end
        
        -- Skip all movement/state changes if no foreign markets
        if trader.noForeignMarkets then
            goto continue
        end
        
        -- Simple stuck detection
        if not trader.stuckCheck then
            trader.stuckCheck = {
                x = trader.x,
                y = trader.y,
                timer = 0
            }
        end
        
        if Utils.distance(trader.x, trader.y, trader.stuckCheck.x, trader.stuckCheck.y) < 1 then
            trader.stuckCheck.timer = trader.stuckCheck.timer + dt
            if trader.stuckCheck.timer > 5 then
                -- Really stuck, reset and nudge position
                trader.stuckCheck.timer = 0
                trader.stuckCheck.x = trader.x
                trader.stuckCheck.y = trader.y
                print("Trader " .. trader.id .. " is stuck, nudging position")
                
                -- Nudge position in a random direction
                for angle = 0, 315, 45 do
                    local radAngle = math.rad(angle)
                    local testX = trader.x + math.cos(radAngle) * 10
                    local testY = trader.y + math.sin(radAngle) * 10
                    
                    -- Check if valid position (not water/mountain)
                    if game.map and game.map:getTileTypeAtWorld(testX, testY) ~= game.map.TILE_WATER and 
                                    game.map:getTileTypeAtWorld(testX, testY) ~= game.map.TILE_MOUNTAIN then
                        trader.x = testX
                        trader.y = testY
                        break
                    end
                end
            end
        else
            trader.stuckCheck.timer = 0
            trader.stuckCheck.x = trader.x
            trader.stuckCheck.y = trader.y
        end
        
        -- STATE MACHINE
        if trader.state == "seeking_market" then
            if not trader.targetMarketId then
                trader:findForeignMarket(game)
                
                -- Failsafe if no foreign market found
                if not trader.targetMarketId or trader.targetMarketId == trader.marketId then
                    print("Trader " .. trader.id .. " found no foreign markets")
                    trader.state = "trading"
                    trader.tradingTimer = trader.tradingTime
                    goto continue  -- Skip to next trader
                end
            end
            
            -- Make sure target market exists
            local targetMarket = trader:getTargetMarket(game)
            if not targetMarket then
                trader.targetMarketId = nil
                goto continue  -- Skip to next iteration
            end
            
            -- Move to market
            trader:moveTowardsTarget(game, dt, targetMarket.x, targetMarket.y)
            
            -- Check if arrived
            local distToTarget = Utils.distance(trader.x, trader.y, targetMarket.x, targetMarket.y)
            if distToTarget < 20 then
                trader.state = "trading"
                trader.tradingTimer = trader.tradingTime
                trader.hasVisitedForeignMarket = true
                print("Trader " .. trader.id .. " arrived at foreign market")
            end
        elseif trader.state == "trading" then
            trader.tradingTimer = trader.tradingTimer - dt
            
            if trader.tradingTimer <= 0 then
                if trader.hasVisitedForeignMarket then
                    -- Head back home
                    trader.state = "returning_home"
                    print("Trader " .. trader.id .. " heading home")
                else
                    -- Find new market
                    trader.state = "seeking_market"
                    trader.targetMarketId = nil
                    print("Trader " .. trader.id .. " looking for market")
                end
            end
        elseif trader.state == "returning_home" then
            -- Get home market
            local homeMarket = trader:getHomeMarket(game)
            if not homeMarket then
                table.remove(traders, i)
                goto continue
            end
            
            -- Move to home market
            trader:moveTowardsTarget(game, dt, homeMarket.x, homeMarket.y)
            
            -- Check if arrived
            local distToHome = Utils.distance(trader.x, trader.y, homeMarket.x, homeMarket.y)
            if distToHome < 20 then
                print("Trader " .. trader.id .. " arrived home")
                
                -- Get money
                if trader.hasVisitedForeignMarket then
                    local moneyEarned = math.floor(trader.travelDistance * trader.rewardMultiplier)
                    game.money = game.money + moneyEarned
                    
                    local UI = require("ui")
                    local homeVillageName = game:getVillageName(trader.villageId)
                    UI.showMessage("Trader returned to " .. homeVillageName .. " with $" .. moneyEarned)
                    
                    trader.rewardMultiplier = math.min(0.5, trader.rewardMultiplier + 0.01)
                    trader.travelDistance = 0
                    trader.hasVisitedForeignMarket = false
                    trader.journeyCount = trader.journeyCount + 1
                end
                
                -- Reset to trading state
                trader.state = "trading"
                trader.tradingTimer = trader.tradingTime
            end
        end
        
        -- Remove if home market gone
        if not trader:getHomeMarket(game) then
            table.remove(traders, i)
        end
        
        ::continue::
    end
end

-- Find a foreign market (in a different village)
function Trader:findForeignMarket(game)
    local bestMarket = nil
    local bestDistance = math.huge
    
    -- Get home village
    local homeVillage = self:getHomeVillage(game)
    if not homeVillage then
        return
    end
    
    print("Trader " .. self.id .. " from " .. game:getVillageName(self.villageId) .. " looking for markets")
    
    -- Find a market in a different village
    for _, building in ipairs(game.buildings) do
        if building.type == "market" then
            -- Skip our own home market
            if building.id == self.marketId then
                goto continue
            end
            
            -- Get target village
            local targetVillage = self:getVillageById(game, building.villageId)
            if not targetVillage then
                goto continue
            end
            
            -- REMOVED CONNECTION CHECK - allow traders to go to any market
            
            print("Found market in " .. game:getVillageName(building.villageId))
            
            -- Calculate distance
            local distance = Utils.distance(self.x, self.y, building.x, building.y)
            
            -- Find closest market
            if distance < bestDistance then
                bestMarket = building
                bestDistance = distance
                self.targetVillageId = building.villageId
            end
            
            ::continue::
        end
    end
    
    -- If found a market, set it as target
    if bestMarket then
        self.targetMarketId = bestMarket.id
        print("Trader " .. self.id .. " targeting market in " .. game:getVillageName(self.targetVillageId))
    else
        -- No foreign markets found
        print("Trader " .. self.id .. " found no foreign markets")
        
        -- Target home market
        self.targetMarketId = self.marketId
        self.state = "trading" 
        self.tradingTimer = self.tradingTime
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

-- Move towards a target position (with road following)
function Trader:moveTowardsTarget(game, dt, targetX, targetY)
    if not targetX or not targetY then
        return
    end
    
    -- Calculate direction to target
    local dx = targetX - self.x
    local dy = targetY - self.y
    local dist = math.sqrt(dx*dx + dy*dy)
    
    if dist < 2 then
        return
    end
    
    -- Fixed movement issues:
    -- 1. Store target to prevent small frame-to-frame variations
    -- 2. Only update direction every 5 game units of movement
    -- 3. Move consistently along road until next direction update
    
    if not self.movementInfo then
        self.movementInfo = {
            lastUpdateDist = 0,
            moveX = dx / dist,
            moveY = dy / dist,
            onRoad = false,
            roadDx = 0,
            roadDy = 0,
            lastRoadCheck = 0 -- Add timer for road checks
        }
    end
    
    -- Update road check timer
    self.movementInfo.lastRoadCheck = self.movementInfo.lastRoadCheck + dt
    
    -- Only recalculate movement if:
    -- 1. We've moved enough distance, OR
    -- 2. It's been at least 1 second since we last checked for roads
    local needsUpdate = (not self.movementInfo.lastUpdateDist) or
                         (math.abs(dist - self.movementInfo.lastUpdateDist) > 5) or
                         (self.movementInfo.lastRoadCheck > 1.0)
    
    if needsUpdate then
        self.movementInfo.lastRoadCheck = 0 -- Reset road check timer
        
        -- Normalize direction
        self.movementInfo.moveX = dx / dist
        self.movementInfo.moveY = dy / dist
        self.movementInfo.lastUpdateDist = dist
        
        -- ENHANCED ROAD DETECTION
        local wasOnRoad = self.movementInfo.onRoad
        self.movementInfo.onRoad = false
        local closestRoad = nil
        local closestDist = 25 -- Increased from 15 to 25 pixels for better detection
        
        -- Check up to 100 units ahead along path for roads
        local checkAheadX = self.x + self.movementInfo.moveX * 100
        local checkAheadY = self.y + self.movementInfo.moveY * 100
        
        for _, road in ipairs(game.roads or {}) do
            -- First check if the road intersects with our future path
            local intersects = Utils.lineSegmentsIntersect(
                self.x, self.y, checkAheadX, checkAheadY,
                road.startX, road.startY, road.endX, road.endY
            )
            
            if intersects then
                -- Road intersects our path, prioritize it
                closestDist = 0
                closestRoad = road
                break
            end
            
            -- Fast midpoint check
            local roadMidX = (road.startX + road.endX) / 2
            local roadMidY = (road.startY + road.endY) / 2
            local roughDist = Utils.distance(self.x, self.y, roadMidX, roadMidY)
            
            if roughDist < 150 then -- Increased search radius
                local dist = Utils.distanceToLine(self.x, self.y, road.startX, road.startY, road.endX, road.endY)
                
                if dist < closestDist then
                    closestDist = dist
                    closestRoad = road
                    
                    if dist < 10 then -- Increased from 5 to 10
                        self.movementInfo.onRoad = true
                    end
                end
            end
        end
        
        -- If we found a road, but weren't on one before, announce it
        if closestRoad and not wasOnRoad and self.movementInfo.onRoad then
            print("Trader " .. self.id .. " found a road to follow!")
        end
        
        -- Calculate direction for movement
        if closestRoad then
            -- Road found - calculate road direction
            local roadDx = closestRoad.endX - closestRoad.startX
            local roadDy = closestRoad.endY - closestRoad.startY
            local roadLength = math.sqrt(roadDx*roadDx + roadDy*roadDy)
            
            if roadLength > 0 then
                -- Normalize road direction
                roadDx = roadDx / roadLength
                roadDy = roadDy / roadLength
                
                -- Store road direction
                self.movementInfo.roadDx = roadDx
                self.movementInfo.roadDy = roadDy
                
                -- If on road, just use road direction
                if self.movementInfo.onRoad then
                    -- Check if road points toward target
                    local dotProduct = roadDx * dx + roadDy * dy
                    
                    if dotProduct >= 0 then
                        -- Use road direction
                        self.movementInfo.moveX = roadDx
                        self.movementInfo.moveY = roadDy
                    else
                        -- Use reverse road direction
                        self.movementInfo.moveX = -roadDx
                        self.movementInfo.moveY = -roadDy
                    end
                else
                    -- If not on road, calculate point on road to move to
                    local t = Utils.projectPointOntoLine(self.x, self.y, closestRoad.startX, closestRoad.startY, closestRoad.endX, closestRoad.endY)
                    local roadPointX = closestRoad.startX + t * (closestRoad.endX - closestRoad.startX)
                    local roadPointY = closestRoad.startY + t * (closestRoad.endY - closestRoad.startY)
                    
                    -- Direction to road
                    local toRoadX = roadPointX - self.x
                    local toRoadY = roadPointY - self.y
                    local toRoadDist = math.sqrt(toRoadX*toRoadX + toRoadY*toRoadY)
                    
                    if toRoadDist > 0.1 then
                        -- Move toward road with a stronger bias
                        self.movementInfo.moveX = toRoadX / toRoadDist
                        self.movementInfo.moveY = toRoadY / toRoadDist
                    end
                end
            end
        end
    end
    
    -- Set speed based on road status
    local moveSpeed = self.speed
    if self.movementInfo.onRoad then
        moveSpeed = moveSpeed * Config.ROAD_SPEED_MULTIPLIER
    end
    
    -- Calculate next position using consistent direction
    local nextX = self.x + self.movementInfo.moveX * moveSpeed * dt
    local nextY = self.y + self.movementInfo.moveY * moveSpeed * dt
    
    -- Check terrain BEFORE moving
    if game.map then
        local nextTileType = game.map:getTileTypeAtWorld(nextX, nextY)
        
        -- Don't walk on water or mountains
        if nextTileType == game.map.TILE_WATER or nextTileType == game.map.TILE_MOUNTAIN then
            -- Try different directions - starting with closest to desired direction
            local angles = {0, 45, 90, 135, 180, 225, 270, 315}
            table.sort(angles, function(a, b)
                local targetAngle = math.deg(math.atan2(self.movementInfo.moveY, self.movementInfo.moveX))
                if targetAngle < 0 then targetAngle = targetAngle + 360 end
                
                local diffA = math.abs((a - targetAngle) % 360)
                if diffA > 180 then diffA = 360 - diffA end
                
                local diffB = math.abs((b - targetAngle) % 360)
                if diffB > 180 then diffB = 360 - diffB end
                
                return diffA < diffB
            end)
            
            for _, angle in ipairs(angles) do
                local radAngle = math.rad(angle)
                local testX = self.x + math.cos(radAngle) * moveSpeed * dt
                local testY = self.y + math.sin(radAngle) * moveSpeed * dt
                
                local testTileType = game.map:getTileTypeAtWorld(testX, testY)
                if testTileType ~= game.map.TILE_WATER and testTileType ~= game.map.TILE_MOUNTAIN then
                    nextX = testX
                    nextY = testY
                    -- Force direction recalculation next frame
                    self.movementInfo.lastUpdateDist = nil
                    break
                end
            end
        end
    end
    
    -- Update position
    self.x = nextX
    self.y = nextY
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

-- Add these utility functions if they don't exist already
if not Utils.distanceToLine then
    -- Calculate shortest distance from point to line segment
    function Utils.distanceToLine(px, py, x1, y1, x2, y2)
        local lineLength = Utils.distance(x1, y1, x2, y2)
        if lineLength == 0 then
            return Utils.distance(px, py, x1, y1)
        end
        
        -- Calculate projection
        local t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / (lineLength * lineLength)
        t = math.max(0, math.min(1, t))
        
        -- Find nearest point on line
        local nearestX = x1 + t * (x2 - x1)
        local nearestY = y1 + t * (y2 - y1)
        
        -- Return distance to nearest point
        return Utils.distance(px, py, nearestX, nearestY)
    end
end

if not Utils.projectPointOntoLine then
    -- Project point onto line and return t parameter (0 to 1 if on segment)
    function Utils.projectPointOntoLine(px, py, x1, y1, x2, y2)
        local lineLength = Utils.distance(x1, y1, x2, y2)
        if lineLength == 0 then
            return 0
        end
        
        -- Calculate projection
        local t = ((px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)) / (lineLength * lineLength)
        return math.max(0, math.min(1, t))
    end
end

if not Utils.findNearestPointOnLine then
    -- Find nearest point on line segment
    function Utils.findNearestPointOnLine(px, py, x1, y1, x2, y2)
        local t = Utils.projectPointOntoLine(px, py, x1, y1, x2, y2)
        
        return {
            x = x1 + t * (x2 - x1),
            y = y1 + t * (y2 - y1)
        }
    end
end

if not Utils.lineSegmentsIntersect then
    function Utils.lineSegmentsIntersect(x1, y1, x2, y2, x3, y3, x4, y4)
        -- Calculate the direction of the lines
        local uA = ((x4-x3)*(y1-y3) - (y4-y3)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1))
        local uB = ((x2-x1)*(y1-y3) - (y2-y1)*(x1-x3)) / ((y4-y3)*(x2-x1) - (x4-x3)*(y2-y1))
        
        -- If uA and uB are between 0-1, lines are colliding
        return (uA >= 0 and uA <= 1 and uB >= 0 and uB <= 1)
    end
end

return Trader 