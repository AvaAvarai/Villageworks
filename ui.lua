local Config = require("config")

local UI = {}

-- Initialize UI resources
function UI.init()
    UI.font = love.graphics.newFont(14)
    UI.bigFont = love.graphics.newFont(20)
    UI.smallFont = love.graphics.newFont(10)
    
    -- UI state
    UI.hoveredBuilding = nil
    UI.selectedBuilding = nil
    UI.showBuildMenu = false
    UI.tooltip = nil
end

-- Update UI state
function UI.update(game, dt)
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Reset hover state
    UI.hoveredBuilding = nil
    
    -- Check if mouse is over a building
    for _, building in ipairs(game.buildings) do
        local screenX, screenY = game.camera:worldToScreen(building.x, building.y)
        local dist = math.sqrt((mouseX - screenX)^2 + (mouseY - screenY)^2)
        
        if dist < 15 then
            UI.hoveredBuilding = building
            break
        end
    end
    
    -- Update tooltip
    UI.tooltip = nil
    if UI.hoveredBuilding then
        if UI.hoveredBuilding.type == "house" then
            UI.tooltip = {
                title = "House",
                lines = {
                    "Villagers: " .. UI.hoveredBuilding.currentVillagers .. "/" .. UI.hoveredBuilding.villagerCapacity,
                    "Spawns a new villager every " .. Config.BUILDING_TYPES.house.spawnTime .. " seconds"
                }
            }
        else
            local buildingInfo = Config.BUILDING_TYPES[UI.hoveredBuilding.type]
            UI.tooltip = {
                title = UI.hoveredBuilding.type:gsub("^%l", string.upper),
                lines = {
                    "Workers: " .. #UI.hoveredBuilding.workers .. "/" .. UI.hoveredBuilding.workersNeeded,
                    "Produces " .. buildingInfo.resource .. " and money",
                    "Income: $" .. buildingInfo.income .. " per cycle"
                }
            }
        end
    end
end

-- Draw the game UI
function UI.draw(game)
    -- Draw top bar
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 40)
    
    -- Draw resources
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.font)
    love.graphics.print("Money: $" .. game.money, 10, 10)
    love.graphics.print("Wood: " .. game.resources.wood, 150, 10)
    love.graphics.print("Stone: " .. game.resources.stone, 250, 10)
    love.graphics.print("Food: " .. game.resources.food, 350, 10)
    love.graphics.print("Builders: " .. #game.builders, 450, 10)
    love.graphics.print("Villages: " .. #game.villages, 550, 10)
    love.graphics.print("Villagers: " .. #game.villagers, 650, 10)
    
    -- Draw tooltip
    if UI.tooltip then
        UI.drawTooltip(UI.tooltip, love.mouse.getX(), love.mouse.getY())
    end
    
    -- Draw build menu if active
    if UI.showBuildMenu then
        UI.drawBuildMenu(game)
    end
    
    -- Draw instructions at bottom
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.smallFont)
    love.graphics.print("Click to place a village ($" .. Config.VILLAGE_COST .. "). Arrow keys to move camera. Scroll to zoom.", 10, love.graphics.getHeight() - 20)
end

-- Draw a tooltip
function UI.drawTooltip(tooltip, x, y)
    -- Set up dimensions
    local width = 200
    local lineHeight = 20
    local padding = 10
    local height = padding * 2 + lineHeight * (#tooltip.lines + 1)
    
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
    love.graphics.setFont(UI.font)
    love.graphics.print(tooltip.title, x + padding, y + padding)
    
    -- Draw lines
    love.graphics.setFont(UI.smallFont)
    for i, line in ipairs(tooltip.lines) do
        love.graphics.print(line, x + padding, y + padding + lineHeight * i)
    end
end

-- Draw the build menu
function UI.drawBuildMenu(game)
    local menuWidth = 300
    local menuHeight = 300
    local x = (love.graphics.getWidth() - menuWidth) / 2
    local y = (love.graphics.getHeight() - menuHeight) / 2
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, menuWidth, menuHeight)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, menuWidth, menuHeight)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.bigFont)
    love.graphics.print("Build Menu", x + 10, y + 10)
    
    -- Draw building options
    love.graphics.setFont(UI.font)
    local yOffset = 60
    
    for buildingType, info in pairs(Config.BUILDING_TYPES) do
        local canAfford = game.resources.wood >= (info.cost.wood or 0) and 
                          game.resources.stone >= (info.cost.stone or 0)
        
        if canAfford then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        
        love.graphics.print(buildingType:gsub("^%l", string.upper), x + 20, y + yOffset)
        love.graphics.print("Wood: " .. (info.cost.wood or 0) .. ", Stone: " .. (info.cost.stone or 0), x + 150, y + yOffset)
        
        yOffset = yOffset + 30
    end
    
    -- Draw close button
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.rectangle("fill", x + menuWidth - 30, y + 10, 20, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("X", x + menuWidth - 24, y + 10)
end

return UI 