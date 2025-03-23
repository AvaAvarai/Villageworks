local Config = require("config")
local Utils = require("utils")
local Documentation = require("ui.documentation")
local SaveLoad = require("ui.saveload")
local MainMenu = require("ui.mainmenu")

local UI = {}

-- Initialize UI resources
function UI.init()
    UI.font = love.graphics.newFont(14)
    UI.bigFont = love.graphics.newFont(20)
    UI.smallFont = love.graphics.newFont(10)
    UI.titleFont = love.graphics.newFont(48)  -- Larger font for titles
    UI.entityNameFont = love.graphics.newFont(16)  -- New font for entity names with higher DPI
    
    -- Font for main menu
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
    UI.showRoadInfo = false
    UI.roadCreationMode = false
    UI.roadStartVillage = nil
    UI.roadStartX = nil
    UI.roadStartY = nil
    
    -- Hover state for menu buttons
    UI.hoveredButton = nil
    
    -- Message system
    UI.message = nil
    UI.messageTimer = 0
    UI.MESSAGE_DURATION = 3 -- seconds to show messages
    
    -- Building queue system
    UI.buildingQueues = {} -- Store building queues per village
    
    -- Menu states
    UI.showMainMenu = true   -- Start with main menu visible
    UI.showPauseMenu = false -- Pause menu initially hidden
    UI.gameRunning = false   -- Game not running until started
    
    -- Initialize modules
    Documentation.init(UI)
    SaveLoad.init(UI)
    MainMenu.init(UI)
    
    -- Pause menu options
    UI.pauseMenuOptions = {
        "Resume",
        "Save Game",
        "Exit to Main Menu"
    }
end

