local Utils = require("utils")
local Config = require("config")

local Map = {}

-- Tile types
Map.TILE_MOUNTAIN = 1
Map.TILE_FOREST = 2
Map.TILE_GRASS = 3
Map.TILE_ROAD = 4
Map.TILE_WATER = 5

-- Keep track of planned road tiles
Map.plannedRoads = {} -- Format: {[y] = {[x] = true}}

-- Initialize the map system
function Map.init()
    -- Empty planned roads table
    Map.plannedRoads = {}
    
    -- Load tileset
    Map.tileset = love.graphics.newImage("data/tiles.png")
    
    -- Set tile dimensions - exactly 5 tiles @ 32px each
    local tileCount = 5  -- mountain, forest, grass, road, water
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
    
    -- Initialize map with grass as default
    Map.tiles = {}
    for y = 1, Map.height do
        Map.tiles[y] = {}
        for x = 1, Map.width do
            Map.tiles[y][x] = Map.TILE_GRASS
        end
    end
    
    -- Generate terrain layers from most dominant to least dominant
    -- 1. Mountains (largest feature)
    Map:generateMountains()
    
    -- Show mountain count before other generation
    Map:countSpecificTile(Map.TILE_MOUNTAIN, "Mountain")
    
    -- 2. Water bodies
    Map:generateWater()
    
    -- Show water count after generation
    Map:countSpecificTile(Map.TILE_WATER, "Water")
    
    -- 3. Forests (least dominant)
    Map:generateForests()
    
    -- Count and print the number of each tile type at the end
    Map:countTiles()
end

