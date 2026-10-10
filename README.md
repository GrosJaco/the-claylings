# The Claylings

A Godot 4.6 2D colony simulation and real-time strategy (RTS) defense game where autonomous clay agents ("Claylings") harvest resources, farm crops, craft equipment, and build a settlement in a procedurally generated world. Players manage colony logistics by day and command military squads by night to defend their Crystal against escalating waves of nocturnal creatures.

<!-- Showcase Section: Replace placeholder paths/URLs with demo video clips or GIFs -->
<!--
<p align="center">
  <video src="https://user-images.githubusercontent.com/.../gameplay-preview.mp4" width="100%" controls autoplay loop muted></video>
</p>
-->

## Features

- **Autonomous Agent Simulation & Traits**: Driven by a modular Finite State Machine (FSM), Claylings autonomously handle colony tasks (hauling, delivering, constructing, farming, foraging, mining, chopping, crafting) while managing vitals like hunger, energy, and health. Each Clayling possesses a unique name, age, and one of 13 distinct personality traits (*Resilient, Swift, Efficient, Strong, Smart, Brave, Dexterous, Optimistic, Hermit, Tough, Gourmand, NightOwl, Curious*) directly impacting their physical capabilities, energy decay, movement speed, or combat resilience.
- **Dynamic Weather System**: A real-time weather cycle featuring Clear, Rain, and Thunderstorm conditions. Rain automatically hydrates tilled soil and halts moisture evaporation while slightly altering movement speed. Thunderstorms feature screen-shaking lightning flashes and spatial thunder audio.
- **Fauna & Livestock Lifecycle**: Autonomous chickens that wander, forage, and lay eggs. Eggs left on the ground have a chance to hatch into chicks over time or can be collected for cooking. Chicks follow adult chickens and mature into adults over time. Animals flee from nearby threats and yield resources upon death (eggs, feathers, raw meat).
- **Fortifications & Offscreen Threat Radar**: Placeable wooden walls that automatically connect to neighboring walls as well as natural terrain obstacles (cliffs, rocks, water bodies), supporting continuous drag-placement. An offscreen threat indicator renders pulsating border beacons pointing directly toward incoming nocturnal enemies.
- **Colony Logistics & Multi-Tier Crafting**: Comprehensive production chain featuring storage piles, crafting buildings (Workbench, Furnace, Forge, Loom, Chopping Block), recipe queues, dynamic fuel mechanics, and an intelligent task-quota and reservation system to prevent worker bottlenecks. Raw resources include wood, stone, clay, fiber, copper, iron, gold, and food, refinable into planks, fabrics, ropes, ingots, cogs, and cooked meals.
- **RTS Squad Combat & Formations**: Seamless transition between civilian tasks and military defense with Call to Arms (`X`) and Call to Work (`Z`). Equip Claylings via Weapon Racks into combat classes (Spearmen, Knights, Archers), command units with RTS box selection, right-click targeting, and dynamic drag-and-drop line formations with collision validation and attack knockback.
- **Procedural World Generation & Custom Settings**: FastNoiseLite-powered map generation with customizable world seed, map sizes (64x64, 128x128, 256x256), and density presets for water, mountains, forests, and resource veins (clay, copper, iron, gold).
- **Difficulty Presets**: Four selectable difficulty modes:
  - **Leaf (Peaceful)**: No nocturnal enemy waves, focusing purely on building, farming, and logistics.
  - **Wood**: Relaxed nocturnal waves for a gentle defense experience.
  - **Clay**: Standard balanced difficulty.
  - **Stone**: Hardcore scaling for seasoned defenders.
- **Multi-Slot Save & Load System**: Comprehensive game state serialization supporting custom-named save slots, quicksaves, and seamless loading of terrain, natural resources, buildings, inventories, clayling stats, weather, and world state.
- **Colony Management HUD & Controls**: Interactive UI suite including a Task Priority & Quota management window, category-based Build Menu, Clayling Status Inspector, Day/Clock tracker with weather indicator, game speed controls (Pause, 1x, 2x, 3x), entity hover outlines, and radial context menus.

## Controls

### Camera & Navigation
| Key / Input | Action |
| --- | --- |
| `W` / `A` / `S` / `D` or `Z` / `Q` / `S` / `D` or Arrows | Pan Camera |
| `Middle Mouse Button (Hold & Drag)` | Pan Camera |
| `Mouse Wheel Up` / `Down` | Camera Zoom In / Zoom Out |
| `H` / `Home` | Center Camera on Crystal |

### Game Speed & Navigation
| Key / Input | Action |
| --- | --- |
| `Space` | Pause / Resume Game Simulation |
| `1` | Normal Speed (1x) |
| `2` | Fast Speed (2x) |
| `3` | Very Fast Speed (3x) |
| `Tab` / `Shift + Tab` | Cycle to Next / Previous Clayling (Centers Camera) |
| `Escape` | Open Pause Menu / Close Active Dialogs & Radial Menus |
| `F11` or `Alt + Enter` | Toggle Fullscreen |

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
| `Left Click (Hold & Drag)` | Drag-place Walls and Soil Tiles in a line or grid |
| `Right Click` | Cancel Blueprint Preview / Close Radial Menus |
| `M` | Place Harvest / Work Zone |

### Developer & Debug Shortcuts
> [!NOTE]
> Press `²` or `~` to toggle **Dev Mode**.

| Key / Input | Condition | Action |
| --- | --- | --- |
| `²` / `~` | Always | Toggle Dev Mode overlay |
| `J` or `Ctrl + S` | Dev Mode only | Equip all Claylings as Spearmen |
| `H`, `Ctrl + A`, or `U` | Dev Mode only | Equip all Claylings as Archers |
| `F6` | Dev Mode only | Cycle Weather (Clear -> Rain -> Thunderstorm) |
| `C` | Dev Mode only | Spawn Clayling at mouse position |
| `P` | Dev Mode only | Spawn Chicken at mouse position |
| `Shift + P` | Dev Mode only | Spawn Chick at mouse position |
| `B` | Dev Mode only | Spawn Bunny at mouse position |
| `F` | Dev Mode only | Spawn Fox at mouse position |
| `O` | Dev Mode only | Kill all chickens |
| `N` | Dev Mode only | Spawn Blue Spider at mouse position |
| `V` | Dev Mode only | Spawn Purple Spider at mouse position |
| `L` | Dev Mode only | Trigger next nocturnal enemy wave |
| `Y` | Dev Mode only | Fill Weapon Racks with random equipment kits |
| `K` | Dev Mode only | Kill all Claylings |
| `Shift + K` | Dev Mode only | Kill all enemies |
| `R` | Defeat screen | Restart Game |

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
4. Open the project and press **F5** (or Run) to launch the Main Menu (`Scenes/UI/MainMenu.tscn`).

## License & Credits

- The **source code** is licensed under the [MIT License](LICENSE).
- All **art, audio, and font assets** belong to their respective creators and are subject to their own licenses and permissions. See [CREDITS.md](CREDITS.md) for full attribution.
