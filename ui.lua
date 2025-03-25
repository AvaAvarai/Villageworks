local Config = require("config")
local Utils = require("utils")
local Documentation = require("ui.documentation")
local SaveLoad = require("ui.saveload")
local MainMenu = require("ui.mainmenu")
local Roads = require("ui.roads")
local Tooltip = require("ui.tooltip")
local BuildMenu = require("ui.buildmenu")

local UI = {}

-- Initialize UI resources
function UI.init()
    UI.font = love.graphics.newFont(14)
    UI.bigFont = love.graphics.newFont(20)
    UI.mediumFont = love.graphics.newFont(16)
    UI.smallFont = love.graphics.newFont(10)
    UI.titleFont = love.graphics.newFont(48)
    UI.entityNameFont = love.graphics.newFont(16)
    UI.menuFont = love.graphics.newFont(32)
    
    -- Pre-load background image
    UI.backgroundImage = love.graphics.newImage("data/background.png")
    
    -- UI scaling factor for different screen densities
    UI.dpiScale = 1

    -- UI state
    UI.hoveredBuilding = nil
    UI.hoveredVillage = nil
    UI.selectedBuilding = nil
    UI.showBuildMenu = false
    UI.tooltip = nil
    UI.showFPS = false  -- Toggle for FPS display
    UI.showBuildingInfo = false  -- Toggle for building info display
    
    -- FPS tracking
    UI.fps = 0
    UI.fpsUpdateTime = 0
    UI.fpsUpdateInterval = 0.5  -- Update FPS every 0.5 seconds
    UI.fpsFrameCount = 0
    
    -- Hover state for menu buttons
    UI.hoveredButton = nil
    
    -- Message system
    UI.message = nil
    UI.messageTimer = 0
    UI.MESSAGE_DURATION = 3 -- seconds to show messages
    
    -- Menu states
    UI.showMainMenu = true   -- Start with main menu visible
    UI.showPauseMenu = false -- Pause menu initially hidden
    UI.gameRunning = false   -- Game not running until started
    
    -- Initialize modules in the correct order
    MainMenu.init(UI)  -- Initialize MainMenu first
    Documentation.init(UI, MainMenu)  -- Pass MainMenu reference to Documentation
    SaveLoad.init(UI)
    Roads.init(UI)
    Tooltip.init(UI)
    BuildMenu.init(UI)
    
    -- Pause menu options
    UI.pauseMenuOptions = {
        "Resume",
        "Save Game",
        "Exit to Main Menu"
    }
end

-- Update UI state
function UI.update(game, dt)
    -- Update FPS counter
    UI.fpsUpdateTime = UI.fpsUpdateTime + dt
    UI.fpsFrameCount = UI.fpsFrameCount + 1
    
    if UI.fpsUpdateTime >= UI.fpsUpdateInterval then
        UI.fps = math.floor(UI.fpsFrameCount / UI.fpsUpdateTime)
        UI.fpsFrameCount = 0
        UI.fpsUpdateTime = 0
    end
    
    -- Update main menu if showing
    if UI.showMainMenu then
        MainMenu.update(dt)
        return
    end
    
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Reset hover states
    UI.hoveredBuilding = nil
    UI.hoveredVillage = nil
    UI.hoveredButton = nil
    
    -- Handle hover detection for main menu
    if UI.showMainMenu then
        local menuWidth = 300
        local buttonHeight = 60  -- Match the actual button height in drawMainMenu
        local buttonSpacing = 20
        local menuX = (love.graphics.getWidth() - menuWidth) / 2
        local startY = love.graphics.getHeight() / 2 - 50  -- Match position in drawMainMenu
        
        for i, option in ipairs(UI.mainMenuOptions) do
            local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
            
            -- Special case for docs row
            if option == "Docs" then
                -- Check hover for documentation buttons
                local smallButtonWidth = (menuWidth - 20) / 3
                
                for j, docOption in ipairs(UI.docsOptions) do
                    local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                    
                    if mouseX >= docButtonX and mouseX <= docButtonX + smallButtonWidth and
                       mouseY >= buttonY and mouseY <= buttonY + buttonHeight then
                        UI.hoveredButton = "doc_" .. j
                        break
                    end
                end
            elseif mouseX >= menuX and mouseX <= menuX + menuWidth and
                   mouseY >= buttonY and mouseY <= buttonY + buttonHeight then
                UI.hoveredButton = option
                break
            end
        end
    end
    
    -- Check if mouse is over a building
    for _, building in ipairs(game.buildings) do
        local screenX, screenY = game.camera:worldToScreen(building.x, building.y)
        local dist = math.sqrt((mouseX - screenX)^2 + (mouseY - screenY)^2)
        
        if dist < 15 then
            UI.hoveredBuilding = building
            break
        end
    end
    
    -- Check if mouse is over a village
    for _, village in ipairs(game.villages) do
        local screenX, screenY = game.camera:worldToScreen(village.x, village.y)
        local dist = math.sqrt((mouseX - screenX)^2 + (mouseY - screenY)^2)
        
        if dist < 20 then
            UI.hoveredVillage = village
            break
        end
    end
    
    -- Update tooltip through Tooltip module
    Tooltip.update(game)
    
    -- Update road-related state through Roads module
    Roads.update(game, dt)
    
    -- Update message timer
    if UI.message then
        UI.messageTimer = UI.messageTimer - dt
        if UI.messageTimer <= 0 then
            UI.message = nil
        end
    end
