# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **Three Kingdoms Idle Game** built with **Godot Engine 4.x**, targeting multi-platform deployment (Steam, Web, iOS, Android) with mobile-first design (414x896 resolution, portrait orientation). The game features pixel art style, automated idle gameplay with strategic skill selection, and follows Three Kingdoms historical themes.

## Development Commands

### Testing with GdUnit4
- **Run all tests**: Use Godot Editor → Project → Tools → GdUnit4 → Run Tests
- **Run specific test**: Open test file in script editor and use GdUnit4 dock
- **Test patterns**: Files matching `**/Test*.gd`, `**/*Test.gd`, `**/*TestSuite.gd`
- **Coverage threshold**: 80% (configured in `addons/gdunit4_config/gdunit4.cfg`)
- **Test reports**: Generated in `user://reports/` directory

### Godot Development
- **Project structure**: No `project.godot` file exists yet - needs to be created
- **Scene testing**: NO test scenes allowed (per development standards) - use unit tests only
- **Debug logs**: Structured logging to `/logs` directory using emoji categorization
- **Asset organization**: Pixel art assets organized in `/assets` with subfolders for backgrounds, characters, icons, UI

## Architecture Overview

### Core Design Principles
The project follows **event-driven architecture** with strict separation of concerns:

1. **Event-Driven Communication**: All system communication through `EventBus.gd`
2. **Layered Architecture**: Core → Systems → Managers → UI
3. **Test-Driven Development**: Mandatory TDD approach using GdUnit4
4. **Mobile-First Design**: Responsive UI using VBoxContainer/HBoxContainer
5. **Professional Standards**: Enterprise-level logging, SOLID principles, dependency injection

### System Layer Structure
```
UI Layer:          SkillSelectionUI | GameMainUI | CityInfoUI | BattleUI
                                    ↓ Event Bus ↓
Manager Layer:     DataManager | UIManager | SaveManager | AudioManager
                                    ↓ Event Bus ↓
Systems Layer:     SkillSystem | BattleSystem | CitySystem | TurnSystem
                                    ↓ Event Bus ↓
Core Layer:        EventBus | GameStateManager | GameCore | LogManager
```

### Key Architectural Files (To Be Implemented)
- `EventBus.gd`: Central communication hub with type-safe event definitions
- `GameStateManager.gd`: State machine (MENU → SKILL_SELECTION → GAME_RUNNING → BATTLE → PAUSED → GAME_OVER)
- `GameCore.gd`: Main controller for game flow coordination
- `SkillSystem.gd`: Self-contained skill selection state machine with star economy
- `LogManager.gd`: Professional logging with file location tracking to `/logs`

### Mobile-Optimized UI Structure
- **TopBar (180px)**: Player info, abilities (武力/智力/統治/政治/魅力/天命), resources
- **GameMainArea**: HSplitContainer with MapArea (Node2D cities) + GameEvent (ScrollContainer)
- **BottomBar (120px)**: TabContainer for 武將/武技/政略/國家/裝備/更多
- **BattleScene**: Overlay Node2D for combat animations

### Game Data Structure
The game requires extensive JSON data files for:
- **Skills Database**: 40+ skills with star costs (1-3 stars) and effects
- **Cities**: 16 Three Kingdoms cities with connections, territories, garrison generals
- **Generals**: 40+ historical figures with attributes (武/智/統/政/魅)
- **Equipment**: Tiered system (普通/稀有/傳說) with city-count unlock requirements
- **Random Events**: 50+ events with probability modifiers based on 天命 attribute

## Development Standards

### Forbidden Practices
- **NO simplified/demo versions**: Must maintain commercial-grade quality
- **NO test scene files**: Use professional unit testing only
- **NO TestMain.tscn**: Debug through actual gameplay and logging system

### Required Practices
- **Test-Driven Development**: Write tests before implementation
- **Event-Driven Communication**: All inter-system communication via EventBus
- **Structured Logging**: Use LogManager with emoji categorization and file tracking
- **Mobile-First UI**: 18px fonts, touch-optimized controls, responsive containers
- **Game/Debug Log Separation**: `game_events` (player-visible) vs `logger` (debug-only)

### Module Loading Order
1. Core systems (EventBus, GameContext)
2. Data layer (DataManager, DataIntegration)
3. Game logic layer (SkillSelection, Battle systems)
4. UI layer (all UI components)
5. Game flow control (GameFlow)

### Save System
- Location: `user://savegame.json`
- Content: Player state, city ownership, general roster, equipment inventory
- Integration: Through SaveManager with event-driven updates

This project emphasizes professional game development practices with comprehensive testing, clear architecture separation, and enterprise-level code quality standards.