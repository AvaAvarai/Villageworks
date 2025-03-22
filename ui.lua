local Config = require("config")
local Utils = require("utils")

local UI = {}

-- Initialize UI resources
function UI.init()
    UI.font = love.graphics.newFont(14)
    UI.bigFont = love.graphics.newFont(20)
    UI.smallFont = love.graphics.newFont(10)
    UI.titleFont = love.graphics.newFont(32)  -- Larger font for titles
    
    -- Pre-load background image
    UI.backgroundImage = love.graphics.newImage("data/background.png")
    
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
    UI.popupType = nil -- "howToPlay", "about", "changelog"
    UI.popupContent = nil
    UI.popupScroll = 0
    
    -- Simple save/load system
    UI.showSaveDialog = false
    UI.showLoadDialog = false
    UI.saveFiles = {}
    UI.selectedSaveFile = nil
    UI.saveNameInput = ""
    UI.saveInputActive = false
    UI.loadDialogScroll = 0 -- Add scroll position for load dialog
    UI.MAX_LOAD_FILES_VISIBLE = 10 -- Number of save files visible at once
    
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
        "Docs", -- Replace the three separate options with a single "Docs" placeholder
        "Exit"
    }
    
    -- Documentation submenu options
    UI.docsOptions = {
        "How to Play",
        "About",
        "Changelog"
    }
    
    -- Pause menu options
    UI.pauseMenuOptions = {
        "Resume",
        "Save Game",
        "Exit to Main Menu"
    }
    
    -- Create saves directory if it doesn't exist
    UI.ensureSavesDirectoryExists()
end

-- Ensure the saves directory exists
function UI.ensureSavesDirectoryExists()
    local success = love.filesystem.getInfo("saves")
    if not success then
        love.filesystem.createDirectory("saves")
    end
end

-- Get list of available save files
function UI.loadSaveFiles()
    UI.saveFiles = {}
    
    -- Ensure saves directory exists
    UI.ensureSavesDirectoryExists()
    
    -- Get list of save files
    local files = love.filesystem.getDirectoryItems("saves")
    
    for _, filename in ipairs(files) do
        if filename:match("%.save$") then
            local saveInfo = {}
            saveInfo.filename = filename
            
            -- Get file modification time
            local info = love.filesystem.getInfo("saves/" .. filename)
            if info then
                saveInfo.modtime = info.modtime -- Unix timestamp
            end
            
            -- Try to read save metadata from the first line
            local content = love.filesystem.read("saves/" .. filename)
            if content then
                local firstLine = content:match("^.-\n")
                if firstLine and firstLine:match("^-- SaveInfo:") then
                    saveInfo.metadata = firstLine:match("^-- SaveInfo: (.+)")
                end
            end
            
            table.insert(UI.saveFiles, saveInfo)
        end
    end
    
    -- Sort files by modification time (newest first)
    table.sort(UI.saveFiles, function(a, b) 
        return (a.modtime or 0) > (b.modtime or 0)
    end)
end

-- Create a timestamped filename
function UI.createTimestampedFilename()
    local date = os.date("%Y-%m-%d_%H-%M-%S")
    return "village_" .. date .. ".save"
end

