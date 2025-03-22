local Config = require("config")
local Utils = require("utils")

local UI = {}

-- Initialize UI resources
function UI.init()
    UI.font = love.graphics.newFont(14)
    UI.bigFont = love.graphics.newFont(20)
    UI.smallFont = love.graphics.newFont(10)
    UI.titleFont = love.graphics.newFont(32)  -- Larger font for titles
    
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
    
    -- Popup system for documentation
    UI.showPopup = false
    UI.popupType = nil -- "howToPlay", "about", or "changelog"
    UI.popupContent = nil
    UI.popupScroll = 0
    
    -- Load documentation content
    UI.docs = {
        howToPlay = loadDocumentFile("docs/GAME_GUIDE.md", "Game guide not found."),
        about = loadDocumentFile("docs/ABOUT.md", "About document not found."),
        changelog = loadDocumentFile("docs/CHANGELOG.md", "Changelog not found.")
    }
    
    -- Main menu options
    UI.mainMenuOptions = {
        "New Game",
        "Load Game",
        "How to Play",
        "About",
        "Changelog",
        "Exit"
    }
    
    -- Pause menu options
    UI.pauseMenuOptions = {
        "Resume",
        "Save Game",
        "Exit to Main Menu"
    }
end

-- Helper function to load markdown documents
function loadDocumentFile(path, defaultMessage)
    local success, content = pcall(function()
        local file = io.open(path, "r")
        if file then
            local content = file:read("*all")
            file:close()
            return content
        end
        return defaultMessage
    end)
    
    if success then
        return content
    else
        return "Error loading document: " .. content
    end
end

