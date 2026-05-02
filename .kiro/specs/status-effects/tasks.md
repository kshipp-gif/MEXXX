# Implementation Plan: Status Effects

## Overview

Implement the Status Effect system for MEXXX in GDScript / Godot 4. The work proceeds in layers: base classes first, then the manager, then the three concrete effects, then integration into existing nodes (Mech, Enemy, BattlefieldManager, CombatTurnManager), and finally the ApplyStatusEffect card-effect subclass. Property-based tests are placed immediately after the code they validate so regressions are caught early.

All property tests live in `tests/`, follow the `@tool / extends EditorScript` pattern already established in the project, run a minimum of 100 iterations with randomly generated inputs, and carry the tag comment:
```
# Feature: status-effects, Property {N}: {property_text}
```

---

## Tasks

- [x] 1. Create StatusEffect base class
  - Create `components/status_effects/StatusEffect.gd` extending `Resource` with `class_name StatusEffect`
  - Add `@export var status_name: String = ""` and `@export var duration: int = 1`
  - Implement `apply(unit: Node) -> void` (no-op override point)
  - Implement `remove(unit: Node) -> void` (no-op override point)
  - Implement `tick() -> void` that decrements `duration` by 1
  - Implement `is_expired() -> bool` that returns `duration <= 0`
  - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 1.1 Write property test for tick() decrement (Property 2)
    - **Property 2: tick() decrements duration by exactly 1**
    - **Validates: Requirements 1.4, 1.5**
    - File: `tests/test_se_property_02_tick_decrement.gd`
    - Generator: random `duration` values in range 1–20; verify `duration == d - 1` after one `tick()` call
    - Tag: `# Feature: status-effects, Property 2: tick() decrements duration by exactly 1`

- [x] 2. Implement PinnedEffect, BrittleEffect, and VulnerableEffect subclasses
  - Create `components/status_effects/PinnedEffect.gd` extending `StatusEffect` with `class_name PinnedEffect`
    - `_init()` sets `status_name = "pinned"`
    - `apply(unit)` calls `unit.set("is_pinned", true)`
    - `remove(unit)` calls `unit.set("is_pinned", false)`
  - Create `components/status_effects/BrittleEffect.gd` extending `StatusEffect` with `class_name BrittleEffect`
    - `_init()` sets `status_name = "brittle"`
    - `apply(unit)` calls `unit.set("block_multiplier", 0.5)`
    - `remove(unit)` calls `unit.set("block_multiplier", 1.0)`
  - Create `components/status_effects/VulnerableEffect.gd` extending `StatusEffect` with `class_name VulnerableEffect`
    - `_init()` sets `status_name = "vulnerable"`
    - `apply(unit)` calls `unit.set("damage_multiplier", 1.25)`
    - `remove(unit)` calls `unit.set("damage_multiplier", 1.0)`
  - _Requirements: 4.1, 4.3, 5.1, 5.3, 6.1, 6.3_

  - [x] 2.1 Write property test for apply/remove round-trip across all three subclasses (Property 1)
    - **Property 1: apply() then remove() is a no-op on the unit**
    - **Validates: Requirements 1.3, 4.3, 5.3, 6.3**
    - File: `tests/test_se_property_01_apply_remove_roundtrip.gd`
    - Generator: plain `Node` mock with `is_pinned`, `block_multiplier`, `damage_multiplier` set to random baseline values; iterate all three effect subclasses; verify each property returns to its pre-apply value after `remove()`
    - Tag: `# Feature: status-effects, Property 1: apply() then remove() is a no-op on the unit`

