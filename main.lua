-- Game state
local game = {
    money = 100,
    villages = {},
    builders = {},
    buildings = {},
    villagers = {},
    resources = { wood = 50, stone = 30, food = 40 },
    selectedEntity = nil,
    camera = { x = 0, y = 0, scale = 1 }
}

-- Constants
local VILLAGE_COST = 50
local BUILDER_COST = 20
local BUILDING_TYPES = {
    farm = { cost = 30, income = 5, buildTime = 3, resource = "food", workCapacity = 3 },
    mine = { cost = 40, income = 8, buildTime = 5, resource = "stone", workCapacity = 2 },
    lumberyard = { cost = 25, income = 6, buildTime = 4, resource = "wood", workCapacity = 2 },
    house = { cost = 15, income = 0, buildTime = 2, villagerCapacity = 2, spawnTime = 15 }
}
local TILE_SIZE = 40
local MAX_BUILD_DISTANCE = 100 -- Maximum distance builders can build from their village

function love.load()
    love.window.setTitle("Village Builder God Game")
    love.window.setMode(800, 600)
    
    -- Initialize fonts
    game.font = love.graphics.newFont(14)
    game.bigFont = love.graphics.newFont(20)
end

function love.update(dt)
    -- Update camera movement
    local cameraSpeed = 200 * dt
    if love.keyboard.isDown("right") then
        game.camera.x = game.camera.x + cameraSpeed
    elseif love.keyboard.isDown("left") then
        game.camera.x = game.camera.x - cameraSpeed
    end
    
    if love.keyboard.isDown("down") then
        game.camera.y = game.camera.y + cameraSpeed
    elseif love.keyboard.isDown("up") then
        game.camera.y = game.camera.y - cameraSpeed
    end
    
    -- Update villages
    for _, village in ipairs(game.villages) do
        village.builderTimer = village.builderTimer - dt
        if village.builderTimer <= 0 and #game.builders < 20 then
            village.builderTimer = 10 -- Create a builder every 10 seconds
            if game.resources.food >= 5 then
                game.resources.food = game.resources.food - 5
                table.insert(game.builders, {
                    x = village.x + math.random(-20, 20),
                    y = village.y + math.random(-20, 20),
                    villageId = village.id,
                    task = nil,
                    progress = 0
                })
            end
        end
    end
    
    -- Update builders
    for _, builder in ipairs(game.builders) do
        if builder.task then
            -- Builder is working on a building
            builder.progress = builder.progress + dt
            local buildingType = BUILDING_TYPES[builder.task.type]
            
            if builder.progress >= buildingType.buildTime then
                -- Building is complete
                local newBuilding = {
                    x = builder.task.x,
                    y = builder.task.y,
                    type = builder.task.type,
                    timer = 0,
                    villageId = builder.villageId,
                    workers = {},
                    workersNeeded = buildingType.workCapacity or 0
                }
                
                if builder.task.type == "house" then
                    newBuilding.villagerTimer = buildingType.spawnTime
                    newBuilding.villagerCapacity = buildingType.villagerCapacity
                    newBuilding.currentVillagers = 0
                end
                
                table.insert(game.buildings, newBuilding)
                builder.task = nil
                builder.progress = 0
            end
        else
            -- Find a new task
            if math.random() < 0.01 and game.resources.wood >= 10 and game.resources.stone >= 5 then
                -- Find the village this builder belongs to
                local village = nil
                for _, v in ipairs(game.villages) do
                    if v.id == builder.villageId then
                        village = v
                        break
                    end
                end
                
                if village then
                    -- Calculate build location based on distance from village
                    local angle = math.random() * math.pi * 2
                    local distance = math.random(30, MAX_BUILD_DISTANCE)
                    local buildX = village.x + math.cos(angle) * distance
                    local buildY = village.y + math.sin(angle) * distance
                    
                    -- Determine what to build based on needs
                    local buildingOptions = {"farm", "mine", "lumberyard", "house"}
                    local buildingType = buildingOptions[math.random(#buildingOptions)]
                    
                    builder.task = {
                        x = buildX,
                        y = buildY,
                        type = buildingType
                    }
                    game.resources.wood = game.resources.wood - 10
                    game.resources.stone = game.resources.stone - 5
                end
            end
        end
    end
    
    -- Update buildings and collect income
    for _, building in ipairs(game.buildings) do
        -- Houses spawn villagers
        if building.type == "house" and building.currentVillagers < building.villagerCapacity then
            building.villagerTimer = building.villagerTimer - dt
            if building.villagerTimer <= 0 then
                building.villagerTimer = BUILDING_TYPES.house.spawnTime
                building.currentVillagers = building.currentVillagers + 1
                
                -- Create a new villager
                table.insert(game.villagers, {
                    x = building.x + math.random(-10, 10),
                    y = building.y + math.random(-10, 10),
                    villageId = building.villageId,
                    workplace = nil,
                    homeBuilding = building
                })
            end
        end
        
        -- Resource buildings generate income if they have workers
        if building.type ~= "house" then
            building.timer = building.timer + dt
            if building.timer >= 1 and #building.workers > 0 then
                building.timer = 0
                local buildingType = BUILDING_TYPES[building.type]
                local productionMultiplier = #building.workers / buildingType.workCapacity
                game.money = game.money + (buildingType.income * productionMultiplier)
                game.resources[buildingType.resource] = game.resources[buildingType.resource] + (1 * productionMultiplier)
            end
        end
    end
    
    -- Update villagers
    for _, villager in ipairs(game.villagers) do
        if not villager.workplace then
            -- Find a workplace that needs workers
            for _, building in ipairs(game.buildings) do
                if building.type ~= "house" and building.villageId == villager.villageId and #building.workers < building.workersNeeded then
                    villager.workplace = building
                    table.insert(building.workers, villager)
                    break
                end
            end
        else
            -- Move toward workplace if not already there
            local dx = villager.workplace.x - villager.x
            local dy = villager.workplace.y - villager.y
            local dist = math.sqrt(dx*dx + dy*dy)
            
            if dist > 5 then
                local speed = 30 * dt
                villager.x = villager.x + (dx/dist) * speed
                villager.y = villager.y + (dy/dist) * speed
            end
        end
    end
end

function love.draw()
    -- Apply camera transformation
    love.graphics.push()
    love.graphics.translate(-game.camera.x, -game.camera.y)
    love.graphics.scale(game.camera.scale)
    
    -- Draw grid
    love.graphics.setColor(0.2, 0.2, 0.2)
    for x = 0, 800, TILE_SIZE do
        for y = 0, 600, TILE_SIZE do
            love.graphics.rectangle("line", x, y, TILE_SIZE, TILE_SIZE)
        end
    end
    
    -- Draw villages
    love.graphics.setColor(0, 0.8, 0)
    for _, village in ipairs(game.villages) do
        love.graphics.circle("fill", village.x, village.y, 15)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Village", village.x - 20, village.y - 25)
        love.graphics.setColor(0, 0.8, 0)
    end
    
    -- Draw builders
    love.graphics.setColor(0.8, 0.8, 0)
    for _, builder in ipairs(game.builders) do
        love.graphics.circle("fill", builder.x, builder.y, 5)
        if builder.task then
            love.graphics.line(builder.x, builder.y, builder.task.x, builder.task.y)
            love.graphics.setColor(1, 1, 1, 0.5)
            love.graphics.print(string.format("%.1f", builder.progress), builder.x + 10, builder.y)
            love.graphics.setColor(0.8, 0.8, 0)
        end
    end
    
    -- Draw villagers
    love.graphics.setColor(0.2, 0.6, 0.9)
    for _, villager in ipairs(game.villagers) do
        love.graphics.circle("fill", villager.x, villager.y, 4)
        if villager.workplace then
            love.graphics.line(villager.x, villager.y, villager.workplace.x, villager.workplace.y)
        end
    end
    
    -- Draw buildings
    for _, building in ipairs(game.buildings) do
        if building.type == "farm" then
            love.graphics.setColor(0.2, 0.8, 0.2)
        elseif building.type == "mine" then
            love.graphics.setColor(0.6, 0.6, 0.6)
        elseif building.type == "lumberyard" then
            love.graphics.setColor(0.6, 0.4, 0.2)
        elseif building.type == "house" then
            love.graphics.setColor(0.9, 0.7, 0.5)
        end
        love.graphics.rectangle("fill", building.x - 10, building.y - 10, 20, 20)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(building.type, building.x - 10, building.y - 25)
        
        if building.type ~= "house" then
            love.graphics.print(#building.workers .. "/" .. building.workersNeeded, building.x - 10, building.y + 15)
        else
            love.graphics.print(building.currentVillagers .. "/" .. building.villagerCapacity, building.x - 10, building.y + 15)
        end
    end
    
    love.graphics.pop()
    
    -- Draw UI
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, 800, 40)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.setFont(game.font)
    love.graphics.print("Money: $" .. game.money, 10, 10)
    love.graphics.print("Wood: " .. game.resources.wood, 150, 10)
    love.graphics.print("Stone: " .. game.resources.stone, 250, 10)
    love.graphics.print("Food: " .. game.resources.food, 350, 10)
    love.graphics.print("Builders: " .. #game.builders, 450, 10)
    love.graphics.print("Villages: " .. #game.villages, 550, 10)
    love.graphics.print("Villagers: " .. #game.villagers, 650, 10)
end

function love.mousepressed(x, y, button)
    if button == 1 then
        local worldX = x + game.camera.x
        local worldY = y + game.camera.y
        
        -- Check if we're clicking on UI area
        if y < 40 then return end
        
        -- Place a new village if we have enough money
        if game.money >= VILLAGE_COST and game.resources.wood >= 20 then
            game.money = game.money - VILLAGE_COST
            game.resources.wood = game.resources.wood - 20
            table.insert(game.villages, {
                x = worldX,
                y = worldY,
                builderTimer = 5, -- First builder comes faster
                id = #game.villages + 1
            })
        end
    end
end