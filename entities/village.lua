local Config = require("config")
local Utils = require("utils")
local VillageNames = require("data/village_names")
local UI = require("ui")

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
        villagerTimer = Config.BUILDER_SPAWN_TIME, -- First villager comes after normal timer
        needsHousing = true,
        needsResources = {},
        needsRoads = {},  -- Track which villages/buildings we need roads to
        
        -- Population tracking
        villagerCount = 0,   -- Current number of villagers
        populationCapacity = Config.INITIAL_VILLAGE_POPULATION,
        
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
        local currentPopulation = village.villagerCount
        if village.lastPopulation > 0 then
            village.populationGrowthRate = (currentPopulation - village.lastPopulation) / dt
        end
        village.lastPopulation = currentPopulation
        
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
    self.villagerCount = 0
    -- Start with the base population capacity from config
    self.populationCapacity = Config.INITIAL_VILLAGE_POPULATION
    self.houseCount = 0
    
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

function Village:canAddVillager(game)
    -- Check if we can add more villagers to this village
    local totalPopulation = self.villagerCount
    
    -- If we have population capacity, allow it
    if totalPopulation < self.populationCapacity then
        return true
    end
    
    return false
end

function Village:updateNeeds(game)
    -- Check if village needs houses
    -- If total population is close to capacity or growing quickly, need housing
    local totalPopulation = self.villagerCount
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
                    local otherVillagePop = village.villagerCount
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
    -- Use the entity name font for the village name
    local currentFont = love.graphics.getFont()
    love.graphics.setFont(UI.entityNameFont)
    love.graphics.print(self.name, self.x - 20, self.y - 30)
    love.graphics.setFont(currentFont)
    
    -- Draw population information when hovered
    if self.showStats then
        local totalPopulation = self.villagerCount
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

-- Check if this village is connected to another village via roads
function Village:isConnectedTo(otherVillage, game)
    -- If villages are the same, they are "connected"
    if self.id == otherVillage.id then
        return true
    end
    
    -- Check if there's a completed road between them
    for _, road in ipairs(game.roads) do
        if road.isComplete then
            -- Check if this road connects our two villages
            if (road.startVillageId == self.id and road.endVillageId == otherVillage.id) or
               (road.startVillageId == otherVillage.id and road.endVillageId == self.id) then
                return true
            end
        end
    end
    
    -- For roads that connect to arbitrary points rather than villages,
    -- we need to check if both villages are within building radius of a road endpoint
    for _, road in ipairs(game.roads) do
        if road.isComplete then
            -- Calculate if both villages are within building radius of either road endpoint
            local startDist1 = Utils.distance(road.startX, road.startY, self.x, self.y)
            local startDist2 = Utils.distance(road.startX, road.startY, otherVillage.x, otherVillage.y)
            local endDist1 = Utils.distance(road.endX, road.endY, self.x, self.y)
            local endDist2 = Utils.distance(road.endX, road.endY, otherVillage.x, otherVillage.y)
            
            -- Check if both villages are within building radius of the start point
            if startDist1 <= Config.MAX_BUILD_DISTANCE and startDist2 <= Config.MAX_BUILD_DISTANCE then
                return true
            end
            
            -- Check if both villages are within building radius of the end point
            if endDist1 <= Config.MAX_BUILD_DISTANCE and endDist2 <= Config.MAX_BUILD_DISTANCE then
                return true
            end
            
            -- Check if one village is near the start and the other is near the end
            if (startDist1 <= Config.MAX_BUILD_DISTANCE and endDist2 <= Config.MAX_BUILD_DISTANCE) or
               (startDist2 <= Config.MAX_BUILD_DISTANCE and endDist1 <= Config.MAX_BUILD_DISTANCE) then
                return true
            end
        end
    end
    
    return false
end

-- Get all villages that are connected to this one by roads
function Village:getConnectedVillages(game)
    local connectedVillages = {}
    
    for _, village in ipairs(game.villages) do
        if village.id ~= self.id and self:isConnectedTo(village, game) then
            table.insert(connectedVillages, village)
        end
    end
    
    return connectedVillages
end

return Village 