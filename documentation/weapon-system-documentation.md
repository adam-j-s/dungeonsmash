# Smash Dungeon Weapon System Documentation

## Overview

The weapon system in Smash Dungeon uses a modular, data-driven architecture that separates the different aspects of weapon functionality into distinct components:

1. **Weapon Base**: Core weapon functionality and central manager
2. **Attack Styles**: How weapons execute attacks (melee, projectile, area, etc.)
3. **Behaviors**: Modifiers that add special properties to weapons
4. **Effects**: Visual and gameplay effects applied during attacks

This document explains how the weapon system works and how to add or modify weapons.

## Architecture

### File Structure

```
res://scripts/
├── weapon_base.gd             # Core weapon class
├── weapon_attacks.gd          # Handles attack execution
├── weapon_effects.gd          # Handles visual/sound effects
├── weapon_types.gd            # Defines weapon categories
├── weapon_database.gd         # Loads weapon data from CSV
├── attack_style_base.gd       # Base class for attack styles
├── attack_style_manager.gd    # Manages attack styles
├── behavior_manager.gd        # Manages weapon behaviors
├── projectile.gd              # Handles projectile physics
├── attack styles/             # Different attack styles
│   ├── melee_attack_style.gd  # Melee attacks
│   ├── projectile_attack_style.gd # Firing projectiles
│   ├── area_attack_style.gd   # Area-based attacks
│   ├── pull_attack_style.gd   # Pull/attraction attacks
│   ├── push_attack_style.gd   # Push/repulsion attacks
│   ├── singularity_attack_style.gd # Special singularity effect
│   └── wave_attack_style.gd   # Wave pattern attacks
└── behaviors/                 # Different behaviors
    ├── bounce_behavior.gd     # Bouncing projectiles
    ├── explosive_behavior.gd  # Explosion on impact
    ├── homing_behavior.gd     # Homing projectiles
    ├── piercing_behavior.gd   # Pierce through targets
    └── rapid_cooldown_behavior.gd # Faster cooldown
```

### Component Relationships

1. **weapon_base.gd**:
   - Central manager that owns references to all other components
   - Handles player input and delegates to specialized components
   - Manages weapon state (cooldown, etc.)

2. **weapon_attacks.gd**:
   - Created and owned by weapon_base.gd
   - Creates and initializes the attack_style_manager
   - Delegates attack execution to the appropriate style

3. **attack_style_manager.gd**:
   - Created by weapon_attacks.gd
   - Loads attack styles based on the weapon's style
   - Manages execution of the current style

4. **Attack Style scripts**:
   - Created by attack_style_manager.gd
   - Handle specific attack behaviors

5. **behavior_manager.gd**:
   - Created and owned by weapon_base.gd
   - Loads behaviors based on weapon data
   - Modifies weapon properties and handles callbacks

6. **Behavior scripts**:
   - Created by behavior_manager.gd
   - Modify weapon properties and respond to events

7. **projectile.gd**:
   - Created by projectile_attack_style.gd
   - Handles projectile physics, movement, and collision
   - Applies damage and effects on impact

## Weapon Data Format

Weapons are defined in a CSV file with the following key fields:

| Field | Description |
|-------|-------------|
| weapon_id | Unique identifier for the weapon |
| name | Display name |
| weapon_type | Category (sword, staff, etc.) |
| weapon_style | Attack style (melee, projectile, area, etc.) |
| damage | Base damage |
| attack_speed | Attacks per second |
| knockback_force | Force applied to targets |
| attack_range_x | Horizontal range for melee/area attacks |
| attack_range_y | Vertical range for melee/area attacks |
| projectile_speed | Speed of projectiles |
| projectile_lifetime | Duration projectiles exist |
| tier | Rarity tier (0-4) |
| effects | Visual/gameplay effects (comma-separated) |
| special_flags | Special modifiers (comma-separated) |
| bounce_count | Number of times projectiles bounce |
| homing_strength | How strongly projectiles track targets (0-1) |
| gravity_factor | How much gravity affects projectiles |
| projectile_count | Number of projectiles fired at once |
| projectile_spread | Angle spread for multiple projectiles |
| piercing | Number of targets projectiles can hit |
| explosion_radius | Explosion area size |
| behaviors | Behavior scripts to apply (semicolon-separated) |
| description | Weapon description text |

## Attack Styles

The weapon system supports various attack styles, each implemented in its own script:

### 1. Melee Attack Style
**Example Weapons**: Sword, Great Sword
- Creates a hitbox in front of the player
- Applies damage and knockback on collision
- Used by weapons with direct swing attacks

```gdscript
# Example melee weapon in CSV
sword,Sword,sword,melee,12,1.2,600,50,30,,,0,,,0,0,0,1,0,0,0,,Standard sword with good damage and speed
```

