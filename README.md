# The Claylings

A Godot 4.6 2D colony simulation and real-time strategy (RTS) defense game where autonomous clay agents ("Claylings") harvest resources, farm crops, craft equipment, and construct a thriving settlement in a procedurally generated world. Players manage civilian logistics by day and command tactical military squads by night to defend their sacred Crystal against escalating waves of nocturnal creatures.

<!-- Showcase Section: Replace placeholder paths/URLs with your demo video clips or GIFs -->
<!-- GitHub supports both embedded videos (MP4/WebM) and animated GIFs: -->
<!--
<p align="center">
  <video src="https://user-images.githubusercontent.com/.../gameplay-preview.mp4" width="100%" controls autoplay loop muted></video>
</p>
-->

## Features

- **Autonomous Agent Simulation & Needs**: Driven by a modular Finite State Machine (FSM), Claylings autonomously handle colony tasks (hauling, delivering, constructing, farming, foraging, mining, chopping) while managing vital personal needs like hunger and energy.
- **Colony Logistics & Multi-Tier Crafting**: Comprehensive production chain featuring storage depots, crafting stations (Workbench, Furnace, Forge, Loom, Chopping Block), recipe queues, dynamic fuel consumption, and an intelligent task-quota and reservation system to prevent worker bottlenecks.
- **RTS Squad Combat & Tactical Formations**: Seamless transition between civilian life and military defense with Call to Arms (`X`) and Call to Work (`Z`). Equip Claylings via Weapon Racks into specialized combat classes (Spearmen, Knights, Archers), command units with RTS box selection, target priorities, and dynamic drag-and-drop line formations with wall collision validation.
- **Procedural World Generation & Ecology**: FastNoiseLite-powered procedural map generation producing organic landmasses, water bodies, impassable cliff walls, harvestable flora (trees, saplings, fiber bushes), and vein clusters of valuable ores (copper, iron, gold).
- **Day/Night Cycle & Nocturnal Wave Defense**: Real-time atmospheric lighting and day-night cycle driving procedural enemy wave spawns (melee Blue Spiders, ranged Purple Spiders) targeting the central Crystal, with difficulty scaling dynamically across surviving days.
- **Grid Agriculture & Harvest Zones**: Dynamic soil moisture and evaporation physics, crop growth staging (carrots), and draggable harvest zones (`M`) for automated mass gathering.
- **Colony Management HUD**: Interactive UI suite including a Task Priority & Quota management window, category-based Build Menu, Clayling Status Inspector, Day/Clock tracker, and context-sensitive radial interaction menus.

## Controls

### Camera & Navigation
| Key / Input | Action |
| --- | --- |
| `W` / `A` / `S` / `D` or Arrow Keys | Pan Camera |
| `Middle Mouse Button (Hold & Drag)` | Pan Camera |
| `Mouse Wheel Up` / `Down` | Camera Zoom In / Zoom Out |

### RTS & Combat Commands
| Key / Input | Action |
| --- | --- |
| `Left Click (Drag)` | Box Select Combat Units |
| `Right Click` | Move Selected Units / Attack Target Enemy |
| `Right Click (Hold & Drag)` | Draw Tactical Line Formation for Selected Units |
| `X` | Call to Arms (Send idle Claylings to equip kits at Weapon Racks) |
| `Z` | Call to Work (Disarm soldiers back to villager duties) |

### Colony & Construction
| Key / Input | Action |
| --- | --- |
| `Left Click` | Inspect Clayling / Interact with Building / Confirm Placement |
| `Right Click` | Cancel Blueprint Preview / Close Radial Menus |
| `A` | Quick-build Storage Pile |
| `B` | Quick-place Soil Tile |
| `F` | Quick-build Furnace |
| `O` | Quick-build Forge |
| `W` | Quick-build Weapon Rack |
| `T` | Quick-plant Oak Sapling |
| `M` | Place Harvest / Work Zone |

### Debug & Spawning Shortcuts
| Key / Input | Action |
| --- | --- |
| `C` | Spawn Clayling at mouse position |
| `N` | Spawn Blue Spider enemy at mouse position |
| `V` | Spawn Purple Spider enemy at mouse position |
| `L` | Manually trigger next enemy wave |
| `Y` | Fill Weapon Racks with random kits |
| `S` | Equip all Claylings as Spearmen |
| `K` | Kill all Claylings |
| `B` / `Shift + K` | Kill all enemies |
| `R` | Restart Game (on Defeat screen) |

## Getting Started

### Prerequisites
- [Godot Engine 4.4+](https://godotengine.org/) (Project uses Godot 4.6 features and `.uid` metadata).

### Running the Project
1. Clone this repository:
   ```bash
   git clone https://github.com/GrosJaco/theclaylings.git
   ```
2. Open the Godot Project Manager.
3. Click **Import** and select the `project.godot` file in this directory.
4. Open the project and press **F5** (or Run) to play the main level (`Scenes/main.tscn`).

## License & Credits

- The **source code** is licensed under the [MIT License](LICENSE).
- All **art, audio, and font assets** belong to their respective creators and are subject to their own licenses and permissions. See [CREDITS.md](CREDITS.md) for full attribution.
