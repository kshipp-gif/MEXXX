# Pattern System Documentation

## Overview

The Pattern system enables multi-tile card effects in MEXXX by defining reusable tile configurations. A Pattern is a Resource that stores a set of tile offsets relative to an origin tile. When a card effect is executed, the pattern's offsets are transformed into absolute battlefield positions, allowing effects to target multiple tiles simultaneously.

## Coordinate System

The Pattern system uses the same coordinate system as the BattlefieldManager:

- **X axis**: Increases rightward (valid range: 0 to 7)
- **Y axis**: Increases downward (valid range: 0 to 5)
- **Origin**: Top-left corner of the battlefield is (0, 0)

### Visual Representation

```
    0   1   2   3   4   5   6   7  (X axis →)
  ┌───┬───┬───┬───┬───┬───┬───┬───┐
0 │   │   │   │   │   │   │   │   │
  ├───┼───┼───┼───┼───┼───┼───┼───┤
1 │   │   │   │   │   │   │   │   │
  ├───┼───┼───┼───┼───┼───┼───┼───┤
2 │   │   │   │   │   │   │   │   │
  ├───┼───┼───┼───┼───┼───┼───┼───┤
3 │   │   │   │   │   │   │   │   │
  ├───┼───┼───┼───┼───┼───┼───┼───┤
4 │   │   │   │   │   │   │   │   │
  ├───┼───┼───┼───┼───┼───┼───┼───┤
5 │   │   │   │   │   │   │   │   │
  └───┴───┴───┴───┴───┴───┴───┴───┘
(Y axis ↓)
```

## Offset Resolution Formula

Absolute positions are calculated by adding each offset to the origin tile:

```
absolute_position = origin_tile + offset
```

**Example:**
- Origin tile: `(3, 2)`
- Offset: `(1, -1)`
- Absolute position: `(3 + 1, 2 + (-1))` = `(4, 1)`

### Multiple Offsets Example

Given a pattern with offsets `[(-1, 0), (0, 0), (1, 0)]` and origin tile `(3, 2)`:

```
Offset (-1, 0) → (3 + (-1), 2 + 0) = (2, 2)
Offset (0, 0)  → (3 + 0, 2 + 0)    = (3, 2)
Offset (1, 0)  → (3 + 1, 2 + 0)    = (4, 2)

Result: [(2, 2), (3, 2), (4, 2)]
```

## Preset Patterns

The system provides four preset patterns for common use cases. All presets are located in `components/patterns/presets/`.

### 1. Single Tile Pattern

**File:** `single_pattern.tres`

**Offsets:** `[(0, 0)]`

**Description:** Targets only the origin tile. Useful for single-target effects that need to use the multi-tile effect system.

**Visual Diagram:**
```
┌───┬───┬───┐
│   │   │   │
├───┼───┼───┤
│   │ X │   │  X = Origin/Target
├───┼───┼───┤
│   │   │   │
└───┴───┴───┘
```

**Usage Example:**
```gdscript
# Create a single-tile damage effect
var effect = MultiTileDamageEffect.new()
effect.pattern = preload("res://components/patterns/presets/single_pattern.tres")
effect.damage = 10
```

---

### 2. Horizontal Line Pattern

**File:** `line_pattern.tres`

**Offsets:** `[(-1, 0), (0, 0), (1, 0)]`

**Description:** A 3-tile horizontal line centered on the origin. Ideal for sweeping attacks or linear effects.

**Visual Diagram:**
```
┌───┬───┬───┬───┬───┐
│   │   │   │   │   │
├───┼───┼───┼───┼───┤
│   │ X │ X │ X │   │  X = Target tiles
├───┼───┼───┼───┼───┤     (middle X is origin)
│   │   │   │   │   │
└───┴───┴───┴───┴───┘
```

**Usage Example:**
```gdscript
# Create a horizontal slash attack
var effect = MultiTileDamageEffect.new()
effect.pattern = preload("res://components/patterns/presets/line_pattern.tres")
effect.damage = 15
```

**Melee Example:** If the player is at position `(3, 2)`, the line pattern targets tiles `(2, 2)`, `(3, 2)`, and `(4, 2)`.

**Ranged Example:** If the player selects tile `(5, 3)` as the origin, the pattern targets tiles `(4, 3)`, `(5, 3)`, and `(6, 3)`.

---

### 3. Cross Pattern