- [x] 3. Implement StatusEffectManager
  - Create `components/managers/StatusEffectManager.gd` extending `Node` with `class_name StatusEffectManager`
  - Add `var _host: Node = null` and `var _active_effects: Array = []`
  - Implement `_ready()` that sets `_host = get_parent()`
  - Implement `add_effect(effect: StatusEffect) -> void`:
    - If an effect with the same `status_name` exists, replace its `duration` and emit `status_effect_applied`; do NOT call `apply()` again
    - Otherwise append, call `effect.apply(_host)`, and emit `status_effect_applied` with `{ "unit": _host, "status_name": effect.status_name, "duration": effect.duration }`
  - Implement `tick_effects() -> void`:
    - Iterate a duplicate of `_active_effects`; call `tick()` on each; if `is_expired()`, call `remove(_host)`, erase from list, emit `status_effect_removed` with `{ "unit": _host, "status_name": effect.status_name }`
  - Implement `has_effect(status_name: String) -> bool`
  - Implement `get_active_effects() -> Array` returning `_active_effects.duplicate()`
  - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5, 2.6, 2.7, 2.8, 2.9_

  - [x] 3.1 Write property test for add_effect() registers and applies (Property 3)
    - **Property 3: add_effect() registers the effect and calls apply()**
    - **Validates: Requirements 2.3**
    - File: `tests/test_se_property_03_add_effect_registers.gd`
    - Generator: random StatusEffect instances (vary `status_name` and `duration`); verify effect appears in `get_active_effects()` and modifier is active on host immediately after `add_effect()`
    - Tag: `# Feature: status-effects, Property 3: add_effect() registers the effect and calls apply()`

  - [x] 3.2 Write property test for re-add adds to duration without stacking (Property 4)
    - **Property 4: Re-adding an effect with the same name adds to duration without stacking a second instance**
    - **Validates: Requirements 2.4**
    - File: `tests/test_se_property_04_readd_adds_duration.gd`
    - Generator: random `(d1, d2)` pairs in range 1–10 with the same `status_name`; verify `get_active_effects().size() == 1` and `duration == d1 + d2` after second `add_effect()`; verify `apply()` was called exactly once (use a tracking subclass)
    - Tag: `# Feature: status-effects, Property 4: Re-adding an effect with the same name adds to duration without stacking a second instance`

  - [x] 3.3 Write property test for tick_effects() removes expired and keeps live effects (Property 5)
    - **Property 5: tick_effects() removes expired effects and keeps live ones**
    - **Validates: Requirements 2.5, 3.3**
    - File: `tests/test_se_property_05_tick_removes_expired.gd`
    - Generator: random arrays of 2–6 effects with varying durations (mix of `duration == 1` and `duration > 1`); after one `tick_effects()` call, verify effects with initial `duration == 1` are absent and effects with `duration > 1` remain with decremented duration
    - Tag: `# Feature: status-effects, Property 5: tick_effects() removes expired effects and keeps live ones`

  - [x] 3.4 Write property test for get_active_effects() returns a copy (Property 6)
    - **Property 6: get_active_effects() returns a copy — mutations do not affect internal state**
    - **Validates: Requirements 2.7**
    - File: `tests/test_se_property_06_get_active_effects_copy.gd`
    - Generator: random effect lists of size 1–5; mutate the returned array (append/erase); verify subsequent `get_active_effects()` call returns the original unmodified list
    - Tag: `# Feature: status-effects, Property 6: get_active_effects() returns a copy — mutations do not affect internal state`

  - [x] 3.5 Write property test for status_effect_applied event emission (Property 7)
    - **Property 7: status_effect_applied is emitted for every add_effect() call**
    - **Validates: Requirements 2.9**
    - File: `tests/test_se_property_07_applied_event_emitted.gd`
    - Generator: local EventBus instance; random effects; subscribe to `status_effect_applied`; verify exactly one event per `add_effect()` call with correct `status_name`, `unit`, and `duration` fields
    - Tag: `# Feature: status-effects, Property 7: status_effect_applied is emitted for every add_effect() call`

  - [x] 3.6 Write property test for status_effect_removed event emission (Property 8)
    - **Property 8: status_effect_removed is emitted for every expired effect**
    - **Validates: Requirements 2.8**
    - File: `tests/test_se_property_08_removed_event_emitted.gd`
    - Generator: local EventBus instance; effects with `duration = 1`; subscribe to `status_effect_removed`; call `tick_effects()`; verify exactly one `status_effect_removed` event per expired effect with correct `status_name` and `unit` fields
    - Tag: `# Feature: status-effects, Property 8: status_effect_removed is emitted for every expired effect`

- [x] 4. Checkpoint — verify base system tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Add is_pinned, block_multiplier, damage_multiplier, and block to Mech and update take_damage()
  - In `nodes/Mech.gd`, add:
    - `var is_pinned: bool = false`
    - `var block_multiplier: float = 1.0`
    - `var damage_multiplier: float = 1.0`
    - `var block: int = 0`
  - Update `take_damage(amount: int)` to apply block absorption first, then armor, then `damage_multiplier` (round to nearest):
    ```gdscript
    func take_damage(amount: int) -> void:
        var absorbed: int = min(block, amount)
        block -= absorbed
        amount -= absorbed
        if amount <= 0:
            return
        var effective: int = max(0, amount - armor_bonus)
        effective = roundi(effective * damage_multiplier)
        current_hp = max(0, current_hp - effective)
    ```
  - _Requirements: 6.1, 6.2, 6.4, 6.5, 8.1, 8.2, 8.3, 8.4_

