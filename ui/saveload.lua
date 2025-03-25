local SaveLoad = {}

-- Initialize save/load system
function SaveLoad.init(UI)
    SaveLoad.UI = UI -- Store reference to main UI
    
    -- Save/load state
    SaveLoad.showSaveDialog = false
    SaveLoad.showLoadDialog = false
    SaveLoad.saveFiles = {}
    SaveLoad.selectedSaveFile = nil
    SaveLoad.saveNameInput = ""
    SaveLoad.saveInputActive = false
    SaveLoad.loadDialogScroll = 0
    
    -- Ensure the saves directory exists
    SaveLoad.ensureSavesDirectoryExists()
end

-- Ensure the saves directory exists
function SaveLoad.ensureSavesDirectoryExists()
    local success = love.filesystem.getInfo("saves")
    if not success then
        love.filesystem.createDirectory("saves")
    end
end

-- Get list of available save files
function SaveLoad.loadSaveFiles()
    SaveLoad.saveFiles = {}
    
    -- Ensure saves directory exists
    SaveLoad.ensureSavesDirectoryExists()
    
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
            
            table.insert(SaveLoad.saveFiles, saveInfo)
        end
    end
    
    -- Sort files by modification time (newest first)
    table.sort(SaveLoad.saveFiles, function(a, b) 
        return (a.modtime or 0) > (b.modtime or 0)
    end)
end

-- Create a timestamped filename
function SaveLoad.createTimestampedFilename()
    local date = os.date("%Y-%m-%d_%H-%M-%S")
    return "village_" .. date .. ".save"
end

-- Save the current game state
function SaveLoad.saveGame(game, filename)
    if not filename then
        filename = SaveLoad.createTimestampedFilename()
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
        mapWidth = game.map.width,
        mapHeight = game.map.height,
        tileSize = game.map.tileSize,
        
        -- Only save the necessary data from entities
        villages = {},
        buildings = {},
        buildingTasks = {},
        villagers = {},
        roads = {}
    }
    
    -- Save villages
    if game.villages then
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
    end
    
    -- Save buildings
    if game.buildings then
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
                productionTime = building.productionTime,
                tileX = math.floor(building.x / game.map.tileSize),
                tileY = math.floor(building.y / game.map.tileSize)
            }
            table.insert(saveData.buildings, savedBuilding)
        end
    end
    
    -- Save building tasks
    if game.buildingTasks then
        for _, task in ipairs(game.buildingTasks) do
            local savedTask = {
                x = task.x,
                y = task.y,
                type = task.type,
                villageId = task.villageId,
                progress = task.progress,
                totalWorkNeeded = task.totalWorkNeeded,
                priority = task.priority,
                tileX = task.tileX,
                tileY = task.tileY
            }
            table.insert(saveData.buildingTasks, savedTask)
        end
    end
    
    -- Save villagers
    if game.villagers then
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
                resourceAmount = villager.resourceAmount,
                tileX = math.floor(villager.x / game.map.tileSize),
                tileY = math.floor(villager.y / game.map.tileSize)
            }
            table.insert(saveData.villagers, savedVillager)
        end
    end
    
    -- Save roads
    if game.roads then
        for _, road in ipairs(game.roads) do
            local savedRoad = {
                id = road.id,
                villageId = road.villageId,
                startX = road.startX,
                startY = road.startY,
                endX = road.endX,
                endY = road.endY,
                nodes = road.nodes,
                startTileX = math.floor(road.startX / game.map.tileSize),
                startTileY = math.floor(road.startY / game.map.tileSize),
                endTileX = math.floor(road.endX / game.map.tileSize),
                endTileY = math.floor(road.endY / game.map.tileSize)
            }
            table.insert(saveData.roads, savedRoad)
        end
    end
    
    -- Serialize the game state using serpent
    local serpent = require("lib/serpent")
    local villageCount = saveData.villages and #saveData.villages or 0
    local serializedData = "-- SaveInfo: " .. date .. " - Villages: " .. villageCount .. "\n"
    
    -- Use pcall to catch any errors during serialization
    local success, result = pcall(function()
        return serpent.dump(saveData)
    end)
    
    if not success then
        SaveLoad.UI.showMessage("Error serializing game data: " .. (result or "Unknown error"))
        return false
    end
    
    serializedData = serializedData .. result
    
    -- Save to file
    local path = "saves/" .. filename
    local writeSuccess, message = love.filesystem.write(path, serializedData)
    
    if writeSuccess then
        SaveLoad.UI.showMessage("Game saved to " .. filename)
        SaveLoad.loadSaveFiles() -- Refresh the list
    else
        SaveLoad.UI.showMessage("Error saving game: " .. (message or "Unknown error"))
    end
    
    return writeSuccess
