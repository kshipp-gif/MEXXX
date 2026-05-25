# Multi-Tile Card Effects - Quick Start Guide

## Overview

The multi-tile card effects system allows you to create area-of-effect card abilities that target multiple tiles simultaneously. This guide will help you get started quickly.

## Creating Your First Multi-Tile Card

### Step 1: Choose or Create a Pattern

**Option A: Use a Preset Pattern**

We provide 4 preset patterns ready to use:

- `res://components/patterns/presets/line_pattern.tres` - 3 tiles in a horizontal line
- `res://components/patterns/presets/cross_pattern.tres` - 5 tiles in a cross shape
- `res://components/patterns/presets/cone_pattern.tres` - 9 tiles in a cone shape
- `res://components/patterns/presets/single_pattern.tres` - 1 tile (for testing)

**Option B: Create a Custom Pattern**

1. In Godot, right-click in the FileSystem panel
2. Create → Resource
3. Select "Pattern" from the list
4. Save the resource (e.g., `my_pattern.tres`)
5. In the Inspector, expand "tile_offsets"
6. Click "Add Element" to add tile offsets
7. Enter Vector2i coordinates for each tile (e.g., `(0, 0)`, `(1, 0)`, `(-1, 0)`)

**Coordinate System**:
- X increases rightward (0 to 7)
- Y increases downward (0 to 5)
- (0, 0) is the origin tile (where the pattern centers)

### Step 2: Create a Multi-Tile Damage Effect

1. In Godot, right-click in the FileSystem panel
2. Create → Resource
3. Select "MultiTileDamageEffect" from the list
4. Save the resource (e.g., `my_aoe_damage.tres`)
5. In the Inspector:
   - Set "damage" to your desired damage amount (1-999)
   - Set "pattern" to your chosen pattern resource

### Step 3: Add the Effect to a Card

1. Open your Card resource in the Inspector
2. Expand the "effects" array
3. Click "Add Element"
4. Drag your MultiTileDamageEffect resource into the new slot

### Step 4: Configure the Source Item

**For Melee Cards** (pattern centers on player):
1. Open the Item resource (e.g., sword, axe)
2. In the Inspector, expand "tags"
3. Add "Melee" to the tags array

**For Ranged Cards** (player selects target tile):
1. Open the Item resource (e.g., bow, staff)
2. In the Inspector, expand "tags"
3. Add "ranged" to the tags array
4. Set the "range_value" property (e.g., 5 for 5 tiles)

### Step 5: Test Your Card

1. Run the game
2. Play the card
3. **Melee**: Pattern automatically centers on player position
4. **Ranged**: Select a target tile within range, pattern centers on selected tile
5. All enemies in the pattern take damage!

## Examples

### Example 1: Melee Sword Slash (3-tile line)

**Pattern**: `line_pattern.tres`
```
Offsets: [(-1, 0), (0, 0), (1, 0)]
Visual:  [X][X][X]
```

**Effect**: `sword_slash_effect.tres`
- damage: 10
- pattern: line_pattern.tres

**Item**: `broadsword.tres`
- tags: ["Melee"]

**Result**: When played, damages 3 tiles in a horizontal line centered on the player.

### Example 2: Ranged Fireball (cross pattern)

**Pattern**: `cross_pattern.tres`
```
Offsets: [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]
Visual:     [X]
         [X][X][X]
            [X]
```

**Effect**: `fireball_effect.tres`
- damage: 15
- pattern: cross_pattern.tres

**Item**: `fire_staff.tres`
- tags: ["ranged"]
- range_value: 5

**Result**: When played, player selects a tile within 5 tiles. Pattern centers on selected tile, damaging all enemies in the cross.

### Example 3: Ranged Cone Attack (cone pattern)

**Pattern**: `cone_pattern.tres`
```
Offsets: [(0, 0), (1, 0), (2, 0), (1, -1), (1, 1), (2, -1), (2, 1), (2, -2), (2, 2)]
Visual:         [X]
             [X][X][X]
          [X][X][X][X][X]
```

**Effect**: `cone_blast_effect.tres`
- damage: 8
- pattern: cone_pattern.tres

**Item**: `shotgun.tres`
- tags: ["ranged"]
- range_value: 3

