# Design Document: Status Effects

## Overview

The Status Effect system adds temporary, turn-counted conditions to units (Mech and Enemy). Each condition is a self-contained `StatusEffect` Resource that knows how to apply itself to a unit, reverse itself, and tick its own duration down. A `StatusEffectManager` Node component manages the active effects on a single unit. The initial set of effects is **Pinned** (blocks movement), **Brittle** (halves Block gains), and **Vulnerable** (increases damage received by 25%).

The design follows the same composition-over-inheritance and data-driven principles already established in the codebase:

- `StatusEffect` mirrors the `Passive` pattern — a `Resource` subclass with `apply()` / `remove()` — extended with a `tick()` method and a `duration` counter.
- `StatusEffectManager` mirrors the manager pattern — a `Node` script that can be attached to any unit without modifying the unit's own script.
- `ApplyStatusEffect` mirrors the `Effect` pattern — an `Effect` subclass that is fully data-driven and requires no code changes to author new cards.
- All cross-system communication goes through the existing `EventBus` autoload.

### Key Design Decisions

**StatusEffect extends Resource, not Passive.** Passives are permanent modifiers tied to equipped items. Status effects are temporary and need a `duration` counter and a `tick()` method. Sharing the `Passive` base class would conflate two distinct lifecycles. A separate `StatusEffect` base class keeps the distinction clear.

**Modifiers live on the unit as plain properties.** `is_pinned`, `block_multiplier`, and `damage_multiplier` are set directly on the unit node by `apply()` / `remove()`. This means `BattlefieldManager` and `take_damage()` can read them with a simple `unit.get("is_pinned")` check — no dependency on the status effect system at all.

**Duration ticking happens at the start of the affected unit's own turn.** This matches the requirements and is the most intuitive player-facing behaviour: an effect applied this turn is active for the rest of this turn and expires at the start of your next turn (if duration = 1).

**No stacking — additive duration on re-apply.** Re-applying an effect with the same `status_name` adds the new duration to the existing remaining duration rather than replacing it or creating a second instance. This means 1 stack of Pinned blocks movement for 1 turn, 2 stacks for 2 turns, and so on. This avoids multiplicative modifier bugs while giving the player meaningful stacking decisions.

---

## Architecture

### Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EventBus (Autoload)                     │
│   status_effect_applied / status_effect_removed / move_rejected │
└──────────────────────────┬──────────────────────────────────────┘
                           │
        ┌──────────────────┼──────────────────────┐
        │                  │                      │
┌───────▼──────────┐  ┌────▼────────────────┐  ┌─▼──────────────────┐
│ CombatTurnManager│  │  BattlefieldManager │  │  UI / other systems│
│ calls tick_effects│  │  checks is_pinned   │  │  listen to events  │
└───────┬──────────┘  └─────────────────────┘  └────────────────────┘
        │ tick_effects()
        ▼
┌──────────────────────────────────────────────────────────────────┐
│                    StatusEffectManager (Node)                    │
│  add_effect()  tick_effects()  has_effect()  get_active_effects()│
└──────────────────────────┬───────────────────────────────────────┘
                           │ apply() / remove() / tick()
                           ▼
┌──────────────────────────────────────────────────────────────────┐
│                    StatusEffect (Resource base)                  │
│  status_name: String   duration: int                             │
│  apply(unit)  remove(unit)  tick()                               │
├──────────────────┬───────────────────┬───────────────────────────┤
│  PinnedEffect    │  BrittleEffect    │  VulnerableEffect         │
│  is_pinned=true  │  block_mult=0.5   │  damage_mult=1.25         │
└──────────────────┴───────────────────┴───────────────────────────┘

┌──────────────────────────────────────────────────────────────────┐
│                  ApplyStatusEffect (Effect subclass)             │
│  status_effect_resource: StatusEffect   target_type: String      │
│  execute(context) → finds unit(s) → StatusEffectManager.add_effect│
└──────────────────────────────────────────────────────────────────┘
```

### Scene Integration

```
CombatScene (Node)
├── Mech (CharacterBody2D)
│   ├── SlotManager
│   ├── APManager
│   └── StatusEffectManager   ← NEW: attached as a child Node
├── CombatTurnManager         ← MODIFIED: calls tick_effects() at turn start
├── BattlefieldManager        ← MODIFIED: checks is_pinned before move
└── Enemies (Node)
    └── Enemy (Node2D)
        └── StatusEffectManager   ← NEW: attached as a child Node (optional)