end

-- Load a saved game
function SaveLoad.loadGame(game, filepath)
    -- Check if file exists
    if not love.filesystem.getInfo(filepath) then
        SaveLoad.UI.showMessage("Save file not found: " .. filepath)
        return false
    end
    
    -- Read the file
    local content = love.filesystem.read(filepath)
    if not content then
        SaveLoad.UI.showMessage("Error reading save file")
        return false
    end
    
    -- Skip the metadata line
    local dataContent = content:gsub("^.-\n", "")
    
    -- Deserialize using serpent
    local serpent = require("lib/serpent")
    local success, saveData = serpent.load(dataContent)
    
    if not success or not saveData then
        SaveLoad.UI.showMessage("Error parsing save file")
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
            local tileCount = 5  -- Updated: Mountain, Forest, Grass, Road, Water
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
        
        -- Restore map dimensions and data
        game.map.width = saveData.mapWidth
        game.map.height = saveData.mapHeight
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
        -- Use tile coordinates to ensure proper alignment
        local x = savedBuilding.tileX * game.map.tileSize
        local y = savedBuilding.tileY * game.map.tileSize
        local building = Building.new(x, y, savedBuilding.type, savedBuilding.villageId)
        building.id = savedBuilding.id
        building.health = savedBuilding.health
        building.maxHealth = savedBuilding.maxHealth
        building.currentVillagers = savedBuilding.currentVillagers
        building.villagerCapacity = savedBuilding.villagerCapacity
        building.productionTimer = savedBuilding.productionTimer
        building.productionTime = savedBuilding.productionTime
        table.insert(game.buildings, building)
    end
    
    -- Load building tasks
    for _, savedTask in ipairs(saveData.buildingTasks or {}) do
        local BuildingTask = require("entities/building_task")
        local task = BuildingTask.new(
            savedTask.x, 
            savedTask.y, 
            savedTask.type, 
            savedTask.villageId, 
            savedTask.totalWorkNeeded
        )
        task.progress = savedTask.progress
        task.priority = savedTask.priority
        task.tileX = savedTask.tileX
        task.tileY = savedTask.tileY
        table.insert(game.buildingTasks, task)
    end
    
    -- Load villagers
    for _, savedVillager in ipairs(saveData.villagers or {}) do
        local Villager = require("entities/villager")
        -- Use tile coordinates to ensure proper alignment
        local x = savedVillager.tileX * game.map.tileSize
        local y = savedVillager.tileY * game.map.tileSize
        local villager = Villager.new(x, y, savedVillager.villageId)
        villager.id = savedVillager.id
        villager.targetX = savedVillager.targetX
        villager.targetY = savedVillager.targetY
        villager.state = savedVillager.state
        villager.buildingId = savedVillager.buildingId
        villager.resourceType = savedVillager.resourceType
        villager.resourceAmount = savedVillager.resourceAmount
        
        -- Always reset building-related fields to prevent nil access errors
        villager.buildTask = nil
        villager.buildProgress = 0
        -- If the villager was in building state, change it to idle
        if villager.state == "building" then
            villager.state = "idle"
        end
        
        table.insert(game.villagers, villager)
    end
    
    -- Load roads
    for _, savedRoad in ipairs(saveData.roads or {}) do
        local Road = require("entities/road")
        -- Use tile coordinates to ensure proper alignment
        local startX = savedRoad.startTileX * game.map.tileSize
        local startY = savedRoad.startTileY * game.map.tileSize
        local endX = savedRoad.endTileX * game.map.tileSize
        local endY = savedRoad.endTileY * game.map.tileSize
        local road = Road.new(startX, startY, endX, endY, savedRoad.villageId)
        road.id = savedRoad.id
        road.nodes = savedRoad.nodes
        table.insert(game.roads, road)
    end
    
    -- Ensure road tiles are in sync with road entities
    local Road = require("entities/road")
    Road.buildRoadsOnMap(game.roads, game.map)
    
    SaveLoad.UI.showMessage("Game loaded successfully!")
    
    -- Close dialogs and show the game
    SaveLoad.UI.showMainMenu = false
    SaveLoad.showLoadDialog = false
    SaveLoad.UI.gameRunning = true
    
    -- Additional post-loading cleanup and linking
    -- Ensure all building tasks are properly linked to villagers
    -- This prevents errors when loading the game multiple times
    for _, village in ipairs(game.villages) do
        -- Assign idle villagers from this village to available building tasks
        local villageBuildingTasks = {}
        for _, task in ipairs(game.buildingTasks) do
            if task.villageId == village.id then
                table.insert(villageBuildingTasks, task)
            end
        end
        
        -- Sort tasks by priority
        table.sort(villageBuildingTasks, function(a, b) 
            return (a.priority or 0) > (b.priority or 0)
        end)
    end
    
    -- Reset pathfinding state to prevent errors
    for _, villager in ipairs(game.villagers) do
        villager.path = nil
        if villager.targetX == nil then villager.targetX = villager.x end
        if villager.targetY == nil then villager.targetY = villager.y end
    end
    
    return true