-- Update UI state
function UI.update(game, dt)
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
    
    -- Update tooltip for buildings
    UI.tooltip = nil
    if UI.hoveredBuilding then
        if UI.hoveredBuilding.type == "house" then
            -- Find the village this house belongs to
            local village = nil
            for _, v in ipairs(game.villages) do
                if v.id == UI.hoveredBuilding.villageId then
                    village = v
                    break
                end
            end
            
            local villageText = village and (village.name) or "Unknown village"
            
            UI.tooltip = {
                title = "House",
                lines = {
                    "Villagers: " .. UI.hoveredBuilding.currentVillagers .. "/" .. UI.hoveredBuilding.villagerCapacity,
                    "Spawns a new villager every " .. Config.BUILDING_TYPES.house.spawnTime .. " seconds",
                    "Belongs to: " .. villageText,
                    "+2 population capacity"
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
    elseif UI.hoveredVillage then
        -- Create tooltip for villages
        local village = UI.hoveredVillage
        local totalPopulation = village.builderCount + village.villagerCount
        
        UI.tooltip = {
            title = village.name,
            lines = {
                "Population: " .. totalPopulation .. "/" .. village.populationCapacity,
                "Builders: " .. village.builderCount .. "/" .. village.maxBuilders,
                "Villagers: " .. village.villagerCount,
                "Housing needed: " .. (village.needsHousing and "Yes" or "No")
            }
        }
        
        -- Add information about needed roads
        if #village.needsRoads > 0 then
            local needsLine = "Needs roads: "
            local first = true
            local count = 0
            
            for i, roadNeed in ipairs(village.needsRoads) do
                if count < 2 then  -- Show at most 2 road needs
                    if not first then needsLine = needsLine .. ", " end
                    if roadNeed.type == "village" then
                        needsLine = needsLine .. "to " .. roadNeed.target.name
                    else
                        needsLine = needsLine .. "to " .. roadNeed.target.type
                    end
                    first = false
                    count = count + 1
                end
            end
            
            if #village.needsRoads > 2 then
                needsLine = needsLine .. " and " .. (#village.needsRoads - 2) .. " more"
            end
            
            table.insert(UI.tooltip.lines, needsLine)
        end
        
        -- Add road building instruction
        if UI.roadCreationMode and not UI.roadStartVillage then
            table.insert(UI.tooltip.lines, "Click to start road from this village")
        elseif UI.roadCreationMode and UI.roadStartVillage and UI.roadStartVillage.id ~= village.id then
            table.insert(UI.tooltip.lines, "Click to connect road to this village")
        end
    end
    
    -- Road creation mode positioning
    if UI.roadCreationMode and UI.roadStartVillage then
        -- Show road preview from start to mouse cursor
        UI.showRoadInfo = true
    else
        UI.showRoadInfo = false
    end
    
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
    
    -- Check for road creation mode
    if UI.roadCreationMode then
        -- If we're selecting a start village
        if UI.hoveredVillage and not UI.roadStartVillage then
            UI.roadStartVillage = UI.hoveredVillage
            UI.roadStartX = UI.hoveredVillage.x
            UI.roadStartY = UI.hoveredVillage.y
            return true
        -- If we're selecting an end village
        elseif UI.hoveredVillage and UI.roadStartVillage and UI.hoveredVillage.id ~= UI.roadStartVillage.id then
            -- Check if we can create a valid road path (not crossing water)
            local roadPath = game.map:createRoadPath(
                UI.roadStartVillage.x, 
                UI.roadStartVillage.y, 
                UI.hoveredVillage.x, 
                UI.hoveredVillage.y
            )
            
            if roadPath then
                -- Don't create the road directly - add it to the village's needs
                -- This makes roads cost resources and need to be built by builders
                
                -- Check if there's already a road with these villages
                local alreadyHasRoad = false
                for _, road in ipairs(game.roads) do
                    if (road.startVillageId == UI.roadStartVillage.id and road.endVillageId == UI.hoveredVillage.id) or
                       (road.startVillageId == UI.hoveredVillage.id and road.endVillageId == UI.roadStartVillage.id) then
                        alreadyHasRoad = true
                        break
                    end
                end
                
                -- Add to village's road needs if no existing road
                if not alreadyHasRoad then
                    local distance = Utils.distance(UI.roadStartVillage.x, UI.roadStartVillage.y, 
                                                 UI.hoveredVillage.x, UI.hoveredVillage.y)
                    
                    local priority = 10 -- High priority since player requested it
                    
                    table.insert(UI.roadStartVillage.needsRoads, {
                        type = "village",
                        target = UI.hoveredVillage,
                        priority = priority,
                        x = UI.hoveredVillage.x,
                        y = UI.hoveredVillage.y,
                        path = roadPath -- Store the valid path to follow
                    })
                    
                    -- Also add to other village's road needs
                    table.insert(UI.hoveredVillage.needsRoads, {
                        type = "village",
                        target = UI.roadStartVillage,
                        priority = priority,
                        x = UI.roadStartVillage.x,
                        y = UI.roadStartVillage.y,
                        path = roadPath -- Store the valid path to follow
                    })
                end
            else
                -- Road path is not possible due to water
                UI.showMessage("Cannot build road through water!")
            end
            
            -- Reset road creation mode
            UI.roadCreationMode = false
            UI.roadStartVillage = nil
            UI.roadStartX = nil
            UI.roadStartY = nil
            return true
        -- If we're clicking anywhere else with a start village set, cancel
        elseif UI.roadStartVillage then
            UI.roadCreationMode = false
            UI.roadStartVillage = nil
            UI.roadStartX = nil
            UI.roadStartY = nil
            return true
        end
    end
    
    -- Build menu interactions
    if UI.showBuildMenu then
        local menuWidth = 450  -- Match the width used in drawBuildMenu
        local menuHeight = 350
        local menuX = (love.graphics.getWidth() - menuWidth) / 2
        local menuY = (love.graphics.getHeight() - menuHeight) / 2
        
        -- Check if we're clicking close button
        if x >= menuX + menuWidth - 30 and x <= menuX + menuWidth - 10 and
           y >= menuY + 10 and y <= menuY + 30 then
            UI.showBuildMenu = false
            return true
        end
        
        -- Check if we're clicking the "Plan Road" button
        if x >= menuX + 20 and x <= menuX + 120 and
           y >= menuY + menuHeight - 80 and y <= menuY + menuHeight - 50 then
            UI.roadCreationMode = true
            UI.showBuildMenu = false
            return true
        end
        
        -- Check if we're clicking the "Build Village" button
        if x >= menuX + 20 and x <= menuX + 120 and
           y >= menuY + menuHeight - 40 and y <= menuY + menuHeight - 10 then
            -- Switch to village building mode
            game.uiMode = Config.UI_MODE_BUILDING_VILLAGE
            UI.showBuildMenu = false
            return true
        end
        
        -- Check if we're clicking on building queue buttons
        if game.selectedVillage then
            local yOffset = 60
            
            -- Initialize building queue for this village if it doesn't exist
            if not UI.buildingQueues[game.selectedVillage.id] then
                UI.buildingQueues[game.selectedVillage.id] = {}
                for buildingType, _ in pairs(Config.BUILDING_TYPES) do
                    UI.buildingQueues[game.selectedVillage.id][buildingType] = 0
                end
            end
            
            -- Check building entries
            for buildingType, info in pairs(Config.BUILDING_TYPES) do
                -- Check for + button click
                if x >= menuX + 400 and x <= menuX + 420 and
                   y >= menuY + yOffset - 5 and y <= menuY + yOffset + 15 then
                    -- Add to building queue
                    UI.buildingQueues[game.selectedVillage.id][buildingType] = 
                        (UI.buildingQueues[game.selectedVillage.id][buildingType] or 0) + 1
                    return true
                end
                
                -- Check for - button click
                if x >= menuX + 420 and x <= menuX + 440 and
                   y >= menuY + yOffset - 5 and y <= menuY + yOffset + 15 and
                   (UI.buildingQueues[game.selectedVillage.id][buildingType] or 0) > 0 then
                    -- Decrease from building queue
                    UI.buildingQueues[game.selectedVillage.id][buildingType] = 
                        UI.buildingQueues[game.selectedVillage.id][buildingType] - 1
                    return true
                end
                
                yOffset = yOffset + 40
            end
        end
        
        -- If we're clicking anywhere in the menu, capture the click
        if x >= menuX and x <= menuX + menuWidth and 
           y >= menuY and y <= menuY + menuHeight then
            return true
        end
    end
    
    -- Top bar buttons
    local topBarHeight = 40
    if y < topBarHeight then
        return false -- Let other clicks in the top bar through
    end
    
    -- Check if clicking on a village (when not in build menu already)
    if not UI.showBuildMenu and UI.hoveredVillage then
        -- Select this village
        game.selectedVillage = UI.hoveredVillage
        
        -- Open build menu for this village
        UI.showBuildMenu = true
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
    
    -- No need to draw the grid anymore as we have tiles
    -- drawGrid(game)
    
    -- Draw entities in proper order
    drawEntities(game)
    
    -- Draw building radius overlay for hovered village
    if UI.hoveredVillage then
        -- Draw a transparent circle showing the building radius
        love.graphics.setColor(0.3, 0.7, 0.9, 0.15) -- Light blue, mostly transparent
        love.graphics.circle("fill", UI.hoveredVillage.x, UI.hoveredVillage.y, Config.MAX_BUILD_DISTANCE)
        
        -- Draw a slightly more visible border
        love.graphics.setColor(0.3, 0.7, 0.9, 0.3)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", UI.hoveredVillage.x, UI.hoveredVillage.y, Config.MAX_BUILD_DISTANCE)
        love.graphics.setLineWidth(1)
        
        -- Label the radius
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("Building Radius", UI.hoveredVillage.x - 50, UI.hoveredVillage.y - Config.MAX_BUILD_DISTANCE - 20)
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
    love.graphics.setFont(UI.bigFont)
    
    -- Calculate available width for resource display
    local screenWidth = love.graphics.getWidth()
    local availableWidth = screenWidth - 40  -- Leave some margin on both sides
    
    -- Count the number of resources we need to display
    local resourceCount = 6  -- Money, Wood, Stone, Food, Builders, Villages
    
    -- Calculate minimum spacing between resources based on screen width
    local minSpacing = 15 * UI.dpiScale  -- Minimum spacing between items
    local baseSpacing = math.max(minSpacing, (availableWidth / resourceCount) * 0.2)  -- Allocate 20% of item width to spacing
    
    local yPos = math.floor(hudHeight/2 - UI.bigFont:getHeight()/2)
    local currentXOffset = 20  -- Start with some margin
    
    -- Money display with icon
    love.graphics.setColor(1, 0.9, 0.2)  -- Gold color for money
    local moneyText = "$" .. math.floor(game.money)
    love.graphics.print(moneyText, currentXOffset, yPos)
    currentXOffset = currentXOffset + UI.bigFont:getWidth(moneyText) + baseSpacing
    
    -- Wood resource
    love.graphics.setColor(0.8, 0.5, 0.2)  -- Brown for wood
    local woodLabel = "Wood: "
    love.graphics.print(woodLabel, currentXOffset, yPos)
    local labelWidth = UI.bigFont:getWidth(woodLabel)
    love.graphics.setColor(1, 1, 1)
    local woodValue = math.floor(game.resources.wood)
    love.graphics.print(woodValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.bigFont:getWidth(woodValue) + baseSpacing
    
    -- Stone resource
    love.graphics.setColor(0.6, 0.6, 0.7)  -- Gray for stone
    local stoneLabel = "Stone: "
    love.graphics.print(stoneLabel, currentXOffset, yPos)
    labelWidth = UI.bigFont:getWidth(stoneLabel)
    love.graphics.setColor(1, 1, 1)
    local stoneValue = math.floor(game.resources.stone)
    love.graphics.print(stoneValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.bigFont:getWidth(stoneValue) + baseSpacing
    
    -- Food resource
    love.graphics.setColor(0.2, 0.8, 0.3)  -- Green for food
    local foodLabel = "Food: "
    love.graphics.print(foodLabel, currentXOffset, yPos)
    labelWidth = UI.bigFont:getWidth(foodLabel)
    love.graphics.setColor(1, 1, 1)
    local foodValue = math.floor(game.resources.food)
    love.graphics.print(foodValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.bigFont:getWidth(foodValue) + baseSpacing
    
    -- Builder count
    love.graphics.setColor(0.3, 0.6, 0.9)  -- Blue for builders
    local builderLabel = "Builders: "
    love.graphics.print(builderLabel, currentXOffset, yPos)
    labelWidth = UI.bigFont:getWidth(builderLabel)
    love.graphics.setColor(1, 1, 1)
    local builderValue = #game.builders
    love.graphics.print(builderValue, currentXOffset + labelWidth, yPos)
    currentXOffset = currentXOffset + labelWidth + UI.bigFont:getWidth(builderValue) + baseSpacing
    
    -- Village count
    love.graphics.setColor(0.9, 0.3, 0.6)  -- Purple for villages
    local villageLabel = "Villages: "
    love.graphics.print(villageLabel, currentXOffset, yPos)
    labelWidth = UI.bigFont:getWidth(villageLabel)
    love.graphics.setColor(1, 1, 1)
    local villageValue = #game.villages
    love.graphics.print(villageValue, currentXOffset + labelWidth, yPos)
    
    -- Restore regular color for other UI
    love.graphics.setColor(1, 1, 1)
    
    -- Draw tooltip
    if UI.tooltip then
        UI.drawTooltip(UI.tooltip, love.mouse.getX(), love.mouse.getY())
    end
    
    -- Draw build menu if active
    if UI.showBuildMenu then
        UI.drawBuildMenu(game)
    end
    
    -- Draw road creation preview
    if UI.showRoadInfo then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = game.camera:screenToWorld(mouseX, mouseY)
        
        -- Check if the current path would be valid
        local isValidPath = false
        if UI.roadStartVillage then
            local path = game.map:createRoadPath(UI.roadStartX, UI.roadStartY, worldX, worldY)
            isValidPath = path ~= nil
            
            -- Draw the path in different colors based on validity
            love.graphics.setLineWidth(3)
            if isValidPath then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.5) -- Yellow for valid path
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.5) -- Red for invalid path
            end
            love.graphics.line(UI.roadStartX, UI.roadStartY, worldX, worldY)
            love.graphics.setLineWidth(1)
        end
        
        -- Draw text instructions
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.font)
        if isValidPath then
            love.graphics.print("Planning Road - Click on another village to connect or ESC to cancel", 
                love.graphics.getWidth() / 2 - 200, love.graphics.getHeight() - 40)
        else
            love.graphics.print("Invalid path - Cannot build roads through water!", 
                love.graphics.getWidth() / 2 - 200, love.graphics.getHeight() - 40)
        end
    end
    
    -- Draw road creation mode indicator
    if UI.roadCreationMode then
        love.graphics.setColor(0.8, 0.8, 0.2)
        love.graphics.setFont(UI.font)
        if not UI.roadStartVillage then
            love.graphics.print("Road Planning Mode - Select starting village", 
                10, love.graphics.getHeight() - 40)
        end
    end
    
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
    love.graphics.print("Press B for build menu. SPACE for fast forward. Arrow keys to move camera. Scroll to zoom. ESC to pause.", 
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
    -- Draw roads first (so they appear behind everything else)
    for _, road in ipairs(game.roads) do
        road:draw()
    end
    
    -- Draw all villages
    for _, village in ipairs(game.villages) do
        village:draw()
        
        -- Highlight selected village
        if game.selectedVillage and village.id == game.selectedVillage.id then
            love.graphics.setColor(1, 1, 0, 0.3)
            love.graphics.circle("line", village.x, village.y, 18)
            love.graphics.circle("line", village.x, village.y, 20)
        end
    end
    
    -- Draw all buildings
    for _, building in ipairs(game.buildings) do
        building:draw()
        
        -- Highlight buildings of selected village
        if game.selectedVillage and building.villageId == game.selectedVillage.id then
            love.graphics.setColor(1, 1, 0, 0.2)
            love.graphics.rectangle("line", building.x - 12, building.y - 12, 24, 24)
        end
    end
    
    -- Draw all builders
    for _, builder in ipairs(game.builders) do
        builder:draw()
        
        -- Highlight builders of selected village
        if game.selectedVillage and builder.villageId == game.selectedVillage.id then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.circle("line", builder.x, builder.y, 7)
        end
    end
    
    -- Draw all villagers
    for _, villager in ipairs(game.villagers) do
        villager:draw()
        
        -- Highlight villagers of selected village
        if game.selectedVillage and villager.villageId == game.selectedVillage.id then
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.circle("line", villager.x, villager.y, 6)
        end
    end
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

-- Draw a summary of all villages
function UI.drawVillageSummary(game)
    -- Only show if we have multiple villages
    if #game.villages <= 1 then return end
    
    local width = 150
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
        local totalPop = village.builderCount + village.villagerCount
        local text = village.name .. ": " .. totalPop .. "/" .. village.populationCapacity
        
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

-- Draw the build menu
function UI.drawBuildMenu(game)
    local menuWidth = 450  -- Increased from 300 to 450
    local menuHeight = 350
    local x = (love.graphics.getWidth() - menuWidth) / 2
    local y = (love.graphics.getHeight() - menuHeight) / 2
    local cornerRadius = 10  -- Radius for rounded corners
    
    -- Draw background
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.rectangle("fill", x, y, menuWidth, menuHeight, cornerRadius, cornerRadius)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.rectangle("line", x, y, menuWidth, menuHeight, cornerRadius, cornerRadius)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.bigFont)
    love.graphics.print("Build Menu", x + 20, y + 15)
    
    -- Draw building options
    love.graphics.setFont(UI.font)
    local yOffset = 60
    
    -- Initialize building queue for selected village if needed
    if game.selectedVillage and not UI.buildingQueues[game.selectedVillage.id] then
        UI.buildingQueues[game.selectedVillage.id] = {}
        for buildingType, _ in pairs(Config.BUILDING_TYPES) do
            UI.buildingQueues[game.selectedVillage.id][buildingType] = 0
        end
    end
    
    for buildingType, info in pairs(Config.BUILDING_TYPES) do
        local canAfford = game.resources.wood >= (info.cost.wood or 0) and 
                          game.resources.stone >= (info.cost.stone or 0)
        
        if canAfford then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.6, 0.6, 0.6)
        end
        
        -- Draw building name (at x + 20)
        love.graphics.print(buildingType:gsub("^%l", string.upper), x + 20, y + yOffset)
        
        -- Draw resource costs (at x + 150)
        love.graphics.print("Wood: " .. (info.cost.wood or 0) .. ", Stone: " .. (info.cost.stone or 0), x + 150, y + yOffset)
        
        -- Draw queue controls if a village is selected (moved to x + 320)
        if game.selectedVillage then
            local queueCount = UI.buildingQueues[game.selectedVillage.id][buildingType] or 0
            
            -- Draw queue count
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("Queue: " .. queueCount, x + 320, y + yOffset)
            
            -- Draw + button (moved to x + 400)
            love.graphics.setColor(0.3, 0.7, 0.3)
            love.graphics.rectangle("fill", x + 400, y + yOffset - 5, 20, 20, 4, 4)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("+", x + 407, y + yOffset - 3)
            
            -- Draw - button (moved to x + 420)
            if queueCount > 0 then
                love.graphics.setColor(0.7, 0.3, 0.3)
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
            end
            love.graphics.rectangle("fill", x + 420, y + yOffset - 5, 20, 20, 4, 4)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("-", x + 427, y + yOffset - 3)
        end
        
        -- Add small description of the building
        love.graphics.setFont(UI.smallFont)
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.print(info.description, x + 20, y + yOffset + 18)
        love.graphics.setFont(UI.font)
        
        yOffset = yOffset + 40
    end
    
    -- Draw road planning option
    love.graphics.setColor(0.8, 0.8, 0.2)
    love.graphics.rectangle("fill", x + 20, y + menuHeight - 80, 100, 30, 8, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Plan Road", x + 30, y + menuHeight - 75)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.smallFont)
    love.graphics.print("Roads require builders & resources", x + 125, y + menuHeight - 75)
    
    -- Draw village building option 
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.rectangle("fill", x + 20, y + menuHeight - 40, 100, 30, 8, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(Config.UI_VILLAGE_BUILD_BUTTON_TEXT, x + 30, y + menuHeight - 35)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Cost: $" .. Config.VILLAGE_COST .. ", Wood: 20", x + 125, y + menuHeight - 35)
    
    -- Draw close button
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.rectangle("fill", x + menuWidth - 30, y + 10, 20, 20, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("X", x + menuWidth - 24, y + 10)
end

-- Initialize or get the building queue for a village
function UI.getVillageBuildingQueue(villageId)
    if not UI.buildingQueues[villageId] then
        UI.buildingQueues[villageId] = {}
        for buildingType, _ in pairs(Config.BUILDING_TYPES) do
            UI.buildingQueues[villageId][buildingType] = 0
        end
        -- Initialize planned positions array
        UI.buildingQueues[villageId].plannedPositions = {}
    end
    return UI.buildingQueues[villageId]
end

-- Check if there are any buildings in the village's queue
function UI.hasQueuedBuildings(villageId)
    local queue = UI.getVillageBuildingQueue(villageId)
    for buildingType, count in pairs(queue) do
        -- Skip the plannedPositions entry which is a table
        if buildingType ~= "plannedPositions" and type(count) == "number" and count > 0 then
            return true
        end
    end
    return false
end

-- Get the next building from the queue
function UI.getNextQueuedBuilding(villageId)
    local queue = UI.getVillageBuildingQueue(villageId)
    for buildingType, count in pairs(queue) do
        -- Skip the plannedPositions entry which is a table
        if buildingType ~= "plannedPositions" and type(count) == "number" and count > 0 then
            return buildingType
        end
    end
    return nil
end

-- Decrement building in queue (called when a builder starts working on it)
function UI.decrementBuildingQueue(villageId, buildingType)
    if not UI.buildingQueues[villageId] then
        return
    end
    
    -- Decrement count if any in queue
    if UI.buildingQueues[villageId][buildingType] and
        (UI.buildingQueues[villageId][buildingType] or 0) > 0 then
        
        UI.buildingQueues[villageId][buildingType] =
            UI.buildingQueues[villageId][buildingType] - 1
            
        -- Remove the oldest planned position of this type
        if UI.buildingQueues[villageId].plannedPositions then
            for i, position in ipairs(UI.buildingQueues[villageId].plannedPositions) do
                if position.type == buildingType then
                    table.remove(UI.buildingQueues[villageId].plannedPositions, i)
                    break
                end
            end
        end
    end
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

-- Get the building queue for a specific village
function UI.getBuildingQueue(villageId)
    if not UI.buildingQueues[villageId] then
        UI.buildingQueues[villageId] = {}
    end
    
    -- Add plannedPositions array if not exists
    if not UI.buildingQueues[villageId].plannedPositions then
        UI.buildingQueues[villageId].plannedPositions = {}
    end
    
    return UI.buildingQueues[villageId]
end

-- Increment building in queue
function UI.incrementBuildingQueue(game, buildingType)
    if not game.selectedVillage then
        return
    end
    
    -- Get village location
    local villageX = game.selectedVillage.x
    local villageY = game.selectedVillage.y
    
    -- Initialize queue if needed
    if not UI.buildingQueues[game.selectedVillage.id] then
        UI.buildingQueues[game.selectedVillage.id] = {}
    end
    
    -- Initialize count for this building type if needed
    if not UI.buildingQueues[game.selectedVillage.id][buildingType] then
        UI.buildingQueues[game.selectedVillage.id][buildingType] = 0
    end
    
    -- Get or initialize planned positions array
    if not UI.buildingQueues[game.selectedVillage.id].plannedPositions then
        UI.buildingQueues[game.selectedVillage.id].plannedPositions = {}
    end
    
    -- Plan a position for the new building
    local foundPosition = false
    local buildX, buildY
    local Builder = require("entities/builder")
    
    -- Create a temporary builder to use its location finding logic
    local tempBuilder = Builder.new(villageX, villageY, game.selectedVillage.id)
    buildX, buildY = Builder.findBuildingLocation(tempBuilder, game, buildingType)
    
    if buildX and buildY then
        -- Store the planned position
        table.insert(UI.buildingQueues[game.selectedVillage.id].plannedPositions, {
            x = buildX,
            y = buildY,
            type = buildingType
        })
        
        -- Increment the count
        UI.buildingQueues[game.selectedVillage.id][buildingType] = 
            (UI.buildingQueues[game.selectedVillage.id][buildingType] or 0) + 1
            
        -- Automatically close build menu after adding to queue
        UI.showBuildMenu = false
    else
        -- Could not find a position - show error message
        UI.showMessage("Cannot find a suitable location for this building!")
    end
end

-- Handle text input
function UI.textinput(text)
    -- Pass text input to SaveLoad module
    SaveLoad.textinput(text)
end

-- Handle key presses
function UI.keypressed(game, key)
    -- Handle documentation popup keypresses first
    if Documentation.showPopup then
        if Documentation.keypressed(key) then
            return
        end
    end

    -- Pass key press events to SaveLoad module
    SaveLoad.keypressed(game, key)
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