```

### Turn Sequence with Status Effects

```
CombatTurnManager — player turn start:
  1. Find Mech's StatusEffectManager (if present)
  2. Call tick_effects()          ← NEW step before draw/AP reset
  3. Emit turn_started { owner: "player" }
     ← APManager.reset()
     ← HandManager draws cards

CombatTurnManager — enemy turn (per enemy):
  1. Find enemy's StatusEffectManager (if present)
  2. Call tick_effects()          ← NEW step before behaviors
  3. Execute enemy.behaviors in order
```

---

## Components and Interfaces

### StatusEffect (Resource base class)

```gdscript
# res://components/status_effects/StatusEffect.gd
extends Resource
class_name StatusEffect

## String identifier used for deduplication in StatusEffectManager.
@export var status_name: String = ""

## Number of turns remaining. Decremented by tick(). Effect expires when 0.
@export var duration: int = 1

## Activate this effect's modifier on the target unit.
## Subclasses set properties on the unit (e.g. unit.is_pinned = true).
func apply(unit: Node) -> void:
    pass

## Reverse this effect's modifier on the target unit.
## Subclasses restore the properties they set in apply().
func remove(unit: Node) -> void:
    pass

## Decrement duration by 1. Called by StatusEffectManager.tick_effects().
func tick() -> void:
    duration -= 1

## Returns true when the effect has expired.
func is_expired() -> bool:
    return duration <= 0
```

### StatusEffectManager (Node component)

```gdscript
# res://components/managers/StatusEffectManager.gd
extends Node
class_name StatusEffectManager

# The unit node this manager is attached to (set in _ready).
var _host: Node = null

# Active effects list — generic Array, no hard-coded type checks.
var _active_effects: Array = []

func _ready() -> void:
    _host = get_parent()

## Add a StatusEffect to the active list.
## If an effect with the same status_name already exists, ADD the new duration
## to the existing duration (do NOT call apply() again). Otherwise append and call apply().
func add_effect(effect: StatusEffect) -> void:
    for existing in _active_effects:
        if existing.status_name == effect.status_name:
            existing.duration += effect.duration
            EventBus.emit("status_effect_applied", {
                "unit": _host,
                "status_name": effect.status_name,
                "duration": existing.duration
            })
            return
    _active_effects.append(effect)
    effect.apply(_host)
    EventBus.emit("status_effect_applied", {
        "unit": _host,
        "status_name": effect.status_name,
        "duration": effect.duration
    })

## Tick all active effects; remove and call remove() on any that have expired.
func tick_effects() -> void:
    for effect in _active_effects.duplicate():
        effect.tick()
        if effect.is_expired():
            effect.remove(_host)
            _active_effects.erase(effect)
            EventBus.emit("status_effect_removed", {
                "unit": _host,
                "status_name": effect.status_name
            })

## Returns true if an effect with the given name is currently active.
func has_effect(status_name: String) -> bool:
    for effect in _active_effects:
        if effect.status_name == status_name:
            return true
    return false

## Returns a shallow copy of the active effects list.
## Callers may not modify the returned array to affect internal state.
func get_active_effects() -> Array:
    return _active_effects.duplicate()
```

### PinnedEffect (StatusEffect subclass)

```gdscript
# res://components/status_effects/PinnedEffect.gd
extends StatusEffect
class_name PinnedEffect

func _init() -> void:
    status_name = "pinned"

## Sets is_pinned = true on the unit.
func apply(unit: Node) -> void:
    unit.set("is_pinned", true)

## Restores is_pinned = false on the unit.
func remove(unit: Node) -> void:
    unit.set("is_pinned", false)
```

### BrittleEffect (StatusEffect subclass)

```gdscript
# res://components/status_effects/BrittleEffect.gd
extends StatusEffect
class_name BrittleEffect

func _init() -> void:
    status_name = "brittle"

## Sets block_multiplier = 0.5 on the unit.
func apply(unit: Node) -> void:
    unit.set("block_multiplier", 0.5)

## Restores block_multiplier = 1.0 on the unit.
func remove(unit: Node) -> void:
    unit.set("block_multiplier", 1.0)
```

### VulnerableEffect (StatusEffect subclass)

```gdscript
# res://components/status_effects/VulnerableEffect.gd
extends StatusEffect
class_name VulnerableEffect

func _init() -> void:
    status_name = "vulnerable"

## Sets damage_multiplier = 1.25 on the unit.
func apply(unit: Node) -> void:
    unit.set("damage_multiplier", 1.25)