### 2. Projectile Attack Style
**Example Weapons**: Magic Staff, Fire Staff, Piercing Lance
- Creates projectiles that travel through the scene
- Handles trajectory, speed, and lifetime
- Most versatile attack style, can be modified by many behaviors

```gdscript
# Example projectile weapon in CSV
staff,Magic Staff,staff,projectile,8,0.8,400,60,30,400,0.8,0,,,0,0,0,1,0,0,0,,Magical staff with medium range
```

### 3. Area Attack Style
**Example Weapons**: Blast Hammer
- Creates an effect area around the player
- Applies damage to all targets within the area
- Good for AoE (Area of Effect) attacks

```gdscript
# Example area weapon in CSV
blast_hammer,Blast Hammer,sword,area,20,0.6,1500,100,60,,,3,fire,push,0,0,0,1,0,0,0,fire;push,Hammer with explosive area damage
```

### 4. Wave Attack Style
**Example Weapons**: Wave Wand
- Creates projectiles that move in a wave pattern
- Good for covering larger areas with a single projectile

```gdscript
# Example wave weapon in CSV
wave_wand,Wave Wand,staff,wave,9,1.0,400,70,40,350,1.2,2,,,0,0,0,1,0,0,0,wave:wave_amplitude=50.0;wave_frequency=3.0,Projects a wave-like pattern
```

### 5. Pull Attack Style
**Example Weapons**: Pull Blade
- Creates a force field that pulls targets toward the player
- Used for crowd control and positioning

```gdscript
# Example pull weapon in CSV
pull_blade,Pull Blade,sword,pull,11,1.1,300,45,30,,,2,,pull,0,0,0,1,0,0,0,pull,Sword that pulls enemies closer
```

### 6. Singularity Attack Style
**Example Weapons**: Singularity Bomb
- Creates a gravity well that pulls targets and then explodes
- Complex combination of pull forces and explosion effects

```gdscript
# Example singularity weapon in CSV
singularity_bomb,Singularity Bomb,staff,singularity,15,0.5,450,60,35,350,2.0,4,,,0,0.2,0.7,1,0,0,120,singularity:pull_strength=800.0;pull_radius=150.0;gravity:gravity_factor=0.7;explosive:explosion_radius=120,Creates a temporary gravitational singularity that pulls enemies in before exploding
```

## Behaviors

Behaviors modify weapon properties and add special effects. These can be combined to create complex weapon functionalities:

### 1. Bounce Behavior
**Example Weapon**: Bounce Orb
- Makes projectiles bounce off walls and obstacles
- Controlled by bounce_count parameter

```gdscript
# Example bounce weapon in CSV
bounce_orb,Bounce Orb,staff,projectile,7,0.9,300,60,30,400,1.2,2,,,3,0,0,1,0,0,0,bounce:bounce_count=3,Magical orb that bounces off surfaces
```

### 2. Homing Behavior
**Example Weapons**: Homing Missile, Plasma Ball
- Makes projectiles track targets
- Controlled by homing_strength parameter (0-1)

```gdscript
# Example homing weapon in CSV
homing_missile,Homing Missile,staff,projectile,9,0.7,350,55,30,350,1.5,2,,,0,1,0,1,0,0,0,homing:homing_strength=1.0,Missile that tracks enemies
```

### 3. Gravity Behavior
**Example Weapons**: Gravity Bomb, Cluster Bomb
- Makes projectiles affected by gravity
- Creates arc trajectories
- Controlled by gravity_factor parameter

```gdscript
# Example gravity weapon in CSV
gravity_bomb,Gravity Bomb,staff,projectile,12,0.6,500,65,35,300,1.8,3,,,0,0,0.8,1,0,0,80,gravity:gravity_factor=0.8;explosive:explosion_radius=80,Heavy bomb affected by gravity with explosion
```

### 4. Multishot Behavior
**Example Weapons**: Shotgun, Multi Staff, Cluster Bomb
- Creates multiple projectiles in a spread pattern
- Controlled by projectile_count and projectile_spread parameters

```gdscript
# Example multishot weapon in CSV
shotgun,Shotgun,sword,projectile,5,0.5,200,80,50,500,0.6,3,,,0,0,0,5,30,0,0,multishot:projectile_count=5;projectile_spread=30,Fires multiple projectiles in a spread
```

### 5. Piercing Behavior
**Example Weapons**: Piercing Lance, Sniper Bow, Laser Drill
- Allows projectiles to hit multiple targets
- Controlled by piercing parameter

```gdscript
# Example piercing weapon in CSV
piercing_lance,Piercing Lance,staff,projectile,15,0.5,600,50,25,600,0.7,3,,,0,0,0,1,0,3,0,piercing:piercing=3,Long projectile that pierces through multiple enemies
```

