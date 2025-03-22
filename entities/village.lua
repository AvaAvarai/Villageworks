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
        needsResources = {},
        
        -- Population tracking
        maxBuilders = Config.DEFAULT_MAX_BUILDERS,
        builderCount = 0,    -- Current number of builders
        villagerCount = 0,   -- Current number of villagers
        populationCapacity = Config.BASE_POPULATION_CAPACITY,
        
        -- Village status display
        showStats = false,   -- Show population stats on hover
        hoverTimer = 0       -- For hover effect
    }, Village)
    
    return village
end

function Village.update(villages, game, dt)
    for i, village in ipairs(villages) do
        -- Update population counts
        village:updatePopulationCounts(game)
        
        -- Spawn builders based on food availability and population limits
        village.builderTimer = village.builderTimer - dt
        if village.builderTimer <= 0 and village:canAddBuilder(game) then
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
                
                -- Increment village builder count
                village.builderCount = village.builderCount + 1
            end
        end
        
        -- Update village needs
        village:updateNeeds(game)
        
        -- Update hover timer - convert world position to screen position
        local screenX, screenY = game.camera:worldToScreen(village.x, village.y)
        local mouseX, mouseY = love.mouse.getPosition()
        local mouseDistance = math.sqrt((mouseX - screenX)^2 + (mouseY - screenY)^2)
        
        if mouseDistance < 20 then
            village.showStats = true
            village.hoverTimer = village.hoverTimer + dt
            if village.hoverTimer > 1 then village.hoverTimer = 1 end
        else
            village.showStats = false
            village.hoverTimer = 0
        end
    end
end

function Village:updatePopulationCounts(game)
    -- Reset counts and recalculate
    self.builderCount = 0
    self.villagerCount = 0
    self.populationCapacity = Config.BASE_POPULATION_CAPACITY  -- Base capacity
    
    -- Count builders
    for _, builder in ipairs(game.builders) do
        if builder.villageId == self.id then
            self.builderCount = self.builderCount + 1
        end
    end
    
    -- Count villagers and calculate capacity from houses
    for _, building in ipairs(game.buildings) do
        if building.villageId == self.id then
            if building.type == "house" then
                self.populationCapacity = self.populationCapacity + building.villagerCapacity
            end
        end
    end
    
    for _, villager in ipairs(game.villagers) do
        if villager.villageId == self.id then
            self.villagerCount = self.villagerCount + 1
        end
    end
end

function Village:canAddBuilder(game)
    -- Check if we can add more builders to this village
    local totalPopulation = self.builderCount + self.villagerCount
    
    -- If we haven't reached max builders yet, allow it
    if self.builderCount < self.maxBuilders then
        return true
    end
    
    -- If we have max builders but have population capacity from houses, allow it
    if totalPopulation < self.populationCapacity then
        return true
    end
    
    return false
end

function Village:updateNeeds(game)
    -- Check if village needs houses
    local housesForVillage = 0
    
    for _, building in ipairs(game.buildings) do
        if building.villageId == self.id then
            if building.type == "house" then
                housesForVillage = housesForVillage + 1
            end
        end
    end
    
    -- If total population is close to capacity, need housing
    local totalPopulation = self.builderCount + self.villagerCount
    self.needsHousing = totalPopulation >= self.populationCapacity - 2
    
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
    
    -- Draw population information when hovered
    if self.showStats then
        local totalPopulation = self.builderCount + self.villagerCount
        local alpha = math.min(1, self.hoverTimer)
        
        -- Draw background
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        love.graphics.rectangle("fill", self.x + 20, self.y - 40, 120, 80)
        
        -- Draw text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print("Population: " .. totalPopulation .. "/" .. self.populationCapacity, 
            self.x + 25, self.y - 35)
        love.graphics.print("Builders: " .. self.builderCount .. "/" .. self.maxBuilders, 
            self.x + 25, self.y - 15)
        love.graphics.print("Villagers: " .. self.villagerCount, 
            self.x + 25, self.y + 5)
        
        -- Population bar
        local barWidth = 100
        love.graphics.setColor(0.3, 0.3, 0.3, alpha)
        love.graphics.rectangle("fill", self.x + 25, self.y + 25, barWidth, 8)
        
        -- Filled portion of bar
        local fillPercent = math.min(1, totalPopulation / self.populationCapacity)
        love.graphics.setColor(0.2, 0.7, 0.3, alpha)
        love.graphics.rectangle("fill", self.x + 25, self.y + 25, barWidth * fillPercent, 8)
    end
end

return Village 