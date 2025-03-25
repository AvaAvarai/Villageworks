local Utils = require("utils")
local Config = require("config")
local Gen = require("worldgen")

local Map = {}

-- Tile types
Map.TILE_MOUNTAIN = 1
Map.TILE_FOREST = 2
Map.TILE_GRASS = 3
Map.TILE_ROAD = 4
Map.TILE_WATER = 5
Map.TILE_VILLAGE = 6 -- New village tile type

-- Keep track of planned road tiles
Map.plannedRoads = {} -- Format: {[y] = {[x] = true}}

-- Initialize the map system
function Map.init()
    -- Empty planned roads table
    Map.plannedRoads = {}
    
    -- Load tileset
    Map.tileset = love.graphics.newImage("data/tiles.png")
    
    -- Set tile dimensions - now 6 tiles @ 32px each (mountain, forest, grass, road, water, village)
    local tileCount = 6  -- Update to include the village tile
    Map.tileSize = 32
    
    -- Create tile quads for each tile in the tileset
    Map.quads = {}
    for i = 0, tileCount - 1 do
        Map.quads[i + 1] = love.graphics.newQuad(
            i * Map.tileSize, 0,
            Map.tileSize, Map.tileSize,
            Map.tileset:getWidth(), Map.tileset:getHeight()
        )
    end
    
    -- Get map dimensions based on config
    Map.width = math.floor(Config.WORLD_WIDTH / Map.tileSize)
    Map.height = math.floor(Config.WORLD_HEIGHT / Map.tileSize)
    
    -- Print dimensions for debugging
    print("Map dimensions: " .. Map.width .. "x" .. Map.height .. " tiles")
    
    -- Generate the map using the Gen module
    local generatedMap = Gen.generateMap(Map.width, Map.height)
    Map.tiles = generatedMap.tiles
end

-- Convert world coordinates to tile coordinates
function Map:worldToTile(worldX, worldY)
    local tileX = math.floor(worldX / Map.tileSize) + 1
    local tileY = math.floor(worldY / Map.tileSize) + 1
    
    -- Ensure coordinates are within map bounds
    tileX = math.max(1, math.min(Map.width, tileX))
    tileY = math.max(1, math.min(Map.height, tileY))
    
    return tileX, tileY
end

-- Convert tile coordinates to world coordinates (returns center of tile)
function Map:tileToWorld(tileX, tileY)
    local worldX = (tileX - 1) * Map.tileSize + Map.tileSize / 2
    local worldY = (tileY - 1) * Map.tileSize + Map.tileSize / 2
    return worldX, worldY
end

-- Get tile type at world coordinates
function Map:getTileTypeAtWorld(worldX, worldY)
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    return Map:getTileType(tileX, tileY)
end

-- Get tile type at tile coordinates
function Map:getTileType(tileX, tileY)
    -- Check boundaries
    if tileX < 1 or tileY < 1 or tileX > Map.width or tileY > Map.height then
        return Map.TILE_GRASS  -- Default to grass for out of bounds
    end
    
    return Map.tiles[tileY][tileX]
end

-- Set tile type at world coordinates
function Map:setTileTypeAtWorld(worldX, worldY, tileType)
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    Map:setTileType(tileX, tileY, tileType)
end

-- Set tile type at tile coordinates
function Map:setTileType(tileX, tileY, tileType)
    -- Check boundaries
    if tileX < 1 or tileY < 1 or tileX > Map.width or tileY > Map.height then
        return
    end
    
    Map.tiles[tileY][tileX] = tileType
end

-- Check if a world position is within map bounds
function Map:isWithinBounds(worldX, worldY)
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    -- Get the actual world boundaries in pixels
    local worldBoundaryX = Config.WORLD_WIDTH
    local worldBoundaryY = Config.WORLD_HEIGHT
    
    -- Strict boundary check with a small buffer to prevent entities from being placed at the very edge
    local buffer = 20
    return worldX >= buffer and worldX <= worldBoundaryX - buffer and 
           worldY >= buffer and worldY <= worldBoundaryY - buffer
end

