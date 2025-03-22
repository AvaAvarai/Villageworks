local Config = require("config")
local Utils = require("utils")

local UI = {}

-- Initialize UI resources
function UI.init()
    UI.font = love.graphics.newFont(14)
    UI.bigFont = love.graphics.newFont(20)
    UI.smallFont = love.graphics.newFont(10)
    
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

-- Draw the game UI
function UI.draw(game)
    -- Draw top bar
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
    love.graphics.print("Press B for build menu. SPACE for fast forward. Arrow keys to move camera. Scroll to zoom.", 
                        10, love.graphics.getHeight() - 20)
    
    -- Draw village summary panel
    if #game.villages > 0 then
        UI.drawVillageSummary(game)
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

return UI 