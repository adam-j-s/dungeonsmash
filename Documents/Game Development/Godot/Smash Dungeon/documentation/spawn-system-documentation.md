# Weapon Spawn System Documentation

## Overview
The weapon spawn system creates weapon pickups at designated points in the battle arena. This document outlines how the system works and how to configure it.

## Components

### 1. Weapon Pickup (weapon_pickup.gd)
- **Purpose**: Defines a collectable weapon that players can pick up
- **Key Features**:
  - Uses enum for weapon types (SWORD, STAFF, RANDOM)
  - Visual representation changes based on weapon type
  - Detects when players overlap with it
  - Gives appropriate weapon to the player
  - Can respawn after being collected

### 2. Weapon Spawner (WeaponSpawner.gd)
- **Purpose**: Creates weapon pickups at designated spawn points
- **Key Features**:
  - Periodically spawns new weapons at random locations
  - Limits maximum number of weapons in the arena
  - Tracks active weapon pickups
  - Configurable spawn intervals

### 3. Spawn Points
- **Purpose**: Define possible locations where weapons can appear
- **Implementation**: Simple Node2D nodes placed throughout the arena

## Setup Instructions

### Creating Spawn Points
1. In your battle arena scene, add Node2D nodes as children
2. Name them descriptively (e.g., "SpawnPoint1", "SpawnPoint2")
3. Position them where you want weapons to appear
4. (Optional) Add small ColorRect children for visual reference in the editor

### Configuring the Weapon Spawner
1. Add a Node2D to your battle arena scene
2. Attach the WeaponSpawner.gd script
3. In the Inspector panel, configure:
   - `weapon_pickup_scene`: Drag your weapon_pickup.tscn file here
   - `spawn_interval_min`: Minimum seconds between spawns (e.g., 5.0)
   - `spawn_interval_max`: Maximum seconds between spawns (e.g., 10.0)
   - `max_weapons`: Maximum number of weapons to spawn (e.g., 3)
   - `spawn_points`: Set the array size to match your number of spawn points
   - Drag each spawn point from the scene tree into the array slots

### Important Script Settings

#### In WeaponSpawner.gd:
```gdscript
# When creating a weapon pickup
var pickup = weapon_pickup_scene.instantiate()
pickup.weapon_type = 2  # 2 corresponds to WeaponType.RANDOM
```

#### In weapon_pickup.gd:
```gdscript
# Make sure your players are in the "players" group
# In both Player1 and Player2's _ready() function:
add_to_group("players")
```

## Common Issues and Solutions

1. **Weapons not appearing**:
   - Check if spawn points are properly added to the `spawn_points` array
   - Ensure the weapon_pickup_scene is correctly assigned
   - Confirm spawn points are positioned within the visible area

2. **Players can't pick up weapons**:
   - Verify players are added to the "players" group
   - Check collision layers/masks (pickup should detect players)
   - Ensure players have the `equip_weapon()` method

3. **Too many/few weapons spawning**:
   - Adjust `max_weapons` to control the maximum count
   - Modify `spawn_interval_min/max` to change the spawn frequency

## Customization Options

- **Weapon Types**: Add new weapon types to the WeaponType enum in weapon_pickup.gd
- **Spawn Behavior**: Modify the timer logic in WeaponSpawner.gd
- **Visual Appearance**: Update the get_weapon_color() function for distinct weapon visuals
- **Placement Strategy**: Add logic to the spawn_weapon() function for strategic placement

## Future Enhancements
- Replace random spawning with altar mechanics
- Add weapon tiers and quality levels
- Implement environmental interactions for weapon acquisition
- Create special spawn events (waves, boss rewards, etc.)
