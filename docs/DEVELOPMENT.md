# Villageworks Development Guide

This document provides technical information for developers who want to understand the codebase or contribute to Villageworks.

## Architecture Overview

Villageworks is built with LÖVE (Love2D), a framework for making 2D games in Lua. The game uses an entity-based architecture with modular components.

### Core Components

- **Entity System**: Villages, buildings, villagers, and builders are separate entities with their own update and draw methods
- **Event System**: Game state updates are driven by the Love2D update/draw cycle
- **UI System**: Handles user input and rendering interface elements

## Code Structure

### Main Files

- **main.lua**: Entry point, contains the Love2D callbacks (load, update, draw)
- **config.lua**: Configuration constants and game settings
- **utils.lua**: Utility functions (distances, resource handling, etc.)
- **camera.lua**: Camera controls including movement and zoom
- **ui.lua**: User interface rendering and interaction

### Entity Files (in /entities/)

- **village.lua**: The core settlement object that tracks population and needs
- **builder.lua**: Units that construct buildings and roads
- **building.lua**: Structures for housing and resource production
- **villager.lua**: Units that work in buildings and transport resources
- **road.lua**: Connections between settlements and buildings

### Data Files (in /data/)

- **village_names.lua**: Historical settlement names

## Game State

The central `game` table contains:

```lua
game = {
    money = Config.STARTING_MONEY,
    villages = {},
    builders = {},
    buildings = {},
    villagers = {},
    roads = {},
    resources = Config.STARTING_RESOURCES,
    selectedEntity = nil,
    selectedVillage = nil
}
```

## Entity Lifecycle

### Creation

Entities are created using their respective `.new()` methods and added to the appropriate game state array:

```lua
local newVillage = Village.new(x, y)
table.insert(game.villages, newVillage)
```

### Update Cycle

Each entity type has a static `update` function that processes all entities of that type:

```lua
function Village.update(villages, game, dt)
    for i, village in ipairs(villages) do
        -- Update village state
    end
end
```

These update functions are called from the main `love.update()` function.

### Drawing

Similar to updates, entities have their own `draw` method:

```lua
function Village:draw()
    -- Draw village graphics
end
```

## Resource System

Resources are tracked in the `game.resources` table:

```lua
resources = { 
    wood = 50, 
    stone = 30, 
    food = 40 
}
```

## Adding New Features

### Adding a New Building Type

1. Add the building configuration to `Config.BUILDING_TYPES` in config.lua:

```lua
newBuilding = {
    cost = { wood = 20, stone = 15 },
    income = 6,
    buildTime = 4,
    resource = "newResource",
    workCapacity = 2,
    description = "Description"
}
```

2. Add rendering code in Building:draw()
3. Add any specialized behavior in Building:update()

### Adding a New Game Mechanic

1. Determine which entity the mechanic affects
2. Add necessary properties to the entity's data structure
3. Implement the behavior in the entity's update function
4. Add UI elements if player interaction is required

## Coding Standards

### Style Guide

- Use local variables when possible
- Use camelCase for variables and functions
- Use PascalCase for module names
- Add comments for complex logic

### Performance Considerations

- Minimize table creation during update cycles
- Use distance squared calculations when possible (avoiding square roots)
- Cache calculated values when appropriate
- Optimize drawing by only rendering what's visible

## Extending the UI

The UI system is managed in ui.lua, with functions to handle:

- Resource display
- Building menus
- Tooltips
- Village selection

To add new UI elements:

1. Add properties to the UI table
2. Update UI.update() to handle any state changes
3. Add rendering code to UI.draw()
4. Handle user interactions in UI.handleClick()

## Testing

Currently, the game does not have automated tests. Manual testing is required for new features. Consider:

- Testing with different village configurations
- Verifying resource calculations
- Ensuring proper villager/builder behavior

## Planned Features

These features are being considered for future development:

- Terrain types affecting building placement and efficiency
- Seasons and weather effects
- Trading between villages
- Enemy threats and defenses
- Technology progression
- Save/load functionality

## Contributing

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Submit a pull request with a clear description of the changes

## Debugging

Debug mode can be enabled by setting a flag in config.lua:

```lua
Config.DEBUG_MODE = true
```

This will show entity IDs, pathfinding information, and resource calculations. 