-- Import modules
local Config = require("config")
local Utils = require("utils")
local Camera = require("camera")
local Village = require("entities/village")
local Builder = require("entities/builder")
local Building = require("entities/building")
local Villager = require("entities/villager")
local UI = require("ui")

-- Game state
local game = {
    money = Config.STARTING_MONEY,
    villages = {},
    builders = {},
    buildings = {},
    villagers = {},
    resources = Config.STARTING_RESOURCES,
    selectedEntity = nil
}

function love.load()
    love.window.setTitle("Village Builder God Game")
    love.window.setMode(800, 600)
    
    -- Initialize camera
    game.camera = Camera.new()
    
    -- Initialize UI
    UI.init()
    
    -- Set random seed
    math.randomseed(os.time())
end

function love.update(dt)
    -- Update camera
    local cameraSpeed = 200 * dt
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
    
    game.camera:update(dt)
    
    -- Update entities
    Village.update(game.villages, game, dt)
    Builder.update(game.builders, game, dt)
    Building.update(game.buildings, game, dt)
    Villager.update(game.villagers, game, dt)
    
    -- Update UI
    UI.update(game, dt)
end

function love.draw()
    -- Begin camera transform
    game.camera:beginDraw()
    
    -- Draw grid
    drawGrid()
    
    -- Draw entities
    drawEntities()
    
    -- End camera transform
    game.camera:endDraw()
    
    -- Draw UI
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
    -- Draw all villages
    for _, village in ipairs(game.villages) do
        village:draw()
    end
    
    -- Draw all buildings
    for _, building in ipairs(game.buildings) do
        building:draw()
    end
    
    -- Draw all builders
    for _, builder in ipairs(game.builders) do
        builder:draw()
    end
    
    -- Draw all villagers
    for _, villager in ipairs(game.villagers) do
        villager:draw()
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Convert screen coordinates to world coordinates
        local worldX, worldY = game.camera:screenToWorld(x, y)
        
        -- Check if we're clicking on UI area
        if y < 40 then return end
        
        -- Place a new village if we have enough resources
        if game.money >= Config.VILLAGE_COST and game.resources.wood >= 20 then
            game.money = game.money - Config.VILLAGE_COST
            game.resources.wood = game.resources.wood - 20
            
            -- Create new village
            local newVillage = Village.new(worldX, worldY)
            table.insert(game.villages, newVillage)
        end
    end
end

function love.wheelmoved(x, y)
    -- Zoom camera with mouse wheel
    local factor = 1.1
    if y > 0 then
        game.camera:zoom(factor)
    elseif y < 0 then
        game.camera:zoom(1/factor)
    end
end

function love.keypressed(key)
    -- Toggle build menu
    if key == "b" then
        UI.showBuildMenu = not UI.showBuildMenu
    end
end