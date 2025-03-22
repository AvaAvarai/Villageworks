# Villageworks

A sophisticated civilization management simulation where you establish and nurture a network of interconnected settlements.

## Overview

Villageworks is a relaxing yet engaging management simulation where you take on the role of a benevolent overseer guiding the development of human civilization. Create multiple villages with historical names, construct buildings, establish resource production chains, and connect your settlements with road networks to build a thriving society.

## Key Features

- **Rich Settlement System**: Create multiple villages, each with a unique historical name
- **Autonomous AI**: Villagers and builders make intelligent decisions based on current needs and priorities
- **Resource Economy**: Strategic management of food, wood, stone, and currency
- **Infrastructure Development**: Plan and build roads to connect villages and enhance resource transport
- **Dynamic Growth**: Watch as villages develop organically based on resource availability and population needs
- **Save & Load**: Preserve your progress with a complete game state saving system
- **Visual Indicators**: Color-coded visual feedback helps quickly identify settlement needs

## Installation

### Requirements

- [LÖVE](https://love2d.org/) 11.3 or newer

### Running the Game

1. Download or clone this repository
2. Run the game using LÖVE:
   - **Windows**: Drag the repository folder onto love.exe or use `"C:\path\to\love.exe" "C:\path\to\villageworks"`
   - **macOS**: Use `open -n -a love "path/to/villageworks"` or drag the folder onto the LÖVE application
   - **Linux**: Use `love /path/to/villageworks`

### Building the Game

1. Download or clone this repository
2. Navigate to the folder and run `zip -9 -r ../villageworks.love ./*`.
3. Go one folder up and run `love villageworks.love`

## Gameplay Guide

### Getting Started

1. From the main menu, select "New Game" to begin
2. Click anywhere on the map to place your first village (costs $50 and 20 wood)
3. Villages automatically spawn builders who will construct buildings
4. Builders prioritize houses to maintain population growth
5. Use the build menu to construct resource production buildings and plan roads

### Controls

- **Left Mouse Button**: Place villages, select villages, interact with UI
- **Right Mouse Button**: Deselect current village, cancel build mode
- **Arrow Keys**: Move the camera
- **Mouse Wheel**: Zoom in/out
- **B Key**: Open/close build menu
- **1-9 Keys**: Quickly select villages by index
- **Escape**: Access pause menu, close open dialogs
- **F5**: Quick save your game

### Game Mechanics

#### Villages

- Each village has a unique historical name
- Villages spawn builders if food is available
- Villages track their own population, resources, and building needs
- Housing needs are shown by village color (green, orange, or red)

#### Buildings

| Building   | Function | Resources Produced |
|------------|----------|-------------------|
| House      | Increases population capacity and spawns villagers | - |
| Farm       | Produces food | Food |
| Mine       | Extracts stone | Stone |
| Lumberyard | Harvests wood | Wood |
| Fishing Hut| Catches fish | Food |

#### Resource System

- **Food**: Required to spawn builders and maintain population
- **Wood**: Used for construction of all buildings
- **Stone**: Used for construction of more advanced buildings
- **Money**: Earned from resource production and trade

#### Roads

- Roads connect villages to each other and to resource buildings
- Villagers and builders move faster on roads
- Roads improve resource transport efficiency
- Roads must be planned and built by builders

#### Saving and Loading

- Quick save with F5
- Save games with custom names through the pause menu
- Load saved games from the main menu
- Maps and all entity data are preserved between saves

## Technical Architecture

### Game Structure

- Built with the LÖVE framework (Love2D)
- Modular Lua codebase with entity-based architecture
- Event-driven update system
- Complete serialization system for game state persistence

### Project Structure

```
villageworks/
├── config.lua       # Game constants and settings
├── utils.lua        # Utility functions
├── camera.lua       # Camera controls and viewport
├── ui.lua           # User interface elements
├── main.lua         # Entry point and game loop
├── map.lua          # Map generation and rendering
├── lib/
│   └── serpent.lua  # Serialization library
├── data/
│   ├── village_names.lua  # Historical village names
│   └── tiles.png     # Tileset graphics
├── saves/           # Directory for saved games
└── entities/
    ├── village.lua    # Village entity
    ├── builder.lua    # Builder entity
    ├── building.lua   # Buildings
    ├── villager.lua   # Villager entity
    └── road.lua       # Road system
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Using the [Serpent](https://github.com/pkulchenko/serpent) serializer available under the MIT License.
- Using the [Simple Tiles](https://opengameart.org/content/simple-tiles) tileset available for open use.

---

*Created with LÖVE. For issues or feedback, please submit through GitHub issues.*