- [x] 6. Add is_pinned, block_multiplier, damage_multiplier, and block to Enemy and update take_damage()
  - In `nodes/Enemy.gd`, add:
    - `var is_pinned: bool = false`
    - `var block_multiplier: float = 1.0`
    - `var damage_multiplier: float = 1.0`
    - `var block: int = 0`
  - Update `take_damage(amount: int)` to apply block absorption first, then `damage_multiplier` (round to nearest):
    ```gdscript
    func take_damage(amount: int) -> void:
        var absorbed: int = min(block, amount)
        block -= absorbed
        amount -= absorbed
        if amount <= 0:
            return
        var effective: int = roundi(amount * damage_multiplier)
        hp = max(0, hp - effective)
    ```
  - _Requirements: 6.1, 6.2, 6.4, 6.5, 8.1, 8.2, 8.3, 8.4_

  - [x] 6.1 Write property test for Vulnerable damage pipeline on Mech and Enemy (Property 11)
    - **Property 11: Vulnerable damage pipeline is roundi((raw - armor - block) * multiplier)**
    - **Validates: Requirements 6.2, 6.4, 8.2**
    - File: `tests/test_se_property_11_vulnerable_damage_pipeline.gd`
    - Generator: random `(raw_damage, armor_bonus, block)` triples in range 0–50; set `damage_multiplier = 1.25` on a mock unit; call `take_damage(raw_damage)`; verify HP reduction equals `roundi(max(0, raw_damage - block - armor_bonus) * 1.25)`; test both Mech (with `armor_bonus`) and Enemy (no armor)
    - Tag: `# Feature: status-effects, Property 11: Vulnerable damage pipeline is roundi((raw - armor - block) * multiplier)`

  - [x] 6.2 Write property test for block absorption (Property 14)
    - **Property 14: Block absorbs damage before HP is reduced; block is consumed correctly**
    - **Validates: Requirements 8.2, 8.3, 8.4**
    - File: `tests/test_se_property_14_block_absorption.gd`
    - Generator: random `(block, damage)` pairs; verify that when `damage <= block`, HP is unchanged and `block == block - damage`; when `damage > block`, `block == 0` and HP is reduced by the remainder
    - Tag: `# Feature: status-effects, Property 14: Block absorbs damage before HP is reduced; block is consumed correctly`

- [x] 7. Modify BattlefieldManager — add unit node lookup and is_pinned check in move_unit()
  - Add `var _unit_nodes: Dictionary = {}` to store `unit_id -> Node` mappings
  - Update `place_unit(unit_id, pos)` to also accept an optional `unit_node: Node = null` parameter and store it: `_unit_nodes[unit_id] = unit_node`
  - Add private helper `_get_unit_node(unit_id: StringName) -> Node` that returns `_unit_nodes.get(unit_id, null)`
  - At the top of `move_unit()`, before bounds/occupancy checks, add the pinned guard:
    ```gdscript
    var unit = _get_unit_node(unit_id)
    if unit != null and unit.get("is_pinned") == true:
        EventBus.emit("move_rejected", {
            "from": _positions.get(unit_id, Vector2i(-1, -1)),
            "to": dest,
            "reason": "unit_pinned"
        })
        return false
    ```
  - _Requirements: 4.2, 4.4_

  - [x] 7.1 Write property test for pinned unit move rejection (Property 9)
    - **Property 9: Pinned unit's move is always rejected**
    - **Validates: Requirements 4.2**
    - File: `tests/test_se_property_09_pinned_rejects_move.gd`
    - Generator: random destination tiles (both in-bounds and out-of-bounds); create a mock unit node with `is_pinned = true`; register it via `place_unit()`; verify `move_unit()` returns `false` and emits `move_rejected` with `reason == "unit_pinned"` for every destination
    - Tag: `# Feature: status-effects, Property 9: Pinned unit's move is always rejected`

- [x] 8. Modify CombatTurnManager — add _tick_unit_effects() and call it at turn start
  - Add private method `_tick_unit_effects(unit: Node) -> void`:
    - If `unit == null`, return immediately
    - Iterate `unit.get_children()`; if a child `is StatusEffectManager`, call `child.tick_effects()` and return
  - In `start_combat()`, call `_tick_unit_effects(mech)` before emitting `turn_started { "owner": "player" }`
  - In `_check_end_conditions()`, where the player turn loops back, call `_tick_unit_effects(mech)` before emitting `turn_started { "owner": "player" }`
  - In `_process_enemy_turn()`, inside the per-enemy loop (after the alive check, before executing behaviors), call `_tick_unit_effects(enemy)`
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 9. Implement GainBlockEffect and wire block reset into turn start
  - Create `components/effects/GainBlockEffect.gd` extending `Effect` with `class_name GainBlockEffect`
  - Add `@export var amount: int = 0`
  - Implement `execute(context: Dictionary) -> void`:
    - Retrieve `unit = context.get("target")`; if null, return
    - Read `multiplier: float = unit.get("block_multiplier") if unit.get("block_multiplier") != null else 1.0`
    - Compute `final_block: int = max(0, floori(amount * multiplier))`
    - Set `unit.set("block", unit.get("block", 0) + final_block)`
  - In `CombatTurnManager._tick_unit_effects()`, reset `block` to 0 on the unit **before** calling `tick_effects()`:
    ```gdscript
    func _tick_unit_effects(unit: Node) -> void:
        if unit == null:
            return
        unit.set("block", 0)   # block does not carry over between turns
        for child in unit.get_children():
            if child is StatusEffectManager:
                child.tick_effects()
                return
    ```
  - _Requirements: 8.1, 8.2, 8.5, 8.6, 8.7_

  - [x] 9.1 Write property test for Brittle block calculation (Property 10)
    - **Property 10: Brittle block gain is always floor(raw * 0.5), clamped to 0**
    - **Validates: Requirements 5.2, 5.4, 8.5**
    - File: `tests/test_se_property_10_brittle_block_calculation.gd`
    - Generator: random non-negative `raw_block` values in range 0–100; set `block_multiplier = 0.5` on a mock unit; execute `GainBlockEffect` with `amount = raw_block`; verify `unit.block == max(0, floori(raw_block * 0.5))`
    - Tag: `# Feature: status-effects, Property 10: Brittle block gain is always floor(raw * 0.5), clamped to 0`