**File:** `cross_pattern.tres`

**Offsets:** `[(0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)]`

**Description:** A 5-tile cross (plus sign) centered on the origin. Covers the origin and all four cardinal directions.

**Visual Diagram:**
```
┌───┬───┬───┬───┬───┐
│   │   │ X │   │   │
├───┼───┼───┼───┼───┤
│   │ X │ X │ X │   │  X = Target tiles
├───┼───┼───┼───┼───┤     (center X is origin)
│   │   │ X │   │   │
└───┴───┴───┴───┴───┘
```

**Usage Example:**
```gdscript
# Create an explosive blast effect
var effect = MultiTileDamageEffect.new()
effect.pattern = preload("res://components/patterns/presets/cross_pattern.tres")
effect.damage = 20
```

**Melee Example:** If the player is at position `(3, 2)`, the cross pattern targets:
- Center: `(3, 2)`
- Left: `(2, 2)`
- Right: `(4, 2)`
- Up: `(3, 1)`
- Down: `(3, 3)`

---

### 4. Cone Pattern

**File:** `cone_pattern.tres`

**Offsets:** `[(0, 0), (1, 0), (2, 0), (1, -1), (1, 1), (2, -1), (2, 1), (2, -2), (2, 2)]`

**Description:** A 9-tile cone spreading rightward from the origin. Simulates a directional area effect like a flamethrower or shotgun blast.

**Visual Diagram:**
```
┌───┬───┬───┬───┬───┬───┬───┐
│   │   │   │   │ X │   │   │
├───┼───┼───┼───┼───┼───┼───┤
│   │   │   │ X │ X │   │   │
├───┼───┼───┼───┼───┼───┼───┤
│   │ X │ X │ X │ X │   │   │  X = Target tiles
├───┼───┼───┼───┼───┼───┼───┤     (leftmost X is origin)
│   │   │   │ X │ X │   │   │
├───┼───┼───┼───┼───┼───┼───┤
│   │   │   │   │ X │   │   │
└───┴───┴───┴───┴───┴───┴───┘
```

**Usage Example:**
```gdscript
# Create a cone-shaped flamethrower attack
var effect = MultiTileDamageEffect.new()
effect.pattern = preload("res://components/patterns/presets/cone_pattern.tres")
effect.damage = 12
```

**Melee Example:** If the player is at position `(1, 2)`, the cone spreads rightward, targeting tiles:
- Row 0: `(3, 0)`
- Row 1: `(2, 1)`, `(3, 1)`
- Row 2: `(1, 2)`, `(2, 2)`, `(3, 2)` (origin row)
- Row 3: `(2, 3)`, `(3, 3)`
- Row 4: `(3, 4)`

**Note:** The cone pattern is directional (points right). For other directions, you'll need to create rotated variants or implement pattern rotation logic.

---

## Creating Custom Patterns

You can create custom patterns directly in the Godot Inspector without writing code.

### Step-by-Step Guide

1. **Create a New Pattern Resource**
   - In the FileSystem panel, navigate to `components/patterns/presets/` (or your desired location)
   - Right-click and select **New Resource**
   - In the resource type dialog, search for `Pattern` and select it
   - Save the resource with a descriptive name (e.g., `my_custom_pattern.tres`)

2. **Edit Tile Offsets**
   - Select your new pattern resource in the FileSystem
   - In the Inspector panel, you'll see the `Tile Offsets` property
   - Click the array size field and set the number of tiles you want
   - For each tile, expand the array element and set the X and Y values

3. **Design Your Pattern**
   - Use the coordinate system reference (X rightward, Y downward)
   - The offset `(0, 0)` represents the origin tile
   - Negative X values target tiles to the left
   - Negative Y values target tiles above
   - Positive X values target tiles to the right
   - Positive Y values target tiles below

4. **Constraints**
   - Maximum 100 offsets per pattern
   - Each offset coordinate must be in range [-99, 99]
   - Duplicate offsets are allowed (though usually not needed)

### Custom Pattern Examples

#### L-Shape Pattern
```
Offsets: [(0, 0), (1, 0), (2, 0), (0, 1), (0, 2)]

Visual:
┌───┬───┬───┬───┐
│ X │ X │ X │   │
├───┼───┼───┼───┤
│ X │   │   │   │
├───┼───┼───┼───┤
│ X │   │   │   │
└───┴───┴───┴───┘
```

