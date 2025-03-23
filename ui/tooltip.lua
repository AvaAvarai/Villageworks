local Tooltip = {}

-- Initialize tooltip functionality
function Tooltip.init(UI)
    -- Store reference to the UI object
    Tooltip.UI = UI
    
    -- Initialize tooltip state
    Tooltip.activeTooltip = nil
end

-- Update tooltip state
function Tooltip.update(game)
    Tooltip.activeTooltip = nil
    
    -- Check for building tooltips
    if Tooltip.UI.hoveredBuilding then
        if Tooltip.UI.hoveredBuilding.type == "house" then
            -- Find the village this house belongs to
            local village = nil
            for _, v in ipairs(game.villages) do
                if v.id == Tooltip.UI.hoveredBuilding.villageId then
                    village = v
                    break
                end
            end
            
            local villageText = village and (village.name) or "Unknown village"
            
            Tooltip.activeTooltip = {
                title = "House",
                lines = {
                    "Villagers: " .. Tooltip.UI.hoveredBuilding.currentVillagers .. "/" .. Tooltip.UI.hoveredBuilding.villagerCapacity,
                    "Spawns a new villager every " .. require("config").BUILDING_TYPES.house.spawnTime .. " seconds",
                    "Belongs to: " .. villageText,
                    "+2 population capacity"
                }
            }
        else
            local buildingInfo = require("config").BUILDING_TYPES[Tooltip.UI.hoveredBuilding.type]
            
            Tooltip.activeTooltip = {
                title = Tooltip.UI.hoveredBuilding.type:gsub("^%l", string.upper),
                lines = {
                    "Workers: " .. #Tooltip.UI.hoveredBuilding.workers .. "/" .. Tooltip.UI.hoveredBuilding.workersNeeded,
                    "Produces " .. buildingInfo.resource
                }
            }
            
            -- Add income information if available
            if buildingInfo.income then
                table.insert(Tooltip.activeTooltip.lines, "Produces " .. buildingInfo.income .. " " .. buildingInfo.resource .. " per cycle")
            end
        end
    elseif Tooltip.UI.hoveredVillage then
        -- Create tooltip for villages
        local village = Tooltip.UI.hoveredVillage
        local totalPopulation = village.villagerCount
        
        -- Initialize tooltip
        Tooltip.activeTooltip = {
            title = village.name,
            lines = {
                "Population: " .. totalPopulation .. "/" .. village.populationCapacity
            }
        }
        
        -- Calculate resource production
        local resourceProduction = {
            food = 0,
            wood = 0,
            stone = 0,
            money = 0
        }
        
        for _, building in ipairs(game.buildings) do
            if building.villageId == village.id then
                -- Calculate resource production potential
                local buildingInfo = require("config").BUILDING_TYPES[building.type]
                if buildingInfo then
                    local workersRatio = #building.workers / (buildingInfo.workCapacity or 1)
                    local productivity = math.min(1.0, workersRatio) -- Cap at 100% productivity
                    
                    if buildingInfo.resource then
                        if buildingInfo.resource == "food" then
                            resourceProduction.food = resourceProduction.food + productivity
                        elseif buildingInfo.resource == "wood" then
                            resourceProduction.wood = resourceProduction.wood + productivity
                        elseif buildingInfo.resource == "stone" then
                            resourceProduction.stone = resourceProduction.stone + productivity
                        end
                    end
                    
                    if buildingInfo.income then
                        resourceProduction.money = resourceProduction.money + (buildingInfo.income * productivity)
                    end
                end
            end
        end
        
        -- Add resource production information (just the raw numbers)
        table.insert(Tooltip.activeTooltip.lines, "Money: +$" .. string.format("%.0f", resourceProduction.money))
        table.insert(Tooltip.activeTooltip.lines, "Food: +" .. string.format("%.1f", resourceProduction.food))
        table.insert(Tooltip.activeTooltip.lines, "Wood: +" .. string.format("%.1f", resourceProduction.wood))
        table.insert(Tooltip.activeTooltip.lines, "Stone: +" .. string.format("%.1f", resourceProduction.stone))
    end
end

-- Get the active tooltip
function Tooltip.getActiveTooltip()
    return Tooltip.activeTooltip
end

-- Draw a tooltip at the specified position
function Tooltip.draw(x, y)
    if not Tooltip.activeTooltip then return end
    
    -- Set up dimensions
    local width = 200
    local lineHeight = 20
    local padding = 10
    local height = padding * 2 + lineHeight * (#Tooltip.activeTooltip.lines + 1)
    
    -- Adjust position to keep on screen
    if x + width > love.graphics.getWidth() then
        x = love.graphics.getWidth() - width - 5
    end
    if y + height > love.graphics.getHeight() then
        y = love.graphics.getHeight() - height - 5
    end
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.8)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(Tooltip.UI.font)
    love.graphics.print(Tooltip.activeTooltip.title, x + padding, y + padding)
    
    -- Draw lines
    love.graphics.setFont(Tooltip.UI.smallFont)
    for i, line in ipairs(Tooltip.activeTooltip.lines) do
        love.graphics.print(line, x + padding, y + padding + lineHeight * i)
    end
end

return Tooltip 