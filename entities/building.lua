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
    
    -- Market-specific properties
    if buildingType == "market" then
        building.traderTimer = Config.BUILDING_TYPES.market.spawnTime
        building.traderCapacity = Config.BUILDING_TYPES.market.traderCapacity
        building.currentTraders = 0
    end
    
    return building
end

function Building.update(buildings, game, dt)
    for i, building in ipairs(buildings) do
        -- Houses spawn villagers
        if building.type == "house" then
            building:updateHouse(game, dt)
        -- Markets spawn traders
        elseif building.type == "market" then
            building:updateMarket(game, dt)
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
        if village and village.villagerCount < village.populationCapacity then
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

function Building:updateMarket(game, dt)
    -- Calculate how many traders are already out from this market
    if game.traders then
        self.currentTraders = 0
        for _, trader in ipairs(game.traders) do
            if trader.marketId == self.id then
                self.currentTraders = self.currentTraders + 1
            end
        end
    end
    
    -- Debug current trader status
    print("Market in " .. game:getVillageName(self.villageId) .. " has " .. self.currentTraders .. "/" .. self.traderCapacity .. " traders")
    
    -- Markets spawn traders if we're below capacity
    if self.currentTraders < self.traderCapacity then
        -- Check if there's at least one other market to trade with
        local hasOtherMarket = false
        local otherMarketCount = 0
        
        for _, building in ipairs(game.buildings) do
            if building.type == "market" and building.id ~= self.id then
                hasOtherMarket = true
                otherMarketCount = otherMarketCount + 1
            end
        end
        
        print("Found " .. otherMarketCount .. " other markets for trading")
        
        -- We allow spawning traders even without other markets for better UX
        -- They'll just return home if no other markets exist
        self.traderTimer = self.traderTimer - dt
        print("Trader timer: " .. self.traderTimer)
        
        if self.traderTimer <= 0 then
            print("Spawning new trader!")
            self.traderTimer = Config.BUILDING_TYPES.market.spawnTime
            self.currentTraders = self.currentTraders + 1
            
            -- Create a new trader
            local TraderModule = require("entities/trader")
            local spawnX, spawnY = Utils.randomPositionAround(self.x, self.y, 5, 10, game.map)
            local newTrader = TraderModule.new(
                spawnX,
                spawnY,
                self.id,    -- Market ID
                self.villageId
            )
            
            -- Make sure the traders table exists
            if not game.traders then
                game.traders = {}
            end
            
            table.insert(game.traders, newTrader)
            
            -- Show a message
            if hasOtherMarket then
                UI.showMessage("Trader sent from " .. game:getVillageName(self.villageId) .. " market to trade with other markets")
            else
                UI.showMessage("Trader exploring from " .. game:getVillageName(self.villageId) .. " market (needs more markets)")
            end
        end
    else
        print("Market already at trader capacity")
    end
end

function Building:updateWorkplace(game, dt)
    self.timer = self.timer + dt
    if self.timer >= 1 and #self.workers > 0 then
        self.timer = 0
        local buildingType = Config.BUILDING_TYPES[self.type]
        local productionMultiplier = #self.workers / buildingType.workCapacity
        
        -- Determine resource type based on building type
        local resourceType = nil
        local resourceAmount = math.floor(1 * productionMultiplier)
        
        if self.type == "farm" or self.type == "Fishery" then
            resourceType = "food"
        elseif self.type == "mine" then
            resourceType = "stone"
        elseif self.type == "Sawmill" then
            resourceType = "wood"
        end
        
        -- If this is a resource building and we have a valid resource amount
        if resourceType and resourceAmount > 0 then
            -- Find a worker that's not already transporting
            for _, worker in ipairs(self.workers) do
                if worker.state == "working" and not worker.carriedResource then
                    -- Find the village this building belongs to
                    local targetVillage = nil
                    for _, village in ipairs(game.villages) do
                        if village.id == self.villageId then
                            targetVillage = village
                            break
                        end
                    end
                    
                    if targetVillage then
                        -- Always store the building reference so worker can return
                        worker.targetBuilding = self
                        
                        -- Assign transport task to this worker using the standardized method
                        worker:transportResourceToVillage(game, resourceType, resourceAmount)
                        
                        -- Only assign one worker per update
                        break
                    end
                end
            end
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
    elseif self.type == "Sawmill" then
        love.graphics.setColor(0.6, 0.4, 0.2)
    elseif self.type == "house" then
        love.graphics.setColor(0.9, 0.7, 0.5)
    elseif self.type == "Fishery" then
        love.graphics.setColor(0.2, 0.4, 0.8)
    elseif self.type == "market" then
        love.graphics.setColor(1, 0.7, 0.1) -- Gold/yellow for market
    end
    
    -- Draw building
    love.graphics.rectangle("fill", self.x - 10, self.y - 10, 20, 20)