#### Diamond Pattern
```
Offsets: [(0, 0), (0, -1), (-1, 0), (1, 0), (0, 1)]

Visual:
┌───┬───┬───┐
│   │ X │   │
├───┼───┼───┤
│ X │ X │ X │
├───┼───┼───┤
│   │ X │   │
└───┴───┴───┘
```

#### 2x2 Square Pattern
```
Offsets: [(0, 0), (1, 0), (0, 1), (1, 1)]

Visual:
┌───┬───┬───┐
│ X │ X │   │
├───┼───┼───┤
│ X │ X │   │
├───┼───┼───┤
│   │   │   │
└───┴───┴───┘
```

#### Vertical Line Pattern
```
Offsets: [(0, -1), (0, 0), (0, 1)]

Visual:
┌───┬───┬───┐
│   │ X │   │
├───┼───┼───┤
│   │ X │   │
├───┼───┼───┤
│   │ X │   │
└───┴───┴───┘
```

---

## Using Patterns in Effects

### Basic Usage

```gdscript
# Load a preset pattern
var pattern = preload("res://components/patterns/presets/cross_pattern.tres")

# Create an effect that uses the pattern
var damage_effect = MultiTileDamageEffect.new()
damage_effect.pattern = pattern
damage_effect.damage = 25

# Add the effect to a card
var card = Card.new()
card.effects.append(damage_effect)
```

### Melee vs Ranged Behavior

The pattern's origin tile is determined by the source item's tags:

**Melee Items** (tagged "Melee"):
- Pattern automatically centers on the player's position
- No tile selection required
- Example: A sword with a cross pattern hits all adjacent tiles

**Ranged Items** (tagged "ranged"):
- Player selects a target tile within the card's range
- Pattern centers on the selected tile
- Example: A grenade launcher with a cross pattern creates an explosion at the target location

### Example: Creating a Melee Sweep Attack

```gdscript
# Create a broadsword item with melee tag
var broadsword = Item.new()
broadsword.tags = ["Melee"]

# Create a sweep attack card
var sweep_card = Card.new()
sweep_card.source_item = broadsword
sweep_card.ap_cost = 2

# Add a line pattern damage effect
var sweep_effect = MultiTileDamageEffect.new()
sweep_effect.pattern = preload("res://components/patterns/presets/line_pattern.tres")
sweep_effect.damage = 18

sweep_card.effects.append(sweep_effect)
```

When played, this card will damage all enemies in a horizontal line centered on the player.

### Example: Creating a Ranged Grenade

```gdscript
# Create a grenade launcher item with ranged tag
var grenade_launcher = Item.new()
grenade_launcher.tags = ["ranged"]

# Create a grenade card
var grenade_card = Card.new()
grenade_card.source_item = grenade_launcher
grenade_card.ap_cost = 3
grenade_card.range_value = 5

# Add a cross pattern explosion effect
var explosion_effect = MultiTileDamageEffect.new()
explosion_effect.pattern = preload("res://components/patterns/presets/cross_pattern.tres")
explosion_effect.damage = 30

grenade_card.effects.append(explosion_effect)
```

When played, the player selects a tile within 5 tiles of their position, and the explosion damages all enemies in a cross pattern centered on that tile.

---

## Advanced Topics

### Out-of-Bounds Handling

Patterns do not validate whether offsets result in valid battlefield positions. The Pattern resource will happily compute absolute positions that fall outside the battlefield bounds (x: 0-7, y: 0-5).

**Effect implementations are responsible for handling out-of-bounds tiles.** For example, `MultiTileDamageEffect` silently skips tiles that are outside the battlefield:

```gdscript
# This is handled automatically by MultiTileDamageEffect
if tile_position.x < 0 or tile_position.x >= battlefield_manager.grid_width:
    return  # Skip this tile
if tile_position.y < 0 or tile_position.y >= battlefield_manager.grid_height:
    return  # Skip this tile
```

**Example:** If the player is at position `(0, 2)` and uses a horizontal line pattern `[(-1, 0), (0, 0), (1, 0)]`, the pattern will compute tiles `(-1, 2)`, `(0, 2)`, and `(1, 2)`. The tile `(-1, 2)` is out of bounds and will be skipped by the effect.

### Unoccupied Tiles

Similarly, patterns do not check whether tiles are occupied by units. Effect implementations handle unoccupied tiles gracefully:

```gdscript
# MultiTileDamageEffect skips unoccupied tiles
var unit_node = battlefield_manager.get_unit_node_at(tile_position)
if unit_node == null:
    return  # No unit here, skip
```

### Duplicate Offsets

Patterns allow duplicate offsets in the `tile_offsets` array. This is generally not useful for damage effects (hitting the same tile twice), but could be relevant for custom effect types that accumulate or stack effects.

**Example:**
```gdscript
# Pattern with duplicate offset
var pattern = Pattern.new()
pattern.tile_offsets = [(0, 0), (0, 0), (1, 0)]

# If origin is (3, 2), get_absolute_positions returns:
# [(3, 2), (3, 2), (4, 2)]

# MultiTileDamageEffect will call apply_to_tile twice for (3, 2)
# This means the unit at (3, 2) takes damage twice
```

### Pattern Rotation

The current system does not support automatic pattern rotation. If you need a cone pattern pointing in different directions, you must create separate pattern resources for each direction:

- `cone_right_pattern.tres` — Points right (provided preset)
- `cone_left_pattern.tres` — Points left (mirror X offsets)
- `cone_up_pattern.tres` — Points up (swap and negate axes)
- `cone_down_pattern.tres` — Points down (swap axes)

**Example: Creating a Left-Pointing Cone**
```
Original (right): [(0, 0), (1, 0), (2, 0), (1, -1), (1, 1), (2, -1), (2, 1), (2, -2), (2, 2)]
Mirrored (left):  [(0, 0), (-1, 0), (-2, 0), (-1, -1), (-1, 1), (-2, -1), (-2, 1), (-2, -2), (-2, 2)]
```

---

## Technical Reference

### Pattern Class API

**Class:** `Pattern` (extends `Resource`)

**Properties:**
- `tile_offsets: Array[Vector2i]` — Array of relative tile positions (max 100 elements)

**Methods:**
- `get_absolute_positions(origin_tile: Vector2i) -> Array[Vector2i]`
  - Transforms relative offsets into absolute battlefield positions
  - Returns an empty array if `tile_offsets` is empty
  - Does not filter for battlefield bounds

**File Location:** `components/patterns/Pattern.gd`

### Coordinate System Summary

| Axis | Direction | Valid Range |
|------|-----------|-------------|
| X    | Rightward | 0 to 7      |
| Y    | Downward  | 0 to 5      |

**Offset Constraints:**
- Offset coordinates: -99 to 99 (enforced by Inspector)
- Maximum offsets per pattern: 100

**Battlefield Bounds:**
- Width: 8 tiles (x: 0-7)
- Height: 6 tiles (y: 0-5)

---

## Troubleshooting

### Pattern Not Affecting Expected Tiles

**Problem:** The pattern doesn't hit the tiles you expect.

**Solutions:**
1. Verify the coordinate system: X increases rightward, Y increases downward
2. Check the origin tile: For melee, it's the player's position; for ranged, it's the selected tile
3. Use the visual diagrams in this README to verify your offsets
4. Test with the single tile pattern first to confirm the origin is correct

### Pattern Hits Out-of-Bounds Tiles

**Problem:** The pattern computes tiles outside the battlefield.

**Solution:** This is expected behavior. Effects automatically skip out-of-bounds tiles. If you want to prevent the player from selecting an origin that would cause out-of-bounds tiles, you'll need to add custom validation logic.

### Effect Not Executing

**Problem:** The multi-tile effect doesn't seem to run.

**Solutions:**
1. Verify the pattern resource is assigned to the effect's `pattern` property
2. Check that the effect is added to the card's `effects` array
3. Ensure the card's source item has either "Melee" or "ranged" tag
4. For ranged effects, verify the tile selection UI is implemented and emitting events

### Duplicate Damage on Same Tile

**Problem:** A unit takes damage multiple times from one effect.

**Solution:** Check if your pattern has duplicate offsets. Remove duplicates unless this behavior is intentional.

---

## See Also

- **MultiTileEffect Base Class:** `components/effects/MultiTileEffect.gd`
- **MultiTileDamageEffect:** `components/effects/MultiTileDamageEffect.gd`
- **BattlefieldManager:** Manages unit positions and battlefield grid
- **Effect System:** Base effect architecture for card abilities

---

## Version History

- **v1.0** — Initial pattern system with four preset patterns (single, line, cross, cone)
