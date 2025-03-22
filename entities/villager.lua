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
        state = "seeking_work", -- seeking_work, going_to_work, working, going_home
        targetX = nil,
        targetY = nil,
        workTimer = 0
    }, Villager)
    
    return villager
end

function Villager.update(villagers, game, dt)
    for i, villager in ipairs(villagers) do
        if villager.state == "seeking_work" then
            -- Find a workplace that needs workers
            villager:findWork(game)
        elseif villager.state == "going_to_work" then
            -- Move toward workplace
            local arrived = Utils.moveToward(villager, villager.targetX, villager.targetY, Config.VILLAGER_SPEED, dt)
            
            if arrived then
                villager.state = "working"
                villager.workTimer = 0
            end
        elseif villager.state == "working" then
            -- Working at workplace
            villager.workTimer = villager.workTimer + dt
            
            -- Occasionally go home to rest
            if villager.workTimer > 30 and math.random() < 0.01 then
                villager.state = "going_home"
                villager.targetX = villager.homeBuilding.x
                villager.targetY = villager.homeBuilding.y
            end
        elseif villager.state == "going_home" then
            -- Move toward home
            local arrived = Utils.moveToward(villager, villager.targetX, villager.targetY, Config.VILLAGER_SPEED, dt)
            
            if arrived then
                -- Rest for a bit then go back to work
                villager.workTimer = villager.workTimer - 10 -- Rest reduces work timer
                if villager.workTimer <= 0 then
                    villager.workTimer = 0
                    villager.state = "going_to_work"
                    villager.targetX = villager.workplace.x
                    villager.targetY = villager.workplace.y
                end
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

function Villager:draw()
    love.graphics.setColor(0.2, 0.6, 0.9)
    love.graphics.circle("fill", self.x, self.y, 4)
    
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
        going_home = {0, 0, 1}
    }
    
    if stateColors[self.state] then
        love.graphics.setColor(stateColors[self.state])
        love.graphics.circle("fill", self.x, self.y - 6, 2)
    end
end

return Villager 