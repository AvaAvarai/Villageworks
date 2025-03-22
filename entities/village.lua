local Config = require("config")
local Utils = require("utils")

local Village = {}
Village.__index = Village

function Village.new(x, y)
    local village = setmetatable({
        id = Utils.generateId(),
        x = x,
        y = y,
        builderTimer = 5, -- First builder comes faster
        needsHousing = true,
        needsResources = {}
    }, Village)
    
    return village
end

function Village.update(villages, game, dt)
    for i, village in ipairs(villages) do
        -- Spawn builders based on food availability
        village.builderTimer = village.builderTimer - dt
        if village.builderTimer <= 0 and #game.builders < 20 then
            village.builderTimer = Config.BUILDER_SPAWN_TIME
            
            if game.resources.food >= 5 then
                -- Check if we can spawn a builder
                game.resources.food = game.resources.food - 5
                
                -- Create new builder
                local builder = require("entities/builder").new(
                    village.x + math.random(-20, 20),
                    village.y + math.random(-20, 20),
                    village.id
                )
                table.insert(game.builders, builder)
            end
        end
        
        -- Update village needs
        village:updateNeeds(game)
    end
end

function Village:updateNeeds(game)
    -- Check if village needs houses
    local housesForVillage = 0
    local villagerCount = 0
    
    for _, building in ipairs(game.buildings) do
        if building.villageId == self.id then
            if building.type == "house" then
                housesForVillage = housesForVillage + 1
            end
        end
    end
    
    for _, villager in ipairs(game.villagers) do
        if villager.villageId == self.id then
            villagerCount = villagerCount + 1
        end
    end
    
    -- If less than 1 house per 4 villagers, need housing
    self.needsHousing = housesForVillage * Config.BUILDING_TYPES.house.villagerCapacity < villagerCount + 2
    
    -- Check resource needs
    self.needsResources = {}
    if game.resources.food < 20 then
        table.insert(self.needsResources, "farm")
        table.insert(self.needsResources, "fishing_hut")
    end
    if game.resources.wood < 30 then
        table.insert(self.needsResources, "lumberyard")
    end
    if game.resources.stone < 20 then
        table.insert(self.needsResources, "mine")
    end
end

function Village:draw()
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.circle("fill", self.x, self.y, 15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Village", self.x - 20, self.y - 25)
end

return Village 