end

-- Show a temporary message on screen
function UI.showMessage(text)
    UI.message = text
    UI.messageTimer = UI.MESSAGE_DURATION
end

-- Handle UI clicks
function UI.handleClick(game, x, y)
    -- If main menu is showing, handle main menu clicks
    if UI.showMainMenu then
        -- If load dialog is showing, handle load dialog clicks
        if SaveLoad.showLoadDialog then
            return SaveLoad.handleLoadDialogClick(game, x, y)
        end
        return MainMenu.handleClick(game, x, y, Documentation, SaveLoad)
    end
    
    -- If save dialog is showing, handle save dialog clicks
    if SaveLoad.showSaveDialog then
        return SaveLoad.handleSaveDialogClick(game, x, y)
    end
    
    -- If pause menu is showing, handle pause menu clicks
    if UI.showPauseMenu then
        return UI.handlePauseMenuClick(game, x, y)
    end
    
    -- Check for road creation mode - handle through Roads module
    if Roads.isInRoadCreationMode() then
        return Roads.handleRoadClick(game, x, y)
    end
    
    -- Build menu interactions
    if UI.showBuildMenu then
        return BuildMenu.handleBuildMenuClick(game, x, y)
    end
    
    -- Top bar buttons
    local topBarHeight = 40
    if y < topBarHeight then
        return false -- Let other clicks in the top bar through
    end
    
    -- Check if clicking on a village (when not in build menu already)
    if not UI.showBuildMenu and UI.hoveredVillage then
        -- Save current camera position to prevent repositioning
        local oldCameraX, oldCameraY = game.camera.x, game.camera.y
        
        -- Select this village
        game.selectedVillage = UI.hoveredVillage
        
        -- Open build menu for this village
        UI.showBuildMenu = true
        BuildMenu.showBuildMenu = true
        
        -- Restore camera position to prevent repositioning
        game.camera.x, game.camera.y = oldCameraX, oldCameraY
        
        return true
    end
    
    return false
end