-- Save the current game state
function UI.saveGame(game, filename)
    if not filename then
        filename = UI.createTimestampedFilename()
    end
    
    -- Get current timestamp for metadata
    local date = os.date("%Y-%m-%d %H:%M:%S")
    
    -- Prepare game state to be saved
    local saveData = {
        money = game.money,
        resources = game.resources,
        gameSpeed = game.gameSpeed,
        
        -- Save map state
        mapData = game.map.tiles,
        
        -- Only save the necessary data from entities
        villages = {},
        buildings = {},
        builders = {},
        villagers = {},
        roads = {}
    }
    
    -- Save villages
    for _, village in ipairs(game.villages) do
        local savedVillage = {
            id = village.id,
            x = village.x,
            y = village.y,
            name = village.name,
            population = village.population,
            maxPopulation = village.maxPopulation,
            resources = village.resources
        }
        table.insert(saveData.villages, savedVillage)
    end
    
    -- Save buildings
    for _, building in ipairs(game.buildings) do
        local savedBuilding = {
            id = building.id,
            villageId = building.villageId,
            x = building.x,
            y = building.y,
            type = building.type,
            health = building.health,
            maxHealth = building.maxHealth,
            currentVillagers = building.currentVillagers,
            villagerCapacity = building.villagerCapacity,
            productionTimer = building.productionTimer,
            productionTime = building.productionTime
        }
        table.insert(saveData.buildings, savedBuilding)
    end
    
    -- Save builders
    for _, builder in ipairs(game.builders) do
        local savedBuilder = {
            id = builder.id,
            villageId = builder.villageId,
            x = builder.x,
            y = builder.y,
            targetX = builder.targetX,
            targetY = builder.targetY,
            state = builder.state,
            buildingId = builder.buildingId,
            buildingType = builder.buildingType,
            buildingX = builder.buildingX,
            buildingY = builder.buildingY
        }
        table.insert(saveData.builders, savedBuilder)
    end
    
    -- Save villagers
    for _, villager in ipairs(game.villagers) do
        local savedVillager = {
            id = villager.id,
            villageId = villager.villageId,
            x = villager.x,
            y = villager.y,
            targetX = villager.targetX,
            targetY = villager.targetY,
            state = villager.state,
            buildingId = villager.buildingId,
            resourceType = villager.resourceType,
            resourceAmount = villager.resourceAmount
        }
        table.insert(saveData.villagers, savedVillager)
    end
    
    -- Save roads
    for _, road in ipairs(game.roads) do
        local savedRoad = {
            id = road.id,
            villageId = road.villageId,
            startX = road.startX,
            startY = road.startY,
            endX = road.endX,
            endY = road.endY,
            nodes = road.nodes
        }
        table.insert(saveData.roads, savedRoad)
    end
    
    -- Serialize the game state using serpent
    local serpent = require("lib/serpent")
    local serializedData = "-- SaveInfo: " .. date .. " - Villages: " .. #saveData.villages .. "\n"
    serializedData = serializedData .. serpent.dump(saveData)
    
    -- Save to file
    local path = "saves/" .. filename
    local success, message = love.filesystem.write(path, serializedData)
    
    if success then
        UI.showMessage("Game saved to " .. filename)
        UI.loadSaveFiles() -- Refresh the list
    else
        UI.showMessage("Error saving game: " .. (message or "Unknown error"))
    end
    
    return success
end

