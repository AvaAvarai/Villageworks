local Config = require("config")
local Utils = require("utils")
local VillageNames = require("data/village_names")

local Village = {}
Village.__index = Village

-- Track used names to avoid duplicates
local usedNames = {}

function Village.new(x, y)
    -- Get a unique historical name for this village
    local name = VillageNames.getUniqueName(usedNames)
    usedNames[name] = true
    
    local village = setmetatable({
        id = Utils.generateId(),
        name = name,
        x = x,
        y = y,
        builderTimer = 5, -- First builder comes faster
        needsHousing = true,
        needsResources = {},
        needsRoads = {},  -- Track which villages/buildings we need roads to
        
        -- Population tracking
        maxBuilders = Config.DEFAULT_MAX_BUILDERS,
        builderCount = 0,    -- Current number of builders
        villagerCount = 0,   -- Current number of villagers
        populationCapacity = Config.BASE_POPULATION_CAPACITY,
        
        -- Village status display
        showStats = false,   -- Show population stats on hover
        hoverTimer = 0,      -- For hover effect
        
        -- House tracking
        houseCount = 0,      -- Track how many houses this village has
        populationGrowthRate = 0, -- Track how quickly population is growing
        lastPopulation = 0   -- For calculating growth rate
    }, Village)
    
    return village
end

function Village.update(villages, game, dt)
    for i, village in ipairs(villages) do
        -- Update population counts
        village:updatePopulationCounts(game)
        
        -- Calculate population growth rate
        local currentPopulation = village.builderCount + village.villagerCount
        if village.lastPopulation > 0 then
            village.populationGrowthRate = (currentPopulation - village.lastPopulation) / dt
        end
        village.lastPopulation = currentPopulation
        
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
    self.houseCount = 0
    
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
                self.houseCount = self.houseCount + 1
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
    -- If total population is close to capacity or growing quickly, need housing
    local totalPopulation = self.builderCount + self.villagerCount
    local populationRatio = totalPopulation / self.populationCapacity
    
    -- Need housing if:
    -- 1. Population is above target percentage of capacity
    -- 2. OR population is growing and we have few houses
    -- 3. OR we have no houses at all
    self.needsHousing = (populationRatio >= Config.POPULATION_GROWTH_TARGET) or
                      (self.populationGrowthRate > 0 and self.houseCount < 3) or
                      (self.houseCount == 0)
    
    -- Higher housing need if we're very close to capacity
    if populationRatio > 0.9 then
        self.housingUrgency = "critical"
    elseif populationRatio > 0.7 then
        self.housingUrgency = "high"
    elseif self.needsHousing then
        self.housingUrgency = "normal"
    else
        self.housingUrgency = "low"
    end
    
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
    
    -- Update road needs: clear previous needs
    self.needsRoads = {}
    
    -- Check resource buildings without road connections
    for _, building in ipairs(game.buildings) do
        if building.villageId == self.id and building.type ~= "house" then
            -- Check if we already have a road to this building
            local hasRoad = false
            for _, road in ipairs(game.roads) do
                if (road.startVillageId == self.id and road.endX == building.x and road.endY == building.y) or
                   (road.endVillageId == self.id and road.startX == building.x and road.startY == building.y) then
                    hasRoad = true
                    break
                end
            end
            
            -- If no road exists and building has workers, prioritize building a road
            if not hasRoad and #building.workers > 0 then
                table.insert(self.needsRoads, {
                    type = "building",
                    target = building,
                    priority = #building.workers / building.workersNeeded,
                    x = building.x,
                    y = building.y
                })
            end
        end
    end
    
    -- Check other villages without road connections
    for _, village in ipairs(game.villages) do
        if village.id ~= self.id then
            -- Check if we already have a road to this village
            local hasRoad = false
            for _, road in ipairs(game.roads) do
                if (road.startVillageId == self.id and road.endVillageId == village.id) or
                   (road.startVillageId == village.id and road.endVillageId == self.id) then
                    hasRoad = true
                    break
                end
            end
            
            -- If no road exists and village is within reasonable distance, consider building a road
            if not hasRoad then
                local distance = Utils.distance(self.x, self.y, village.x, village.y)
                if distance <= Config.MAX_BUILD_DISTANCE * 2 then
                    -- Higher priority for closer villages with more population
                    local otherVillagePop = village.builderCount + village.villagerCount
                    local priority = otherVillagePop / (distance / 100)
                    
                    table.insert(self.needsRoads, {
                        type = "village",
                        target = village,
                        priority = priority,
                        x = village.x,
                        y = village.y
                    })
                end
            end
        end
    end
    
    -- Sort road needs by priority (higher first)
    table.sort(self.needsRoads, function(a, b) return a.priority > b.priority end)
end

function Village:draw()
    -- Base village color
    love.graphics.setColor(0, 0.8, 0)
    
    -- Adjust village color based on housing urgency
    if self.housingUrgency == "critical" then
        love.graphics.setColor(0.8, 0.2, 0.2) -- Red for critical housing need
    elseif self.housingUrgency == "high" then
        love.graphics.setColor(0.8, 0.6, 0.1) -- Orange for high housing need
    end
    
    love.graphics.circle("fill", self.x, self.y, 15)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(self.name, self.x - 20, self.y - 25)
    
    -- Draw population information when hovered
    if self.showStats then
        local totalPopulation = self.builderCount + self.villagerCount
        local alpha = math.min(1, self.hoverTimer)
        
        -- Draw background
        love.graphics.setColor(0, 0, 0, 0.7 * alpha)
        love.graphics.rectangle("fill", self.x + 20, self.y - 40, 130, 80)
        
        -- Draw text
        love.graphics.setColor(1, 1, 1, alpha)
        love.graphics.print("Village: " .. self.name, 
            self.x + 25, self.y - 35)
        love.graphics.print("Population: " .. totalPopulation .. "/" .. self.populationCapacity, 
            self.x + 25, self.y - 15)
        love.graphics.print("Builders: " .. self.builderCount .. "/" .. self.maxBuilders, 
            self.x + 25, self.y + 5)
        love.graphics.print("Houses: " .. self.houseCount .. " (+" .. self.houseCount * Config.BUILDING_TYPES.house.villagerCapacity .. " pop)", 
            self.x + 25, self.y + 25)
        
        -- Population bar
        local barWidth = 100
        love.graphics.setColor(0.3, 0.3, 0.3, alpha)
        love.graphics.rectangle("fill", self.x + 25, self.y + 45, barWidth, 8)
        
        -- Filled portion of bar
        local fillPercent = math.min(1, totalPopulation / self.populationCapacity)
        
        -- Color the bar based on how full it is
        if fillPercent > 0.9 then
            love.graphics.setColor(0.8, 0.2, 0.2, alpha) -- Red when nearly full
        elseif fillPercent > 0.7 then
            love.graphics.setColor(0.8, 0.6, 0.1, alpha) -- Yellow when getting full
        else
            love.graphics.setColor(0.2, 0.7, 0.3, alpha) -- Green when plenty of room
        end
        
        love.graphics.rectangle("fill", self.x + 25, self.y + 45, barWidth * fillPercent, 8)
    end
end

return Village 