- [x] 10. Checkpoint — verify unit and turn-manager integration tests pass
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Implement ApplyStatusEffect card effect
  - Create `components/effects/ApplyStatusEffect.gd` extending `Effect` with `class_name ApplyStatusEffect`
  - Add `@export var status_effect_resource: StatusEffect = null`
  - Add `@export var target_type: String = "target"` (valid values: `"target"`, `"caster"`, `"all_enemies"`)
  - Implement `execute(context: Dictionary) -> void`:
    - If `status_effect_resource == null`, call `push_warning(...)` and return
    - Call `_resolve_targets(context)` to get the target array
    - For each unit, call `_get_manager(unit)`; if null, `push_warning(...)` and continue; otherwise call `mgr.add_effect(status_effect_resource.duplicate())`
  - Implement `_resolve_targets(context: Dictionary) -> Array`:
    - `"target"`: return `[context.get("target")]` if not null, else `[]`
    - `"caster"`: return `[context.get("caster")]` if not null, else `[]`
    - `"all_enemies"`: filter `context.get("enemies", [])` to living enemies only (`e.has_method("is_alive") and e.is_alive()`)
    - default: `push_warning(...)` and return `[]`
  - Implement `_get_manager(unit: Node) -> StatusEffectManager`:
    - Iterate `unit.get_children()`; return first child that `is StatusEffectManager`; return `null` if none found
  - _Requirements: 7.1, 7.2, 7.3, 7.4, 7.5_

  - [x] 11.1 Write property test for duplicate() gives independent instances (Property 12)
    - **Property 12: ApplyStatusEffect.duplicate() gives each target an independent instance**
    - **Validates: Requirements 7.4**
    - File: `tests/test_se_property_12_duplicate_independent_instances.gd`
    - Generator: random target counts 2–5; execute ApplyStatusEffect against multiple mock units each with a StatusEffectManager; mutate `duration` on one target's active effect; verify other targets' durations are unchanged
    - Tag: `# Feature: status-effects, Property 12: ApplyStatusEffect.duplicate() gives each target an independent instance`

  - [x] 11.2 Write property test for all_enemies reaches every living enemy (Property 13)
    - **Property 13: ApplyStatusEffect with target_type "all_enemies" reaches every living enemy**
    - **Validates: Requirements 7.5**
    - File: `tests/test_se_property_13_all_enemies_living_only.gd`
    - Generator: random enemy lists of size 2–6 with random alive/dead states (at least one alive); verify every living enemy's StatusEffectManager received `add_effect()` and no dead enemy's StatusEffectManager received `add_effect()`; use a tracking StatusEffectManager subclass to count calls
    - Tag: `# Feature: status-effects, Property 13: ApplyStatusEffect with target_type "all_enemies" reaches every living enemy`

- [x] 12. Final checkpoint — ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

---

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests use the `@tool / extends EditorScript` pattern; run them via **File → Run** in the Godot editor script panel
- All property tests run a minimum of 100 iterations (`const ITERATIONS := 100`)
- **Stacking**: re-applying a status effect adds durations (d1 + d2), not replaces. 1 stack of Pinned = 1 turn, 2 stacks = 2 turns, etc.
- **Block**: resets to 0 at the start of each unit's own turn (before effects tick); does not carry over between turns or combats
- **Vulnerable rounding**: `roundi()` (round to nearest), not `ceili()` or `floori()`
- `place_unit()` signature change in Task 7 is backward-compatible — the `unit_node` parameter defaults to `null`, so existing call sites continue to work; the pinned check is simply skipped when no node is registered