-- Load a saved game
function UI.loadGame(game, filepath)
    -- Check if file exists
    if not love.filesystem.getInfo(filepath) then
        UI.showMessage("Save file not found: " .. filepath)
        return false
    end
    
    -- Read the file
    local content = love.filesystem.read(filepath)
    if not content then
        UI.showMessage("Error reading save file")
        return false
    end
    
    -- Skip the metadata line
    local dataContent = content:gsub("^.-\n", "")
    
    -- Deserialize using serpent
    local serpent = require("lib/serpent")
    local success, saveData = serpent.load(dataContent)
    
    if not success or not saveData then
        UI.showMessage("Error parsing save file")
        return false
    end
    
    -- Reset current game state
    game:reset(true) -- Pass true to indicate we're resetting for a loading operation
    
    -- Restore game state
    game.money = saveData.money or Config.STARTING_MONEY
    game.resources = saveData.resources or Config.STARTING_RESOURCES
    game.gameSpeed = saveData.gameSpeed or Config.TIME_NORMAL_SPEED
    
    -- Restore map if saved
    if saveData.mapData then
        -- Ensure map resources are loaded before restoring tiles
        if not game.map.tileset then
            game.map.tileset = love.graphics.newImage("data/tiles.png")
            
            -- Calculate tile dimensions from the tileset image
            local tilesetWidth = game.map.tileset:getWidth()
            local tileCount = 3  -- We have 3 tiles: grass, road, water
            game.map.tileSize = tilesetWidth / tileCount
            
            -- Create tile quads for each tile in the tileset
            game.map.quads = {}
            for i = 0, tileCount - 1 do
                game.map.quads[i + 1] = love.graphics.newQuad(
                    i * game.map.tileSize, 0,
                    game.map.tileSize, game.map.tileSize,
                    tilesetWidth, game.map.tileset:getHeight()
                )
            end
        end
        
        game.map.tiles = saveData.mapData
    end
    
    -- Load villages
    for _, savedVillage in ipairs(saveData.villages or {}) do
        local Village = require("entities/village")
        local village = Village.new(savedVillage.x, savedVillage.y)
        village.id = savedVillage.id
        village.name = savedVillage.name
        village.population = savedVillage.population
        village.maxPopulation = savedVillage.maxPopulation
        village.resources = savedVillage.resources
        table.insert(game.villages, village)
    end
    
    -- Load buildings
    for _, savedBuilding in ipairs(saveData.buildings or {}) do
        local Building = require("entities/building")
        local building = Building.new(savedBuilding.x, savedBuilding.y, savedBuilding.type, savedBuilding.villageId)
        building.id = savedBuilding.id
        building.health = savedBuilding.health
        building.maxHealth = savedBuilding.maxHealth
        building.currentVillagers = savedBuilding.currentVillagers
        building.villagerCapacity = savedBuilding.villagerCapacity
        building.productionTimer = savedBuilding.productionTimer
        building.productionTime = savedBuilding.productionTime
        table.insert(game.buildings, building)
    end
    
    -- Load builders
    for _, savedBuilder in ipairs(saveData.builders or {}) do
        local Builder = require("entities/builder")
        local builder = Builder.new(savedBuilder.x, savedBuilder.y, savedBuilder.villageId)
        builder.id = savedBuilder.id
        builder.targetX = savedBuilder.targetX
        builder.targetY = savedBuilder.targetY
        builder.state = savedBuilder.state
        builder.buildingId = savedBuilder.buildingId
        builder.buildingType = savedBuilder.buildingType
        builder.buildingX = savedBuilder.buildingX
        builder.buildingY = savedBuilder.buildingY
        table.insert(game.builders, builder)
    end
    
    -- Load villagers
    for _, savedVillager in ipairs(saveData.villagers or {}) do
        local Villager = require("entities/villager")
        local villager = Villager.new(savedVillager.x, savedVillager.y, savedVillager.villageId)
        villager.id = savedVillager.id
        villager.targetX = savedVillager.targetX
        villager.targetY = savedVillager.targetY
        villager.state = savedVillager.state
        villager.buildingId = savedVillager.buildingId
        villager.resourceType = savedVillager.resourceType
        villager.resourceAmount = savedVillager.resourceAmount
        table.insert(game.villagers, villager)
    end
    
    -- Load roads
    for _, savedRoad in ipairs(saveData.roads or {}) do
        local Road = require("entities/road")
        local road = Road.new(savedRoad.startX, savedRoad.startY, savedRoad.endX, savedRoad.endY, savedRoad.villageId)
        road.id = savedRoad.id
        road.nodes = savedRoad.nodes
        table.insert(game.roads, road)
    end
    
    -- Ensure road tiles are in sync with road entities
    local Road = require("entities/road")
    Road.buildRoadsOnMap(game.roads, game.map)
    
    UI.showMessage("Game loaded successfully!")
    
    -- Close dialogs and show the game
    UI.showMainMenu = false
    UI.showLoadDialog = false
    UI.gameRunning = true
    
    return true
end