### 6. Explosive Behavior
**Example Weapons**: Gravity Bomb, Plasma Ball, Cluster Bomb
- Creates explosions when projectiles hit targets
- Controlled by explosion_radius parameter

```gdscript
# Example explosive weapon in CSV
plasma_ball,Plasma Ball,staff,projectile,8,0.6,300,60,35,350,1.0,3,,,0,0.2,0,1,0,0,60,homing:homing_strength=0.2;explosive:explosion_radius=60,Energy ball that explodes on impact
```

### 7. Rapid Behavior
**Example Weapons**: Laser Drill
- Reduces cooldown between attacks
- Controlled by cooldown_factor parameter

```gdscript
# Example rapid weapon in CSV
laser_drill,Laser Drill,staff,projectile,3,2.0,150,80,10,700,0.6,3,,,0,0,0,1,0,5,0,piercing:piercing=5;rapid:cooldown_factor=0.5,Rapid-fire laser that pierces multiple targets
```

## Complex Weapon Examples

### Cluster Bomb
The Cluster Bomb combines multiple behaviors:
- **Projectile Style**: Base attack method
- **Gravity Behavior**: Makes bombs arc downward
- **Multishot Behavior**: Creates 3 projectiles with spread
- **Explosive Behavior**: Creates explosions on impact

```gdscript
# Cluster Bomb in CSV
cluster_bomb,Cluster Bomb,staff,projectile,6,0.4,250,70,40,300,1.2,4,,,0,0,0.5,3,20,0,40,gravity:gravity_factor=0.5;multishot:projectile_count=3;projectile_spread=20;explosive:explosion_radius=40,Fires bombs that explode in a wide radius
```

### Multi Staff
The Multi Staff combines:
- **Projectile Style**: Base attack method
- **Multishot Behavior**: Creates 3 projectiles with spread
- **Homing Behavior**: Makes projectiles track targets

```gdscript
# Multi Staff in CSV
multi_staff,Multi Staff,staff,projectile,6,0.7,250,65,35,400,0.9,2,,,0,0.3,0,3,15,0,0,multishot:projectile_count=3;projectile_spread=15;homing:homing_strength=0.3,Staff that fires three arcing projectiles
```

### Singularity Bomb
The Singularity Bomb is one of the most complex weapons:
- **Singularity Style**: Creates a gravity well
- **Gravity Behavior**: Makes the projectile arc
- **Explosive Behavior**: Creates a large explosion

```gdscript
# Singularity Bomb in CSV
singularity_bomb,Singularity Bomb,staff,singularity,15,0.5,450,60,35,350,2.0,4,,,0,0.2,0.7,1,0,0,120,singularity:pull_strength=800.0;pull_radius=150.0;gravity:gravity_factor=0.7;explosive:explosion_radius=120,Creates a temporary gravitational singularity that pulls enemies in before exploding
```

## Adding New Weapons

To add a new weapon:

1. Add a row to the weapon CSV file with all required attributes
2. Ensure the weapon_style matches one of the registered styles
3. Specify behaviors in the behaviors column
4. Add any special parameters needed by the behaviors

For example, to add a new flamethrower weapon:

```
flamethrower,Flamethrower,staff,projectile,3,1.8,200,70,40,350,0.7,3,fire,,0,0,0,8,10,0,0,multishot:projectile_count=8;projectile_spread=10;rapid:cooldown_factor=0.3;fire,Rapid-fire weapon that spews flames in a wide arc
```

## Adding a New Attack Style

To add a new attack style:

1. Create a new script in the "attack styles" folder that extends Resource or attack_style_base.gd
2. Implement the following methods:
   - `initialize(weapon_ref)`: Set up the style with the weapon reference
   - `get_style_name()`: Return a string name for the style
   - `execute_attack()`: Perform the attack logic
3. Register the style in attack_style_manager.gd's _register_default_styles method

Example of a new attack style script:

```gdscript
# beam_attack_style.gd
extends Resource

var weapon = null
var wielder = null
const DEBUG = true

func initialize(weapon_ref):
    print("Beam style initialize called with weapon: ", weapon_ref.get_weapon_name() if weapon_ref else "None")
    weapon = weapon_ref
    if weapon:
        wielder = weapon.wielder
        print("Wielder set to: ", wielder.name if wielder else "None")

func get_style_name() -> String:
    return "BeamAttackStyle"

func execute_attack():
    print("BeamAttackStyle executing attack")
    
    if !wielder or !weapon:
        print("Missing wielder or weapon reference - cannot execute attack")
        return
    
    # Create a laser beam
    create_beam()
    
    # Apply visual effects
    weapon.apply_effects(null, "visual")

func create_beam():
    # Implementation details
    # ...
```

## Adding a New Behavior

To add a new behavior:

1. Create a new script in the "behaviors" folder that extends Behavior
2. Implement the following methods:
   - `_init_behavior()`: Set up the behavior
   - `get_behavior_name()`: Return a string name for the behavior
   - Implement relevant event callbacks (on_weapon_used, on_hit, etc.)
3. Register the behavior in behavior_manager.gd's _register_default_behaviors method

Example of a new behavior script:

```gdscript
# lightning_chain_behavior.gd
class_name LightningChainBehavior
extends Behavior

var chain_count = 3  # Default chain count
var chain_range = 100.0  # Default range

func _init_behavior():
    # Get parameters from configuration
    chain_count = int(get_param("chain_count", 3))
    chain_range = float(get_param("chain_range", 100.0))

func get_behavior_name() -> String:
    return "LightningChainBehavior"

func on_hit(target):
    # Find nearby targets to chain to
    var nearby_targets = find_nearby_targets(target, chain_range)
    
    # Apply chain lightning effect
    var remaining_chains = chain_count
    var last_target = target
    
    for next_target in nearby_targets:
        if remaining_chains <= 0:
            break
            
        if next_target != target and next_target != wielder:
            # Apply damage to the next target
            var damage = weapon.calculate_damage() * 0.7  # Reduced damage for chain targets
            next_target.take_damage(damage, Vector2.ZERO, 0)
            
            # Create visual lightning effect between targets
            create_lightning_effect(last_target, next_target)
            
            last_target = next_target
            remaining_chains -= 1

# Helper functions
func find_nearby_targets(origin_target, max_range):
    # Implementation details
    # ...
```

## Troubleshooting

If a weapon isn't working as expected:

1. **Check the CSV data**:
   - Ensure all required fields are present
   - Verify weapon_style matches a registered style

2. **Debug the attack style**:
   - Add print statements in execute_attack method
   - Verify the style is being created and initialized

3. **Debug the behaviors**:
   - Check if behaviors are being loaded
   - Verify behavior callbacks are being triggered

4. **Check collision settings**:
   - Ensure projectiles have the correct collision mask
   - Verify collision callbacks are connected

5. **Common Issues**:
   - **Projectiles not firing**: Check weapon_style and attack style initialization
   - **Projectiles not moving**: Verify velocity and direction settings
   - **No damage applied**: Check collision masks and damage application
   - **Behaviors not applying**: Ensure behaviors are correctly formatted in CSV
   - **Multiple projectiles not working**: Verify multishot behavior and projectile creation

## Weapon Balancing

The current weapon stats range as follows:

- **Damage**: 3-20
- **Attack Speed**: 0.3-2.0 attacks per second
- **Knockback**: 150-1500
- **Projectile Speed**: 300-800
- **Tier**: 0-4 (Common to Legendary)

When balancing new weapons, consider:

1. **Tier Level**: Higher tier weapons should be more powerful
2. **Damage vs Speed**: High damage usually comes with lower attack speed
3. **Special Effects**: Weapons with powerful behaviors should have lower base stats
4. **Range Advantages**: Long-range weapons typically have lower damage
5. **AOE Tradeoffs**: Area-effect weapons usually have longer cooldowns

## Full Weapon List

Here's a summary of all current weapons:

| Weapon | Type | Style | Tier | Key Features |
|--------|------|-------|------|-------------|
| Sword | sword | melee | 0 | Basic melee weapon |
| Magic Staff | staff | projectile | 0 | Basic projectile weapon |
| Great Sword | sword | melee | 1 | High damage, slow speed |
| Fire Staff | staff | projectile | 1 | Fire damage projectiles |
| Wave Wand | staff | wave | 2 | Wave-pattern projectile |
| Pull Blade | sword | pull | 2 | Pulls enemies closer |
| Blast Hammer | sword | area | 3 | Area explosion damage |
| Bounce Orb | staff | projectile | 2 | Bouncing projectiles |
| Homing Missile | staff | projectile | 2 | Tracks enemies |
| Gravity Bomb | staff | projectile | 3 | Arcing explosive projectile |
| Shotgun | sword | projectile | 3 | Multiple spread projectiles |
| Multi Staff | staff | projectile | 2 | Three homing projectiles |
| Piercing Lance | staff | projectile | 3 | Passes through multiple enemies |
| Plasma Ball | staff | projectile | 3 | Homing explosive projectile |
| Sniper Bow | staff | projectile | 4 | High damage piercing projectile |
| Cluster Bomb | staff | projectile | 4 | Multiple arcing explosives |
| Laser Drill | staff | projectile | 3 | Rapid-fire piercing beam |
| Singularity Bomb | staff | singularity | 4 | Creates gravity well that explodes |

This document provides a comprehensive overview of the Smash Dungeon weapon system. By following these guidelines, you can modify existing weapons or add new ones with unique behaviors and attack patterns.
