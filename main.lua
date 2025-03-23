-- Import modules
local Config = require("config")
local Utils = require("utils")
local Camera = require("camera")
local Village = require("entities/village")
local Builder = require("entities/builder")
local Building = require("entities/building")
local Villager = require("entities/villager")
local Road = require("entities/road")
local UI = require("ui")
local Map = require("map")

-- Game state
local game = {
    money = Config.STARTING_MONEY,
    villages = {},
    builders = {},
    buildings = {},
    villagers = {},
    roads = {},
    resources = Config.STARTING_RESOURCES,
    selectedEntity = nil,
    selectedVillage = nil,  -- Track which village is selected
    uiMode = Config.UI_MODE_NORMAL, -- Current UI interaction mode
    gameSpeed = Config.TIME_NORMAL_SPEED, -- Current game speed
    map = nil -- Reference to the map
}

-- Function to reset the game state
function game:reset(isLoading)
    self.money = Config.STARTING_MONEY
    self.villages = {}
    self.builders = {}
    self.buildings = {}
    self.villagers = {}
    self.roads = {}
    self.resources = {
        wood = Config.STARTING_RESOURCES.wood,
        stone = Config.STARTING_RESOURCES.stone,
        food = Config.STARTING_RESOURCES.food
    }
    self.selectedEntity = nil
    self.selectedVillage = nil
    self.uiMode = Config.UI_MODE_NORMAL
    self.gameSpeed = Config.TIME_NORMAL_SPEED
    
    -- Reset camera position
    if self.camera then
        if isLoading then
            -- When loading a game, just reset zoom
            self.camera.targetScale = 1
        else
            -- When starting a new game, center on the world
            local worldCenterX = Config.WORLD_WIDTH / 2
            local worldCenterY = Config.WORLD_HEIGHT / 2
            self.camera:setTarget(worldCenterX - love.graphics.getWidth() / 2, worldCenterY - love.graphics.getHeight() / 2)
            self.camera.targetScale = 1
        end
    end
    
    -- Regenerate the map only if not loading a saved game
    if self.map and not isLoading then
        Map.init()
    end
    
    -- Ensure road tiles are in sync with road entities after reset
    Road.buildRoadsOnMap(self.roads, self.map)
end

function love.load()
    love.graphics.setBackgroundColor(0.2, 0.6, 0.1) -- Green grass background
    
    -- Load version information
    local Version = require("version")
    love.window.setTitle("Villageworks " .. Version.getVersionString())
    
    -- Set the window to be resizable
    love.window.setMode(800, 600, {
        resizable = true,
        minwidth = 800,
        minheight = 600,
        highdpi = true,
        msaa = 4
    })
    
    -- Initialize camera
    game.camera = Camera.new()
    
    -- Initialize map
    Map.init()
    game.map = Map
    
    -- Center camera at the middle of the world
    local worldCenterX = Config.WORLD_WIDTH / 2
    local worldCenterY = Config.WORLD_HEIGHT / 2
    game.camera:setTarget(worldCenterX - love.graphics.getWidth() / 2, worldCenterY - love.graphics.getHeight() / 2)
    
    -- Initialize UI
    UI.init()
    
    -- Set random seed
    math.randomseed(os.time())
    
    -- Ensure road tiles are in sync with road entities on initial load
    Road.buildRoadsOnMap(game.roads, game.map)
end

function love.update(dt)
    -- Update UI always
    UI.update(game, dt)
    
    -- If in main menu or pause menu, don't update game logic
    if UI.showMainMenu or UI.showPauseMenu then
        return
    end
    
    -- Ensure road tiles are in sync with road entities
    Road.buildRoadsOnMap(game.roads, game.map)
    
    -- Apply game speed
    local adjustedDt = dt * game.gameSpeed
    
    -- Update camera
    local cameraSpeed = 200 * dt -- Camera speed not affected by game speed
    if love.keyboard.isDown("right") then
        game.camera:move(cameraSpeed, 0)
    elseif love.keyboard.isDown("left") then
        game.camera:move(-cameraSpeed, 0)
    end
    
    if love.keyboard.isDown("down") then
        game.camera:move(0, cameraSpeed)
    elseif love.keyboard.isDown("up") then
        game.camera:move(0, -cameraSpeed)
    end
    
    -- Check for spacebar (time acceleration)
    if love.keyboard.isDown("space") then
        game.gameSpeed = Config.TIME_FAST_SPEED
    else
        game.gameSpeed = Config.TIME_NORMAL_SPEED
    end
    
    game.camera:update(dt) -- Camera update not affected by game speed
    
    -- Update entities with adjusted time
    Village.update(game.villages, game, adjustedDt)
    Builder.update(game.builders, game, adjustedDt)
    Building.update(game.buildings, game, adjustedDt)
    Villager.update(game.villagers, game, adjustedDt)
    Road.update(game.roads, game, adjustedDt)
    Map.update(adjustedDt) -- Update map for forest regrowth
end

function love.draw()
    -- All drawing is now handled by the UI module
    UI.draw(game)
end

function drawGrid()
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