-- Check if a world position is buildable (not water or mountain)
function Map:canBuildAt(worldX, worldY)
    -- First check if position is within map bounds
    if not Map:isWithinBounds(worldX, worldY) then
        return false
    end
    
    local tileType = Map:getTileTypeAtWorld(worldX, worldY)
    return tileType ~= Map.TILE_WATER and tileType ~= Map.TILE_MOUNTAIN
end

-- Check if a position is adjacent to water (for Fisherys)
function Map:isAdjacentToWater(worldX, worldY)
    -- First check if position is within map bounds
    if not Map:isWithinBounds(worldX, worldY) then
        return false
    end
    
    -- The position itself shouldn't be water
    local tileType = Map:getTileTypeAtWorld(worldX, worldY)
    if tileType == Map.TILE_WATER then
        return false
    end
    
    -- Get tile coordinates
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    
    -- Check all adjacent tiles (including diagonals)
    for dy = -1, 1 do
        for dx = -1, 1 do
            -- Skip the center tile (the position itself)
            if not (dx == 0 and dy == 0) then
                local nx, ny = tileX + dx, tileY + dy
                
                -- Make sure adjacent tile is within map bounds
                if nx >= 1 and ny >= 1 and nx <= Map.width and ny <= Map.height then
                    if Map.tiles[ny][nx] == Map.TILE_WATER then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Draw visible portion of the map
