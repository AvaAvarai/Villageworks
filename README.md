# Villageworks

A village builder god game where you create and manage a network of thriving settlements.

![Villageworks](docs/screenshot.png)

## Overview

Villageworks is a relaxing management simulation where you play as a benevolent deity guiding the growth of villages. Create multiple villages, each with their own historical name, and watch as builders construct houses, resource buildings, and roads to connect your growing civilization.

## Features

- **Multiple Villages**: Establish numerous settlements, each with a unique historical name
- **Autonomous Villagers**: Villagers and builders make intelligent decisions based on needs
- **Resource Management**: Balance food, wood, stone and money resources
- **Road Networks**: Plan roads between villages and buildings for faster travel and improved efficiency
- **Organic Growth**: Watch as villages grow naturally based on housing availability
- **Visual Feedback**: Color-coded villages show housing urgency at a glance

## Installation

### Requirements

- [LÖVE](https://love2d.org/) 11.3 or newer

### Running the Game

1. Download or clone this repository
2. Run the game using LÖVE:
   - **Windows**: Drag the repository folder onto love.exe or use `"C:\path\to\love.exe" "C:\path\to\villageworks"`
   - **macOS**: Use `open -n -a love "path/to/villageworks"` or drag the folder onto the LÖVE application
   - **Linux**: Use `love /path/to/villageworks`

## How to Play

### Getting Started

1. Click anywhere on the map to place your first village (costs $50 and 20 wood)
2. Villages automatically spawn builders who will construct buildings
3. Builders prioritize houses to maintain population growth
4. Use the build menu (press 'B') to plan roads between villages

### Controls

- **Left Mouse Button**: Place villages, select villages, or interact with UI
- **Right Mouse Button**: Deselect current village
- **Arrow Keys**: Move the camera
- **Mouse Wheel**: Zoom in/out
- **B Key**: Open/close build menu
- **1-9 Keys**: Quickly select villages by index
- **Escape**: Deselect current village or close menus

## Game Mechanics

### Villages

- Each village has a unique historical name
- Villages spawn builders if food is available
- Villages track their own population, resources, and building needs
- Housing needs are shown by village color (green, orange, or red)

### Buildings

| Building   | Function | Resources Produced |
|------------|----------|-------------------|
| House      | Increases population capacity and spawns villagers | - |
| Farm       | Produces food | Food |
| Mine       | Extracts stone | Stone |
| Lumberyard | Harvests wood | Wood |
| Fishing Hut| Catches fish | Food |

### Resource System

- **Food**: Required to spawn builders and maintain population
- **Wood**: Used for construction of all buildings
- **Stone**: Used for construction of more advanced buildings
- **Money**: Earned from resource production and trade

### Roads

- Roads connect villages to each other and to resource buildings
- Villagers and builders move faster on roads
- Roads improve resource transport efficiency
- Roads must be planned and built by builders

## Development

### Game Structure

- Built with the LÖVE framework (Love2D)
- Modular Lua codebase with entity-based architecture
- Event-driven update system

### Project Structure

```
villageworks/
├── config.lua       # Game constants and settings
├── utils.lua        # Utility functions
├── camera.lua       # Camera controls and viewport
├── ui.lua           # User interface elements
├── main.lua         # Entry point and game loop
├── data/
│   └── village_names.lua  # Historical village names
└── entities/
    ├── village.lua    # Village entity
    ├── builder.lua    # Builder entity
    ├── building.lua   # Buildings
    ├── villager.lua   # Villager entity
    └── road.lua       # Road system
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

---

*Villageworks was created with LÖVE. For any issues or feedback, please submit through GitHub issues.*
