local Config = require("config")
local Utils = require("utils")
local UI = require("ui")

local Building = {}
Building.__index = Building

function Building.new(x, y, buildingType, villageId)
    local building = setmetatable({
        id = Utils.generateId(),
        x = x,
        y = y,
        type = buildingType,
        villageId = villageId,
        timer = 0,
        workers = {},
        workersNeeded = Config.BUILDING_TYPES[buildingType].workCapacity or 0
    }, Building)
    
    -- House-specific properties
    if buildingType == "house" then
        building.villagerTimer = Config.BUILDING_TYPES.house.spawnTime
        building.villagerCapacity = Config.BUILDING_TYPES.house.villagerCapacity
        building.currentVillagers = 0
    end
    
    return building
end

function Building.update(buildings, game, dt)
    for i, building in ipairs(buildings) do
        -- Houses spawn villagers
        if building.type == "house" then
            building:updateHouse(game, dt)
        else
            -- Resource buildings generate income if they have workers
            building:updateWorkplace(game, dt)
        end
    end
end

function Building:updateHouse(game, dt)
    if self.currentVillagers < self.villagerCapacity then
        -- Find the village
        local village = nil
        for _, v in ipairs(game.villages) do
            if v.id == self.villageId then
                village = v
                break
            end
        end
        
        -- Only spawn villagers if village has population capacity
        if village and village.builderCount + village.villagerCount < village.populationCapacity then
            self.villagerTimer = self.villagerTimer - dt
            if self.villagerTimer <= 0 then
                self.villagerTimer = Config.BUILDING_TYPES.house.spawnTime
                self.currentVillagers = self.currentVillagers + 1
                
                -- Create a new villager
                local VillagerModule = require("entities/villager")
                local spawnX, spawnY = Utils.randomPositionAround(self.x, self.y, 5, 10, game.map)
                local newVillager = VillagerModule.new(
                    spawnX,
                    spawnY,
                    self.villageId,
                    self
                )
                
                table.insert(game.villagers, newVillager)
            end
        end
    end
end

function Building:updateWorkplace(game, dt)
    self.timer = self.timer + dt
    if self.timer >= 1 and #self.workers > 0 then
        self.timer = 0
        local buildingType = Config.BUILDING_TYPES[self.type]
        local productionMultiplier = #self.workers / buildingType.workCapacity
        
        -- Generate income
        game.money = game.money + (buildingType.income * productionMultiplier)
        
        -- Generate resources
        if buildingType.resource then
            game.resources[buildingType.resource] = game.resources[buildingType.resource] + (1 * productionMultiplier)
        end
    end
end

function Building:assignWorker(villager)
    if #self.workers < self.workersNeeded then
        table.insert(self.workers, villager)
        return true
    end
    return false
end

function Building:removeWorker(villager)
    for i, worker in ipairs(self.workers) do
        if worker.id == villager.id then
            table.remove(self.workers, i)
            return true
        end
    end
    return false
end

function Building:draw(UI)
    -- Set color based on building type
    if self.type == "farm" then
        love.graphics.setColor(0.2, 0.8, 0.2)
    elseif self.type == "mine" then
        love.graphics.setColor(0.6, 0.6, 0.6)
    elseif self.type == "lumberyard" then
        love.graphics.setColor(0.6, 0.4, 0.2)
    elseif self.type == "house" then
        love.graphics.setColor(0.9, 0.7, 0.5)
    elseif self.type == "fishing_hut" then
        love.graphics.setColor(0.2, 0.4, 0.8)
    end
    
    -- Draw building
    love.graphics.rectangle("fill", self.x - 10, self.y - 10, 20, 20)
    
    -- Check if we should show information
    local showInfo = UI.infoKeyDown or (UI.hoveredBuilding and UI.hoveredBuilding.id == self.id)
    
    -- Only show text info if building is hovered or info key is down
    if showInfo then
        love.graphics.setColor(1, 1, 1)
        -- Use the entity name font for the building type
        local currentFont = love.graphics.getFont()
        love.graphics.setFont(UI.entityNameFont)
        love.graphics.print(self.type, self.x - 10, self.y - 30)
        love.graphics.setFont(currentFont)
        
        -- Display workers or villagers
        if self.type ~= "house" then
            love.graphics.print(#self.workers .. "/" .. self.workersNeeded, self.x - 10, self.y + 15)
        else
            love.graphics.print(self.currentVillagers .. "/" .. self.villagerCapacity, self.x - 10, self.y + 15)
            
            -- If villager is being produced, show timer
            if self.currentVillagers < self.villagerCapacity then
                local percentDone = 1 - (self.villagerTimer / Config.BUILDING_TYPES.house.spawnTime)
                love.graphics.setColor(0.2, 0.7, 0.9, 0.7)
                love.graphics.rectangle("fill", self.x - 10, self.y + 25, 20 * percentDone, 3)
            end
        end
    end
end

return Building 