function Map:draw(camera)
    -- Calculate visible area in tile coordinates
    local startX, startY = camera:screenToWorld(0, 0)
    local endX, endY = camera:screenToWorld(love.graphics.getWidth(), love.graphics.getHeight())
    
    local tileStartX, tileStartY = Map:worldToTile(startX, startY)
    local tileEndX, tileEndY = Map:worldToTile(endX, endY)
    
    -- Add a buffer to ensure we draw tiles that are partially visible
    tileStartX = math.max(1, tileStartX - 1)
    tileStartY = math.max(1, tileStartY - 1)
    tileEndX = math.min(Map.width, tileEndX + 1)
    tileEndY = math.min(Map.height, tileEndY + 1)
    
    -- Keep count of tile types drawn for debugging
    local drawnTiles = {0, 0, 0, 0, 0, 0} -- Updated to include village tile
    
    -- Draw all visible tiles
    for y = tileStartY, tileEndY do
        for x = tileStartX, tileEndX do
            local tileType = Map.tiles[y][x]
            local worldX = (x - 1) * Map.tileSize
            local worldY = (y - 1) * Map.tileSize
            
            -- Count the tile type being drawn (only if it's a valid index)
            if tileType and tileType >= 1 and tileType <= #drawnTiles then
                drawnTiles[tileType] = drawnTiles[tileType] + 1
            end
            
            -- Set color (full brightness for regular tiles)
            love.graphics.setColor(1, 1, 1, 1)
            
            -- Draw the normal tile (make sure the quad exists)
            if tileType and Map.quads[tileType] then
                love.graphics.draw(
                    Map.tileset,
                    Map.quads[tileType],
                    worldX,
                    worldY
                )
            end
            
            -- If this is a planned road, draw the road tile with transparency on top
            if Map:isPlannedRoad(x, y) then
                -- Draw the road tile with transparency
                love.graphics.setColor(1, 1, 1, 0.5)
                love.graphics.draw(
                    Map.tileset,
                    Map.quads[Map.TILE_ROAD],
                    worldX,
                    worldY
                )
            end
        end
    end
    
    -- Reset color to full opacity
    love.graphics.setColor(1, 1, 1, 1)
    
    -- Optional debug mode: print out what was drawn in this frame
    if false then -- Set to true to enable debug output
        print(string.format("Drew: Mountains: %d, Forests: %d, Grass: %d, Roads: %d, Water: %d, Villages: %d",
            drawnTiles[Map.TILE_MOUNTAIN], drawnTiles[Map.TILE_FOREST], 
            drawnTiles[Map.TILE_GRASS], drawnTiles[Map.TILE_ROAD], drawnTiles[Map.TILE_WATER],
            drawnTiles[Map.TILE_VILLAGE]))
    end
end

-- Set a road tile at the given world position if not water or mountain
function Map:setRoad(worldX, worldY)
    local tileType = Map:getTileTypeAtWorld(worldX, worldY)
    if tileType ~= Map.TILE_WATER and tileType ~= Map.TILE_MOUNTAIN then
        Map:setTileTypeAtWorld(worldX, worldY, Map.TILE_ROAD)
        return true
    end
    return false
end

-- Create a road path between two points
function Map:createRoadPath(startX, startY, endX, endY)
    local path = {}
    local tileStartX, tileStartY = Map:worldToTile(startX, startY)
    local tileEndX, tileEndY = Map:worldToTile(endX, endY)
    
    -- Use a simple line algorithm to create a path
    local dx = math.abs(tileEndX - tileStartX)
    local dy = math.abs(tileEndY - tileStartY)
    local sx = tileStartX < tileEndX and 1 or -1
    local sy = tileStartY < tileEndY and 1 or -1
    local err = dx - dy
    
    local x, y = tileStartX, tileStartY
    while x ~= tileEndX or y ~= tileEndY do
        -- Add current tile to path if not water or mountain
        if Map:getTileType(x, y) ~= Map.TILE_WATER and Map:getTileType(x, y) ~= Map.TILE_MOUNTAIN then
            table.insert(path, {x = x, y = y})
        else
            -- If water or mountain is encountered, path is not possible
            return nil
        end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
    end
    
    -- Add the end tile if not water or mountain
    if Map:getTileType(tileEndX, tileEndY) ~= Map.TILE_WATER and 
       Map:getTileType(tileEndX, tileEndY) ~= Map.TILE_MOUNTAIN then
        table.insert(path, {x = tileEndX, y = tileEndY})
    else
        return nil
    end
    
    return path
end

-- Find a buildable position near the specified coordinates
function Map:findNearestBuildablePosition(worldX, worldY, maxDistance)
    maxDistance = maxDistance or 5 * Map.tileSize
    
    -- Ensure the starting position is within map bounds
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    
    -- If current position is buildable, return it
    if Map:isWithinBounds(worldX, worldY) and 
       Map:getTileType(tileX, tileY) ~= Map.TILE_WATER and 
       Map:getTileType(tileX, tileY) ~= Map.TILE_MOUNTAIN then
        return worldX, worldY
    end
    
    -- Search in expanding circles for a buildable tile
    local maxTileDistance = math.ceil(maxDistance / Map.tileSize)
    for dist = 1, maxTileDistance do
        for offsetX = -dist, dist do
            for offsetY = -dist, dist do
                -- Only check tiles at the current distance (roughly circular)
                if math.abs(offsetX) + math.abs(offsetY) >= dist - 1 and 
                   math.abs(offsetX) + math.abs(offsetY) <= dist + 1 then
                    
                    local checkX = tileX + offsetX
                    local checkY = tileY + offsetY
                    
                    if checkX >= 1 and checkY >= 1 and 
                       checkX <= Map.width and checkY <= Map.height and
                       Map:getTileType(checkX, checkY) ~= Map.TILE_WATER and
                       Map:getTileType(checkX, checkY) ~= Map.TILE_MOUNTAIN then
                        
                        -- Found a buildable position, convert to world coordinates
                        local buildableX, buildableY = Map:tileToWorld(checkX, checkY)
                        return buildableX, buildableY
                    end
                end
            end
        end
    end
    
    -- If no buildable position found, return nil
    return nil, nil
end

-- Find nearest position suitable for building (not water)
function Map:findNearestBuildablePosition(startX, startY)
    -- First check if start position is already buildable
    if Map:canBuildAt(startX, startY) then
        return startX, startY
    end
    
    -- Define search parameters
    local maxSearchRadius = 200 -- Maximum radius to search in
    local searchStep = 10 -- Step size for each search increment
    
    -- Search in expanding circles
    for radius = searchStep, maxSearchRadius, searchStep do
        -- Search along the perimeter of the circle
        for angle = 0, 2*math.pi, math.pi/8 do
            local x = startX + radius * math.cos(angle)
            local y = startY + radius * math.sin(angle)
            
            if Map:canBuildAt(x, y) then
                return x, y
            end
        end
    end
    
    -- If no suitable spot found, return nil
    return nil, nil
end

-- Find nearest position adjacent to water (for Fisherys)
function Map:findNearestWaterEdge(startX, startY)
    -- First check if start position is already adjacent to water
    if Map:canBuildAt(startX, startY) and Map:isAdjacentToWater(startX, startY) then
        return startX, startY
    end
    
    -- Define search parameters
    local maxSearchRadius = 300 -- Larger search radius for water edges
    local searchStep = 15 -- Step size for each search increment
    
    -- Search in expanding circles
    for radius = searchStep, maxSearchRadius, searchStep do
        -- Search along the perimeter of the circle
        for angle = 0, 2*math.pi, math.pi/12 do  -- More angles for better coverage
            local x = startX + radius * math.cos(angle)
            local y = startY + radius * math.sin(angle)
            
            -- Check if this location is suitable for a Fishery
            if Map:canBuildAt(x, y) and Map:isAdjacentToWater(x, y) then
                return x, y
            end
        end
    end
    
    -- Check the map systematically if circular search failed
    local closestX, closestY = nil, nil
    local closestDistance = math.huge
    
    -- Calculate starting tile coordinates
    local startTileX, startTileY = Map:worldToTile(startX, startY)
    
    -- Define search grid size
    local searchWidth = 20
    local searchHeight = 20
    
    -- Calculate search bounds
    local minX = math.max(1, startTileX - searchWidth)
    local maxX = math.min(Map.width, startTileX + searchWidth)
    local minY = math.max(1, startTileY - searchHeight)
    local maxY = math.min(Map.height, startTileY + searchHeight)
    
    -- Check every tile in the search area
    for y = minY, maxY do
        for x = minX, maxX do
            local worldX, worldY = Map:tileToWorld(x, y)
            
            -- Check if this is a valid position for a Fishery
            if Map:canBuildAt(worldX, worldY) and Map:isAdjacentToWater(worldX, worldY) then
                local distance = Utils.distance(startX, startY, worldX, worldY)
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestX = worldX
                    closestY = worldY
                end
            end
        end
    end
    
    -- Return the closest valid position, or nil if none found
    return closestX, closestY
end

-- Check if a world position is clear of any existing or planned buildings
function Map:isPositionClearOfBuildings(worldX, worldY, game)
    local BUILDING_SPACING = 24 -- Minimum distance between buildings
    
    -- Check existing buildings
    for _, building in ipairs(game.buildings) do
        local distance = Utils.distance(worldX, worldY, building.x, building.y)
        if distance < BUILDING_SPACING then
            return false
        end
    end
    
    -- Check villages (need spacing from those too)
    for _, village in ipairs(game.villages) do
        local distance = Utils.distance(worldX, worldY, village.x, village.y)
        if distance < BUILDING_SPACING then
            return false
        end
    end
    
    -- Check for overlap with in-progress buildings being constructed by villagers
    for _, villager in ipairs(game.villagers) do
        -- Check villagers that are currently building
        if (villager.state == "building" or villager.state == "moving_to_build") and
           villager.buildTask and villager.buildTask.x and villager.buildTask.y then
            local distance = Utils.distance(worldX, worldY, villager.buildTask.x, villager.buildTask.y)
            if distance < BUILDING_SPACING then
                return false
            end
        end
        
        -- Also check target coordinates for villagers on the move
        if villager.targetX and villager.targetY then
            local distance = Utils.distance(worldX, worldY, villager.targetX, villager.targetY)
            if distance < BUILDING_SPACING / 2 then
                return false
            end
        end
    end
    
    return true -- Position is clear
end

-- Find a path between two points that avoids water tiles (A* algorithm)
function Map:findPathAvoidingWater(startX, startY, endX, endY, ignoreBuildings, preferRoads)
    -- Convert world coordinates to tile coordinates
    local tileStartX, tileStartY = Map:worldToTile(startX, startY)
    local tileEndX, tileEndY = Map:worldToTile(endX, endY)
    
    -- Ensure start and end points are on valid tiles
    if not Map:isWithinBounds(startX, startY) or not Map:isWithinBounds(endX, endY) then
        return nil
    end
    
    -- If start is on water or mountain, find closest traversable land tile
    if Map:getTileType(tileStartX, tileStartY) == Map.TILE_WATER or 
       Map:getTileType(tileStartX, tileStartY) == Map.TILE_MOUNTAIN then
        local landX, landY = Map:findNearestBuildablePosition(startX, startY)
        if not landX then
            return nil -- No valid start position
        end
        tileStartX, tileStartY = Map:worldToTile(landX, landY)
    end
    
    -- If end is on water or mountain, find closest traversable land tile
    if Map:getTileType(tileEndX, tileEndY) == Map.TILE_WATER or
       Map:getTileType(tileEndX, tileEndY) == Map.TILE_MOUNTAIN then
        local landX, landY = Map:findNearestBuildablePosition(endX, endY)
        if not landX then
            return nil -- No valid end position
        end
        tileEndX, tileEndY = Map:worldToTile(landX, landY)
    end
    
    -- Define offsets for the 8 neighboring tiles
    local neighbors = {
        {x = -1, y = -1}, {x = 0, y = -1}, {x = 1, y = -1},
        {x = -1, y = 0},                   {x = 1, y = 0},
        {x = -1, y = 1},  {x = 0, y = 1},  {x = 1, y = 1}
    }
    
    -- Calculate heuristic (estimated distance to goal)
    local function heuristic(x, y)
        return math.abs(x - tileEndX) + math.abs(y - tileEndY)
    end
    
    -- Node representation
    local function createNode(x, y, parent, g)
        return {
            x = x,
            y = y,
            parent = parent,
            g = g,          -- Cost from start
            h = heuristic(x, y), -- Estimated cost to end
            f = g + heuristic(x, y) -- Total estimated cost
        }
    end
    
    -- A* algorithm
    local openSet = {}
    local closedSet = {}
    local startNode = createNode(tileStartX, tileStartY, nil, 0)
    
    -- Helper function to find node with lowest f score in open set
    local function findLowestFScore()
        local lowestIndex = 1
        local lowestF = openSet[1].f
        
        for i = 2, #openSet do
            if openSet[i].f < lowestF then
                lowestF = openSet[i].f
                lowestIndex = i
            end
        end
        
        return lowestIndex
    end
    
    -- Helper function to check if node is in a set
    local function isInSet(set, x, y)
        for _, node in ipairs(set) do
            if node.x == x and node.y == y then
                return true
            end
        end
        return false
    end
    
    -- Add start node to open set
    table.insert(openSet, startNode)
    
    -- Main A* loop
    while #openSet > 0 do
        -- Get node with lowest f score
        local currentIndex = findLowestFScore()
        local current = openSet[currentIndex]
        
        -- If current node is the goal, reconstruct and return the path
        if current.x == tileEndX and current.y == tileEndY then
            local path = {}
            while current do
                table.insert(path, 1, {x = current.x, y = current.y})
                current = current.parent
            end
            return path
        end
        
        -- Move current node from open to closed set
        table.remove(openSet, currentIndex)
        table.insert(closedSet, current)
        
        -- Check all neighboring tiles
        for _, neighbor in ipairs(neighbors) do
            local nx = current.x + neighbor.x
            local ny = current.y + neighbor.y
            
            -- Check if neighbor is valid (within bounds and not water or mountain)
            if nx >= 1 and ny >= 1 and nx <= Map.width and ny <= Map.height and
               Map:getTileType(nx, ny) ~= Map.TILE_WATER and 
               Map:getTileType(nx, ny) ~= Map.TILE_MOUNTAIN and
               not isInSet(closedSet, nx, ny) then
                
                -- Calculate cost to neighbor
                local moveCost = 1
                if neighbor.x ~= 0 and neighbor.y ~= 0 then
                    moveCost = 1.414 -- Diagonal movement costs more
                end
                
                -- Adjust cost based on tile type
                local tileType = Map:getTileType(nx, ny)
                
                -- Forest tiles are more expensive to traverse
                if tileType == Map.TILE_FOREST then
                    moveCost = moveCost * 1.5 -- Forest is harder to traverse
                -- Road tiles are cheaper to traverse
                elseif tileType == Map.TILE_ROAD then
                    if preferRoads then
                        -- Strongly prefer roads when parameter is set
                        moveCost = moveCost * 0.3 -- Much stronger road preference for traders
                    else
                        moveCost = moveCost * 0.7 -- Default road preference
                    end
                end
                
                local tentativeG = current.g + moveCost
                local inOpenSet = false
                
                -- Check if neighbor is already in open set
                for i, node in ipairs(openSet) do
                    if node.x == nx and node.y == ny then
                        inOpenSet = true
                        if tentativeG < node.g then
                            -- Found a better path to this node
                            node.g = tentativeG
                            node.f = tentativeG + node.h
                            node.parent = current
                        end
                        break
                    end
                end
                
                -- If not in open set, add it
                if not inOpenSet then
                    local newNode = createNode(nx, ny, current, tentativeG)
                    table.insert(openSet, newNode)
                end
            end
        end
    end
    
    -- No path found
    return nil
end

-- Convert a path of tiles to world coordinates
function Map:pathToWorldCoordinates(path)
    if not path then return nil end
    
    local worldPath = {}
    for _, tile in ipairs(path) do
        local wx, wy = Map:tileToWorld(tile.x, tile.y)
        table.insert(worldPath, {x = wx, y = wy})
    end
    
    return worldPath
end

-- Check if a position has forest tiles nearby
function Map:hasForestNearby(worldX, worldY, radius)
    if not radius then radius = 4 * Map.tileSize end
    
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    local tileRadius = math.ceil(radius / Map.tileSize)
    
    for dy = -tileRadius, tileRadius do
        for dx = -tileRadius, tileRadius do
            local checkX, checkY = tileX + dx, tileY + dy
            
            -- Check if the position is within bounds
            if checkX >= 1 and checkY >= 1 and checkX <= Map.width and checkY <= Map.height then
                -- Calculate distance (circular radius)
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= tileRadius and Map:getTileType(checkX, checkY) == Map.TILE_FOREST then
                    return true
                end
            end
        end
    end
    
    return false
end

-- Find a forest tile near the position
function Map:findNearestForestTile(worldX, worldY, maxRadius)
    if not maxRadius then maxRadius = 5 * Map.tileSize end
    
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    local maxTileRadius = math.ceil(maxRadius / Map.tileSize)
    
    -- Search in expanding circles
    for radius = 1, maxTileRadius do
        -- Check in a spiral pattern (more efficient)
        for dy = -radius, radius do
            for dx = -radius, radius do
                -- Only check tiles at the current radius (roughly circular)
                if math.abs(dx) + math.abs(dy) >= radius - 1 and 
                   math.abs(dx) + math.abs(dy) <= radius + 1 then
                    
                    local checkX, checkY = tileX + dx, tileY + dy
                    
                    -- Check if the position is within bounds
                    if checkX >= 1 and checkY >= 1 and checkX <= Map.width and checkY <= Map.height then
                        if Map:getTileType(checkX, checkY) == Map.TILE_FOREST then
                            -- Found a forest tile, return its world coordinates
                            local forestX, forestY = Map:tileToWorld(checkX, checkY)
                            return forestX, forestY, checkX, checkY
                        end
                    end
                end
            end
        end
    end
    
    -- No forest tile found within the maximum radius
    return nil, nil, nil, nil
end

-- Harvest a forest tile (convert it to grass and return wood)
function Map:harvestForestTile(tileX, tileY)
    -- Check if the tile is a forest
    if Map:getTileType(tileX, tileY) == Map.TILE_FOREST then
        -- Set the tile to grass
        Map:setTileType(tileX, tileY, Map.TILE_GRASS)
        
        -- Return the amount of wood harvested
        return Config.FOREST_WOOD_YIELD
    end
    
    return 0 -- No wood harvested
end

-- Harvest a forest tile at world coordinates
function Map:harvestForestTileAtWorld(worldX, worldY)
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    return Map:harvestForestTile(tileX, tileY)
end

-- Find all forest tiles within a certain radius
function Map:findForestTilesInRadius(worldX, worldY, radius)
    local forestTiles = {}
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    local tileRadius = math.ceil(radius / Map.tileSize)
    
    for dy = -tileRadius, tileRadius do
        for dx = -tileRadius, tileRadius do
            local checkX, checkY = tileX + dx, tileY + dy
            
            -- Check if the position is within bounds
            if checkX >= 1 and checkY >= 1 and checkX <= Map.width and checkY <= Map.height then
                -- Calculate distance (circular radius)
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= tileRadius and Map:getTileType(checkX, checkY) == Map.TILE_FOREST then
                    -- Add to forest tiles list
                    table.insert(forestTiles, {
                        x = checkX, 
                        y = checkY,
                        worldX = (checkX - 1) * Map.tileSize + Map.tileSize / 2,
                        worldY = (checkY - 1) * Map.tileSize + Map.tileSize / 2
                    })
                end
            end
        end
    end
    
    return forestTiles
end

-- Update function for map - handles forest regrowth
function Map:update(dt)
    -- Forest regrowth (slow process)
    -- We'll randomly select a few tiles to check for regrowth each update
    -- rather than checking every tile, for performance
    local tilesToCheck = 20
    
    for i = 1, tilesToCheck do  
        -- Pick a random tile
        local x = math.random(1, Map.width)
        local y = math.random(1, Map.height)
        
        -- Only grass tiles can regrow into forest
        if Map.tiles[y][x] == Map.TILE_GRASS then
            -- Check if there are adjacent forest tiles (required for regrowth)
            local hasAdjacentForest = false
            for dy = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dy == 0) then -- Skip center
                        local nx, ny = x + dx, y + dy
                        if nx >= 1 and ny >= 1 and nx <= Map.width and ny <= Map.height then
                            if Map.tiles[ny][nx] == Map.TILE_FOREST then
                                hasAdjacentForest = true
                                break
                            end
                        end
                    end
                end
                if hasAdjacentForest then break end
            end
            
            -- If there are adjacent forests, there's a small chance to regrow
            if hasAdjacentForest and math.random() < Config.FOREST_REGROWTH_CHANCE then
                Map.tiles[y][x] = Map.TILE_FOREST
            end
        end
    end