function drawEntities()
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

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = game.camera:screenToWorld(x, y)
        
        -- Check if we're clicking on UI area
        if y < 40 then return end
        if UI.handleClick(game, x, y) then return end
        
        -- Handle based on UI mode
        if game.uiMode == Config.UI_MODE_BUILDING_VILLAGE then
            -- First check if position is within map bounds
            if not game.map:isWithinBounds(worldX, worldY) then
                -- Show error message
                UI.showMessage("ERROR: Cannot build outside map boundaries! Move closer to the center.")
                return
            end
            
            -- Check if position is buildable (not water)
            if game.map:canBuildAt(worldX, worldY) then
                -- In village building mode, place a new village if we have resources
                if game.money >= Config.VILLAGE_COST and game.resources.wood >= 20 then
                    game.money = game.money - Config.VILLAGE_COST
                    game.resources.wood = game.resources.wood - 20
                    
                    -- Set the tile below the village to a road tile
                    game.map:setTileTypeAtWorld(worldX, worldY, Map.TILE_ROAD)
                    
                    -- Create new village
                    local newVillage = Village.new(worldX, worldY)
                    table.insert(game.villages, newVillage)
                    
                    -- Select the new village
                    game.selectedVillage = newVillage
                    
                    -- Return to normal mode
                    game.uiMode = Config.UI_MODE_NORMAL
                else
                    -- Not enough resources, show message through UI
                    UI.showMessage("Not enough resources! Need $" .. Config.VILLAGE_COST .. " and " .. 20 .. " wood.")
                end
            else
                -- Cannot build on water
                UI.showMessage("Cannot build on water! Choose a valid location on land.")
            end
        else
            -- Normal mode - handle selection
            -- Check if we're clicking on an existing village
            local clickedVillage = nil
            for _, village in ipairs(game.villages) do
                if Utils.distance(worldX, worldY, village.x, village.y) < 15 then
                    clickedVillage = village
                    break
                end
            end
            
            if clickedVillage then
                -- Select/focus the village
                game.selectedVillage = clickedVillage
                
                -- Center camera on the village (with smooth transition)
                game.camera:setTarget(clickedVillage.x - love.graphics.getWidth() / 2, clickedVillage.y - love.graphics.getHeight() / 2)
            end
        end
    elseif button == 2 then
        -- Right-click to deselect current village and cancel build mode
        game.selectedVillage = nil
        game.uiMode = Config.UI_MODE_NORMAL
    end
end

function love.wheelmoved(x, y)
    -- Let UI module handle wheel events first
    if UI.wheelmoved(x, y) then
        return
    end
    
    -- Zoom camera with mouse wheel
    local factor = 1.1
    if y > 0 then
        game.camera:zoom(factor)
    elseif y < 0 then
        game.camera:zoom(1/factor)
    end
end

function love.keypressed(key)
    -- Let UI handle key events first
    UI.keypressed(game, key)
    
    -- Check if we're in the main menu
    if UI.showMainMenu then
        return -- Let UI handle main menu keypresses
    end
    
    -- Toggle build menu
    if key == "b" then
        UI.showBuildMenu = not UI.showBuildMenu
    end
    
    -- Escape key for pause menu if in the game
    if key == "escape" then
        if game.uiMode == Config.UI_MODE_BUILDING_VILLAGE then
            -- If in village building mode, just exit that mode
            game.uiMode = Config.UI_MODE_NORMAL
        elseif UI.showBuildMenu then
            -- If build menu is open, close it
            UI.showBuildMenu = false
        elseif UI.roadCreationMode then
            -- If in road creation mode, exit that mode
            UI.roadCreationMode = false
            UI.roadStartVillage = nil
            UI.roadStartX = nil
            UI.roadStartY = nil
        else
            -- Otherwise toggle pause menu
            UI.showPauseMenu = not UI.showPauseMenu
        end
    end
    
    -- Quick save with F5
    if key == "f5" then
        SaveLoad.saveGame(game)
    end
    
    -- Number keys to quickly select villages by index
    if key >= "1" and key <= "9" then
        local index = tonumber(key)
        if game.villages[index] then
            game.selectedVillage = game.villages[index]
            
            -- Center camera on the village
            game.camera:setTarget(game.selectedVillage.x - love.graphics.getWidth() / 2, 
                                 game.selectedVillage.y - love.graphics.getHeight() / 2)
        end
    end
end

-- Handle window resize events
function love.resize(w, h)
    -- Update camera if it exists
    if game.camera then
        -- Calculate world coordinates of the screen center before resize
        local oldCenterX = love.graphics.getWidth() / 2
        local oldCenterY = love.graphics.getHeight() / 2
        local worldCenterX, worldCenterY = game.camera:screenToWorld(oldCenterX, oldCenterY)
        
        -- Update camera bounds based on new window size
        game.camera:recalculateBounds()
        
        -- Recalculate the camera position to keep the same world point at the center
        local newCenterX = w / 2
        local newCenterY = h / 2
        game.camera.targetX = worldCenterX * game.camera.scale - newCenterX
        game.camera.targetY = worldCenterY * game.camera.scale - newCenterY
    end
end