-- Handle main menu clicks
function UI.handleMainMenuClick(game, x, y)
    -- Check if documentation popup is showing and handle its clicks first
    if Documentation.showPopup then
        return Documentation.handleClick(x, y)
    end
    
    -- Handle menu option clicks
    local menuWidth = 300
    local buttonHeight = 60  -- Updated to match the new button height
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 50  -- Updated to match drawMainMenu
    
    for i, option in ipairs(UI.mainMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Special case for docs buttons
        if option == "Docs" then
            -- Check clicks on the three documentation buttons
            local smallButtonWidth = (menuWidth - 20) / 3
            
            for j, docOption in ipairs(UI.docsOptions) do
                local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                
                if x >= docButtonX and x <= docButtonX + smallButtonWidth and
                   y >= buttonY and y <= buttonY + buttonHeight then
                    
                    -- Handle documentation option clicks
                    if docOption == "How to Play" then
                        Documentation.show("howToPlay")
                        return true
                    elseif docOption == "About" then
                        Documentation.show("about")
                        return true
                    elseif docOption == "Changelog" then
                        Documentation.show("changelog")
                        return true
                    end
                end
            end
        elseif x >= menuX and x <= menuX + menuWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            
            -- Handle option selection
            if option == "New Game" then
                UI.showMainMenu = false
                UI.gameRunning = true
                game:reset() -- Reset game state for a new game
                return true
            elseif option == "Load Game" then
                -- Show load dialog and refresh save slots
                SaveLoad.showLoadDialog = true
                SaveLoad.loadSaveFiles() -- Refresh list of saves
                SaveLoad.selectedSaveFile = nil
                SaveLoad.loadDialogScroll = 0 -- Reset scroll position
                return true
            elseif option == "Exit" then
                love.event.quit()
                return true
            end
        end
    end
    
    return true -- Capture all clicks in main menu
end

-- Handle pause menu clicks
function UI.handlePauseMenuClick(game, x, y)
    local menuWidth = 300
    local buttonHeight = 50
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 50
    
    for i, option in ipairs(UI.pauseMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        if x >= menuX and x <= menuX + menuWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            
            -- Handle option selection
            if option == "Resume" then
                UI.showPauseMenu = false
                return true
            elseif option == "Save Game" then
                -- Show save dialog
                SaveLoad.showSaveDialog = true
                SaveLoad.loadSaveFiles() -- Refresh list of saves
                SaveLoad.selectedSaveFile = nil
                UI.showPauseMenu = false
                return true
            elseif option == "Exit to Main Menu" then
                UI.showPauseMenu = false
                UI.showMainMenu = true
                UI.gameRunning = false
                return true
            end
        end
    end
    
    return true -- Capture all clicks in pause menu
end

-- Draw the game UI
function UI.draw(game)
    -- If main menu is showing, draw it and nothing else
    if UI.showMainMenu then
        MainMenu.draw()
        
        -- If load dialog is showing, draw it on top of main menu
        if SaveLoad.showLoadDialog then
            SaveLoad.drawLoadDialog()
        -- If documentation popup is active, draw it on top
        elseif Documentation.showPopup then
            Documentation.drawPopup()
        end
        
        return
    end
    
    -- Draw game world
    game.camera:beginDraw()
    
    -- Draw the map tiles first
    game.map:draw(game.camera)
    
    -- Draw roads first (so they appear behind everything else)
    for _, road in ipairs(game.roads) do
        road:draw()
    end
    
    -- Draw entities in proper order
    drawEntities(game)
    
    -- Draw building radius overlay for hovered village
    if UI.hoveredVillage then
        local buildRadius = UI.hoveredVillage:getBuildRadius()
        
        -- Draw a transparent circle showing the building radius
        love.graphics.setColor(0.3, 0.7, 0.9, 0.15) -- Light blue, mostly transparent
        love.graphics.circle("fill", UI.hoveredVillage.x, UI.hoveredVillage.y, buildRadius)
        
        -- Draw a slightly more visible border
        love.graphics.setColor(0.3, 0.7, 0.9, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", UI.hoveredVillage.x, UI.hoveredVillage.y, buildRadius)
        love.graphics.setLineWidth(1)
        
        -- Label the radius
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("Building Radius", UI.hoveredVillage.x - 50, UI.hoveredVillage.y - buildRadius - 20)
    end

    -- Draw village placement preview if in building mode
    if game.uiMode == Config.UI_MODE_BUILDING_VILLAGE then
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = game.camera:screenToWorld(mouseX, mouseY)
        
        -- Check if position is within map bounds and buildable
        local isValidPosition = game.map:isWithinBounds(worldX, worldY)
        local isBuildable = isValidPosition and game.map:canBuildAt(worldX, worldY)
        
        if isBuildable then
            -- Valid placement position
            love.graphics.setColor(0, 0.8, 0, 0.5)
            love.graphics.circle("fill", worldX, worldY, 15)
            love.graphics.setColor(1, 1, 1, 0.7)
            love.graphics.print("Click to place village", worldX - 60, worldY - 40) 
        else
            -- Invalid placement position
            love.graphics.setColor(0.8, 0, 0, 0.5)
            love.graphics.circle("fill", worldX, worldY, 20) -- Larger circle for emphasis
            love.graphics.setLineWidth(3)
            love.graphics.setColor(1, 0, 0, 0.8)
            love.graphics.circle("line", worldX, worldY, 22) -- Add outline for emphasis
            love.graphics.setLineWidth(1)
            
            -- Draw a more visible warning message
            love.graphics.setColor(1, 0, 0, 0.9)
            
            if not isValidPosition then
                -- Draw a bigger, more obvious warning text
                love.graphics.rectangle("fill", worldX - 100, worldY - 45, 200, 30)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("OUTSIDE MAP BOUNDARIES!", worldX - 90, worldY - 40)
            else
                -- Check if tile is water or mountain and show appropriate message
                local tileType = game.map:getTileTypeAtWorld(worldX, worldY)
                if tileType == game.map.TILE_WATER then
                    love.graphics.rectangle("fill", worldX - 80, worldY - 45, 160, 30)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print("Cannot build on water!", worldX - 70, worldY - 40)
                elseif tileType == game.map.TILE_MOUNTAIN then
                    love.graphics.rectangle("fill", worldX - 85, worldY - 45, 170, 30)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print("Cannot build on mountains!", worldX - 75, worldY - 40)
                end
            end
        end
    end
    
    -- End camera transform
    game.camera:endDraw()

    -- Draw normal game UI
    local hudHeight = math.floor(50 * UI.dpiScale)
    love.graphics.setColor(0.1, 0.1, 0.2, 0.85)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), hudHeight)
    
    -- Add a subtle border at the bottom
    love.graphics.setColor(0.3, 0.3, 0.5, 0.7)
    love.graphics.rectangle("fill", 0, hudHeight - 1, love.graphics.getWidth(), 1)
    
    -- Draw resources with improved styling
    love.graphics.setFont(UI.mediumFont)
    
    -- Calculate available width for resource display
    local screenWidth = love.graphics.getWidth()
    local availableWidth = screenWidth - 40  -- Leave some margin on both sides
    
    -- Count the number of resources we need to display
    local resourceCount = 7  -- Money, Wood, Stone, Food, Builders, Villages, Traders
    
    -- Calculate minimum spacing between resources based on screen width
    local minSpacing = 15 * UI.dpiScale  -- Minimum spacing between items
    local baseSpacing = math.max(minSpacing, (availableWidth / resourceCount) * 0.2)  -- Allocate 20% of item width to spacing
    
    local yPos = math.floor(hudHeight/2 - UI.mediumFont:getHeight()/2)
    local currentXOffset = 20  -- Start with some margin
    
    -- Money display with icon
    love.graphics.setColor(1, 0.9, 0.2)  -- Gold color for money
    local moneyText = "Money: $" .. math.floor(game.money)
    love.graphics.print(moneyText, currentXOffset, yPos)
    currentXOffset = currentXOffset + UI.mediumFont:getWidth(moneyText) + baseSpacing
    
    -- Wood resource
    love.graphics.setColor(0.8, 0.5, 0.2)  -- Brown for wood
    local woodLabel = "Wood: "
    love.graphics.print(woodLabel, currentXOffset, yPos)
    local labelWidth = UI.mediumFont:getWidth(woodLabel)
    love.graphics.setColor(1, 1, 1)
    local woodValue = math.floor(game.resources.wood)
    love.graphics.print(woodValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.mediumFont:getWidth(woodValue) + baseSpacing
    
    -- Stone resource
    love.graphics.setColor(0.6, 0.6, 0.7)  -- Gray for stone
    local stoneLabel = "Stone: "
    love.graphics.print(stoneLabel, currentXOffset, yPos)
    labelWidth = UI.mediumFont:getWidth(stoneLabel)
    love.graphics.setColor(1, 1, 1)
    local stoneValue = math.floor(game.resources.stone)
    love.graphics.print(stoneValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.mediumFont:getWidth(stoneValue) + baseSpacing
    
    -- Food resource
    love.graphics.setColor(0.2, 0.8, 0.3)  -- Green for food
    local foodLabel = "Food: "
    love.graphics.print(foodLabel, currentXOffset, yPos)
    labelWidth = UI.mediumFont:getWidth(foodLabel)
    love.graphics.setColor(1, 1, 1)
    local foodValue = math.floor(game.resources.food)
    love.graphics.print(foodValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.mediumFont:getWidth(foodValue) + baseSpacing
    
    -- Builder count
    love.graphics.setColor(0.3, 0.6, 0.9)  -- Blue for builders
    local builderLabel = "Villagers: "
    love.graphics.print(builderLabel, currentXOffset, yPos)
    labelWidth = UI.mediumFont:getWidth(builderLabel)
    love.graphics.setColor(1, 1, 1)
    local builderValue = #game.villagers
    love.graphics.print(builderValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.mediumFont:getWidth(builderValue) + baseSpacing
    
    -- Village count
    love.graphics.setColor(0.9, 0.3, 0.6)  -- Purple for villages
    local villageLabel = "Villages: "
    love.graphics.print(villageLabel, currentXOffset, yPos)
    labelWidth = UI.mediumFont:getWidth(villageLabel)
    love.graphics.setColor(1, 1, 1)
    local villageValue = #game.villages
    love.graphics.print(villageValue, currentXOffset + labelWidth, yPos)
    
    -- Draw trader count
    love.graphics.setColor(0.3, 0.6, 0.9)  -- Blue for traders
    local traderLabel = "Traders: "
    currentXOffset = currentXOffset + labelWidth + UI.mediumFont:getWidth(villageValue) + baseSpacing
    love.graphics.print(traderLabel, currentXOffset, yPos)
    labelWidth = UI.mediumFont:getWidth(traderLabel)
    love.graphics.setColor(1, 1, 1)
    local traderValue = #game.traders
    love.graphics.print(traderValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.mediumFont:getWidth(traderValue) + baseSpacing
    
    -- Draw FPS counter if enabled
    if UI.showFPS then
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.setFont(UI.smallFont)
        love.graphics.print("FPS: " .. UI.fps, 10, hudHeight + 5)
    end
    
    -- Restore regular color for other UI
    love.graphics.setColor(1, 1, 1)
    
    -- Draw tooltip using Tooltip module
    if Tooltip.getActiveTooltip() then
        Tooltip.draw(love.mouse.getX(), love.mouse.getY())
    end
    
    -- Draw build menu if active
    if UI.showBuildMenu then
        BuildMenu.drawBuildMenu(game)
    end
    
    -- Draw road interface using Roads module
    Roads.draw(game)
    
    -- Draw village building mode indicator
    if game.uiMode == Config.UI_MODE_BUILDING_VILLAGE then
        love.graphics.setColor(0, 0.8, 0)
        love.graphics.setFont(UI.font)
        love.graphics.print("Village Building Mode - Click to place (ESC to cancel)", 
            10, love.graphics.getHeight() - 40)
    end
    
    -- Draw game speed indicator
    if game.gameSpeed > Config.TIME_NORMAL_SPEED then
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.print("FAST FORWARD (x" .. game.gameSpeed .. ")", 10, love.graphics.getHeight() - 40)
    end
    
    -- Draw message if there is one
    if UI.message then
        local msgWidth = love.graphics.getFont():getWidth(UI.message) + 20
        local msgHeight = 30
        local msgX = (love.graphics.getWidth() - msgWidth) / 2
        local msgY = 60
        
        -- Draw message background
        love.graphics.setColor(0, 0, 0, 0.8)
        love.graphics.rectangle("fill", msgX, msgY, msgWidth, msgHeight)
        love.graphics.setColor(1, 0.8, 0.2)
        love.graphics.rectangle("line", msgX, msgY, msgWidth, msgHeight)
        
        -- Draw message text
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(UI.message, msgX + 10, msgY + 8)
    end
    
    -- Draw instructions at bottom
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.smallFont)
    love.graphics.print("Press B for build menu. Press I to toggle information. SPACE to fast forward time. Arrow keys to move camera. Scroll to zoom. ESC to pause.", 
                        10, love.graphics.getHeight() - 20)
    
    -- Draw village summary panel
    if #game.villages > 0 then
        UI.drawVillageSummary(game)
    end
    
    -- Draw pause menu if showing (on top of everything else)
    if UI.showPauseMenu then
        UI.drawPauseMenu()
    end
    
    -- Draw save/load dialogs if showing
    if SaveLoad.showSaveDialog then
        SaveLoad.drawSaveDialog()
    end
    
    if SaveLoad.showLoadDialog then
        SaveLoad.drawLoadDialog()
    end
end

-- Draw the grid
function drawGrid(game)
    love.graphics.setColor(0.2, 0.2, 0.2)
    
    -- Calculate visible grid area
    local startX = math.floor(game.camera.x / Config.TILE_SIZE) * Config.TILE_SIZE
    local startY = math.floor(game.camera.y / Config.TILE_SIZE) * Config.TILE_SIZE
    local endX = startX + (love.graphics.getWidth() / game.camera.scale) + Config.TILE_SIZE
    local endY = startY + (love.graphics.getHeight() / game.camera.scale) + Config.TILE_SIZE
    
    for x = startX, endX, Config.TILE_SIZE do
        for y = startY, endY, Config.TILE_SIZE do
            love.graphics.rectangle("line", x, y, Config.TILE_SIZE, Config.TILE_SIZE)
        end
    end
end

-- Draw all entities
function drawEntities(game)
    -- Draw all buildings (just the sprites, not text)
    for _, building in ipairs(game.buildings) do
        building:draw(UI)
        
        -- Highlight buildings of selected village
        if game.selectedVillage and building.villageId == game.selectedVillage.id then
            love.graphics.setColor(1, 1, 0, 0.2)
            love.graphics.rectangle("line", building.x - 12, building.y - 12, 24, 24)
        end
    end

    -- Draw all villages
    for _, village in ipairs(game.villages) do
        village:draw(game)
    end
    
    -- Draw all villagers
    for _, villager in ipairs(game.villagers) do
        villager:draw(game)
        
        -- Highlight villagers of selected village
        if game.selectedVillage and villager.villageId == game.selectedVillage.id then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.circle("line", villager.x, villager.y, 6)
        end
    end
    
    -- Draw all traders
    if game.traders then
        for _, trader in ipairs(game.traders) do
            trader:draw()
            
            -- Highlight traders of selected village
            if game.selectedVillage and trader.villageId == game.selectedVillage.id then
                love.graphics.setColor(1, 1, 0, 0.5)
                love.graphics.circle("line", trader.x, trader.y, 7)
            end
        end
    else
        print("No traders array found in UI!")
    end
    
    -- Draw all building text AFTER all other entities to ensure it appears on top
    if UI.showBuildingInfo then
        for _, building in ipairs(game.buildings) do
            building:drawText(UI)
        end
    end
end

-- Draw a summary of all villages
function UI.drawVillageSummary(game)
    -- Only show if we have multiple villages
    if #game.villages <= 1 then return end
    
    local width = 200 -- Increased width to fit tier information
    local lineHeight = 18
    local padding = 5
    local height = padding * 2 + lineHeight * (#game.villages + 1)
    local x = love.graphics.getWidth() - width - 10
    local y = 50
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.font)
    love.graphics.print("Villages", x + padding, y + padding)
    
    -- Draw village list
    love.graphics.setFont(UI.smallFont)
    for i, village in ipairs(game.villages) do
        local totalPop = village.villagerCount
        local Village = require("entities/village")
        local tierName = Village.TIER_NAMES[village.tier]
        local text = village.name .. " (" .. tierName .. "): " .. totalPop .. "/" .. village.populationCapacity
        
        -- Highlight the village if it's hovered
        if UI.hoveredVillage and UI.hoveredVillage.id == village.id then
            love.graphics.setColor(0.3, 0.7, 0.9, 0.5)
            love.graphics.rectangle("fill", x + 2, y + padding + lineHeight * i, width - 4, lineHeight)
        end
        
        -- Highlight selected village
        if game.selectedVillage and game.selectedVillage.id == village.id then
            love.graphics.setColor(0.9, 0.9, 0.2, 0.5)
            love.graphics.rectangle("fill", x + 2, y + padding + lineHeight * i, width - 4, lineHeight)
        end
        
        -- Show different color based on population status
        if totalPop >= village.populationCapacity then
            love.graphics.setColor(1, 0.4, 0.4) -- Red for full
        elseif totalPop >= village.populationCapacity * 0.8 then
            love.graphics.setColor(1, 0.8, 0.2) -- Yellow for near capacity
        else
            love.graphics.setColor(0.8, 1, 0.8) -- Green for plenty of room
        end
        
        love.graphics.print(text, x + padding, y + padding + lineHeight * i)
    end
end

-- Draw the pause menu
function UI.drawPauseMenu()
    -- Save the current font so we can restore it
    local currentFont = love.graphics.getFont()
    
    -- Draw semi-transparent overlay
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    local title = "Game Paused"
    local titleWidth = UI.titleFont:getWidth(title)
    love.graphics.print(title, (love.graphics.getWidth() - titleWidth) / 2, 100)
    
    -- Draw menu options
    local menuWidth = 300
    local buttonHeight = 50
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 50
    local cornerRadius = 10  -- Radius for rounded corners
    
    love.graphics.setFont(UI.bigFont)
    
    for i, option in ipairs(UI.pauseMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Draw button background
        love.graphics.setColor(0.2, 0.3, 0.4)
        love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.rectangle("line", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1)
        local textWidth = UI.bigFont:getWidth(option)
        love.graphics.print(option, menuX + (menuWidth - textWidth) / 2, buttonY + 15)
    end
    
    -- Restore the original font
    love.graphics.setFont(currentFont)
end

-- Initialize or get the building queue for a village
function UI.getVillageBuildingQueue(villageId)
    return BuildMenu.getVillageBuildingQueue(villageId)
end

-- Check if there are any buildings in the village's queue
function UI.hasQueuedBuildings(villageId)
    return BuildMenu.hasQueuedBuildings(villageId)
end

-- Get the next building from the queue
function UI.getNextQueuedBuilding(villageId)
    return BuildMenu.getNextQueuedBuilding(villageId)
end

-- Decrement building in queue (called when a builder starts working on it)
function UI.decrementBuildingQueue(villageId, buildingType)
    BuildMenu.decrementBuildingQueue(villageId, buildingType)
end

-- Draw the main menu
function UI.drawMainMenu()
    -- Load and draw background image
    if not UI.backgroundImage then
        UI.backgroundImage = love.graphics.newImage("data/background.png")
    end
    
    -- Draw the background image scaled to fill the screen
    love.graphics.setColor(1, 1, 1, 1)
    local screenWidth = love.graphics.getWidth()
    local screenHeight = love.graphics.getHeight()
    local imgWidth = UI.backgroundImage:getWidth()
    local imgHeight = UI.backgroundImage:getHeight()
    
    -- Calculate scale to ensure image covers the entire screen
    local scaleX = screenWidth / imgWidth
    local scaleY = screenHeight / imgHeight
    local scale = math.max(scaleX, scaleY)
    
    -- Calculate centered position
    local scaledWidth = imgWidth * scale
    local scaledHeight = imgHeight * scale
    local x = (screenWidth - scaledWidth) / 2
    local y = (screenHeight - scaledHeight) / 2
    
    love.graphics.draw(UI.backgroundImage, x, y, 0, scale, scale)
    
    -- Add a dark overlay for better text visibility (darkened at the top and bottom, lighter in the middle)
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenWidth, screenHeight / 3) -- Darker at top
    
    -- Center gradient section
    for i = 1, 10 do
        local alpha = 0.7 - (i / 15) -- Gradient from 0.7 to 0.03
        love.graphics.setColor(0, 0, 0, alpha)
        local height = screenHeight / 3 / 10
        love.graphics.rectangle("fill", 0, screenHeight / 3 + (i-1) * height, screenWidth, height)
    end
    
    -- Bottom section
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", 0, screenHeight * 2/3, screenWidth, screenHeight/3)
    
    -- Draw title with a dramatic glow effect
    love.graphics.setFont(UI.titleFont)
    local title = "Villageworks"
    local titleWidth = UI.titleFont:getWidth(title)
    
    -- Draw shadow for depth
    love.graphics.setColor(0.1, 0.2, 0.3, 0.8)
    love.graphics.print(title, (screenWidth - titleWidth) / 2 + 4, 78)
    
    -- Draw outer glow
    local glowColor = {0.4, 0.7, 1.0}
    local pulseIntensity = math.abs(math.sin(love.timer.getTime() * 0.5)) * 0.5
    
    for i = 5, 1, -1 do
        local alpha = (pulseIntensity / i) * 0.3
        love.graphics.setColor(glowColor[1], glowColor[2], glowColor[3], alpha)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 - i, 80 - i)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 + i, 80 - i)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 - i, 80 + i)
        love.graphics.print(title, (screenWidth - titleWidth) / 2 + i, 80 + i)
    end
    
    -- Draw main title with a subtle gradient effect
    local r, g, b = 1, 1, 1
    love.graphics.setColor(r, g, b, 1)
    love.graphics.print(title, (screenWidth - titleWidth) / 2, 80)
    
    -- Draw tagline
    love.graphics.setFont(UI.bigFont)  -- Larger font for tagline
    local tagline = "Create and manage a network of thriving settlements."
    local taglineWidth = UI.bigFont:getWidth(tagline)
    love.graphics.setColor(0.9, 0.9, 0.9, 0.9)
    love.graphics.print(tagline, (screenWidth - taglineWidth) / 2, 140)
    
    -- Draw menu options
    local menuWidth = 300
    local buttonHeight = 60  -- Increased button height
    local buttonSpacing = 20
    local menuX = (screenWidth - menuWidth) / 2
    local startY = screenHeight / 2 - 50
    local cornerRadius = 10  -- Radius for rounded corners
    
    -- Use the fun font for menu buttons
    love.graphics.setFont(UI.menuFont)
    
    for i, option in ipairs(UI.mainMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Special case for docs row
        if option == "Docs" then
            -- Draw three side-by-side buttons for documentation
            local smallButtonWidth = (menuWidth - 20) / 3
            
            for j, docOption in ipairs(UI.docsOptions) do
                local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                local isHovered = UI.hoveredButton == "doc_" .. j
                
                -- Draw button background with hover effect
                if j == 1 then
                    -- How to Play
                    love.graphics.setColor(0.2, 0.4, 0.5)
                    if isHovered then love.graphics.setColor(0.3, 0.5, 0.7) end
                elseif j == 2 then
                    -- About
                    love.graphics.setColor(0.3, 0.3, 0.5)
                    if isHovered then love.graphics.setColor(0.4, 0.4, 0.7) end
                else
                    -- Changelog
                    love.graphics.setColor(0.4, 0.3, 0.4)
                    if isHovered then love.graphics.setColor(0.6, 0.4, 0.6) end
                end
                
                -- Draw rounded rectangle for button
                love.graphics.rectangle("fill", docButtonX, buttonY, smallButtonWidth, buttonHeight, cornerRadius, cornerRadius)
                
                -- Add a subtle glow on hover
                if isHovered then
                    -- Draw glow effect
                    love.graphics.setColor(0.6, 0.8, 1, 0.3)
                    love.graphics.rectangle("fill", docButtonX, buttonY, smallButtonWidth, buttonHeight, cornerRadius, cornerRadius)
                end
                
                -- Draw button border
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.rectangle("line", docButtonX, buttonY, smallButtonWidth, buttonHeight, cornerRadius, cornerRadius)
                
                -- Draw button text
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.font) -- Use smaller font for doc buttons
                local textWidth = UI.font:getWidth(docOption)
                
                -- Button text animation on hover
                local textY = buttonY + 20  -- Adjusted y position
                if isHovered then
                    textY = buttonY + 20 + math.sin(love.timer.getTime() * 5) * 2
                end
                
                love.graphics.print(docOption, docButtonX + (smallButtonWidth - textWidth) / 2, textY)
            end
            
            -- Reset font size for other buttons
            love.graphics.setFont(UI.menuFont)
        else
            -- Check if this button is hovered
            local isHovered = UI.hoveredButton == option
            
            -- Draw regular button background with hover effects
            love.graphics.setColor(0.2, 0.3, 0.4)
            
            -- Change color on hover
            if isHovered then
                love.graphics.setColor(0.3, 0.4, 0.6)
            end
            
            -- Draw the button with rounded corners
            love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
            
            -- Add a subtle glow on hover
            if isHovered then
                -- Draw glow effect
                love.graphics.setColor(0.6, 0.8, 1, 0.3)
                love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
            end
            
            -- Draw button border with animation if hovered
            if isHovered then
                love.graphics.setColor(0.7, 0.9, 1)
                love.graphics.setLineWidth(2)
            else
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.setLineWidth(1)
            end
            
            love.graphics.rectangle("line", menuX, buttonY, menuWidth, buttonHeight, cornerRadius, cornerRadius)
            love.graphics.setLineWidth(1)
            
            -- Draw button text
            love.graphics.setColor(1, 1, 1)
            local textWidth = UI.menuFont:getWidth(option)
            
            -- Button text animation on hover
            local textX = menuX + (menuWidth - textWidth) / 2
            local textY = buttonY + 15  -- Adjusted y position
            
            if isHovered then
                textY = buttonY + 15 + math.sin(love.timer.getTime() * 5) * 2
            end
            
            love.graphics.print(option, textX, textY)
        end
    end
    
    -- Draw version information at the bottom of the screen
    local Version = require("version")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(UI.smallFont)
    local versionString = Version.getFullVersionString()
    love.graphics.print(versionString, 10, screenHeight - 20)
end

-- Handle text input
function UI.textinput(text)
    -- Pass text input to SaveLoad module
    SaveLoad.textinput(text)
end

-- Handle key press events
function UI.keypressed(game, key)
    -- Handle documentation popup keypresses first
    if Documentation.showPopup then
        if Documentation.keypressed(key) then
            return
        end
    end

    -- If main menu is showing, let MainMenu handle keypresses
    if UI.showMainMenu then
        if MainMenu.keypressed(key, SaveLoad) then
            return
        end
    end

    -- Pass key press events to SaveLoad module
    SaveLoad.keypressed(game, key)

    if key == "i" then
        UI.showBuildingInfo = not UI.showBuildingInfo  -- Toggle building info display
        UI.showFPS = not UI.showFPS  -- Toggle FPS display
    end
end

-- Handle key release events (empty function since we don't need it anymore)
function UI.keyreleased(key)
    -- Empty function to prevent nil value errors
end

-- Handle mouse wheel events
function UI.wheelmoved(x, y)
    -- Pass wheel events to documentation module if popup is showing
    if Documentation.showPopup then
        return Documentation.wheelmoved(x, y)
    end
    
    -- Pass wheel events to saveload module if active
    if SaveLoad.showLoadDialog or SaveLoad.showSaveDialog then
        return SaveLoad.wheelmoved(x, y)
    end
    
    -- Pass wheel events to build menu if active and mouse is hovering over it
    if UI.showBuildMenu then
        local menuWidth = 450
        local menuHeight = 350
        local menuX = (love.graphics.getWidth() - menuWidth) / 2
        local menuY = (love.graphics.getHeight() - menuHeight) / 2
        
        -- Get current mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        
        -- Check if mouse is within the build menu bounds
        if mouseX >= menuX and mouseX <= menuX + menuWidth and
           mouseY >= menuY and mouseY <= menuY + menuHeight then
            -- Handle build menu scrolling
            BuildMenu.scrollPosition = BuildMenu.scrollPosition + y * BuildMenu.scrollSpeed
            BuildMenu.scrollPosition = math.max(0, math.min(BuildMenu.scrollPosition, BuildMenu.maxScroll))
            return true  -- Return true to prevent camera zoom
        end
    end
    
    -- Pass wheel events to main menu if it's showing and world size selection is active
    if UI.showMainMenu then
        -- Check if MainMenu has wheelmoved handler
        local MainMenu = require("ui.mainmenu")
        if MainMenu.wheelmoved then
            return MainMenu.wheelmoved(x, y)
        end
    end
    
    -- Default wheel behavior (e.g., zooming)
    return false
end

return UI 