## Restores damage_multiplier = 1.0 on the unit.
func remove(unit: Node) -> void:
    unit.set("damage_multiplier", 1.0)
```

### ApplyStatusEffect (Effect subclass)

```gdscript
# res://components/effects/ApplyStatusEffect.gd
extends Effect
class_name ApplyStatusEffect

## The StatusEffect resource to apply. Will be duplicated before each application.
@export var status_effect_resource: StatusEffect = null

## Who receives the effect: "target", "caster", or "all_enemies".
@export var target_type: String = "target"

func execute(context: Dictionary) -> void:
    if status_effect_resource == null:
        push_warning("ApplyStatusEffect: status_effect_resource is null")
        return

    var targets: Array = _resolve_targets(context)
    for unit in targets:
        var mgr = _get_manager(unit)
        if mgr == null:
            push_warning("ApplyStatusEffect: unit %s has no StatusEffectManager" % str(unit))
            continue
        mgr.add_effect(status_effect_resource.duplicate())

func _resolve_targets(context: Dictionary) -> Array:
    match target_type:
        "target":
            var t = context.get("target")
            return [t] if t != null else []
        "caster":
            var c = context.get("caster")
            return [c] if c != null else []
        "all_enemies":
            var enemies = context.get("enemies", [])
            return enemies.filter(func(e): return e.has_method("is_alive") and e.is_alive())
        _:
            push_warning("ApplyStatusEffect: unknown target_type '%s'" % target_type)
            return []

func _get_manager(unit: Node) -> StatusEffectManager:
    for child in unit.get_children():
        if child is StatusEffectManager:
            return child
    return null
```

### BattlefieldManager — Pinned check

The existing `move_unit()` method gains one guard at the top:

```gdscript
func move_unit(unit_id: StringName, dest: Vector2i) -> bool:
    # NEW: reject move if the unit is pinned
    var unit = _get_unit_node(unit_id)   # helper that looks up the node by id
    if unit != null and unit.get("is_pinned") == true:
        EventBus.emit("move_rejected", {
            "from": _positions.get(unit_id, Vector2i(-1, -1)),
            "to": dest,
            "reason": "unit_pinned"
        })
        return false
    # ... existing bounds and occupancy checks ...
```

`_get_unit_node` is a small helper that maps `unit_id` to the actual node. The simplest implementation stores a `unit_id -> Node` dictionary populated by `place_unit()`.

### CombatTurnManager — tick integration

Two small additions to the existing turn sequence:

```gdscript
# At the start of the player turn (before emitting turn_started):
func _tick_unit_effects(unit: Node) -> void:
    if unit == null:
        return
    for child in unit.get_children():
        if child is StatusEffectManager:
            child.tick_effects()
            return

# In start_combat / loop-back to player turn:
_tick_unit_effects(mech)
EventBus.emit("turn_started", { "owner": "player" })

# In _process_enemy_turn(), before executing behaviors:
for enemy in enemies:
    if not enemy.is_alive():
        continue
    _tick_unit_effects(enemy)
    # ... existing behavior loop ...
```

### Mech and Enemy — new properties

Both unit scripts need the four modifier properties added (with defaults that represent "no effect active"):

```gdscript
# In Mech.gd
var is_pinned: bool = false
var block_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var block: int = 0

# Updated take_damage() — block absorbs first, then armor, then damage_multiplier:
func take_damage(amount: int) -> void:
    # Block absorbs first
    var absorbed: int = min(block, amount)
    block -= absorbed
    amount -= absorbed
    if amount <= 0:
        return
    # Armor reduction, then Vulnerable multiplier (round to nearest)
    var effective: int = max(0, amount - armor_bonus)
    effective = roundi(effective * damage_multiplier)
    current_hp = max(0, current_hp - effective)

# In Enemy.gd — same four properties and same take_damage() update
var is_pinned: bool = false
var block_multiplier: float = 1.0
var damage_multiplier: float = 1.0
var block: int = 0

func take_damage(amount: int) -> void:
    var absorbed: int = min(block, amount)
    block -= absorbed
    amount -= absorbed
    if amount <= 0:
        return
    var effective: int = roundi(amount * damage_multiplier)
    hp = max(0, hp - effective)
