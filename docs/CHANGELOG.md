# Changelog

All notable changes to Villageworks will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- Added the serpent library for Lua serialization, enabling save/load functionality
- Enhanced fishing huts with water adjacency requirement for more realistic gameplay
- Added resource refunding when buildings cannot be constructed
- Added building overlap prevention for more realistic placement
- Added visual building radius overlay when hovering over villages

### Changed

- Updated camera system to start at the center of the world on map initialization
- Made fishing huts require adjacency to water tiles for placement
- Improved building placement logic with smarter positioning algorithms
- Enhanced builder AI with improved positioning logic to prevent building overlaps
- Added MAX_BUILD_DISTANCE configuration parameter to control building placement limits

### Fixed

- Fixed a critical issue where loading a saved game would generate a new map instead of restoring the saved map
- Fixed save/load system to properly serialize and deserialize map data
- Implemented proper map state persistence during game loads
- Fixed fishing hut placement to ensure they're built only next to water tiles
- Fixed building placement to prevent buildings from overlapping with each other
- Fixed "Maximum stack depth reached" error by ensuring camera transformations are properly balanced
- Fixed build menu not appearing when toggled or when clicking on villages

### UI Improvements

- Added transparent overlay showing building radius when hovering over villages
- Visual feedback helps players understand building placement constraints

## [0.1.1] - 2025-06-22

### Added

- Main menu with New Game, Load Game, documentation, and Exit options
- Pause menu with Resume, Save Game, and Exit to Main Menu options
- Documentation system with "How to Play", "About", and "Changelog" sections
- Game state management with proper pausing and resuming
- Game reset functionality for starting a new game
- Tile-based rendering system with a complete map implementation
- Procedural water generation with natural-looking lakes and ponds
- Improved road creation system using map tiles
- Map boundary constraints for entities and camera

### Changed

- Build menu now appears when clicking on a village
- Increased build menu width to 450px to accommodate all content
- Fixed issue with the close button's click detection
- Improved building queue controls
- Centralized drawing logic in the UI module
- Enhanced camera system with proper edge constraints
- Removed the 'V' key shortcut for building villages
- Water generation algorithm improved to create more interesting terrain
- Buildings cannot be placed on water tiles
- Road paths cannot go through water tiles

### Fixed

- Village placement now works properly with map boundaries
- Build menu now shows correctly when a village is selected
- Camera reset works correctly when starting a new game
- Camera no longer allows viewing beyond map edges
- Menu navigation is more intuitive
- Window layout adapts better to different content
- Entity spawning checks for valid positions within map bounds
- Road tiles are properly synchronized with road entities

## [0.1.0] - Initial Development

### Added

- Project structure and core mechanics
- Entity-based architecture
- Basic resource management
- Village creation
- Building construction
- Multiple villages with historical names
- Building system (houses, resource buildings)
- Road planning and construction mechanics
- Resource transport and production
- Villager and builder AI
- Population management
- Camera controls with zoom
- Basic UI elements

## Future Plans

- Terrain types and effects
- Seasons and weather
- Enhanced villager behavior
- Trade routes and economy
- Research and technology progression
- Save/load functionality
- Custom map creation
- Village specialization
- Achievements and challenges
