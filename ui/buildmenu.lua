local Config = require("config")

local BuildMenu = {}
local UI = nil -- Will be set during init

-- Initialize BuildMenu module
function BuildMenu.init(uiReference)
    UI = uiReference
    BuildMenu.buildingQueues = {} -- Store building queues per village
    BuildMenu.showBuildMenu = false
    BuildMenu.scrollPosition = 0  -- Track scroll position
    BuildMenu.maxScroll = 0       -- Maximum scroll position
    BuildMenu.scrollSpeed = 20    -- How fast to scroll
end

-- Draw the build menu
function BuildMenu.drawBuildMenu(game)
    local menuWidth = 450  -- Increased from 300 to 450
    local menuHeight = 350  -- Fixed height for consistent behavior
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
    
    -- Show selected village name and tier in the title
    if game.selectedVillage then
        local Village = require("entities/village")
        local tierName = Village.TIER_NAMES[game.selectedVillage.tier]
        love.graphics.print(game.selectedVillage.name .. " (" .. tierName .. ")", x + 20, y + 15)
    else
        love.graphics.print("Build Menu", x + 20, y + 15)
    end
    
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
    
    -- Calculate total height needed for all buildings
    local totalHeight = 0
    for _ in pairs(Config.BUILDING_TYPES) do
        totalHeight = totalHeight + 40  -- Each building entry is 40 pixels high
    end
    
    -- Add height for bottom buttons
    totalHeight = totalHeight + 100  -- Space for bottom buttons
    
    -- Calculate maximum scroll position
    BuildMenu.maxScroll = math.max(0, totalHeight - (menuHeight - 80))  -- 80 pixels for header and bottom margin
    
    -- Apply scroll position
    yOffset = yOffset - BuildMenu.scrollPosition
    
    -- Draw building entries
    for buildingType, info in pairs(Config.BUILDING_TYPES) do
        -- Skip if this entry would be above or below the visible area
        if yOffset - 30 > 0 and yOffset + 100 < menuHeight then
            local canAfford = game.resources.wood >= (info.cost.wood or 0) and game.resources.stone >= (info.cost.stone or 0)
            
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
        end
        
        yOffset = yOffset + 40
    end
    
    -- Draw bottom buttons (always visible at bottom)
    local bottomY = y + menuHeight - 80
    
    -- Draw road planning option
    love.graphics.setColor(0.8, 0.8, 0.2)
    love.graphics.rectangle("fill", x + 20, bottomY, 100, 30, 8, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print("Plan Road", x + 30, bottomY + 5)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.setFont(UI.smallFont)
    love.graphics.print("Roads require builders & resources", x + 125, bottomY + 5)
    
    -- Draw village building option 
    love.graphics.setColor(0, 0.8, 0)
    love.graphics.rectangle("fill", x + 20, bottomY + 40, 100, 30, 8, 8)
    love.graphics.setColor(0, 0, 0)
    love.graphics.print(Config.UI_VILLAGE_BUILD_BUTTON_TEXT, x + 30, bottomY + 45)
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.print("Cost: $" .. Config.VILLAGE_COST .. ", Wood: 20", x + 125, bottomY + 45)
    
    -- Add village upgrade button if a village is selected
    if game.selectedVillage then
        local Village = require("entities/village")
        local canUpgrade, reason = game.selectedVillage:canUpgrade(game)
        
        -- Draw upgrade button in right column
        if game.selectedVillage.tier < Village.TIERS.EMPIRE then
            -- Button background changes color based on whether upgrade is possible
            if canUpgrade then
                love.graphics.setColor(0.4, 0.4, 0.8) -- Blue when can upgrade
            else
                love.graphics.setColor(0.5, 0.5, 0.5) -- Gray when cannot upgrade
            end
            
            -- Draw the upgrade button
            love.graphics.rectangle("fill", x + menuWidth - 140, bottomY, 120, 60, 8, 8)
            
            -- Button text
            love.graphics.setFont(UI.font)
            love.graphics.setColor(1, 1, 1)
            local nextTier = Village.TIER_NAMES[game.selectedVillage.tier + 1]
            love.graphics.print("Upgrade to\n" .. nextTier, x + menuWidth - 130, bottomY + 10)
            
            -- Show upgrade cost
            love.graphics.setFont(UI.smallFont)
            local costs = Village.UPGRADE_COSTS[game.selectedVillage.tier + 1]
            love.graphics.print("$" .. costs.money .. ", Wood: " .. costs.wood .. ", Stone: " .. costs.stone, 
                               x + menuWidth - 130, bottomY + 40)
            
            -- Show reason why upgrade isn't possible
            if not canUpgrade then
                love.graphics.setColor(1, 0.7, 0.7)
                -- Draw reason text below the button
                love.graphics.print(reason, x + menuWidth - 140, bottomY + 65)
            end
        else
            -- Already at max tier
            love.graphics.setColor(0.7, 0.7, 0.7)
            love.graphics.rectangle("fill", x + menuWidth - 140, bottomY, 120, 60, 8, 8)
            love.graphics.setColor(1, 1, 1)
            love.graphics.setFont(UI.font)
            love.graphics.print("Maximum\nTier Reached", x + menuWidth - 130, bottomY + 15)
        end
    end
    
    -- Draw close button
    love.graphics.setColor(1, 0.3, 0.3)
    love.graphics.rectangle("fill", x + menuWidth - 30, y + 10, 20, 20, 5, 5)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("X", x + menuWidth - 24, y + 10)
    
    -- Draw scrollbar if needed
    if BuildMenu.maxScroll > 0 then
        local scrollbarWidth = 10
        local scrollbarHeight = (menuHeight - 80) * (menuHeight - 80) / totalHeight
        local scrollbarY = y + 60 + (BuildMenu.scrollPosition / BuildMenu.maxScroll) * (menuHeight - 80 - scrollbarHeight)
        local scrollbarX = x + menuWidth - scrollbarWidth - 5
        
        -- Draw scrollbar background
        love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
        love.graphics.rectangle("fill", scrollbarX, y + 60, scrollbarWidth, menuHeight - 80)
        
        -- Draw scrollbar handle
        love.graphics.setColor(0.7, 0.7, 0.7, 0.8)
        love.graphics.rectangle("fill", scrollbarX, scrollbarY, scrollbarWidth, scrollbarHeight)
    end
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
    
    -- Check if we're clicking the village upgrade button
    if game.selectedVillage and 
       x >= menuX + menuWidth - 140 and x <= menuX + menuWidth - 20 and
       y >= menuY + menuHeight - 80 and y <= menuY + menuHeight - 20 then
        -- Try to upgrade the village
        local Village = require("entities/village")
        if game.selectedVillage.tier < Village.TIERS.EMPIRE then
            local success, message = game.selectedVillage:upgrade(game)
            if success then
                UI.showMessage(message)
            else
                UI.showMessage("Cannot upgrade: " .. message)
            end
            return true
        else
            UI.showMessage("Village is already at maximum tier!")
            return true
        end
    end
    
    -- Check if we're clicking on building queue buttons
    if game.selectedVillage then
        local yOffset = 60 - BuildMenu.scrollPosition
        
        -- Initialize building queue for this village if it doesn't exist
        if not BuildMenu.buildingQueues[game.selectedVillage.id] then
            BuildMenu.buildingQueues[game.selectedVillage.id] = {}
            for buildingType, _ in pairs(Config.BUILDING_TYPES) do
                BuildMenu.buildingQueues[game.selectedVillage.id][buildingType] = 0
            end
        end
        
        -- Check building entries
        for buildingType, info in pairs(Config.BUILDING_TYPES) do
            -- Only check clicks if this entry is visible
            if yOffset + 40 > 0 and yOffset < menuHeight - 80 then
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

-- Handle mouse wheel events for scrolling
function BuildMenu.wheelmoved(x, y)
    if BuildMenu.showBuildMenu then
        -- Update scroll position
        BuildMenu.scrollPosition = BuildMenu.scrollPosition + y * BuildMenu.scrollSpeed
        
        -- Clamp scroll position
        BuildMenu.scrollPosition = math.max(0, math.min(BuildMenu.scrollPosition, BuildMenu.maxScroll))
        
        return true
    end
    return false
end

return BuildMenu 