-- Draw the save dialog
function UI.drawSaveDialog()
    local width = love.graphics.getWidth() * 0.5
    local height = love.graphics.getHeight() * 0.3
    local x = (love.graphics.getWidth() - width) / 2
    local y = (love.graphics.getHeight() - height) / 2
    
    -- Draw dialog background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.5, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    local title = "Save Game"
    local titleWidth = UI.titleFont:getWidth(title)
    love.graphics.print(title, x + (width - titleWidth) / 2, y + 20)
    
    love.graphics.setFont(UI.font)
    love.graphics.print("Your game will be saved with the current timestamp", x + 40, y + 70)
    
    -- Draw action buttons
    local buttonWidth = 120
    local buttonHeight = 40
    
    -- Save button
    love.graphics.setColor(0.2, 0.5, 0.3)
    love.graphics.rectangle("fill", x + width - buttonWidth - 20, y + height - 60, buttonWidth, buttonHeight)
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.rectangle("line", x + width - buttonWidth - 20, y + height - 60, buttonWidth, buttonHeight)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Save", x + width - buttonWidth + 10, y + height - 50)
    
    -- Cancel button
    love.graphics.setColor(0.5, 0.2, 0.2)
    love.graphics.rectangle("fill", x + 20, y + height - 60, buttonWidth, buttonHeight)
    love.graphics.setColor(0.8, 0.5, 0.5)
    love.graphics.rectangle("line", x + 20, y + height - 60, buttonWidth, buttonHeight)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Cancel", x + 50, y + height - 50)
end

-- Draw the load dialog
function UI.drawLoadDialog()
    local width = love.graphics.getWidth() * 0.6
    local height = love.graphics.getHeight() * 0.7
    local x = (love.graphics.getWidth() - width) / 2
    local y = (love.graphics.getHeight() - height) / 2
    
    -- Draw dialog background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.95)
    love.graphics.rectangle("fill", x, y, width, height)
    love.graphics.setColor(0.5, 0.5, 0.7, 1)
    love.graphics.rectangle("line", x, y, width, height)
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    local title = "Load Game"
    local titleWidth = UI.titleFont:getWidth(title)
    love.graphics.print(title, x + (width - titleWidth) / 2, y + 20)
    
    -- Setup scrollable area for save files
    local fileListX = x + 20
    local fileListY = y + 80
    local fileListWidth = width - 40
    local fileListHeight = height - 160
    local fileHeight = 40
    local fileSpacing = 10
    
    -- Draw border for file list area
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle("line", fileListX, fileListY, fileListWidth, fileListHeight)
    
    -- Create a stencil for the file list area
    love.graphics.stencil(function()
        love.graphics.rectangle("fill", fileListX, fileListY, fileListWidth, fileListHeight)
    end, "replace", 1)
    love.graphics.setStencilTest("greater", 0)
    
    -- Draw save files list
    love.graphics.setFont(UI.font)
    
    if #UI.saveFiles == 0 then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("No saved games found.", fileListX + 10, fileListY + 20)
    else
        local visibleHeight = fileListHeight
        local totalHeight = #UI.saveFiles * (fileHeight + fileSpacing)
        
        -- Adjust scroll if needed
        if UI.loadDialogScroll > totalHeight - visibleHeight then
            UI.loadDialogScroll = math.max(0, totalHeight - visibleHeight)
        end
        
        for i, saveInfo in ipairs(UI.saveFiles) do
            local fileY = fileListY + (i-1) * (fileHeight + fileSpacing) - UI.loadDialogScroll
            
            -- Only draw files that are in the visible area
            if fileY + fileHeight >= fileListY and fileY <= fileListY + fileListHeight then
                -- Draw file background
                if UI.selectedSaveFile and UI.selectedSaveFile == i then
                    love.graphics.setColor(0.3, 0.5, 0.7)
                else
                    love.graphics.setColor(0.2, 0.3, 0.4)
                end
                love.graphics.rectangle("fill", fileListX, fileY, fileListWidth, fileHeight)
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.rectangle("line", fileListX, fileY, fileListWidth, fileHeight)
                
                -- Draw file information
                love.graphics.setColor(1, 1, 1)
                
                -- Format the date/time from timestamp
                local dateStr = "Unknown date"
                if saveInfo.modtime then
                    dateStr = os.date("%Y-%m-%d %H:%M:%S", saveInfo.modtime)
                end
                
                love.graphics.print(saveInfo.filename:gsub("%.save$", ""), fileListX + 10, fileY + 8)
                
                if saveInfo.metadata then
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.setFont(UI.smallFont)
                    love.graphics.print(saveInfo.metadata, fileListX + 10, fileY + 25)
                    love.graphics.setFont(UI.font)
                else
                    love.graphics.setColor(0.7, 0.7, 0.7)
                    love.graphics.setFont(UI.smallFont)
                    love.graphics.print("Saved: " .. dateStr, fileListX + 10, fileY + 25)
                    love.graphics.setFont(UI.font)
                end
            end
        end
        
        -- Draw scroll bar if needed
        if totalHeight > visibleHeight then
            local scrollBarWidth = 10
            local scrollBarHeight = math.max(30, visibleHeight * (visibleHeight / totalHeight))
            local scrollBarX = fileListX + fileListWidth - scrollBarWidth
            local scrollBarY = fileListY + (UI.loadDialogScroll / (totalHeight - visibleHeight)) * (visibleHeight - scrollBarHeight)
            
            -- Draw scroll bar background
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
            love.graphics.rectangle("fill", scrollBarX, fileListY, scrollBarWidth, visibleHeight)
            
            -- Draw scroll bar handle
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.rectangle("fill", scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight)
            
            -- Draw scroll indicators
            love.graphics.setColor(0.8, 0.8, 0.8, UI.loadDialogScroll > 0 and 1 or 0.3)
            love.graphics.print("▲", scrollBarX - 15, fileListY)
            love.graphics.setColor(0.8, 0.8, 0.8, UI.loadDialogScroll < totalHeight - visibleHeight and 1 or 0.3)
            love.graphics.print("▼", scrollBarX - 15, fileListY + visibleHeight - 20)
        end
    end
    
    -- Reset stencil
    love.graphics.setStencilTest()
    
    -- Draw action buttons
    local buttonWidth = 120
    local buttonHeight = 40
    
    -- Load button
    love.graphics.setColor(0.2, 0.5, 0.3)
    love.graphics.rectangle("fill", x + width - buttonWidth - 20, y + height - 60, buttonWidth, buttonHeight)
    love.graphics.setColor(0.5, 0.8, 0.5)
    love.graphics.rectangle("line", x + width - buttonWidth - 20, y + height - 60, buttonWidth, buttonHeight)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Load", x + width - buttonWidth + 10, y + height - 50)
    
    -- Cancel button
    love.graphics.setColor(0.5, 0.2, 0.2)
    love.graphics.rectangle("fill", x + 20, y + height - 60, buttonWidth, buttonHeight)
    love.graphics.setColor(0.8, 0.5, 0.5)
    love.graphics.rectangle("line", x + 20, y + height - 60, buttonWidth, buttonHeight)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Cancel", x + 50, y + height - 50)