end

-- Check if a position is adjacent to mountains (for mines)
function Map:isAdjacentToMountain(worldX, worldY)
    -- First check if position is within map bounds
    if not Map:isWithinBounds(worldX, worldY) then
        return false
    end
    
    -- The position itself shouldn't be a mountain
    local tileType = Map:getTileTypeAtWorld(worldX, worldY)
    if tileType == Map.TILE_MOUNTAIN then
        return false
    end
    
    -- Get tile coordinates
    local tileX, tileY = Map:worldToTile(worldX, worldY)
    
    -- Check all adjacent tiles (including diagonals)
    for dy = -1, 1 do
        for dx = -1, 1 do
            -- Skip the center tile (the position itself)
            if not (dx == 0 and dy == 0) then
                local nx, ny = tileX + dx, tileY + dy
                
                -- Make sure adjacent tile is within map bounds
                if nx >= 1 and ny >= 1 and nx <= Map.width and ny <= Map.height then
                    if Map.tiles[ny][nx] == Map.TILE_MOUNTAIN then
                        return true
                    end
                end
            end
        end
    end
    
    return false
end

-- Find nearest position adjacent to mountains (for mines)
function Map:findNearestMountainEdge(startX, startY)
    -- First check if start position is already adjacent to mountains
    if Map:canBuildAt(startX, startY) and Map:isAdjacentToMountain(startX, startY) then
        return startX, startY
    end
    
    -- Define search parameters
    local maxSearchRadius = 300 -- Larger search radius for mountain edges
    local searchStep = 15 -- Step size for each search increment
    
    -- Search in expanding circles
    for radius = searchStep, maxSearchRadius, searchStep do
        -- Search along the perimeter of the circle
        for angle = 0, 2*math.pi, math.pi/12 do  -- More angles for better coverage
            local x = startX + radius * math.cos(angle)
            local y = startY + radius * math.sin(angle)
            
            -- Check if this location is suitable for a mine
            if Map:canBuildAt(x, y) and Map:isAdjacentToMountain(x, y) then
                return x, y
            end
        end
    end
    
    -- Check the map systematically if circular search failed
    local closestX, closestY = nil, nil
    local closestDistance = math.huge
    
    -- Calculate starting tile coordinates
    local startTileX, startTileY = Map:worldToTile(startX, startY)
    
    -- Define search grid size
    local searchWidth = 20
    local searchHeight = 20
    
    -- Calculate search bounds
    local minX = math.max(1, startTileX - searchWidth)
    local maxX = math.min(Map.width, startTileX + searchWidth)
    local minY = math.max(1, startTileY - searchHeight)
    local maxY = math.min(Map.height, startTileY + searchHeight)
    
    -- Check every tile in the search area
    for y = minY, maxY do
        for x = minX, maxX do
            local worldX, worldY = Map:tileToWorld(x, y)
            
            -- Check if this is a valid position for a mine
            if Map:canBuildAt(worldX, worldY) and Map:isAdjacentToMountain(worldX, worldY) then
                local distance = Utils.distance(startX, startY, worldX, worldY)
                
                if distance < closestDistance then
                    closestDistance = distance
                    closestX = worldX
                    closestY = worldY
                end
            end
        end
    end
    
    -- Return the closest valid position, or nil if none found
    return closestX, closestY