-- Update UI state
function UI.update(game, dt)
    local mouseX, mouseY = love.mouse.getPosition()
    
    -- Reset hover states
    UI.hoveredBuilding = nil
    UI.hoveredVillage = nil
    
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
        return UI.handleMainMenuClick(game, x, y)
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
                    y = UI.hoveredVillage.y
                })
                
                -- Also add to other village's road needs
                table.insert(UI.hoveredVillage.needsRoads, {
                    type = "village",
                    target = UI.roadStartVillage,
                    priority = priority,
                    x = UI.roadStartVillage.x,
                    y = UI.roadStartVillage.y
                })
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
    if UI.showPopup then
        return UI.handlePopupClick(x, y)
    end
    
    -- Existing click handling code for main menu
    local menuWidth = 300
    local buttonHeight = 50
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 100 -- Adjusted starting position to fit all options
    
    for i, option in ipairs(UI.mainMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        if x >= menuX and x <= menuX + menuWidth and
           y >= buttonY and y <= buttonY + buttonHeight then
            
            -- Handle option selection
            if option == "New Game" then
                UI.showMainMenu = false
                UI.gameRunning = true
                game:reset() -- Reset game state for a new game
                return true
            elseif option == "Load Game" then
                -- TODO: Implement game loading
                UI.showMessage("Loading game not yet implemented")
                return true
            elseif option == "How to Play" then
                UI.showPopup = true
                UI.popupType = "howToPlay"
                UI.popupScroll = 0
                return true
            elseif option == "About" then
                UI.showPopup = true
                UI.popupType = "about"
                UI.popupScroll = 0
                return true
            elseif option == "Changelog" then
                UI.showPopup = true
                UI.popupType = "changelog"
                UI.popupScroll = 0
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
                -- TODO: Implement game saving
                UI.showMessage("Game saved (not actually implemented yet)")
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
        UI.drawMainMenu()
        
        -- If documentation popup is active, draw it on top
        if UI.showPopup then
            UI.drawDocumentationPopup()
        end
        
        return
    end
    
    -- Draw game world
    game.camera:beginDraw()
    
    -- Draw grid
    drawGrid(game)
    
    -- Draw entities in proper order
    drawEntities(game)
    
    -- Draw village placement preview if in building mode
    if game.uiMode == Config.UI_MODE_BUILDING_VILLAGE then
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = game.camera:screenToWorld(mouseX, mouseY)
        
        love.graphics.setColor(0, 0.8, 0, 0.5)
        love.graphics.circle("fill", worldX, worldY, 15)
        love.graphics.setColor(1, 1, 1, 0.7)
        love.graphics.print("Click to place village", worldX - 60, worldY - 40)
    end
    
    -- End camera transform
    game.camera:endDraw()
    
    -- Draw normal game UI
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), 40)
    
    -- Draw resources
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.font)
    love.graphics.print("Money: $" .. math.floor(game.money), 10, 10)
    love.graphics.print("Wood: " .. math.floor(game.resources.wood), 150, 10)
    love.graphics.print("Stone: " .. math.floor(game.resources.stone), 250, 10)
    love.graphics.print("Food: " .. math.floor(game.resources.food), 350, 10)
    love.graphics.print("Builders: " .. #game.builders, 450, 10)
    love.graphics.print("Villages: " .. #game.villages, 550, 10)
    
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
        -- Draw a preview line from start to mouse cursor
        local worldX, worldY = game.camera:screenToWorld(love.mouse.getX(), love.mouse.getY())
        
        love.graphics.setLineWidth(3)
        love.graphics.setColor(0.8, 0.8, 0.2, 0.5)
        love.graphics.line(UI.roadStartX, UI.roadStartY, worldX, worldY)
        love.graphics.setLineWidth(1)
        
        -- Draw text instructions
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(UI.font)
        love.graphics.print("Planning Road - Click on another village to connect or ESC to cancel", 
            love.graphics.getWidth() / 2 - 200, love.graphics.getHeight() - 40)
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
            love.graphics.rectangle("fill", x + 400, y + yOffset - 5, 20, 20)
            love.graphics.setColor(0, 0, 0)
            love.graphics.print("+", x + 407, y + yOffset - 3)
            
            -- Draw - button (moved to x + 420)
            if queueCount > 0 then
                love.graphics.setColor(0.7, 0.3, 0.3)
            else
                love.graphics.setColor(0.5, 0.5, 0.5)
            end
            love.graphics.rectangle("fill", x + 420, y + yOffset - 5, 20, 20)
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
    love.graphics.rectangle("fill", x + 20, y + menuHeight - 80, 100, 30)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Plan Road", x + 30, y + menuHeight - 75)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.smallFont)
    love.graphics.print("Roads require builders & resources", x + 125, y + menuHeight - 75)
    
    -- Draw village building option 
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.rectangle("fill", x + 20, y + menuHeight - 40, 100, 30)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(Config.UI_VILLAGE_BUILD_BUTTON_TEXT, x + 30, y + menuHeight - 35)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Cost: $" .. Config.VILLAGE_COST .. ", Wood: 20", x + 125, y + menuHeight - 35)
    
    -- Draw close button
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.rectangle("fill", x + menuWidth - 30, y + 10, 20, 20)
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
    end
    return UI.buildingQueues[villageId]
end

-- Check if there are any buildings in the village's queue
function UI.hasQueuedBuildings(villageId)
    local queue = UI.getVillageBuildingQueue(villageId)
    for buildingType, count in pairs(queue) do
        if count > 0 then
            return true
        end
    end
    return false
end

-- Get the next building from the queue
function UI.getNextQueuedBuilding(villageId)
    local queue = UI.getVillageBuildingQueue(villageId)
    for buildingType, count in pairs(queue) do
        if count > 0 then
            return buildingType
        end
    end
    return nil
end

-- Decrement a building from the queue
function UI.decrementBuildingQueue(villageId, buildingType)
    local queue = UI.getVillageBuildingQueue(villageId)
    if queue[buildingType] and queue[buildingType] > 0 then
        queue[buildingType] = queue[buildingType] - 1
        return true
    end
    return false
end

-- Draw the main menu
function UI.drawMainMenu()
    -- Draw background (could be replaced with a nice image)
    love.graphics.setColor(0.1, 0.2, 0.3)
    love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    local title = "Village Builder"
    local titleWidth = UI.titleFont:getWidth(title)
    love.graphics.print(title, (love.graphics.getWidth() - titleWidth) / 2, 100)
    
    -- Draw menu options
    local menuWidth = 300
    local buttonHeight = 50
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 100 -- Adjusted starting position to fit all options
    
    love.graphics.setFont(UI.bigFont)
    
    for i, option in ipairs(UI.mainMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Draw button background
        love.graphics.setColor(0.2, 0.3, 0.4)
        love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight)
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.rectangle("line", menuX, buttonY, menuWidth, buttonHeight)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1)
        local textWidth = UI.bigFont:getWidth(option)
        love.graphics.print(option, menuX + (menuWidth - textWidth) / 2, buttonY + 15)
    end
end

-- Draw the pause menu
function UI.drawPauseMenu()
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
    
    love.graphics.setFont(UI.bigFont)
    
    for i, option in ipairs(UI.pauseMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Draw button background
        love.graphics.setColor(0.2, 0.3, 0.4)
        love.graphics.rectangle("fill", menuX, buttonY, menuWidth, buttonHeight)
        love.graphics.setColor(0.5, 0.7, 0.9)
        love.graphics.rectangle("line", menuX, buttonY, menuWidth, buttonHeight)
        
        -- Draw button text
        love.graphics.setColor(1, 1, 1)
        local textWidth = UI.bigFont:getWidth(option)
        love.graphics.print(option, menuX + (menuWidth - textWidth) / 2, buttonY + 15)
    end
end

-- Draw the documentation popup (How to Play, About, or Changelog)
function UI.drawDocumentationPopup()
    local width = love.graphics.getWidth() * 0.8
    local height = love.graphics.getHeight() * 0.8
    local x = (love.graphics.getWidth() - width) / 2
    local y = (love.graphics.getHeight() - height) / 2
    
    -- Draw popup background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.5, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw title based on popup type
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    
    local title = ""
    local content = ""
    
    if UI.popupType == "howToPlay" then
        title = "How to Play"
        content = UI.docs.howToPlay
    elseif UI.popupType == "about" then
        title = "About"
        content = UI.docs.about
    elseif UI.popupType == "changelog" then
        title = "Changelog"
        content = UI.docs.changelog
    end
    
    love.graphics.print(title, x + 20, y + 20)
    
    -- Draw close button
    love.graphics.setColor(0.7, 0.3, 0.3)
    love.graphics.rectangle("fill", x + width - 40, y + 20, 25, 25)
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.font)
    love.graphics.print("X", x + width - 33, y + 25)
    
    -- Create a stencil for content area
    local contentX = x + 20
    local contentY = y + 70
    local contentWidth = width - 40
    local contentHeight = height - 100
    
    -- Draw scrollable content
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", contentX, contentY, contentWidth, contentHeight)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(UI.font)
    
    -- Parse and render Markdown-like content
    local lineHeight = 20
    local textY = contentY - UI.popupScroll
    local lines = {}
    
    -- Split the content into lines
    for line in string.gmatch(content, "[^\r\n]+") do
        table.insert(lines, line)
    end
    
    for i, line in ipairs(lines) do
        -- Handle headers
        if line:match("^#%s+") then
            love.graphics.setFont(UI.bigFont)
            love.graphics.setColor(0.8, 0.8, 1)
            love.graphics.print(line:gsub("^#%s+", ""), contentX, textY)
            textY = textY + 30
        elseif line:match("^##%s+") then
            love.graphics.setFont(UI.bigFont)
            love.graphics.setColor(0.7, 0.9, 1)
            love.graphics.print(line:gsub("^##%s+", ""), contentX + 10, textY)
            textY = textY + 25
        elseif line:match("^###%s+") then
            love.graphics.setFont(UI.font)
            love.graphics.setColor(0.8, 1, 0.8)
            love.graphics.print(line:gsub("^###%s+", ""), contentX + 20, textY)
            textY = textY + 20
        -- Handle bullet points
        elseif line:match("^%-%s+") or line:match("^%*%s+") then
            love.graphics.setFont(UI.font)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print("• " .. line:gsub("^[%-%*]%s+", ""), contentX + 20, textY)
            textY = textY + lineHeight
        -- Handle numbered lists
        elseif line:match("^%d+%.%s+") then
            love.graphics.setFont(UI.font)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(line, contentX + 20, textY)
            textY = textY + lineHeight
        -- Regular text
        elseif line ~= "" then
            love.graphics.setFont(UI.font)
            love.graphics.setColor(0.9, 0.9, 0.9)
            love.graphics.print(line, contentX, textY)
            textY = textY + lineHeight
        else
            textY = textY + 10 -- Empty line spacing
        end
    end
    
    -- Reset stencil
    love.graphics.setStencilTest()
    
    -- Draw scroll indicators if needed
    local totalHeight = textY + UI.popupScroll - contentY
    if totalHeight > contentHeight then
        -- Draw scroll bar
        local scrollBarHeight = math.max(30, contentHeight * (contentHeight / totalHeight))
        local scrollBarY = contentY + (UI.popupScroll / (totalHeight - contentHeight)) * (contentHeight - scrollBarHeight)
        
        love.graphics.setColor(0.5, 0.5, 0.5, 0.8)
        love.graphics.rectangle("fill", x + width - 15, contentY, 10, contentHeight)
        love.graphics.setColor(0.7, 0.7, 0.7, 1)
        love.graphics.rectangle("fill", x + width - 15, scrollBarY, 10, scrollBarHeight)
        
        -- Draw scroll indicators
        love.graphics.setColor(0.8, 0.8, 0.8, UI.popupScroll > 0 and 1 or 0.3)
        love.graphics.print("▲", x + width - 25, contentY)
        love.graphics.setColor(0.8, 0.8, 0.8, UI.popupScroll < totalHeight - contentHeight and 1 or 0.3)
        love.graphics.print("▼", x + width - 25, contentY + contentHeight - 20)
    end
end

-- Handle mouse press events for the documentation popup
function UI.handlePopupClick(x, y)
    if not UI.showPopup then
        return false
    end
    
    local width = love.graphics.getWidth() * 0.8
    local height = love.graphics.getHeight() * 0.8
    local popupX = (love.graphics.getWidth() - width) / 2
    local popupY = (love.graphics.getHeight() - height) / 2
    
    -- Check if clicking close button
    if x >= popupX + width - 40 and x <= popupX + width - 15 and
       y >= popupY + 20 and y <= popupY + 45 then
        UI.showPopup = false
        UI.popupType = nil
        return true
    end
    
    -- Check if clicking inside the content area (for future interactions)
    if x >= popupX and x <= popupX + width and
       y >= popupY and y <= popupY + height then
        return true -- Capture the click
    end
    
    return false
end

return UI 