end

-- Handle save dialog clicks
function UI.handleSaveDialogClick(game, x, y)
    local dialogWidth = love.graphics.getWidth() * 0.5
    local dialogHeight = love.graphics.getHeight() * 0.3
    local dialogX = (love.graphics.getWidth() - dialogWidth) / 2
    local dialogY = (love.graphics.getHeight() - dialogHeight) / 2
    
    -- Check action buttons
    local buttonWidth = 120
    local buttonHeight = 40
    
    -- Save button
    if x >= dialogX + dialogWidth - buttonWidth - 20 and x <= dialogX + dialogWidth - 20 and
       y >= dialogY + dialogHeight - 60 and y <= dialogY + dialogHeight - 20 then
        
        -- Create a new save file with timestamp
        UI.saveGame(game)
        
        -- Close the dialog
        UI.showSaveDialog = false
        UI.showPauseMenu = true
        return true
    end
    
    -- Cancel button
    if x >= dialogX + 20 and x <= dialogX + 20 + buttonWidth and
       y >= dialogY + dialogHeight - 60 and y <= dialogY + dialogHeight - 20 then
        UI.showSaveDialog = false
        UI.showPauseMenu = true
        return true
    end
    
    -- Clicking anywhere else in the dialog
    return true
end

-- Handle load dialog clicks
function UI.handleLoadDialogClick(game, x, y)
    local dialogWidth = love.graphics.getWidth() * 0.6
    local dialogHeight = love.graphics.getHeight() * 0.7
    local dialogX = (love.graphics.getWidth() - dialogWidth) / 2
    local dialogY = (love.graphics.getHeight() - dialogHeight) / 2
    
    -- Setup file list area
    local fileListX = dialogX + 20
    local fileListY = dialogY + 80
    local fileListWidth = dialogWidth - 40
    local fileListHeight = dialogHeight - 160
    local fileHeight = 40
    local fileSpacing = 10
    
    -- Check scroll bar clicks
    local scrollBarWidth = 10
    local scrollBarX = fileListX + fileListWidth - scrollBarWidth
    
    -- Check up arrow click
    if #UI.saveFiles > 0 and 
       x >= scrollBarX - 15 and x <= scrollBarX and
       y >= fileListY and y <= fileListY + 20 then
        -- Scroll up
        UI.loadDialogScroll = math.max(0, UI.loadDialogScroll - (fileHeight + fileSpacing))
        return true
    end
    
    -- Check down arrow click
    if #UI.saveFiles > 0 and 
       x >= scrollBarX - 15 and x <= scrollBarX and
       y >= fileListY + fileListHeight - 20 and y <= fileListY + fileListHeight then
        -- Scroll down
        local totalHeight = #UI.saveFiles * (fileHeight + fileSpacing)
        UI.loadDialogScroll = math.min(totalHeight - fileListHeight, UI.loadDialogScroll + (fileHeight + fileSpacing))
        return true
    end
    
    -- Check file clicks within the stencil area
    if x >= fileListX and x <= fileListX + fileListWidth - scrollBarWidth and
       y >= fileListY and y <= fileListY + fileListHeight then
        
        for i, saveInfo in ipairs(UI.saveFiles) do
            local fileY = fileListY + (i-1) * (fileHeight + fileSpacing) - UI.loadDialogScroll
            
            -- Only check files in the visible area
            if fileY + fileHeight >= fileListY and fileY <= fileListY + fileListHeight then
                if y >= fileY and y <= fileY + fileHeight then
                    UI.selectedSaveFile = i
                    return true
                end
            end
        end
    end
    
    -- Check action buttons
    local buttonWidth = 120
    local buttonHeight = 40
    
    -- Load button
    if x >= dialogX + dialogWidth - buttonWidth - 20 and x <= dialogX + dialogWidth - 20 and
       y >= dialogY + dialogHeight - 60 and y <= dialogY + dialogHeight - 20 then
        
        if UI.selectedSaveFile and UI.selectedSaveFile <= #UI.saveFiles then
            local saveInfo = UI.saveFiles[UI.selectedSaveFile]
            UI.loadGame(game, "saves/" .. saveInfo.filename)
        else
            UI.showMessage("Please select a save file first")
        end
        
        return true
    end
    
    -- Cancel button
    if x >= dialogX + 20 and x <= dialogX + 20 + buttonWidth and
       y >= dialogY + dialogHeight - 60 and y <= dialogY + dialogHeight - 20 then
        UI.showLoadDialog = false
        UI.selectedSaveFile = nil
        UI.loadDialogScroll = 0 -- Reset scroll position
        return true
    end
    
    -- Clicking anywhere else in the dialog
    return true
