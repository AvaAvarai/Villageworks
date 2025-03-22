-- Game Constants
local Config = {
    -- Costs
    VILLAGE_COST = 50,
    BUILDER_COST = 20,
    
    -- Building properties
    BUILDING_TYPES = {
        farm = { 
            cost = { wood = 15, stone = 10 }, 
            income = 5, 
            buildTime = 3, 
            resource = "food", 
            workCapacity = 3,
            description = "Produces food for your villages"
        },
        mine = { 
            cost = { wood = 10, stone = 25 }, 
            income = 8, 
            buildTime = 5, 
            resource = "stone", 
            workCapacity = 2,
            description = "Extracts stone resources"
        },
        lumberyard = { 
            cost = { wood = 10, stone = 10 }, 
            income = 6, 
            buildTime = 4, 
            resource = "wood", 
            workCapacity = 2,
            description = "Harvests wood from trees"
        },
        house = { 
            cost = { wood = 15, stone = 5 }, -- Reduced cost to encourage more building
            income = 0, 
            buildTime = 2, -- Reduced build time for houses
            villagerCapacity = 3, -- Increased capacity for better population growth
            spawnTime = 8, -- Faster villager spawning
            description = "Houses villagers and increases village population capacity"
        },
        fishing_hut = {
            cost = { wood = 25, stone = 5 },
            income = 7,
            buildTime = 4,
            resource = "food",
            workCapacity = 2,
            description = "Catches fish for food (must be near water)"
        }
    },
    
    -- Map and rendering
    TILE_SIZE = 40,
    MAX_BUILD_DISTANCE = 150,
    WORLD_WIDTH = 3000,  -- Width of the game world in pixels
    WORLD_HEIGHT = 3000, -- Height of the game world in pixels
    
    -- Entity behavior
    BUILDER_SPAWN_TIME = 10,
    BUILDER_BUILD_CHANCE = 0.05, -- Increased from 0.01
    BUILDER_SPEED = 40,
    VILLAGER_SPEED = 30,
    
    -- Village population settings
    DEFAULT_MAX_BUILDERS = 3,       -- Maximum builders per village without houses
    BASE_POPULATION_CAPACITY = 5,   -- Base population capacity per village
    HOUSE_PRIORITY_FACTOR = 0.8,    -- How strongly builders prioritize building houses
    POPULATION_GROWTH_TARGET = 0.7, -- Target to maintain population at % of capacity
    
    -- Resource initial values
    STARTING_MONEY = 100,
    STARTING_RESOURCES = { wood = 50, stone = 30, food = 40 },
    
    -- Road settings
    ROAD_COST_PER_UNIT = { wood = 0.05, stone = 0.02 },
    ROAD_BUILD_SPEED = 50,          -- How fast builders construct roads (units per second)
    ROAD_SPEED_MULTIPLIER = 1.5,    -- Movement speed multiplier when on roads
    ROAD_BUILD_PRIORITY = 0.3,      -- Chance a builder will prioritize road building
    
    -- Resource transport
    RESOURCE_CARRY_CAPACITY = 5,    -- How many resources a villager can carry
    RESOURCE_EXTRACT_TIME = 5,      -- Time to extract resources at a resource building
    RESOURCE_BONUS_WITH_ROAD = 1.5,  -- Multiplier for resource extraction when connected by roads
    
    -- Game speed settings
    TIME_NORMAL_SPEED = 1.0,        -- Normal game speed (1x)
    TIME_FAST_SPEED = 3.0,          -- Fast game speed when spacebar is held (3x)
    CURRENT_GAME_SPEED = 1.0,       -- Current game speed multiplier
    
    -- Game UI settings
    UI_MODE_NORMAL = "normal",      -- Normal interaction mode
    UI_MODE_BUILDING_VILLAGE = "building_village", -- Mode for placing new villages
    UI_VILLAGE_BUILD_BUTTON_TEXT = "Build Village"  -- Text for the village build button
}

return Config 