end

-- Draw the save dialog
function SaveLoad.drawSaveDialog()
    local UI = SaveLoad.UI
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
    love.graphics.print("Your game will be saved as the timestamp", x + 40, y + 70)
    
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
function SaveLoad.drawLoadDialog()
    local UI = SaveLoad.UI
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
    
    if #SaveLoad.saveFiles == 0 then
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("No saved games found.", fileListX + 10, fileListY + 20)
    else
        local visibleHeight = fileListHeight
        local totalHeight = #SaveLoad.saveFiles * (fileHeight + fileSpacing)
        
        -- Adjust scroll if needed
        if SaveLoad.loadDialogScroll > totalHeight - visibleHeight then
            SaveLoad.loadDialogScroll = math.max(0, totalHeight - visibleHeight)
        end
        
        for i, saveInfo in ipairs(SaveLoad.saveFiles) do
            local fileY = fileListY + (i-1) * (fileHeight + fileSpacing) - SaveLoad.loadDialogScroll
            
            -- Only draw files that are in the visible area
            if fileY + fileHeight >= fileListY and fileY <= fileListY + fileListHeight then
                -- Draw file background
                if SaveLoad.selectedSaveFile and SaveLoad.selectedSaveFile == i then
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
            local scrollBarY = fileListY + (SaveLoad.loadDialogScroll / (totalHeight - visibleHeight)) * (visibleHeight - scrollBarHeight)
            
            -- Draw scroll bar background
            love.graphics.setColor(0.3, 0.3, 0.3, 0.8)
            love.graphics.rectangle("fill", scrollBarX, fileListY, scrollBarWidth, visibleHeight)
            
            -- Draw scroll bar handle
            love.graphics.setColor(0.6, 0.6, 0.6, 1)
            love.graphics.rectangle("fill", scrollBarX, scrollBarY, scrollBarWidth, scrollBarHeight)
            
            -- Draw scroll indicators
            love.graphics.setColor(0.8, 0.8, 0.8, SaveLoad.loadDialogScroll > 0 and 1 or 0.3)
            love.graphics.print("▲", scrollBarX - 15, fileListY)
            love.graphics.setColor(0.8, 0.8, 0.8, SaveLoad.loadDialogScroll < totalHeight - visibleHeight and 1 or 0.3)
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
function SaveLoad.handleSaveDialogClick(game, x, y)
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
        SaveLoad.saveGame(game)
        
        -- Close the dialog
        SaveLoad.showSaveDialog = false
        SaveLoad.UI.showPauseMenu = true
        return true
    end
    
    -- Cancel button
    if x >= dialogX + 20 and x <= dialogX + 20 + buttonWidth and
       y >= dialogY + dialogHeight - 60 and y <= dialogY + dialogHeight - 20 then
        SaveLoad.showSaveDialog = false
        SaveLoad.UI.showPauseMenu = true
        return true
    end
    
    -- Clicking anywhere else in the dialog
    return true
end