end

-- Handle text input for save naming
function UI.textinput(text)
    if UI.saveInputActive then
        UI.saveNameInput = UI.saveNameInput .. text
    end
end

-- Handle keypressed for save dialog
function UI.keypressed(game, key)
    if UI.saveInputActive then
        if key == "backspace" then
            -- Remove the last character
            UI.saveNameInput = UI.saveNameInput:sub(1, -2)
        elseif key == "escape" then
            -- Cancel save name input
            UI.saveInputActive = false
            UI.saveNameInput = ""
        elseif key == "return" or key == "kpenter" then
            -- Save with the current name
            UI.saveGame(game, UI.saveNameInput)
            UI.saveInputActive = false
            UI.showSaveDialog = false
            UI.showPauseMenu = true
            UI.saveNameInput = ""
            UI.selectedSaveFile = nil
        end
    end
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
        -- If load dialog is showing, handle load dialog clicks
        if UI.showLoadDialog then
            return UI.handleLoadDialogClick(game, x, y)
        end
        return UI.handleMainMenuClick(game, x, y)
    end
    
    -- If save dialog is showing, handle save dialog clicks
    if UI.showSaveDialog then
        return UI.handleSaveDialogClick(game, x, y)
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
    if UI.showPopup then
        return UI.handlePopupClick(x, y)
    end
    
    -- Handle menu option clicks
    local menuWidth = 300
    local buttonHeight = 50
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 100
    
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
                        UI.showPopup = true
                        UI.popupType = "howToPlay"
                        UI.popupScroll = 0
                        return true
                    elseif docOption == "About" then
                        UI.showPopup = true
                        UI.popupType = "about"
                        UI.popupScroll = 0
                        return true
                    elseif docOption == "Changelog" then
                        UI.showPopup = true
                        UI.popupType = "changelog"
                        UI.popupScroll = 0
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
                UI.loadSaveFiles() -- Refresh list of saves
                UI.showLoadDialog = true
                UI.selectedSaveFile = nil
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
                -- Show save dialog and refresh save slots
                UI.loadSaveFiles() -- Refresh list of saves
                UI.showSaveDialog = true
                UI.showPauseMenu = false
                UI.selectedSaveFile = nil
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
        
        -- If load dialog is showing, draw it on top of main menu
        if UI.showLoadDialog then
            UI.drawLoadDialog()
        -- If documentation popup is active, draw it on top
        elseif UI.showPopup then
            UI.drawDocumentationPopup()
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
                love.graphics.rectangle("fill", worldX - 80, worldY - 45, 160, 30)
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print("Cannot build on water!", worldX - 70, worldY - 40)
            end
        end
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
    
    -- Draw save dialog if showing
    if UI.showSaveDialog then
        UI.drawSaveDialog()
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
    
    -- Draw title
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(UI.titleFont)
    local title = "Villageworks"
    local titleWidth = UI.titleFont:getWidth(title)
    love.graphics.print(title, (love.graphics.getWidth() - titleWidth) / 2, 100)
    
    -- Draw menu options
    local menuWidth = 300
    local buttonHeight = 50
    local buttonSpacing = 20
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local startY = love.graphics.getHeight() / 2 - 100
    
    love.graphics.setFont(UI.bigFont)
    
    for i, option in ipairs(UI.mainMenuOptions) do
        local buttonY = startY + (i-1) * (buttonHeight + buttonSpacing)
        
        -- Special case for docs row
        if option == "Docs" then
            -- Draw three side-by-side buttons for documentation
            local smallButtonWidth = (menuWidth - 20) / 3
            
            for j, docOption in ipairs(UI.docsOptions) do
                local docButtonX = menuX + (j-1) * (smallButtonWidth + 10)
                
                -- Draw button background
                if j == 1 then
                    love.graphics.setColor(0.2, 0.4, 0.5) -- How to Play
                elseif j == 2 then
                    love.graphics.setColor(0.3, 0.3, 0.5) -- About
                else
                    love.graphics.setColor(0.4, 0.3, 0.4) -- Changelog
                end
                
                love.graphics.rectangle("fill", docButtonX, buttonY, smallButtonWidth, buttonHeight)
                love.graphics.setColor(0.5, 0.7, 0.9)
                love.graphics.rectangle("line", docButtonX, buttonY, smallButtonWidth, buttonHeight)
                
                -- Draw button text
                love.graphics.setColor(1, 1, 1)
                love.graphics.setFont(UI.font) -- Use smaller font for doc buttons
                local textWidth = UI.font:getWidth(docOption)
                love.graphics.print(docOption, docButtonX + (smallButtonWidth - textWidth) / 2, buttonY + 17)
            end
            
            -- Reset font size for other buttons
            love.graphics.setFont(UI.bigFont)
        else
            -- Draw regular button background
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
    
    -- Draw version information at the bottom of the screen
    local Version = require("version")
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setFont(UI.smallFont)
    local versionString = Version.getFullVersionString()
    love.graphics.print(versionString, 10, love.graphics.getHeight() - 20)
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
    
    -- Restore the original font
    love.graphics.setFont(currentFont)
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

return UI 