```

Note: Enemy does not have `armor_bonus` in the current implementation. If armor is added to enemies later, the pipeline order from Requirement 6.4 applies: `roundi((amount - armor) * damage_multiplier)`.

---

## Data Models

### StatusEffect Resource

| Field | Type | Default | Notes |
|---|---|---|---|
| `status_name` | `String` | `""` | Unique identifier; used for deduplication |
| `duration` | `int` | `1` | Turns remaining; must be ≥ 1 when applied |

### Unit modifier properties (added to Mech and Enemy)

| Property | Type | Default | Set by |
|---|---|---|---|
| `is_pinned` | `bool` | `false` | PinnedEffect.apply() / remove() |
| `block_multiplier` | `float` | `1.0` | BrittleEffect.apply() / remove() |
| `damage_multiplier` | `float` | `1.0` | VulnerableEffect.apply() / remove() |
| `block` | `int` | `0` | GainBlockEffect; consumed by take_damage() |

### EventBus events added by this feature

| Event name | Emitter | Payload keys |
|---|---|---|
| `status_effect_applied` | StatusEffectManager | `unit`, `status_name`, `duration` |
| `status_effect_removed` | StatusEffectManager | `unit`, `status_name` |
| `move_rejected` (extended) | BattlefieldManager | `from`, `to`, `reason: "unit_pinned"` |

### Block gain pipeline (Brittle)

Block is gained via `GainBlockEffect`. That effect reads `block_multiplier` from the target unit and floors the result:

```gdscript
# res://components/effects/GainBlockEffect.gd
extends Effect
class_name GainBlockEffect

@export var amount: int = 0

func execute(context: Dictionary) -> void:
    var unit = context.get("target")
    if unit == null:
        return
    var multiplier: float = unit.get("block_multiplier") if unit.get("block_multiplier") != null else 1.0
    var final_block: int = max(0, floori(amount * multiplier))
    unit.set("block", unit.get("block", 0) + final_block)
```

Block resets to 0 at the start of the unit's own turn (before effects tick), so it only absorbs damage during the opponent's turn.

### Damage pipeline (Vulnerable)

The full pipeline per Requirements 6.4 and 8.2 (block absorbs before armor and multiplier):

```
# 1. Block absorbs first
absorbed = min(unit.block, raw_damage)
unit.block -= absorbed
remaining = raw_damage - absorbed

# 2. Armor reduction (Mech only)
after_armor = max(0, remaining - armor_bonus)

