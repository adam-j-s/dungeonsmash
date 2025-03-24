How to adjust the cluster bomb's attributes to fine-tune its behaviour:

## Location of Code

The cluster bomb logic is in the `projectile_attack_style.gd` script, specifically in the `create_cluster_bomb()` function.

## Key Attributes to Adjust

### Basic Properties

- **Number of Bomblets**:
    
    gdscript
    
    Copy
    
    `var count = int(get_param("projectile_count", 3))`
    
    Change the default value (3) to create more or fewer bomblets.
- **Bomblet Size**:
    
    gdscript
    
    Copy
    
    `var sprite_size = Vector2(16, 16)`
    
    Adjust this to make bomblets larger or smaller.

### Movement Properties

- **Horizontal Spread**:
    
    gdscript
    
    Copy
    
    `var spread_factor = 30.0`
    
    Increase for wider spread, decrease for tighter grouping.
- **Vertical Offset**:
    
    gdscript
    
    Copy
    
    `bomblet.global_position.y -= i * 10`
    
    Adjusts the initial vertical separation between bomblets.
- **Base Speed**:
    
    gdscript
    
    Copy
    
    `var base_speed = float(get_param("projectile_speed", 300)) * 0.6`
    
    The 0.6 multiplier slows down the horizontal movement. Decrease for slower movement, increase for faster.

### Gravity Properties

- **Gravity Values**:
    
    gdscript
    
    Copy
    
    `var gravity_values = [0.8, 1.2, 0.6]`
    
    These control how quickly each bomblet falls. Higher values make bomblets fall faster.
- **Initial Vertical Velocity**:
    
    gdscript
    
    Copy
    
    `var vertical_velocity = -100 - vert_variation`
    
    The negative values create upward movement. Less negative values (like -50) mean less upward arc, more negative values (like -200) create higher arcs.
- **Vertical Variation**:
    
    gdscript
    
    Copy
    
    `var vert_variation = 40.0 * i`
    
    Creates differences in initial vertical velocity between bomblets.

### Timing Properties

- **Lifetime**:
    
    gdscript
    
    Copy
    
    `var lifetime = 2.0 + (i * 0.5)`
    
    How long each bomblet exists before automatically exploding. Increase for longer-lived bomblets.

### Visual Properties

- **Colors**:
    
    gdscript
    
    Copy
    
    `var hue_offset = i * 0.1 sprite.color = Color.from_hsv(0.1 + hue_offset, 0.9, 1.0)`
    
    Adjusts the color variations between bomblets.

## Common Adjustments

1. **For a more spread-out pattern**:
    - Increase `spread_factor` to 40-50
    - Increase the vertical offset (`i * 10` → `i * 20`)
2. **For less initial upward movement**:
    - Reduce the vertical velocity (change -100 to -50)
    - Reduce vert_variation (change 40.0 to 20.0)
3. **For slower falling bomblets**:
    - Reduce gravity values (change [0.8, 1.2, 0.6] to [0.4, 0.6, 0.3])
4. **For faster falling bomblets**:
    - Increase gravity values (change [0.8, 1.2, 0.6] to [1.2, 1.6, 1.0])
5. **For more bomblets**:
    - Change the default value in `get_param("projectile_count", 3)` to a higher number
    - You may need to adjust the spread factor if you add more bomblets

## Testing Tips

1. Change one parameter at a time to see its effect
2. Use `print()` statements to log values for debugging
3. If bomblets aren't visible, increase their size or lifetime
4. For dramatic effect, try adjusting explosion_radius as well