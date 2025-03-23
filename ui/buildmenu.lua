local Config = require("config")

local BuildMenu = {}
local UI = nil -- Will be set during init

-- Initialize BuildMenu module
function BuildMenu.init(uiReference)
    UI = uiReference
    BuildMenu.buildingQueues = {} -- Store building queues per village
    BuildMenu.showBuildMenu = false
end

-- Draw the build menu
function BuildMenu.drawBuildMenu(game)
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
    if game.selectedVillage and not BuildMenu.buildingQueues[game.selectedVillage.id] then
        BuildMenu.buildingQueues[game.selectedVillage.id] = {}
        for buildingType, _ in pairs(Config.BUILDING_TYPES) do
            BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] = 0
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
            local queueCount = BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] or 0
            
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
function BuildMenu.getVillageBuildingQueue(villageId)
    if not BuildMenu.buildingQueues[villageId] then
        BuildMenu.buildingQueues[villageId] = {}
        for buildingType, _ in pairs(Config.BUILDING_TYPES) do
            BuildMenu.buildingQueues[villageId][buildingType] = 0
        end
        -- Initialize planned positions array
        BuildMenu.buildingQueues[villageId].plannedPositions = {}
    end
    return BuildMenu.buildingQueues[villageId]
end

-- Check if there are any buildings in the village's queue
function BuildMenu.hasQueuedBuildings(villageId)
    local queue = BuildMenu.getVillageBuildingQueue(villageId)
    for buildingType, count in pairs(queue) do
        -- Skip the plannedPositions entry which is a table
        if buildingType ~= "plannedPositions" and type(count) == "number" and count > 0 then
            return true
        end
    end
    return false
end

-- Get the next building from the queue
function BuildMenu.getNextQueuedBuilding(villageId)
    local queue = BuildMenu.getVillageBuildingQueue(villageId)
    for buildingType, count in pairs(queue) do
        -- Skip the plannedPositions entry which is a table
        if buildingType ~= "plannedPositions" and type(count) == "number" and count > 0 then
            return buildingType
        end
    end
    return nil
end

-- Decrement building in queue (called when a builder starts working on it)
function BuildMenu.decrementBuildingQueue(villageId, buildingType)
    if not BuildMenu.buildingQueues[villageId] then
        return
    end
    
    -- Decrement count if any in queue
    if BuildMenu.buildingQueues[villageId][buildingType] and
        (BuildMenu.buildingQueues[villageId][buildingType] or 0) > 0 then
        
        BuildMenu.buildingQueues[villageId][buildingType] =
            BuildMenu.buildingQueues[villageId][buildingType] - 1
            
        -- Remove the oldest planned position of this type
        if BuildMenu.buildingQueues[villageId].plannedPositions then
            for i, position in ipairs(BuildMenu.buildingQueues[villageId].plannedPositions) do
                if position.type == buildingType then
                    table.remove(BuildMenu.buildingQueues[villageId].plannedPositions, i)
                    break
                end
            end
        end
    end
end

-- Get the building queue for a specific village
function BuildMenu.getBuildingQueue(villageId)
    if not BuildMenu.buildingQueues[villageId] then
        BuildMenu.buildingQueues[villageId] = {}
    end
    
    -- Add plannedPositions array if not exists
    if not BuildMenu.buildingQueues[villageId].plannedPositions then
        BuildMenu.buildingQueues[villageId].plannedPositions = {}
    end
    
    return BuildMenu.buildingQueues[villageId]
end

-- Increment building in queue
function BuildMenu.incrementBuildingQueue(game, buildingType)
    if not game.selectedVillage then
        return
    end
    
    -- Get village location
    local villageX = game.selectedVillage.x
    local villageY = game.selectedVillage.y
    
    -- Initialize queue if needed
    if not BuildMenu.buildingQueues[game.selectedVillage.id] then
        BuildMenu.buildingQueues[game.selectedVillage.id] = {}
    end
    
    -- Initialize count for this building type if needed
    if not BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] then
        BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] = 0
    end
    
    -- Get or initialize planned positions array
    if not BuildMenu.buildingQueues[game.selectedVillage.id].plannedPositions then
        BuildMenu.buildingQueues[game.selectedVillage.id].plannedPositions = {}
    end
    
    -- Plan a position for the new building
    local foundPosition = false
    local buildX, buildY
    local Villager = require("entities/villager")
    
    -- Create a temporary villager to use its location finding logic
    local tempVillager = Villager.new(villageX, villageY, game.selectedVillage.id, nil)
    buildX, buildY = tempVillager:findBuildingLocation(game, buildingType, game.selectedVillage)
    
    if buildX and buildY then
        -- Store the planned position
        table.insert(BuildMenu.buildingQueues[game.selectedVillage.id].plannedPositions, {
            x = buildX,
            y = buildY,
            type = buildingType
        })
        
        -- Increment the count
        BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] = 
            (BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] or 0) + 1
    else
        -- Could not find a position - show error message
        UI.showMessage("Cannot find a suitable location for this building!")
    end
end

-- Handle build menu clicks
function BuildMenu.handleBuildMenuClick(game, x, y)
    local menuWidth = 450  -- Match the width used in drawBuildMenu
    local menuHeight = 350
    local menuX = (love.graphics.getWidth() - menuWidth) / 2
    local menuY = (love.graphics.getHeight() - menuHeight) / 2
    
    -- Check if we're clicking close button
    if x >= menuX + menuWidth - 30 and x <= menuX + menuWidth - 10 and
       y >= menuY + 10 and y <= menuY + 30 then
        BuildMenu.showBuildMenu = false
        UI.showBuildMenu = false
        return true
    end
    
    -- Check if we're clicking the "Plan Road" button
    if x >= menuX + 20 and x <= menuX + 120 and
       y >= menuY + menuHeight - 80 and y <= menuY + menuHeight - 50 then
        local Roads = require("ui.roads")
        Roads.enterRoadCreationMode()
        BuildMenu.showBuildMenu = false
        UI.showBuildMenu = false
        return true
    end
    
    -- Check if we're clicking the "Build Village" button
    if x >= menuX + 20 and x <= menuX + 120 and
       y >= menuY + menuHeight - 40 and y <= menuY + menuHeight - 10 then
        -- Switch to village building mode
        game.uiMode = Config.UI_MODE_BUILDING_VILLAGE
        BuildMenu.showBuildMenu = false
        UI.showBuildMenu = false
        return true
    end
    
    -- Check if we're clicking on building queue buttons
    if game.selectedVillage then
        local yOffset = 60
        
        -- Initialize building queue for this village if it doesn't exist
        if not BuildMenu.buildingQueues[game.selectedVillage.id] then
            BuildMenu.buildingQueues[game.selectedVillage.id] = {}
            for buildingType, _ in pairs(Config.BUILDING_TYPES) do
                BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] = 0
            end
        end
        
        -- Check building entries
        for buildingType, info in pairs(Config.BUILDING_TYPES) do
            -- Check for + button click
            if x >= menuX + 400 and x <= menuX + 420 and
               y >= menuY + yOffset - 5 and y <= menuY + yOffset + 15 then
                -- Add to building queue
                BuildMenu.incrementBuildingQueue(game, buildingType)
                return true
            end
            
            -- Check for - button click
            if x >= menuX + 420 and x <= menuX + 440 and
               y >= menuY + yOffset - 5 and y <= menuY + yOffset + 15 and
               (BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] or 0) > 0 then
                -- Decrease from building queue
                BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] = 
                    BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] - 1
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
    
    return false
end

return BuildMenu 