-- Handle load dialog clicks
function SaveLoad.handleLoadDialogClick(game, x, y)
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
    if #SaveLoad.saveFiles > 0 and 
       x >= scrollBarX - 15 and x <= scrollBarX and
       y >= fileListY and y <= fileListY + 20 then
        -- Scroll up
        SaveLoad.loadDialogScroll = math.max(0, SaveLoad.loadDialogScroll - (fileHeight + fileSpacing))
        return true
    end
    
    -- Check down arrow click
    if #SaveLoad.saveFiles > 0 and 
       x >= scrollBarX - 15 and x <= scrollBarX and
       y >= fileListY + fileListHeight - 20 and y <= fileListY + fileListHeight then
        -- Scroll down
        local totalHeight = #SaveLoad.saveFiles * (fileHeight + fileSpacing)
        SaveLoad.loadDialogScroll = math.min(totalHeight - fileListHeight, SaveLoad.loadDialogScroll + (fileHeight + fileSpacing))
        return true
    end
    
    -- Check file clicks within the stencil area
    if x >= fileListX and x <= fileListX + fileListWidth - scrollBarWidth and
       y >= fileListY and y <= fileListY + fileListHeight then
        
        for i, saveInfo in ipairs(SaveLoad.saveFiles) do
            local fileY = fileListY + (i-1) * (fileHeight + fileSpacing) - SaveLoad.loadDialogScroll
            
            -- Only check files in the visible area
            if fileY + fileHeight >= fileListY and fileY <= fileListY + fileListHeight then
                if y >= fileY and y <= fileY + fileHeight then
                    SaveLoad.selectedSaveFile = i
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
        
        if SaveLoad.selectedSaveFile and SaveLoad.selectedSaveFile <= #SaveLoad.saveFiles then
            local saveInfo = SaveLoad.saveFiles[SaveLoad.selectedSaveFile]
            SaveLoad.loadGame(game, "saves/" .. saveInfo.filename)
        else
            SaveLoad.UI.showMessage("Please select a save file first")
        end
        
        return true
    end
    
    -- Cancel button
    if x >= dialogX + 20 and x <= dialogX + 20 + buttonWidth and
       y >= dialogY + dialogHeight - 60 and y <= dialogY + dialogHeight - 20 then
        SaveLoad.showLoadDialog = false
        SaveLoad.selectedSaveFile = nil
        SaveLoad.loadDialogScroll = 0 -- Reset scroll position
        
        -- Reset the hover sound in MainMenu
        local MainMenu = require("ui.mainmenu")
        if MainMenu then
            MainMenu.reset_hover_sound()
        end
        
        return true
    end
    
    -- Clicking anywhere else in the dialog
    return true
end

-- Handle text input for save naming
function SaveLoad.textinput(text)
    if SaveLoad.saveInputActive then
        SaveLoad.saveNameInput = SaveLoad.saveNameInput .. text
    end
end

-- Handle keypressed for save dialog
function SaveLoad.keypressed(game, key)
    if SaveLoad.saveInputActive then
        if key == "backspace" then
            -- Remove the last character
            SaveLoad.saveNameInput = SaveLoad.saveNameInput:sub(1, -2)
        elseif key == "escape" then
            -- Cancel save name input
            SaveLoad.saveInputActive = false
            SaveLoad.saveNameInput = ""
        elseif key == "return" or key == "kpenter" then
            -- Save with the current name
            SaveLoad.saveGame(game, SaveLoad.saveNameInput)
            SaveLoad.saveInputActive = false
            SaveLoad.showSaveDialog = false
            SaveLoad.UI.showPauseMenu = true
            SaveLoad.saveNameInput = ""
            SaveLoad.selectedSaveFile = nil
        end
    end
    
    if SaveLoad.showLoadDialog then
        if key == "escape" then
            SaveLoad.showLoadDialog = false
            SaveLoad.selectedSaveFile = nil
            SaveLoad.loadDialogScroll = 0 -- Reset scroll position
        end
    end
    
    if SaveLoad.showSaveDialog then
        if key == "escape" then
            SaveLoad.showSaveDialog = false
            SaveLoad.UI.showPauseMenu = true
        end
    end
end

-- Handle mouse wheel events for scrolling
function SaveLoad.wheelmoved(x, y)
    if SaveLoad.showLoadDialog then
        local scrollSpeed = 30
        if y > 0 then -- Scroll up
            SaveLoad.loadDialogScroll = math.max(0, SaveLoad.loadDialogScroll - scrollSpeed)
        elseif y < 0 then -- Scroll down
            -- Calculate the maximum scroll possible
            local fileHeight = 40
            local fileSpacing = 10
            local totalHeight = #SaveLoad.saveFiles * (fileHeight + fileSpacing)
            local dialogHeight = love.graphics.getHeight() * 0.7
            local visibleHeight = dialogHeight - 160
            
            -- Apply scroll with limit
            SaveLoad.loadDialogScroll = math.min(math.max(0, totalHeight - visibleHeight), SaveLoad.loadDialogScroll + scrollSpeed)
        end
        return true -- Event handled
    end
    
    return false -- Event not handled
end

return SaveLoad