**Result**: When played, player selects a tile within 3 tiles. Cone pattern centers on selected tile, damaging up to 9 enemies.

## Pattern Design Tips

### Coordinate System

The battlefield uses a grid coordinate system:
- **X-axis**: 0 (left) to 7 (right)
- **Y-axis**: 0 (top) to 5 (bottom)
- **Origin**: (0, 0) is always the center of the pattern

### Common Patterns

**Horizontal Line (3 tiles)**:
```
Offsets: [(-1, 0), (0, 0), (1, 0)]
[X][X][X]
```

**Vertical Line (3 tiles)**:
```
Offsets: [(0, -1), (0, 0), (0, 1)]
[X]
[X]
[X]
```

**Square (4 tiles)**:
```
Offsets: [(0, 0), (1, 0), (0, 1), (1, 1)]
[X][X]
[X][X]
```

**Large Cross (5 tiles)**:
```
Offsets: [(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]
   [X]
[X][X][X]
   [X]
```

**Diagonal (3 tiles)**:
```
Offsets: [(-1, -1), (0, 0), (1, 1)]
[X]
   [X]
      [X]
```

**L-Shape (3 tiles)**:
```
Offsets: [(0, 0), (1, 0), (0, 1)]
[X][X]
[X]
```

### Pattern Constraints

- Maximum 100 tile offsets per pattern
- Coordinates must be in range [-99, 99]
- Duplicate offsets are allowed (will hit the same tile multiple times)
- Out-of-bounds tiles are automatically skipped

## Advanced Usage

### Creating Custom Effect Types

You can extend `MultiTileEffect` to create new effect types beyond damage:

```gdscript
extends MultiTileEffect
class_name MultiTileHealEffect

@export_range(1, 999) var heal_amount: int = 5

func apply_to_tile(tile_position: Vector2i, context: Dictionary, battlefield_manager: Node) -> void:
    # Check bounds
    if tile_position.x < 0 or tile_position.x >= battlefield_manager.grid_width:
        return
    if tile_position.y < 0 or tile_position.y >= battlefield_manager.grid_height:
        return
    
    # Get unit at tile
    var unit_node: Node = battlefield_manager.get_unit_node_at(tile_position)
    if unit_node == null:
        return
    
    # Apply healing
    if unit_node.has_method("heal"):
        unit_node.heal(heal_amount)
```

### Combining Multiple Effects

You can add multiple effects to a single card:

```
Card Effects:
1. MultiTileDamageEffect (damage: 10, pattern: cross_pattern)
2. StatusEffect (apply: "burning", duration: 3)
3. SoundEffect (sound: "explosion.wav")
```

All effects execute in order when the card is played.

### Dynamic Patterns

While patterns are static resources, you can create multiple pattern variants and swap them at runtime:

```gdscript
# In your card logic
if player_level >= 5:
    effect.pattern = large_cone_pattern
else:
    effect.pattern = small_cone_pattern
```

## Troubleshooting

### Pattern doesn't appear where expected

**Problem**: Pattern centers on wrong tile  
**Solution**: Check if item has correct tag ("Melee" or "ranged")

**Problem**: Pattern is rotated wrong  
**Solution**: Patterns don't rotate. Create a new pattern with different offsets.

### Damage not applied

**Problem**: No damage dealt to enemies  
**Solution**: Check that enemies have a `take_damage(amount, caster)` method

**Problem**: Some tiles skipped  
**Solution**: Out-of-bounds tiles are automatically skipped. Check pattern offsets.

### Range validation fails

**Problem**: Can't select tiles within range  
**Solution**: Check that Item has `range_value` property set correctly

**Problem**: Range seems wrong  
**Solution**: Range uses Chebyshev distance (max of |dx| and |dy|)

## Next Steps

- Read the full documentation: `components/patterns/README.md`
- Review example cards in `resources/cards/`
- Check test files in `tests/` for more examples
- Experiment with custom patterns!

## Support

For more information, see:
- `components/patterns/README.md` - Full pattern system documentation
- `components/effects/MultiTileEffect.gd` - Base class documentation
- `components/effects/MultiTileDamageEffect.gd` - Damage effect documentation
- `tests/` - Test files with usage examples
