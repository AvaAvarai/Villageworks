# Changelog

All notable changes to Villageworks will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

### Added

- Village tile.
- Village upgrade to Town to City to Empire button improving build radius.

### Changed

- Traders farther markets get higher scores.
- Traders use A* and wont walk over mountains or water.
- Traders will look for new markets.
- Renamed 'Lumberyard' into 'Sawmill'.
- Renamed 'Fishing Hut' into 'Fishery'.

### Fixed

- Draw buidling hover or 'i' key text over units and tiles.
- Trader refresh market query.

## [0.1.4] - 2025-03-24

### Added

- Market building for spawning traders and conducting trades at.
- Trader unit for trading between markets to produce money.
- Generalized Villagers to work at nearest needed station, cart goods back to associated village, and return to work.
- Made a priority for building queue which is now worked by the villagers.
- Updated UI to reflect Villagers instead of Builders and Villagers.

### Changed

- Black background rectangle behind the village names
- Scrollpane embedded in build menu to scroll building list.
- Update screenshots.
- Main menu title backdrop.
- Removed redundant start game buttons per game size
- World generation module.
- Map water gen with flowing rivers.
- UI build menu module.
- UI tooltips module.
- UI roads module.
- Removed builders.
- Only show building text for non-village buildings on hover or 'i' key press.
- Made it so that workers and villages work between road connected villages.
- Update mountain tile.

### Fixed

- Fixed build menu not showing on large window sizes.
- Resource ui layout fix for added trader unit.
- Draw villages over buildings so their titles aren't obscured by buildings.
- Save serialization nil checks and safer entity list handeling.
- Villagers pathing can move over buildings, prioritize building, return to villages.

## [0.1.3] - 2025-03-22

### Added

- Added freeform road construction where two map points have road interpolated.
- Road build queue and in-process road tiles using alpha-overlay on road tiles.
- Added world size selection menu with Small, Medium, Large, and Huge options
- Added scrollable interface for world size selection with mouse wheel support
- Added detailed descriptions and dimensions for each world size option
- Added mountain terrain features as a natural barrier in the world
- Added mine buildings that require adjacency to mountains for stone resource extraction
- Added isAdjacentToMountain and findNearestMountainEdge functions for mine placement
- Enhanced builders to intelligently find valid locations near mountains for mines
- Added A* pathfinding algorithm to find paths around water tiles and mountains
- Added intelligent path following for villagers and builders
- Added dynamic forest system with natural regrowth mechanics
- Added forest harvesting for wood resource collection
- Added proximity-based forest detection and management functions
- Added spiral search pattern for efficient forest tile location

### Changed

- Updated New Game flow to include world size selection before starting
- Improved main menu UI with animated buttons and hover effects
- Made world configuration dynamic based on selected world size
- Updated tileset to include mountain tiles at position 1, shifting all other tiles forward
- Units (villagers and builders) now path around water and mountains instead of walking over them
- Roads can no longer be built through mountains, adding strategic gameplay around terrain
- Improved movement logic with waypoint-based pathfinding
- Units prefer to follow roads when available (lower movement cost)
- Forest tiles now impact movement with higher traversal costs
- Implemented natural forest regrowth from adjacent forest tiles
- Terrain generation follows a logical order (mountains → water → forests) to ensure proper feature distribution

### Fixed

- Fixed syntax error in map.lua that was preventing the game from starting
- Fixed forest regrowth logic to work correctly in various edge cases
- Fixed a critical issue where loading a saved game would generate a new map instead of restoring the saved map
- Fixed terrain generation to ensure mountains don't get overwritten by later terrain features

## [0.1.2] - 2025-03-22

### Added

- Added the serpent library for Lua serialization, enabling save/load functionality
- Enhanced Fisherys with water adjacency requirement for more realistic gameplay
- Added resource refunding when buildings cannot be constructed
- Added building overlap prevention for more realistic placement
- Added visual building radius overlay when hovering over villages
- Added improved building placement rules to prevent building on villages or overlapping with in-progress construction
- Added building queue position planning system to prevent overlaps
- Implemented modular UI code structure with separate modules for different UI components

### Changed

- Updated camera system to start at the center of the world on map initialization
- Made Fisherys require adjacency to water tiles for placement
- Improved building placement logic with smarter positioning algorithms
- Enhanced builder AI with improved positioning logic to prevent building overlaps
- Added MAX_BUILD_DISTANCE configuration parameter to control building placement limits
- Increased safety margins for building placement to prevent any potential overlaps
- Refactored UI code into separate modules for maintainability

### Fixed

- Fixed save/load system to properly serialize and deserialize map data
- Implemented proper map state persistence during game loads
- Fixed Fishery placement to ensure they're built only next to water tiles
- Fixed building placement to prevent buildings from overlapping with each other
- Fixed "Maximum stack depth reached" error by ensuring camera transformations are properly balanced
- Fixed build menu not appearing when toggled or when clicking on villages
- Fixed issue where buildings could overlap with villages or in-progress construction
- Fixed rare issue where planned buildings could overlap with each other in the queue
- Fixed menu button hover detection offset issue
- Fixed documentation popups with proper scrolling functionality
- Fixed various UI module integration issues

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