-- Generate mountain regions
function Map:generateMountains()
    -- Adjust these values to control mountain generation
    local mountainPercentage = 0.12  -- Slightly increased target percentage
    local mountainTileCount = math.floor(Map.width * Map.height * mountainPercentage)
    local currentMountainTiles = 0
    
    -- Create mountain ridges for more realistic-looking ranges
    local function createMountainRidge(startX, startY, length, width, angle)
        -- Calculate direction vector based on angle
        local dirX = math.cos(angle)
        local dirY = math.sin(angle)
        
        -- Create mountain ridge along the direction
        for i = 0, length do
            -- Calculate center position for this segment of the ridge
            local centerX = math.floor(startX + i * dirX)
            local centerY = math.floor(startY + i * dirY)
            
            -- Create width of the ridge perpendicular to direction
            local perpX = -dirY
            local perpY = dirX
            
            -- Add random variation to width to make it more natural
            local thisWidth = width * (0.7 + math.random() * 0.6)
            
            -- Create ridge cross-section
            for w = -thisWidth, thisWidth do
                local x = math.floor(centerX + w * perpX)
                local y = math.floor(centerY + w * perpY)
                
                -- Check map boundaries
                if x >= 4 and y >= 4 and x <= Map.width - 3 and y <= Map.height - 3 then
                    -- Add height variation - higher in the middle, lower at edges
                    local heightFactor = 1 - (math.abs(w) / thisWidth) * 0.8
                    
                    -- Only place if random value is below height factor (creates tapering)
                    if math.random() < heightFactor then
                        Map.tiles[y][x] = Map.TILE_MOUNTAIN
                        currentMountainTiles = currentMountainTiles + 1
                    end
                end
            end
        end
    end
    
    -- Create branching mountain range (with main ridge and smaller side ridges)
    local function createMountainRange(startX, startY, mainLength, mainAngle)
        -- Create the main ridge
        local mainWidth = math.random(2, 5)
        createMountainRidge(startX, startY, mainLength, mainWidth, mainAngle)
        
        -- Create some branches/side ridges
        local numBranches = math.random(2, 5)
        for i = 1, numBranches do
            -- Branch starts somewhere along the main ridge
            local branchPos = math.random(mainLength * 0.2, mainLength * 0.8)
            local branchX = math.floor(startX + branchPos * math.cos(mainAngle))
            local branchY = math.floor(startY + branchPos * math.sin(mainAngle))
            
            -- Branch angle differs from main angle
            local branchAngle = mainAngle + (math.random() * 0.8 - 0.4) * math.pi
            local branchLength = math.random(mainLength * 0.3, mainLength * 0.7)
            local branchWidth = math.max(1, mainWidth * 0.6)
            
            createMountainRidge(branchX, branchY, branchLength, branchWidth, branchAngle)
        end
    end
    
    -- Create several mountain ranges distributed across the map
    local numMountainRanges = math.random(3, 5)  -- Create 3-5 mountain ranges
    for i = 1, numMountainRanges do
        local startX = math.random(20, Map.width - 20)
        local startY = math.random(20, Map.height - 20)
        local angle = math.random() * math.pi * 2  -- Random direction
        local length = math.random(20, 50)  -- Longer ranges
        
        createMountainRange(startX, startY, length, angle)
    end
    
    print("Created " .. numMountainRanges .. " mountain ranges")
    
    -- Run cellular automata iterations to create natural-looking mountain shapes
    local iterations = 3
    for i = 1, iterations do
        local newTiles = {}
        for y = 1, Map.height do
            newTiles[y] = {}
            for x = 1, Map.width do
                -- Initialize with the current tile type
                newTiles[y][x] = Map.tiles[y][x]
                
                -- Count mountain neighbors
                local mountainNeighbors = 0
                local totalNeighbors = 0
                
                for ny = math.max(1, y-1), math.min(Map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(Map.width, x+1) do
                        if not (nx == x and ny == y) then
                            totalNeighbors = totalNeighbors + 1
                            if Map.tiles[ny][nx] == Map.TILE_MOUNTAIN then
                                mountainNeighbors = mountainNeighbors + 1
                            end
                        end
                    end
                end
                
                -- Apply cellular automata rules with lower threshold
                local mountainRatio = mountainNeighbors / totalNeighbors
                
                if Map.tiles[y][x] == Map.TILE_MOUNTAIN then
                    -- Mountains stay mountains more easily
                    newTiles[y][x] = (mountainRatio >= 0.2) and Map.TILE_MOUNTAIN or Map.TILE_GRASS
                else
                    -- Grass becomes mountain if it has enough mountain neighbors
                    newTiles[y][x] = (mountainRatio >= 0.5) and Map.TILE_MOUNTAIN or Map.TILE_GRASS
                end
                
                -- Keep only minimal border clear
                if x <= 2 or y <= 2 or x >= Map.width - 1 or y >= Map.height - 1 then
                    newTiles[y][x] = Map.TILE_GRASS
                end
            end
        end
        
        -- Copy the new tiles back to the map
        Map.tiles = newTiles
    end
    
    -- Count current mountain tiles
    currentMountainTiles = 0
    for y = 1, Map.height do
        for x = 1, Map.width do
            if Map.tiles[y][x] == Map.TILE_MOUNTAIN then
                currentMountainTiles = currentMountainTiles + 1
            end
        end
    end
    
    print("Generated " .. currentMountainTiles .. " mountain tiles before adjustment")
    
    -- Ensure we don't exceed the mountain percentage limit
    if currentMountainTiles > mountainTileCount * 1.5 then
        local tilesToConvert = currentMountainTiles - mountainTileCount
        while tilesToConvert > 0 do
            local x = math.random(4, Map.width - 4)
            local y = math.random(4, Map.height - 4)
            if Map.tiles[y][x] == Map.TILE_MOUNTAIN then
                -- Convert some mountain tiles back to grass
                Map.tiles[y][x] = Map.TILE_GRASS
                tilesToConvert = tilesToConvert - 1
            end
        end
    end
    
    -- If we have too few mountains, add more ridges
    if currentMountainTiles < mountainTileCount * 0.7 then
        print("Adding more mountain ridges to reach target")
        local additionalRidges = math.random(2, 4)
        for i = 1, additionalRidges do
            local startX = math.random(20, Map.width - 20)
            local startY = math.random(20, Map.height - 20)
            local angle = math.random() * math.pi * 2
            local length = math.random(15, 30)
            local width = math.random(2, 4)
            
            createMountainRidge(startX, startY, length, width, angle)
        end
    end
end

-- Generate water bodies using cellular automata
function Map:generateWater()
    -- Adjust these values to control water generation
    local waterPercentage = 0.15  -- Maximum percentage of map covered with water
    local waterTileCount = math.floor(Map.width * Map.height * waterPercentage)
    local currentWaterTiles = 0
    
    -- Create rivers and lakes
    local function createRiver(startX, startY, length, sinuosity, width)
        -- Start position
        local x, y = startX, startY
        
        -- Set initial direction - prefer going downward/horizontal for natural rivers
        local dirX = math.random(-0.5, 0.5)
        local dirY = math.random(0.5, 1.0)
        
        -- Normalize direction vector
        local dirLen = math.sqrt(dirX*dirX + dirY*dirY)
        dirX = dirX / dirLen
        dirY = dirY / dirLen
        
        -- Track river path for later widening
        local riverPath = {}
        
        -- River generation
        for i = 1, length do
            -- Add some randomness to direction (creates meandering)
            local angleChange = (math.random() - 0.5) * 0.2 * sinuosity
            local newDirX = dirX * math.cos(angleChange) - dirY * math.sin(angleChange)
            local newDirY = dirX * math.sin(angleChange) + dirY * math.cos(angleChange)
            
            -- Update direction with some momentum (blend old and new direction)
            dirX = (dirX * 0.8 + newDirX * 0.2)
            dirY = (dirY * 0.8 + newDirY * 0.2)
            
            -- Normalize direction vector again
            dirLen = math.sqrt(dirX*dirX + dirY*dirY)
            dirX = dirX / dirLen
            dirY = dirY / dirLen
            
            -- Move to next position
            x = x + dirX
            y = y + dirY
            
            -- Round to nearest tile
            local tileX = math.floor(x + 0.5)
            local tileY = math.floor(y + 0.5)
            
            -- Check map boundaries
            if tileX < 4 or tileY < 4 or tileX > Map.width - 3 or tileY > Map.height - 3 then
                break
            end
            
            -- Add to river path
            table.insert(riverPath, {x = tileX, y = tileY})
            
            -- Place water tile if not a mountain
            if Map.tiles[tileY] and Map.tiles[tileY][tileX] ~= Map.TILE_MOUNTAIN then
                Map.tiles[tileY][tileX] = Map.TILE_WATER
                currentWaterTiles = currentWaterTiles + 1
            end
            
            -- Avoid river bending back on itself too much - apply gravity influence
            -- Rivers tend to flow downhill, so we add a small downward bias
            dirY = dirY * 0.95 + 0.05
            
            -- Normalize again
            dirLen = math.sqrt(dirX*dirX + dirY*dirY)
            dirX = dirX / dirLen
            dirY = dirY / dirLen
        end
        
        -- Widen the river path
        for _, pos in ipairs(riverPath) do
            -- River width varies along the path (wider in the middle)
            local riverWidth = math.random(1, width)
            
            -- Create a small circle of water tiles around each point in the path
            for dy = -riverWidth, riverWidth do
                for dx = -riverWidth, riverWidth do
                    -- Use circular shape for the river cross-section
                    if dx*dx + dy*dy <= riverWidth*riverWidth then
                        local wx = pos.x + dx
                        local wy = pos.y + dy
                        
                        -- Check boundaries
                        if wx >= 4 and wy >= 4 and wx <= Map.width - 3 and wy <= Map.height - 3 then
                            -- Only place water if not mountains
                            if Map.tiles[wy] and Map.tiles[wy][wx] ~= Map.TILE_MOUNTAIN then
                                Map.tiles[wy][wx] = Map.TILE_WATER
                                currentWaterTiles = currentWaterTiles + 1
                            end
                        end
                    end
                end
            end
        end
        
        -- Create a lake at the end (river delta or mouth)
        if #riverPath > 0 then
            local endPos = riverPath[#riverPath]
            local lakeSize = math.random(width, width * 2)
            
            for dy = -lakeSize, lakeSize do
                for dx = -lakeSize, lakeSize do
                    -- Use circular shape for the lake
                    local dist = math.sqrt(dx*dx + dy*dy)
                    if dist <= lakeSize * (0.7 + math.random() * 0.3) then
                        local lx = endPos.x + dx
                        local ly = endPos.y + dy
                        
                        -- Check boundaries
                        if lx >= 4 and ly >= 4 and lx <= Map.width - 3 and ly <= Map.height - 3 then
                            -- Only place water if not mountains
                            if Map.tiles[ly] and Map.tiles[ly][lx] ~= Map.TILE_MOUNTAIN then
                                Map.tiles[ly][lx] = Map.TILE_WATER
                                currentWaterTiles = currentWaterTiles + 1
                            end
                        end
                    end
                end
            end
        end
        
        return riverPath
    end
    
    -- Create some small lakes
    local function createLake(centerX, centerY, size)
        for y = math.max(4, centerY - size), math.min(Map.height - 3, centerY + size) do
            for x = math.max(4, centerX - size), math.min(Map.width - 3, centerX + size) do
                -- Create rough circular lake
                local dx = x - centerX
                local dy = y - centerY
                local dist = math.sqrt(dx*dx + dy*dy)
                
                -- Only place water on grass tiles (not on mountains)
                if dist <= size * (0.7 + math.random() * 0.3) and Map.tiles[y][x] ~= Map.TILE_MOUNTAIN then
                    Map.tiles[y][x] = Map.TILE_WATER
                    currentWaterTiles = currentWaterTiles + 1
                end
            end
        end
    end
    
    -- Create tributary branches from main river
    local function createTributary(riverPath, mainLength)
        if #riverPath < 3 then return end
        
        -- Choose a point along the river to branch from (avoid endpoints)
        local branchIndex = math.random(math.floor(#riverPath * 0.2), math.floor(#riverPath * 0.8))
        local branchPos = riverPath[branchIndex]
        
        -- Get direction vector from nearby points to determine perpendicular direction
        local prevPos = riverPath[math.max(1, branchIndex - 1)]
        local nextPos = riverPath[math.min(#riverPath, branchIndex + 1)]
        
        -- Calculate direction of main river at this point
        local riverDirX = (nextPos.x - prevPos.x)
        local riverDirY = (nextPos.y - prevPos.y)
        
        -- Normalize
        local dirLen = math.sqrt(riverDirX*riverDirX + riverDirY*riverDirY)
        if dirLen > 0 then
            riverDirX = riverDirX / dirLen
            riverDirY = riverDirY / dirLen
        end
        
        -- Create perpendicular vector (rotate 90 degrees) - this gives us tributary direction
        local perpDirX = -riverDirY
        local perpDirY = riverDirX
        
        -- Randomly choose one side or the other to branch
        if math.random() < 0.5 then
            perpDirX = -perpDirX
            perpDirY = -perpDirY
        end
        
        -- Add some randomness to branch direction
        local angleOffset = (math.random() - 0.5) * math.pi / 4  -- +/- 45 degrees
        local startDirX = perpDirX * math.cos(angleOffset) - perpDirY * math.sin(angleOffset)
        local startDirY = perpDirX * math.sin(angleOffset) + perpDirY * math.cos(angleOffset)
        
        -- Create tributary starting offset from main river
        local startX = branchPos.x + startDirX * 2
        local startY = branchPos.y + startDirY * 2
        
        -- Tributary parameters - make them smaller than main river
        local tributaryLength = math.random(mainLength * 0.3, mainLength * 0.7)
        local tributarySinuosity = math.random(0.5, 1.5)
        local tributaryWidth = math.random(1, 2)
        
        -- Create the tributary river
        createRiver(startX, startY, tributaryLength, tributarySinuosity, tributaryWidth)
    end
    
    -- Create main rivers
    local numRivers = math.random(2, 4)  -- Create 2-4 major rivers
    local riverPaths = {}
    
    for i = 1, numRivers do
        -- Start rivers from near edges or mountains for more realistic appearance
        local startX, startY
        
        -- Try to start rivers from near mountains for realism
        local foundMountainSource = false
        for attempt = 1, 10 do
            local mx = math.random(10, Map.width - 10)
            local my = math.random(10, Map.height - 10)
            
            -- Check if this position is near mountains
            for dy = -3, 3 do
                for dx = -3, 3 do
                    local checkX = mx + dx
                    local checkY = my + dy
                    
                    if checkX >= 1 and checkY >= 1 and 
                       checkX <= Map.width and checkY <= Map.height and
                       Map.tiles[checkY][checkX] == Map.TILE_MOUNTAIN then
                        -- Found a mountain source
                        startX = mx
                        startY = my
                        foundMountainSource = true
                        break
                    end
                end
                if foundMountainSource then break end
            end
            if foundMountainSource then break end
        end
        
        -- If no mountain source found, start from map edge
        if not foundMountainSource then
            -- Choose which edge to start from
            local edge = math.random(1, 4)
            if edge == 1 then -- Top
                startX = math.random(Map.width * 0.2, Map.width * 0.8)
                startY = math.random(5, 15)
            elseif edge == 2 then -- Right
                startX = Map.width - math.random(5, 15)
                startY = math.random(Map.height * 0.2, Map.height * 0.8)
            elseif edge == 3 then -- Bottom
                startX = math.random(Map.width * 0.2, Map.width * 0.8)
                startY = Map.height - math.random(5, 15)
            else -- Left
                startX = math.random(5, 15)
                startY = math.random(Map.height * 0.2, Map.height * 0.8)
            end
        end
        
        -- River parameters
        local riverLength = math.random(30, 70)  -- Length of river
        local sinuosity = math.random(0.8, 1.5)  -- How much the river meanders (higher = more)
        local riverWidth = math.random(2, 4)     -- Width of river
        
        -- Create main river
        local riverPath = createRiver(startX, startY, riverLength, sinuosity, riverWidth)
        table.insert(riverPaths, {path = riverPath, length = riverLength})
        
        -- Create 1-3 tributaries for this river
        local numTributaries = math.random(1, 3)
        for j = 1, numTributaries do
            createTributary(riverPath, riverLength)
        end
    end
    
    -- Create a few small lakes
    local numLakes = math.random(2, 5)
    for i = 1, numLakes do
        local lakeX = math.random(10, Map.width - 10)
        local lakeY = math.random(10, Map.height - 10)
        local lakeSize = math.random(2, 5)
        createLake(lakeX, lakeY, lakeSize)
    end
    
    -- Run cellular automata iterations to smooth water bodies
    local iterations = 3
    for i = 1, iterations do
        local newTiles = {}
        for y = 1, Map.height do
            newTiles[y] = {}
            for x = 1, Map.width do
                -- Always preserve mountains
                if Map.tiles[y][x] == Map.TILE_MOUNTAIN then
                    newTiles[y][x] = Map.TILE_MOUNTAIN
                    goto continue
                end
                
                -- Count water neighbors
                local waterNeighbors = 0
                local totalNeighbors = 0
                
                for ny = math.max(1, y-1), math.min(Map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(Map.width, x+1) do
                        if not (nx == x and ny == y) then
                            -- Don't count mountain tiles in the water calculation
                            if Map.tiles[ny][nx] ~= Map.TILE_MOUNTAIN then
                                totalNeighbors = totalNeighbors + 1
                                if Map.tiles[ny][nx] == Map.TILE_WATER then
                                    waterNeighbors = waterNeighbors + 1
                                end
                            end
                        end
                    end
                end
                
                -- Apply cellular automata rules to smooth river edges
                if totalNeighbors > 0 then
                    local waterRatio = waterNeighbors / totalNeighbors
                    
                    if Map.tiles[y][x] == Map.TILE_WATER then
                        -- Water stays water if it has enough water neighbors
                        newTiles[y][x] = (waterRatio >= 0.3) and Map.TILE_WATER or Map.TILE_GRASS
                    else
                        -- Grass becomes water if it has many water neighbors (fill small gaps)
                        newTiles[y][x] = (waterRatio >= 0.6) and Map.TILE_WATER or Map.TILE_GRASS
                    end
                else
                    newTiles[y][x] = Map.tiles[y][x]
                end
                
                -- Keep borders as grass
                if x <= 3 or y <= 3 or x >= Map.width - 3 or y >= Map.height - 3 then
                    newTiles[y][x] = Map.TILE_GRASS
                end
                
                ::continue::
            end
        end
        Map.tiles = newTiles
    end
    
    -- Count current water tiles
    currentWaterTiles = 0
    for y = 1, Map.height do
        for x = 1, Map.width do
            if Map.tiles[y][x] == Map.TILE_WATER then
                currentWaterTiles = currentWaterTiles + 1
            end
        end
    end
    
    -- Ensure we have enough water - if not, add more lakes or extend rivers
    local minWaterTiles = math.floor(Map.width * Map.height * 0.08)  -- Minimum 8% water
    if currentWaterTiles < minWaterTiles then
        print("Adding more water to reach minimum percentage")
        -- Add lakes until we reach the target
        while currentWaterTiles < minWaterTiles do
            local lakeX = math.random(10, Map.width - 10)
            local lakeY = math.random(10, Map.height - 10)
            local lakeSize = math.random(3, 6)
            
            -- Create a lake
            createLake(lakeX, lakeY, lakeSize)
            
            -- Recount water tiles
            currentWaterTiles = 0
            for y = 1, Map.height do
                for x = 1, Map.width do
                    if Map.tiles[y][x] == Map.TILE_WATER then
                        currentWaterTiles = currentWaterTiles + 1
                    end
                end
            end
        end
    end
    
    -- Ensure we don't exceed the water percentage limit
    if currentWaterTiles > waterTileCount then
        local tilesToConvert = currentWaterTiles - waterTileCount
        print("Removing " .. tilesToConvert .. " excess water tiles")
        
        while tilesToConvert > 0 do
            local x = math.random(4, Map.width - 4)
            local y = math.random(4, Map.height - 4)
            if Map.tiles[y][x] == Map.TILE_WATER then
                -- Only remove water tiles that won't break river continuity
                local waterNeighbors = 0
                for ny = math.max(1, y-1), math.min(Map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(Map.width, x+1) do
                        if Map.tiles[ny][nx] == Map.TILE_WATER then
                            waterNeighbors = waterNeighbors + 1
                        end
                    end
                end
                
                -- Only remove if it won't create weird patterns or break rivers
                -- Preserve tiles with lots of water neighbors (river centers)
                if waterNeighbors <= 4 then
                    Map.tiles[y][x] = Map.TILE_GRASS
                    tilesToConvert = tilesToConvert - 1
                end
            end
        end
    end
    
    print("Generated " .. currentWaterTiles .. " water tiles (" .. 
          math.floor(currentWaterTiles / (Map.width * Map.height) * 100) .. "% of map)")
end

-- Generate forest regions using cellular automata
function Map:generateForests()
    -- Adjust these values to control forest generation
    local forestPercentage = 0.20  -- Target percentage of map covered with forests
    local seedPercentage = 0.20    -- Initial seeding percentage
    local forestTileCount = math.floor(Map.width * Map.height * forestPercentage)
    local currentForestTiles = 0
    
    -- Create forest seed clusters for more natural-looking forest patches
    local function createForestCluster(centerX, centerY, size)
        for y = math.max(4, centerY - size), math.min(Map.height - 3, centerY + size) do
            for x = math.max(4, centerX - size), math.min(Map.width - 3, centerX + size) do
                -- Create rough circular cluster
                local dx = x - centerX
                local dy = y - centerY
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= size * (0.7 + math.random() * 0.3) then
                    -- Only place forest on grass tiles (not on water or mountains)
                    if Map.tiles[y][x] == Map.TILE_GRASS then
                        Map.tiles[y][x] = Map.TILE_FOREST
                        currentForestTiles = currentForestTiles + 1
                    end
                end
            end
        end
    end
    
    -- Create several forest patches distributed across the map
    local numForests = math.random(5, 10)  -- Create 5-10 forest patches
    for i = 1, numForests do
        local forestX = math.random(10, Map.width - 10)
        local forestY = math.random(10, Map.height - 10)
        local forestSize = math.random(4, 12)  -- Size of forest patch
        createForestCluster(forestX, forestY, forestSize)
    end
    
    -- Also add random forest seeding for smaller forest patches
    for y = 1, Map.height do
        for x = 1, Map.width do
            -- Leave a border of grass around the edges of the map
            if x > 5 and y > 5 and x < Map.width - 5 and y < Map.height - 5 then
                if math.random() < seedPercentage / 4 and Map.tiles[y][x] == Map.TILE_GRASS then
                    Map.tiles[y][x] = Map.TILE_FOREST
                    currentForestTiles = currentForestTiles + 1
                end
            end
        end
    end
    
    -- Run cellular automata iterations to create natural-looking forests
    local iterations = 3  -- More iterations for smoother boundaries
    for i = 1, iterations do
        local newTiles = {}
        for y = 1, Map.height do
            newTiles[y] = {}
            for x = 1, Map.width do
                -- Initialize with original tile
                newTiles[y][x] = Map.tiles[y][x]
                
                -- Keep water and mountains as they are
                if Map.tiles[y][x] == Map.TILE_WATER or Map.tiles[y][x] == Map.TILE_MOUNTAIN then
                    goto continue
                end
                
                -- Count forest neighbors
                local forestNeighbors = 0
                local totalNeighbors = 0
                
                for ny = math.max(1, y-1), math.min(Map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(Map.width, x+1) do
                        if not (nx == x and ny == y) then
                            -- Only count grass and forest tiles for forest calculation
                            if Map.tiles[ny][nx] ~= Map.TILE_WATER and Map.tiles[ny][nx] ~= Map.TILE_MOUNTAIN then
                                totalNeighbors = totalNeighbors + 1
                                if Map.tiles[ny][nx] == Map.TILE_FOREST then
                                    forestNeighbors = forestNeighbors + 1
                                end
                            end
                        end
                    end
                end
                
                -- Apply cellular automata rules
                if totalNeighbors > 0 then
                    local forestRatio = forestNeighbors / totalNeighbors
                    
                    if Map.tiles[y][x] == Map.TILE_FOREST then
                        -- Forest stays if it has enough forest neighbors
                        newTiles[y][x] = (forestRatio >= 0.3) and Map.TILE_FOREST or Map.TILE_GRASS
                    else
                        -- Grass becomes forest if it has enough forest neighbors
                        newTiles[y][x] = (forestRatio >= 0.5) and Map.TILE_FOREST or Map.TILE_GRASS
                    end
                end
                
                -- Keep borders as grass
                if x <= 3 or y <= 3 or x >= Map.width - 3 or y >= Map.height - 3 then
                    if newTiles[y][x] == Map.TILE_FOREST then
                        newTiles[y][x] = Map.TILE_GRASS
                    end
                end
                
                ::continue::
            end
        end
        
        Map.tiles = newTiles
    end
    
    -- Ensure we don't exceed the forest percentage limit
    currentForestTiles = 0
    for y = 1, Map.height do
        for x = 1, Map.width do
            if Map.tiles[y][x] == Map.TILE_FOREST then
                currentForestTiles = currentForestTiles + 1
            end
        end
    end
    
    if currentForestTiles > forestTileCount then
        local tilesToConvert = currentForestTiles - forestTileCount
        while tilesToConvert > 0 do
            local x = math.random(4, Map.width - 4)
            local y = math.random(4, Map.height - 4)
            if Map.tiles[y][x] == Map.TILE_FOREST then
                -- Convert some forest tiles back to grass
                Map.tiles[y][x] = Map.TILE_GRASS
                tilesToConvert = tilesToConvert - 1
            end
        end
    end
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

-- Check if a position is adjacent to water (for fishing huts)
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
    local drawnTiles = {0, 0, 0, 0, 0}
    
    -- Draw all visible tiles
    for y = tileStartY, tileEndY do
        for x = tileStartX, tileEndX do
            local tileType = Map.tiles[y][x]
            local worldX = (x - 1) * Map.tileSize
            local worldY = (y - 1) * Map.tileSize
            
            -- Count the tile type being drawn
            drawnTiles[tileType] = drawnTiles[tileType] + 1
            
            -- Set color (full brightness for regular tiles)
            love.graphics.setColor(1, 1, 1, 1)
            
            -- Draw the normal tile
            love.graphics.draw(
                Map.tileset,
                Map.quads[tileType],
                worldX,
                worldY
            )
            
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
        print(string.format("Drew: Mountains: %d, Forests: %d, Grass: %d, Roads: %d, Water: %d",
            drawnTiles[Map.TILE_MOUNTAIN], drawnTiles[Map.TILE_FOREST], 
            drawnTiles[Map.TILE_GRASS], drawnTiles[Map.TILE_ROAD], drawnTiles[Map.TILE_WATER]))
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

-- Find nearest position adjacent to water (for fishing huts)
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
            
            -- Check if this location is suitable for a fishing hut
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
            
            -- Check if this is a valid position for a fishing hut
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
function Map:findPathAvoidingWater(startX, startY, endX, endY)
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
                    moveCost = moveCost * 0.7 -- Prefer following roads
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

-- Count and print the number of tiles of each type
function Map:countTiles()
    local tileCounts = {0, 0, 0, 0, 0}  -- Initialize counts for each tile type
    
    for y = 1, Map.height do
        for x = 1, Map.width do
            local tileType = Map.tiles[y][x]
            tileCounts[tileType] = tileCounts[tileType] + 1
        end
    end
    
    local totalTiles = Map.width * Map.height
    
    print("=== MAP TILE STATISTICS ===")
    print("Mountain tiles: " .. tileCounts[Map.TILE_MOUNTAIN] .. " (" .. 
          math.floor(tileCounts[Map.TILE_MOUNTAIN] / totalTiles * 100) .. "%)")
    print("Forest tiles: " .. tileCounts[Map.TILE_FOREST] .. " (" .. 
          math.floor(tileCounts[Map.TILE_FOREST] / totalTiles * 100) .. "%)")
    print("Grass tiles: " .. tileCounts[Map.TILE_GRASS] .. " (" .. 
          math.floor(tileCounts[Map.TILE_GRASS] / totalTiles * 100) .. "%)")
    print("Road tiles: " .. tileCounts[Map.TILE_ROAD] .. " (" .. 
          math.floor(tileCounts[Map.TILE_ROAD] / totalTiles * 100) .. "%)")
    print("Water tiles: " .. tileCounts[Map.TILE_WATER] .. " (" .. 
          math.floor(tileCounts[Map.TILE_WATER] / totalTiles * 100) .. "%)")
    print("Total tiles: " .. totalTiles)
    print("==========================")
end

-- Count a specific tile type
function Map:countSpecificTile(tileType, tileName)
    local count = 0
    for y = 1, Map.height do
        for x = 1, Map.width do
            if Map.tiles[y][x] == tileType then
                count = count + 1
            end
        end
    end
    
    local totalTiles = Map.width * Map.height
    local percentage = math.floor(count / totalTiles * 100)
    
    print(tileName .. " tiles: " .. count .. " (" .. percentage .. "%)")
    return count, percentage
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