# 3. Vulnerable multiplier — round to nearest
final_damage = roundi(after_armor * damage_multiplier)
hp -= max(0, final_damage)
```

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

---

### Property 1: apply() then remove() is a no-op on the unit

*For any* StatusEffect subclass and *for any* unit node, calling `apply(unit)` followed immediately by `remove(unit)` SHALL leave every property on the unit in exactly the state it was in before `apply()` was called.

**Validates: Requirements 1.3, 4.3, 5.3, 6.3**

---

### Property 2: tick() decrements duration by exactly 1

*For any* StatusEffect with any initial `duration` value `d ≥ 1`, calling `tick()` once SHALL result in `duration == d - 1`.

**Validates: Requirements 1.4, 1.5**

---

### Property 3: add_effect() registers the effect and calls apply()

*For any* StatusEffect added to a StatusEffectManager, the effect SHALL appear in `get_active_effects()` and the effect's modifier SHALL be active on the host unit immediately after `add_effect()` returns.

**Validates: Requirements 2.3**

---

### Property 4: Re-adding an effect with the same name adds to duration without stacking a second instance

*For any* StatusEffectManager and *for any* two StatusEffect instances sharing the same `status_name` with duration values `d1` and `d2`, adding the first then the second SHALL result in exactly one active effect with `duration == d1 + d2`, and `apply()` SHALL have been called exactly once.

**Validates: Requirements 2.4**

---

### Property 5: tick_effects() removes expired effects and keeps live ones

*For any* set of active StatusEffects with varying durations, after one call to `tick_effects()`, every effect that had `duration == 1` SHALL be absent from `get_active_effects()` and every effect that had `duration > 1` SHALL remain with its duration decremented by 1.

**Validates: Requirements 2.5, 3.3**

---

### Property 6: get_active_effects() returns a copy — mutations do not affect internal state

*For any* StatusEffectManager with any number of active effects, modifying the array returned by `get_active_effects()` (adding or removing elements) SHALL NOT change the result of a subsequent call to `get_active_effects()`.

**Validates: Requirements 2.7**

---

### Property 7: status_effect_applied is emitted for every add_effect() call

*For any* StatusEffect added via `add_effect()`, the EventBus SHALL have received exactly one `status_effect_applied` event with `status_name` matching the effect's `status_name`, `unit` matching the host, and `duration` matching the effect's duration.

**Validates: Requirements 2.9**

---

### Property 8: status_effect_removed is emitted for every expired effect

*For any* StatusEffect that expires during `tick_effects()`, the EventBus SHALL have received exactly one `status_effect_removed` event with `status_name` matching the effect's `status_name` and `unit` matching the host.

**Validates: Requirements 2.8**

---

### Property 9: Pinned unit's move is always rejected

*For any* unit with `is_pinned == true` and *for any* destination tile, `BattlefieldManager.move_unit()` SHALL return `false` and emit `move_rejected` with `reason == "unit_pinned"`.

**Validates: Requirements 4.2**

---

### Property 10: Brittle block gain is always floor(raw * 0.5), clamped to 0

*For any* non-negative integer `raw_block` and a unit with `block_multiplier == 0.5`, the block actually applied to the unit SHALL equal `max(0, floor(raw_block * 0.5))`.

**Validates: Requirements 5.2, 5.4**

---

### Property 11: Vulnerable damage pipeline is roundi((raw - armor - block) * multiplier)

*For any* non-negative integers `raw_damage`, `armor_bonus`, and `block`, and `damage_multiplier == 1.25`, the HP reduction applied by `take_damage(raw_damage)` SHALL equal `roundi(max(0, raw_damage - block - armor_bonus) * 1.25)`, where block is consumed first, then armor is subtracted, then the multiplier is applied and rounded to nearest.

**Validates: Requirements 6.2, 6.4, 8.2**

---

### Property 14: Block absorbs damage before HP is reduced; block is consumed correctly

*For any* unit with `block == b` and incoming `damage == d`, after `take_damage(d)`:
- If `d <= b`: HP is unchanged and `block == b - d`.
- If `d > b`: `block == 0` and HP is reduced by `roundi((d - b - armor_bonus) * damage_multiplier)`.

**Validates: Requirements 8.2, 8.3, 8.4**

---

### Property 12: ApplyStatusEffect.duplicate() gives each target an independent instance

*For any* ApplyStatusEffect applied to two or more targets, modifying the `duration` of the effect on one target SHALL NOT affect the `duration` of the effect on any other target.

**Validates: Requirements 7.4**

---

### Property 13: ApplyStatusEffect with target_type "all_enemies" reaches every living enemy

*For any* list of enemies (mix of alive and dead), executing an ApplyStatusEffect with `target_type == "all_enemies"` SHALL result in every living enemy's StatusEffectManager receiving `add_effect()`, and no dead enemy's StatusEffectManager receiving `add_effect()`.

**Validates: Requirements 7.5**

---

## Error Handling

- **Unit has no StatusEffectManager** — `ApplyStatusEffect.execute()` logs a `push_warning` and skips the unit. No error is raised. `CombatTurnManager._tick_unit_effects()` iterates children and silently does nothing if no `StatusEffectManager` child is found.
- **status_effect_resource is null** — `ApplyStatusEffect.execute()` logs a `push_warning` and returns early.
- **Unknown target_type** — `ApplyStatusEffect._resolve_targets()` logs a `push_warning` and returns an empty array.
- **duration ≤ 0 on construction** — `StatusEffect` does not enforce this at the base class level; individual subclasses or the editor inspector should clamp `duration` to ≥ 1. `tick_effects()` calls `is_expired()` which checks `duration <= 0`, so a zero-duration effect added by mistake will be removed on the very next tick.
- **Re-applying an effect** — handled gracefully by the refresh-duration path in `add_effect()`; no double-apply, no error.
- **BattlefieldManager unit lookup fails** — if `_get_unit_node(unit_id)` returns null (unit not registered), the pinned check is skipped and the existing bounds/occupancy checks proceed normally.

---

## Testing Strategy

### Dual Testing Approach

Unit tests cover specific examples, edge cases, and error conditions. Property-based tests verify universal invariants across many generated inputs. Both are needed for comprehensive coverage.

### Property-Based Testing Library

Use **gdUnit4** (already the standard GDScript test framework for this project style) with a custom property-test harness, or use a lightweight PBT helper that generates random inputs and runs each property a minimum of **100 iterations**.

Tag format for each property test:
```
# Feature: status-effects, Property {N}: {property_text}
```

### Property Tests

Each of the 13 Correctness Properties above maps to one property-based test:

| Property | Test file | Generator inputs |
|---|---|---|
| P1: apply/remove round-trip | `test_status_effect_base.gd` | Random unit property states; all three effect subclasses |
| P2: tick decrements duration | `test_status_effect_base.gd` | Random `duration` values 1–20 |
| P3: add_effect registers and applies | `test_status_effect_manager.gd` | Random effect instances |
| P4: re-add refreshes duration | `test_status_effect_manager.gd` | Random `(d1, d2)` pairs, same status_name |
| P5: tick_effects removes expired | `test_status_effect_manager.gd` | Random arrays of effects with varying durations |
| P6: get_active_effects returns copy | `test_status_effect_manager.gd` | Random effect lists |
| P7: applied event emitted | `test_status_effect_manager.gd` | Random effects; mock EventBus listener |
| P8: removed event emitted | `test_status_effect_manager.gd` | Random effects with duration=1 |
| P9: pinned rejects all moves | `test_pinned_effect.gd` | Random destinations (in-bounds and out-of-bounds) |
| P10: brittle block calculation | `test_brittle_effect.gd` | Random non-negative block amounts |
| P11: vulnerable damage pipeline | `test_vulnerable_effect.gd` | Random `(raw_damage, armor_bonus)` pairs |
| P12: duplicate gives independent instances | `test_apply_status_effect.gd` | Random target counts (2–5) |
| P13: all_enemies reaches living only | `test_apply_status_effect.gd` | Random enemy lists with random alive/dead states |

### Unit Tests

Focus areas for example-based tests:

- **StatusEffect base**: `status_name` and `duration` fields are set correctly; `is_expired()` returns true when `duration == 0`.
- **PinnedEffect**: `apply()` sets `is_pinned = true`; `remove()` sets `is_pinned = false`.
- **BrittleEffect**: `apply()` sets `block_multiplier = 0.5`; `remove()` restores `1.0`.
- **VulnerableEffect**: `apply()` sets `damage_multiplier = 1.25`; `remove()` restores `1.0`.
- **StatusEffectManager**: `has_effect()` returns false for unknown names; `add_effect()` with null host does not crash.
- **ApplyStatusEffect**: `target_type = "target"` applies to context["target"]; `target_type = "caster"` applies to context["caster"]; missing StatusEffectManager logs warning without error; null `status_effect_resource` logs warning without error.
- **BattlefieldManager**: non-pinned unit can move normally; pinned unit is rejected; `is_pinned` flag is checked via `unit.get()` so it works for both Mech and Enemy.
- **CombatTurnManager**: unit without StatusEffectManager does not cause an error during tick step.
- **Mech.take_damage()**: with `damage_multiplier = 1.0` (baseline); with `damage_multiplier = 1.25` (Vulnerable); with `armor_bonus > 0` and `damage_multiplier = 1.25` (pipeline order).

### Integration Tests

- **Full effect lifecycle**: apply Vulnerable to Mech → deal damage → verify HP reduction is 1.25× → tick until expired → deal same damage → verify HP reduction is 1.0×.
- **Pinned + movement**: apply Pinned to Mech → attempt move → verify rejection → tick until expired → attempt same move → verify success.
- **Brittle + block**: apply Brittle to Enemy → grant block → verify block is halved → tick until expired → grant same block → verify full block.
- **CombatTurnManager integration**: start combat with effects active on Mech → end player turn → verify effects ticked; start next player turn → verify effects ticked again.
- **ApplyStatusEffect via card play**: create a Card with an ApplyStatusEffect → play it via HandManager → verify target has the effect active.

---

## File / Folder Structure

```
res://
└── components/
    ├── status_effects/           ← NEW folder
    │   ├── StatusEffect.gd       ← Base class (Resource)
    │   ├── PinnedEffect.gd       ← Subclass
    │   ├── BrittleEffect.gd      ← Subclass
    │   └── VulnerableEffect.gd   ← Subclass
    │
    ├── managers/
    │   └── StatusEffectManager.gd  ← NEW Node component
    │
    └── effects/
        ├── ApplyStatusEffect.gd    ← NEW Effect subclass
        └── GainBlockEffect.gd      ← NEW Effect subclass

nodes/
├── Mech.gd     ← MODIFIED: add is_pinned, block_multiplier, damage_multiplier; update take_damage()
└── Enemy.gd    ← MODIFIED: add is_pinned, block_multiplier, damage_multiplier; update take_damage()

components/managers/
├── BattlefieldManager.gd   ← MODIFIED: add is_pinned check in move_unit(); add unit node lookup
└── CombatTurnManager.gd    ← MODIFIED: add _tick_unit_effects() calls at turn start
```