end

-- Mark a location as a planned road
function Map:planRoad(tileX, tileY)
    -- Make sure the y table exists
    if not Map.plannedRoads[tileY] then
        Map.plannedRoads[tileY] = {}
    end
    
    -- Mark this tile as a planned road
    Map.plannedRoads[tileY][tileX] = true
end

-- Check if a tile is a planned road
function Map:isPlannedRoad(tileX, tileY)
    return Map.plannedRoads[tileY] and Map.plannedRoads[tileY][tileX] == true
end

-- Complete a planned road by setting the actual tile to road
function Map:completePlannedRoad(tileX, tileY)
    -- Check if this is actually a planned road
    if self:isPlannedRoad(tileX, tileY) then
        -- Set the tile to a road
        self:setTileType(tileX, tileY, Map.TILE_ROAD)
        
        -- Remove it from the planned roads table
        Map.plannedRoads[tileY][tileX] = nil
        
        return true
    end
    
    return false
end

-- Plan a road at world coordinates
function Map:planRoadAtWorld(worldX, worldY)
    local tileX, tileY = self:worldToTile(worldX, worldY)
    
    -- Check if the tile is buildable (not water, mountain, or already a road)
    local tileType = self:getTileType(tileX, tileY)
    if tileType ~= Map.TILE_WATER and tileType ~= Map.TILE_MOUNTAIN and tileType ~= Map.TILE_ROAD then
        self:planRoad(tileX, tileY)
        return true
    end
    
    return false
