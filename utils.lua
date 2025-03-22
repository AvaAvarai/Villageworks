local Utils = {}

-- Calculate distance between two points
function Utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Check if there are enough resources for a cost
function Utils.canAfford(resources, cost)
    for resource, amount in pairs(cost) do
        if (resources[resource] or 0) < amount then
            return false
        end
    end
    return true
end

-- Deduct resources based on a cost table
function Utils.deductResources(resources, cost)
    for resource, amount in pairs(cost) do
        resources[resource] = resources[resource] - amount
    end
end

-- Get a random position within a radius of a point
function Utils.randomPositionAround(x, y, minRadius, maxRadius)
    local angle = math.random() * math.pi * 2
    local distance = math.random(minRadius, maxRadius)
    return x + math.cos(angle) * distance, y + math.sin(angle) * distance
end

-- Move an entity toward a target position with a given speed
function Utils.moveToward(entity, targetX, targetY, speed, dt)
    local dx = targetX - entity.x
    local dy = targetY - entity.y
    local dist = Utils.distance(entity.x, entity.y, targetX, targetY)
    
    if dist > 5 then
        entity.x = entity.x + (dx/dist) * speed * dt
        entity.y = entity.y + (dy/dist) * speed * dt
        return false -- not arrived yet
    end
    return true -- arrived at destination
end

-- Generate a unique ID
local nextId = 1
function Utils.generateId()
    local id = nextId
    nextId = nextId + 1
    return id
end

-- Find closest entity based on a filter function
function Utils.findClosest(x, y, entities, filterFn)
    local closest = nil
    local minDist = math.huge
    
    for _, entity in ipairs(entities) do
        if not filterFn or filterFn(entity) then
            local dist = Utils.distance(x, y, entity.x, entity.y)
            if dist < minDist then
                minDist = dist
                closest = entity
            end
        end
    end
    
    return closest, minDist
end

return Utils 