end

-- Draw text labels separately so they appear on top of all other elements
function Building:drawText(UI)
    -- Check if we should show information
    local showInfo = UI.showBuildingInfo or (UI.hoveredBuilding and UI.hoveredBuilding.id == self.id)
    
    -- Only show text info if building is hovered or info key is down
    if showInfo then
        love.graphics.setColor(1, 1, 1)
        -- Use the entity name font for the building type
        local currentFont = love.graphics.getFont()
        love.graphics.setFont(UI.entityNameFont)
        local name = self.type
        if self.type == "Fishery" then
            name = "Fishery"
        elseif self.type == "mine" then
            name = "Mine"
        elseif self.type == "Sawmill" then
            name = "Sawmill"
        elseif self.type == "house" then
            name = "House"
        elseif self.type == "farm" then
            name = "Farm"
        elseif self.type == "market" then
            name = "Market"
        end
        
        -- Draw black background behind text for better visibility
        local nameWidth = UI.entityNameFont:getWidth(name)
        local nameHeight = UI.entityNameFont:getHeight()
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.rectangle("fill", self.x - 10, self.y - 30, nameWidth, nameHeight)
        
        -- Draw text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(name, self.x - 10, self.y - 30)
        love.graphics.setFont(currentFont)
        
        -- Display workers or villagers or traders
        if self.type == "house" then
            -- Draw black background behind text
            local countText = self.currentVillagers .. "/" .. self.villagerCapacity
            local countWidth = love.graphics.getFont():getWidth(countText)
            
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", self.x - 10, self.y + 15, countWidth, 15)
            
            -- Draw count text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(countText, self.x - 10, self.y + 15)
            
            -- If villager is being produced, show timer
            if self.currentVillagers < self.villagerCapacity then
                local percentDone = 1 - (self.villagerTimer / Config.BUILDING_TYPES.house.spawnTime)
                love.graphics.setColor(0.2, 0.7, 0.9, 0.7)
                love.graphics.rectangle("fill", self.x - 10, self.y + 25, 20 * percentDone, 3)
            end
        elseif self.type == "market" then
            -- Draw black background behind text
            local countText = self.currentTraders .. "/" .. self.traderCapacity
            local countWidth = love.graphics.getFont():getWidth(countText)
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", self.x - 10, self.y + 15, countWidth, 15)
            
            -- Draw count text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(countText, self.x - 10, self.y + 15)
            
            -- If trader is being produced, show timer
            if self.currentTraders < self.traderCapacity then
                local percentDone = 1 - (self.traderTimer / Config.BUILDING_TYPES.market.spawnTime)
                love.graphics.setColor(1, 0.7, 0.1, 0.25)
                love.graphics.rectangle("fill", self.x - 10, self.y + 25, 20 * percentDone, 3)
            end
        else
            -- Draw black background behind text
            local countText = #self.workers .. "/" .. self.workersNeeded
            local countWidth = love.graphics.getFont():getWidth(countText)
            love.graphics.setColor(0, 0, 0, 0.25)
            love.graphics.rectangle("fill", self.x - 10, self.y + 15, countWidth, 15)
            
            -- Draw count text
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(countText, self.x - 10, self.y + 15)
        end
    end
end

return Building 