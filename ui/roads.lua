local Config = require("config")
local Utils = require("utils")

local Roads = {}

-- Initialize roads module
function Roads.init(UI)
    -- Store reference to UI
    Roads.UI = UI
    
    -- Road creation mode state variables
    Roads.roadCreationMode = false
    Roads.roadStartVillage = nil
    Roads.roadStartX = nil
    Roads.roadStartY = nil
    Roads.showRoadInfo = false
end

-- Enter road creation mode
function Roads.enterRoadCreationMode()
    Roads.roadCreationMode = true
    Roads.roadStartVillage = nil
    Roads.roadStartX = nil
    Roads.roadStartY = nil
    Roads.showRoadInfo = false
    Roads.UI.showMessage("Select starting point for the road")
end

-- Exit road creation mode
function Roads.exitRoadCreationMode()
    Roads.roadCreationMode = false
    Roads.roadStartVillage = nil
    Roads.roadStartX = nil
    Roads.roadStartY = nil
    Roads.showRoadInfo = false
end

-- Handle clicks in road creation mode
function Roads.handleRoadClick(game, x, y)
    if not Roads.roadCreationMode then
        return false
    end
    
    -- Convert screen coordinates to world coordinates
    local worldX, worldY = game.camera:screenToWorld(x, y)
    
    -- Handle clicks on villages while in road creation mode
    if Roads.UI.hoveredVillage then
        -- Starting point village selected
        if not Roads.roadStartVillage then
            Roads.roadStartVillage = Roads.UI.hoveredVillage
            Roads.roadStartX = Roads.roadStartVillage.x
            Roads.roadStartY = Roads.roadStartVillage.y
            Roads.showRoadInfo = true
            Roads.UI.showMessage("Select destination village for the road")
            return true
        -- End-point village selected
        elseif Roads.roadStartVillage.id ~= Roads.UI.hoveredVillage.id then
            -- Plan the road path
            game.map:planRoadPath(
                Roads.roadStartVillage.x, 
                Roads.roadStartVillage.y, 
                Roads.UI.hoveredVillage.x, 
                Roads.UI.hoveredVillage.y
            )
            
            -- Create builder tasks for all planned roads
            local plannedRoads = game.map:getAllPlannedRoads()
            Roads.createRoadBuildTasks(game, plannedRoads)
            
            -- Show a message about the planned road
            Roads.UI.showMessage("Road planned from " .. Roads.roadStartVillage.name .. " to " .. Roads.UI.hoveredVillage.name)
            
            -- Reset road creation mode
            Roads.exitRoadCreationMode()
            return true
        end
    else
        -- If this is the first click (no start point set)
        if not Roads.roadStartX then
            -- Only start a road on buildable tiles
            if game.map:canBuildAt(worldX, worldY) then
                Roads.roadStartX = worldX
                Roads.roadStartY = worldY
                Roads.showRoadInfo = true
                Roads.UI.showMessage("Select destination point for the road")
            else
                Roads.UI.showMessage("Cannot start a road on water or mountains")
            end
            return true
        else
            -- This is the second click, plan the road between points
            if game.map:canBuildAt(worldX, worldY) then
                -- Plan the road path
                game.map:planRoadPath(
                    Roads.roadStartX, 
                    Roads.roadStartY, 
                    worldX, 
                    worldY
                )
                
                -- Create builder tasks for all planned roads
                local plannedRoads = game.map:getAllPlannedRoads()
                Roads.createRoadBuildTasks(game, plannedRoads)
                
                -- Show message about the planned road
                Roads.UI.showMessage("Road planned with " .. #plannedRoads .. " tiles")
            else
                Roads.UI.showMessage("Cannot end a road on water or mountains")
            end
            
            -- Reset road creation mode
            Roads.exitRoadCreationMode()
            return true
        end
    end
    
    return false
end

-- Create road build tasks for all planned roads
function Roads.createRoadBuildTasks(game, plannedRoads)
    -- Make sure builder tasks array exists
    if not game.buildingTasks then
        game.buildingTasks = {}
    end
    
    -- Create tasks for each planned road tile
    for _, roadTile in ipairs(plannedRoads) do
        -- Convert tile coordinates to world coordinates
        local worldX, worldY = game.map:tileToWorld(roadTile.x, roadTile.y)
        
        -- Create a task
        local task = {
            type = "build_road",
            x = worldX,
            y = worldY,
            tileX = roadTile.x,
            tileY = roadTile.y,
            priority = 3,  -- Medium priority
            progress = 0,
            totalWorkNeeded = 2  -- Seconds to build a road
        }
        
        -- Add the task to the game's task list
        table.insert(game.buildingTasks, task)
    end
    
    -- Ensure we have builders assigned to these tasks
    Roads.UI.showMessage("Road construction tasks created: " .. #plannedRoads .. " tiles")
end

-- Check if in road creation mode
function Roads.isInRoadCreationMode()
    return Roads.roadCreationMode
end

-- Update road preview
function Roads.update(game, dt)
    -- Only update when in road creation mode
    if not Roads.roadCreationMode then
        Roads.showRoadInfo = false
        return
    end
    
    -- Road creation mode positioning
    if Roads.roadStartX then
        -- Show road preview from start to mouse cursor
        Roads.showRoadInfo = true
    else
        Roads.showRoadInfo = false
    end
end

-- Draw road interface
function Roads.draw(game)
    -- Draw road creation preview
    if Roads.showRoadInfo then
        -- Get mouse position
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = game.camera:screenToWorld(mouseX, mouseY)
        
        -- Check if the current path would be valid
        local isValidPath = false
        if Roads.roadStartX then
            local path = game.map:createRoadPath(Roads.roadStartX, Roads.roadStartY, worldX, worldY)
            isValidPath = path ~= nil
            
            -- Draw the path in different colors based on validity
            love.graphics.setLineWidth(3)
            if isValidPath then
                love.graphics.setColor(0.8, 0.8, 0.2, 0.5) -- Yellow for valid path
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.5) -- Red for invalid path
            end
            love.graphics.line(Roads.roadStartX, Roads.roadStartY, worldX, worldY)
            love.graphics.setLineWidth(1)
            
            -- Draw circles at start and potential end points
            love.graphics.setColor(0.2, 0.8, 0.2, 0.7)
            love.graphics.circle("fill", Roads.roadStartX, Roads.roadStartY, 5)
            
            if isValidPath then
                love.graphics.setColor(0.2, 0.8, 0.2, 0.5)
            else
                love.graphics.setColor(0.8, 0.2, 0.2, 0.5)
            end
            love.graphics.circle("fill", worldX, worldY, 5)
        end
        
        -- Draw text instructions
        love.graphics.setColor(1, 1, 1)
        love.graphics.setFont(Roads.UI.font)
        if isValidPath then
            love.graphics.print("Planning Road - Click to set end point or ESC to cancel", 
                love.graphics.getWidth() / 2 - 200, love.graphics.getHeight() - 40)
        else
            love.graphics.print("Invalid path - Cannot build roads through water or mountains!", 
                love.graphics.getWidth() / 2 - 200, love.graphics.getHeight() - 40)
        end
    end
    
    -- Draw road creation mode indicator
    if Roads.roadCreationMode then
        love.graphics.setColor(0.8, 0.8, 0.2)
        love.graphics.setFont(Roads.UI.font)
        if not Roads.roadStartX then
            love.graphics.print("Road Planning Mode - Click to set starting point", 
                10, love.graphics.getHeight() - 40)
        else
            love.graphics.print("Road Planning Mode - Click to set end point", 
                10, love.graphics.getHeight() - 40)
        end
    end
end

return Roads 