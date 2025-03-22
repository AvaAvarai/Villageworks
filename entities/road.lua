local Config = require("config")
local Utils = require("utils")

local Road = {}
Road.__index = Road

function Road.new(startX, startY, endX, endY, startVillageId, endVillageId, buildProgress)
    local road = setmetatable({
        id = Utils.generateId(),
        startX = startX,
        startY = startY,
        endX = endX,
        endY = endY,
        startVillageId = startVillageId,
        endVillageId = endVillageId or nil, -- Can be nil if connecting to a building
        buildProgress = buildProgress or 0,
        isComplete = buildProgress and buildProgress >= 1 or false,
        length = Utils.distance(startX, startY, endX, endY)
    }, Road)
    
    return road
end

function Road.update(roads, game, dt)
    -- Roads don't need much updating after they're built
    -- We could add maintenance requirements later
end

-- Check if a point is near this road (used for movement speed calculations)
function Road:isPointNearRoad(x, y, threshold)
    threshold = threshold or 10
    
    -- If road isn't complete, it doesn't provide a speed boost
    if not self.isComplete then
        return false
    end
    
    -- Calculate distance from point to line segment (road)
    local roadLength = self.length
    if roadLength == 0 then return false end
    
    local t = ((x - self.startX) * (self.endX - self.startX) + (y - self.startY) * (self.endY - self.startY)) / (roadLength * roadLength)
    
    -- If t is outside [0,1], use distance to nearest endpoint
    if t < 0 then
        return Utils.distance(x, y, self.startX, self.startY) < threshold
    elseif t > 1 then
        return Utils.distance(x, y, self.endX, self.endY) < threshold
    end
    
    -- Calculate perpendicular distance to line
    local projX = self.startX + t * (self.endX - self.startX)
    local projY = self.startY + t * (self.endY - self.startY)
    local distance = Utils.distance(x, y, projX, projY)
    
    return distance < threshold
end

-- Find the nearest road to a given point
function Road.findNearestRoad(roads, x, y, threshold)
    threshold = threshold or 10
    local nearestRoad = nil
    local minDistance = threshold
    
    for _, road in ipairs(roads) do
        if road.isComplete then
            -- Calculate distance from point to line segment (road)
            local roadLength = road.length
            if roadLength > 0 then
                local t = ((x - road.startX) * (road.endX - road.startX) + (y - road.startY) * (road.endY - road.startY)) / (roadLength * roadLength)
                
                -- Clamp t to [0,1]
                t = math.max(0, math.min(1, t))
                
                -- Calculate perpendicular distance to line
                local projX = road.startX + t * (road.endX - road.startX)
                local projY = road.startY + t * (road.endY - road.startY)
                local distance = Utils.distance(x, y, projX, projY)
                
                if distance < minDistance then
                    minDistance = distance
                    nearestRoad = road
                end
            end
        end
    end
    
    return nearestRoad, minDistance
end

-- Check if two entities are connected by roads
function Road.areConnected(roads, x1, y1, x2, y2)
    -- This is simplified - a proper implementation would use a graph search
    for _, road in ipairs(roads) do
        if road.isComplete then
            -- Check if road connects start and end points (directly)
            local distStart1 = Utils.distance(x1, y1, road.startX, road.startY)
            local distEnd1 = Utils.distance(x1, y1, road.endX, road.endY)
            local distStart2 = Utils.distance(x2, y2, road.startX, road.startY)
            local distEnd2 = Utils.distance(x2, y2, road.endX, road.endY)
            
            if (distStart1 < 20 and distEnd2 < 20) or (distEnd1 < 20 and distStart2 < 20) then
                return true
            end
        end
    end
    
    return false
end

function Road:draw()
    -- Draw road based on completion status
    if self.isComplete then
        love.graphics.setColor(0.6, 0.6, 0.6)
        love.graphics.setLineWidth(6)
        love.graphics.line(self.startX, self.startY, self.endX, self.endY)
        
        -- Draw line markings
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.setLineWidth(1)
        
        -- Draw dashed line down the center
        local segments = math.floor(self.length / 20)
        local dirX = (self.endX - self.startX) / self.length
        local dirY = (self.endY - self.startY) / self.length
        
        for i = 1, segments do
            local startPos = (i - 1) / segments
            local endPos = (i - 0.5) / segments
            
            local dashStartX = self.startX + dirX * self.length * startPos
            local dashStartY = self.startY + dirY * self.length * startPos
            local dashEndX = self.startX + dirX * self.length * endPos
            local dashEndY = self.startY + dirY * self.length * endPos
            
            love.graphics.line(dashStartX, dashStartY, dashEndX, dashEndY)
        end
    else
        -- Draw incomplete road
        love.graphics.setColor(0.6, 0.6, 0.6, 0.5)
        love.graphics.setLineWidth(3)
        love.graphics.line(self.startX, self.startY, self.endX, self.endY)
        
        -- Draw progress indicator
        local progressX = self.startX + (self.endX - self.startX) * self.buildProgress
        local progressY = self.startY + (self.endY - self.startY) * self.buildProgress
        
        love.graphics.setColor(0.8, 0.8, 0.2)
        love.graphics.circle("fill", progressX, progressY, 4)
    end
    
    -- Reset line width
    love.graphics.setLineWidth(1)
end

return Road 