end

-- Complete a planned road at world coordinates
function Map:completePlannedRoadAtWorld(worldX, worldY)
    local tileX, tileY = self:worldToTile(worldX, worldY)
    return self:completePlannedRoad(tileX, tileY)
end

-- Plan a path of roads between two points
function Map:planRoadPath(startX, startY, endX, endY)
    local tileStartX, tileStartY = self:worldToTile(startX, startY)
    local tileEndX, tileEndY = self:worldToTile(endX, endY)
    
    -- Use a simple line algorithm to create a path
    local dx = math.abs(tileEndX - tileStartX)
    local dy = math.abs(tileEndY - tileStartY)
    local sx = tileStartX < tileEndX and 1 or -1
    local sy = tileStartY < tileEndY and 1 or -1
    local err = dx - dy
    
    local x, y = tileStartX, tileStartY
    while x ~= tileEndX or y ~= tileEndY do
        -- Plan a road at this tile if not water or mountain or already a road
        local tileType = self:getTileType(x, y)
        if tileType ~= Map.TILE_WATER and tileType ~= Map.TILE_MOUNTAIN and tileType ~= Map.TILE_ROAD then
            self:planRoad(x, y)
        end
        
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
    end
    
    -- Plan the end tile if not water or mountain
    local tileType = self:getTileType(tileEndX, tileEndY)
    if tileType ~= Map.TILE_WATER and tileType ~= Map.TILE_MOUNTAIN and tileType ~= Map.TILE_ROAD then
        self:planRoad(tileEndX, tileEndY)
    end
end

-- Get all planned roads as a list of tile coordinates
function Map:getAllPlannedRoads()
    local result = {}
    
    for y, row in pairs(Map.plannedRoads) do
        for x, _ in pairs(row) do
            table.insert(result, {x = x, y = y})
        end
    end
    
    return result
end

return Map
