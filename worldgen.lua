local Utils = require("utils")
local Config = require("config")

local Gen = {}

-- Tile types (must match Map constants)
Gen.TILE_MOUNTAIN = 1
Gen.TILE_FOREST = 2
Gen.TILE_GRASS = 3
Gen.TILE_ROAD = 4
Gen.TILE_WATER = 5

-- Generate mountain regions
function Gen.generateMountains(map)
    -- Adjust these values to control mountain generation
    local mountainPercentage = 0.12  -- Slightly increased target percentage
    local mountainTileCount = math.floor(map.width * map.height * mountainPercentage)
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
                if x >= 4 and y >= 4 and x <= map.width - 3 and y <= map.height - 3 then
                    -- Add height variation - higher in the middle, lower at edges
                    local heightFactor = 1 - (math.abs(w) / thisWidth) * 0.8
                    
                    -- Only place if random value is below height factor (creates tapering)
                    if math.random() < heightFactor then
                        map.tiles[y][x] = Gen.TILE_MOUNTAIN
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
        local startX = math.random(20, map.width - 20)
        local startY = math.random(20, map.height - 20)
        local angle = math.random() * math.pi * 2  -- Random direction
        local length = math.random(20, 50)  -- Longer ranges
        
        createMountainRange(startX, startY, length, angle)
    end
    
    print("Created " .. numMountainRanges .. " mountain ranges")
    
    -- Run cellular automata iterations to create natural-looking mountain shapes
    local iterations = 3
    for i = 1, iterations do
        local newTiles = {}
        for y = 1, map.height do
            newTiles[y] = {}
            for x = 1, map.width do
                -- Initialize with the current tile type
                newTiles[y][x] = map.tiles[y][x]
                
                -- Count mountain neighbors
                local mountainNeighbors = 0
                local totalNeighbors = 0
                
                for ny = math.max(1, y-1), math.min(map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(map.width, x+1) do
                        if not (nx == x and ny == y) then
                            totalNeighbors = totalNeighbors + 1
                            if map.tiles[ny][nx] == Gen.TILE_MOUNTAIN then
                                mountainNeighbors = mountainNeighbors + 1
                            end
                        end
                    end
                end
                
                -- Apply cellular automata rules with lower threshold
                local mountainRatio = mountainNeighbors / totalNeighbors
                
                if map.tiles[y][x] == Gen.TILE_MOUNTAIN then
                    -- Mountains stay mountains more easily
                    newTiles[y][x] = (mountainRatio >= 0.2) and Gen.TILE_MOUNTAIN or Gen.TILE_GRASS
                else
                    -- Grass becomes mountain if it has enough mountain neighbors
                    newTiles[y][x] = (mountainRatio >= 0.5) and Gen.TILE_MOUNTAIN or Gen.TILE_GRASS
                end
                
                -- Keep only minimal border clear
                if x <= 2 or y <= 2 or x >= map.width - 1 or y >= map.height - 1 then
                    newTiles[y][x] = Gen.TILE_GRASS
                end
            end
        end
        
        -- Copy the new tiles back to the map
        map.tiles = newTiles
    end
    
    -- Count current mountain tiles
    currentMountainTiles = 0
    for y = 1, map.height do
        for x = 1, map.width do
            if map.tiles[y][x] == Gen.TILE_MOUNTAIN then
                currentMountainTiles = currentMountainTiles + 1
            end
        end
    end
    
    print("Generated " .. currentMountainTiles .. " mountain tiles before adjustment")
    
    -- Ensure we don't exceed the mountain percentage limit
    if currentMountainTiles > mountainTileCount * 1.5 then
        local tilesToConvert = currentMountainTiles - mountainTileCount
        while tilesToConvert > 0 do
            local x = math.random(4, map.width - 4)
            local y = math.random(4, map.height - 4)
            if map.tiles[y][x] == Gen.TILE_MOUNTAIN then
                -- Convert some mountain tiles back to grass
                map.tiles[y][x] = Gen.TILE_GRASS
                tilesToConvert = tilesToConvert - 1
            end
        end
    end
    
    -- If we have too few mountains, add more ridges
    if currentMountainTiles < mountainTileCount * 0.7 then
        print("Adding more mountain ridges to reach target")
        local additionalRidges = math.random(2, 4)
        for i = 1, additionalRidges do
            local startX = math.random(20, map.width - 20)
            local startY = math.random(20, map.height - 20)
            local angle = math.random() * math.pi * 2
            local length = math.random(15, 30)
            local width = math.random(2, 4)
            
            createMountainRidge(startX, startY, length, width, angle)
        end
    end
end

-- Generate water bodies using cellular automata
function Gen.generateWater(map)
    -- Adjust these values to control water generation
    local waterPercentage = 0.15  -- Maximum percentage of map covered with water
    local waterTileCount = math.floor(map.width * map.height * waterPercentage)
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
            if tileX < 4 or tileY < 4 or tileX > map.width - 3 or tileY > map.height - 3 then
                break
            end
            
            -- Add to river path
            table.insert(riverPath, {x = tileX, y = tileY})
            
            -- Place water tile if not a mountain
            if map.tiles[tileY] and map.tiles[tileY][tileX] ~= Gen.TILE_MOUNTAIN then
                map.tiles[tileY][tileX] = Gen.TILE_WATER
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
                        if wx >= 4 and wy >= 4 and wx <= map.width - 3 and wy <= map.height - 3 then
                            -- Only place water if not mountains
                            if map.tiles[wy] and map.tiles[wy][wx] ~= Gen.TILE_MOUNTAIN then
                                map.tiles[wy][wx] = Gen.TILE_WATER
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
                        if lx >= 4 and ly >= 4 and lx <= map.width - 3 and ly <= map.height - 3 then
                            -- Only place water if not mountains
                            if map.tiles[ly] and map.tiles[ly][lx] ~= Gen.TILE_MOUNTAIN then
                                map.tiles[ly][lx] = Gen.TILE_WATER
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
        for y = math.max(4, centerY - size), math.min(map.height - 3, centerY + size) do
            for x = math.max(4, centerX - size), math.min(map.width - 3, centerX + size) do
                -- Create rough circular lake
                local dx = x - centerX
                local dy = y - centerY
                local dist = math.sqrt(dx*dx + dy*dy)
                
                -- Only place water on grass tiles (not on mountains)
                if dist <= size * (0.7 + math.random() * 0.3) and map.tiles[y][x] ~= Gen.TILE_MOUNTAIN then
                    map.tiles[y][x] = Gen.TILE_WATER
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
            local mx = math.random(10, map.width - 10)
            local my = math.random(10, map.height - 10)
            
            -- Check if this position is near mountains
            for dy = -3, 3 do
                for dx = -3, 3 do
                    local checkX = mx + dx
                    local checkY = my + dy
                    
                    if checkX >= 1 and checkY >= 1 and 
                       checkX <= map.width and checkY <= map.height and
                       map.tiles[checkY][checkX] == Gen.TILE_MOUNTAIN then
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
                startX = math.random(map.width * 0.2, map.width * 0.8)
                startY = math.random(5, 15)
            elseif edge == 2 then -- Right
                startX = map.width - math.random(5, 15)
                startY = math.random(map.height * 0.2, map.height * 0.8)
            elseif edge == 3 then -- Bottom
                startX = math.random(map.width * 0.2, map.width * 0.8)
                startY = map.height - math.random(5, 15)
            else -- Left
                startX = math.random(5, 15)
                startY = math.random(map.height * 0.2, map.height * 0.8)
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
        local lakeX = math.random(10, map.width - 10)
        local lakeY = math.random(10, map.height - 10)
        local lakeSize = math.random(2, 5)
        createLake(lakeX, lakeY, lakeSize)
    end
    
    -- Run cellular automata iterations to smooth water bodies
    local iterations = 3
    for i = 1, iterations do
        local newTiles = {}
        for y = 1, map.height do
            newTiles[y] = {}
            for x = 1, map.width do
                -- Always preserve mountains
                if map.tiles[y][x] == Gen.TILE_MOUNTAIN then
                    newTiles[y][x] = Gen.TILE_MOUNTAIN
                    goto continue
                end
                
                -- Count water neighbors
                local waterNeighbors = 0
                local totalNeighbors = 0
                
                for ny = math.max(1, y-1), math.min(map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(map.width, x+1) do
                        if not (nx == x and ny == y) then
                            -- Don't count mountain tiles in the water calculation
                            if map.tiles[ny][nx] ~= Gen.TILE_MOUNTAIN then
                                totalNeighbors = totalNeighbors + 1
                                if map.tiles[ny][nx] == Gen.TILE_WATER then
                                    waterNeighbors = waterNeighbors + 1
                                end
                            end
                        end
                    end
                end
                
                -- Apply cellular automata rules to smooth river edges
                if totalNeighbors > 0 then
                    local waterRatio = waterNeighbors / totalNeighbors
                    
                    if map.tiles[y][x] == Gen.TILE_WATER then
                        -- Water stays water if it has enough water neighbors
                        newTiles[y][x] = (waterRatio >= 0.3) and Gen.TILE_WATER or Gen.TILE_GRASS
                    else
                        -- Grass becomes water if it has many water neighbors (fill small gaps)
                        newTiles[y][x] = (waterRatio >= 0.6) and Gen.TILE_WATER or Gen.TILE_GRASS
                    end
                else
                    newTiles[y][x] = map.tiles[y][x]
                end
                
                -- Keep borders as grass
                if x <= 3 or y <= 3 or x >= map.width - 3 or y >= map.height - 3 then
                    newTiles[y][x] = Gen.TILE_GRASS
                end
                
                ::continue::
            end
        end
        map.tiles = newTiles
    end
    
    -- Count current water tiles
    currentWaterTiles = 0
    for y = 1, map.height do
        for x = 1, map.width do
            if map.tiles[y][x] == Gen.TILE_WATER then
                currentWaterTiles = currentWaterTiles + 1
            end
        end
    end
    
    -- Ensure we have enough water - if not, add more lakes or extend rivers
    local minWaterTiles = math.floor(map.width * map.height * 0.08)  -- Minimum 8% water
    if currentWaterTiles < minWaterTiles then
        print("Adding more water to reach minimum percentage")
        -- Add lakes until we reach the target
        while currentWaterTiles < minWaterTiles do
            local lakeX = math.random(10, map.width - 10)
            local lakeY = math.random(10, map.height - 10)
            local lakeSize = math.random(3, 6)
            
            -- Create a lake
            createLake(lakeX, lakeY, lakeSize)
            
            -- Recount water tiles
            currentWaterTiles = 0
            for y = 1, map.height do
                for x = 1, map.width do
                    if map.tiles[y][x] == Gen.TILE_WATER then
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
            local x = math.random(4, map.width - 4)
            local y = math.random(4, map.height - 4)
            if map.tiles[y][x] == Gen.TILE_WATER then
                -- Only remove water tiles that won't break river continuity
                local waterNeighbors = 0
                for ny = math.max(1, y-1), math.min(map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(map.width, x+1) do
                        if map.tiles[ny][nx] == Gen.TILE_WATER then
                            waterNeighbors = waterNeighbors + 1
                        end
                    end
                end
                
                -- Only remove if it won't create weird patterns or break rivers
                -- Preserve tiles with lots of water neighbors (river centers)
                if waterNeighbors <= 4 then
                    map.tiles[y][x] = Gen.TILE_GRASS
                    tilesToConvert = tilesToConvert - 1
                end
            end
        end
    end
    
    print("Generated " .. currentWaterTiles .. " water tiles (" .. 
          math.floor(currentWaterTiles / (map.width * map.height) * 100) .. "% of map)")
end

-- Generate forest regions using cellular automata
function Gen.generateForests(map)
    -- Adjust these values to control forest generation
    local forestPercentage = 0.20  -- Target percentage of map covered with forests
    local seedPercentage = 0.20    -- Initial seeding percentage
    local forestTileCount = math.floor(map.width * map.height * forestPercentage)
    local currentForestTiles = 0
    
    -- Create forest seed clusters for more natural-looking forest patches
    local function createForestCluster(centerX, centerY, size)
        for y = math.max(4, centerY - size), math.min(map.height - 3, centerY + size) do
            for x = math.max(4, centerX - size), math.min(map.width - 3, centerX + size) do
                -- Create rough circular cluster
                local dx = x - centerX
                local dy = y - centerY
                local dist = math.sqrt(dx*dx + dy*dy)
                if dist <= size * (0.7 + math.random() * 0.3) then
                    -- Only place forest on grass tiles (not on water or mountains)
                    if map.tiles[y][x] == Gen.TILE_GRASS then
                        map.tiles[y][x] = Gen.TILE_FOREST
                        currentForestTiles = currentForestTiles + 1
                    end
                end
            end
        end
    end
    
    -- Create several forest patches distributed across the map
    local numForests = math.random(5, 10)  -- Create 5-10 forest patches
    for i = 1, numForests do
        local forestX = math.random(10, map.width - 10)
        local forestY = math.random(10, map.height - 10)
        local forestSize = math.random(4, 12)  -- Size of forest patch
        createForestCluster(forestX, forestY, forestSize)
    end
    
    -- Also add random forest seeding for smaller forest patches
    for y = 1, map.height do
        for x = 1, map.width do
            -- Leave a border of grass around the edges of the map
            if x > 5 and y > 5 and x < map.width - 5 and y < map.height - 5 then
                if math.random() < seedPercentage / 4 and map.tiles[y][x] == Gen.TILE_GRASS then
                    map.tiles[y][x] = Gen.TILE_FOREST
                    currentForestTiles = currentForestTiles + 1
                end
            end
        end
    end
    
    -- Run cellular automata iterations to create natural-looking forests
    local iterations = 3  -- More iterations for smoother boundaries
    for i = 1, iterations do
        local newTiles = {}
        for y = 1, map.height do
            newTiles[y] = {}
            for x = 1, map.width do
                -- Initialize with original tile
                newTiles[y][x] = map.tiles[y][x]
                
                -- Keep water and mountains as they are
                if map.tiles[y][x] == Gen.TILE_WATER or map.tiles[y][x] == Gen.TILE_MOUNTAIN then
                    goto continue
                end
                
                -- Count forest neighbors
                local forestNeighbors = 0
                local totalNeighbors = 0
                
                for ny = math.max(1, y-1), math.min(map.height, y+1) do
                    for nx = math.max(1, x-1), math.min(map.width, x+1) do
                        if not (nx == x and ny == y) then
                            -- Only count grass and forest tiles for forest calculation
                            if map.tiles[ny][nx] ~= Gen.TILE_WATER and map.tiles[ny][nx] ~= Gen.TILE_MOUNTAIN then
                                totalNeighbors = totalNeighbors + 1
                                if map.tiles[ny][nx] == Gen.TILE_FOREST then
                                    forestNeighbors = forestNeighbors + 1
                                end
                            end
                        end
                    end
                end
                
                -- Apply cellular automata rules
                if totalNeighbors > 0 then
                    local forestRatio = forestNeighbors / totalNeighbors
                    
                    if map.tiles[y][x] == Gen.TILE_FOREST then
                        -- Forest stays if it has enough forest neighbors
                        newTiles[y][x] = (forestRatio >= 0.3) and Gen.TILE_FOREST or Gen.TILE_GRASS
                    else
                        -- Grass becomes forest if it has enough forest neighbors
                        newTiles[y][x] = (forestRatio >= 0.5) and Gen.TILE_FOREST or Gen.TILE_GRASS
                    end
                end
                
                -- Keep borders as grass
                if x <= 3 or y <= 3 or x >= map.width - 3 or y >= map.height - 3 then
                    if newTiles[y][x] == Gen.TILE_FOREST then
                        newTiles[y][x] = Gen.TILE_GRASS
                    end
                end
                
                ::continue::
            end
        end
        
        map.tiles = newTiles
    end
    
    -- Ensure we don't exceed the forest percentage limit
    currentForestTiles = 0
    for y = 1, map.height do
        for x = 1, map.width do
            if map.tiles[y][x] == Gen.TILE_FOREST then
                currentForestTiles = currentForestTiles + 1
            end
        end
    end
    
    if currentForestTiles > forestTileCount then
        local tilesToConvert = currentForestTiles - forestTileCount
        while tilesToConvert > 0 do
            local x = math.random(4, map.width - 4)
            local y = math.random(4, map.height - 4)
            if map.tiles[y][x] == Gen.TILE_FOREST then
                -- Convert some forest tiles back to grass
                map.tiles[y][x] = Gen.TILE_GRASS
                tilesToConvert = tilesToConvert - 1
            end
        end
    end
end

-- Count and print the number of tiles of each type
function Gen.countTiles(map)
    local tileCounts = {0, 0, 0, 0, 0}  -- Initialize counts for each tile type
    
    for y = 1, map.height do
        for x = 1, map.width do
            local tileType = map.tiles[y][x]
            tileCounts[tileType] = tileCounts[tileType] + 1
        end
    end
    
    local totalTiles = map.width * map.height
    
    print("=== MAP TILE STATISTICS ===")
    print("Mountain tiles: " .. tileCounts[Gen.TILE_MOUNTAIN] .. " (" .. 
          math.floor(tileCounts[Gen.TILE_MOUNTAIN] / totalTiles * 100) .. "%)")
    print("Forest tiles: " .. tileCounts[Gen.TILE_FOREST] .. " (" .. 
          math.floor(tileCounts[Gen.TILE_FOREST] / totalTiles * 100) .. "%)")
    print("Grass tiles: " .. tileCounts[Gen.TILE_GRASS] .. " (" .. 
          math.floor(tileCounts[Gen.TILE_GRASS] / totalTiles * 100) .. "%)")
    print("Road tiles: " .. tileCounts[Gen.TILE_ROAD] .. " (" .. 
          math.floor(tileCounts[Gen.TILE_ROAD] / totalTiles * 100) .. "%)")
    print("Water tiles: " .. tileCounts[Gen.TILE_WATER] .. " (" .. 
          math.floor(tileCounts[Gen.TILE_WATER] / totalTiles * 100) .. "%)")
    print("Total tiles: " .. totalTiles)
    print("==========================")
end

-- Count a specific tile type
function Gen.countSpecificTile(map, tileType, tileName)
    local count = 0
    for y = 1, map.height do
        for x = 1, map.width do
            if map.tiles[y][x] == tileType then
                count = count + 1
            end
        end
    end
    
    local totalTiles = map.width * map.height
    local percentage = math.floor(count / totalTiles * 100)
    
    print(tileName .. " tiles: " .. count .. " (" .. percentage .. "%)")
    return count, percentage
end

-- Initialize a map grid with default values
function Gen.initializeMapGrid(width, height, defaultTile)
    defaultTile = defaultTile or Gen.TILE_GRASS
    
    local tiles = {}
    for y = 1, height do
        tiles[y] = {}
        for x = 1, width do
            tiles[y][x] = defaultTile
        end
    end
    
    return tiles
end

-- Generate a new map with all terrain layers
function Gen.generateMap(width, height)
    -- Create a map data structure with necessary properties
    local map = {
        width = width,
        height = height,
        tiles = Gen.initializeMapGrid(width, height)
    }
    
    -- Generate terrain in order of dominance
    Gen.generateMountains(map)
    Gen.generateWater(map)
    Gen.generateForests(map)
    
    -- Count and print statistics
    Gen.countTiles(map)
    
    return map
end

return Gen 