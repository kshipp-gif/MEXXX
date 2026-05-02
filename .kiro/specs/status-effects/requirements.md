# Requirements Document

## Introduction

This document covers the Status Effect system for MEXXX. A status effect is a temporary condition applied to a unit (Mech or Enemy) that modifies its behaviour for a defined duration. Status effects are applied by Card Effects and removed automatically when their duration expires. The initial set of status effects is: **Pinned** (prevents movement), **Brittle** (halves Block gains), and **Vulnerable** (increases damage received by 25%). The system is designed to be extensible so that new status effects can be added as new Component resources without modifying existing code.

---

## Glossary

- **Status_Effect**: A temporary condition attached to a unit that modifies its behaviour for a fixed duration measured in turns.
- **StatusEffectManager**: The Component responsible for storing, ticking, and removing Status_Effects on a single unit.
- **Stack**: One application of a Status_Effect. Each stack adds to the duration of the effect. Applying a Status_Effect that is already active adds the new duration to the remaining duration rather than replacing it.
- **Pinned**: A Status_Effect that prevents the affected unit from moving for the duration of the effect.
- **Brittle**: A Status_Effect that halves all Block gains received by the affected unit for the duration of the effect.
- **Vulnerable**: A Status_Effect that causes the affected unit to receive 1.25× damage from all sources for the duration of the effect.
- **Block**: A temporary damage-absorbing value that reduces incoming damage before HP is affected. Block is gained by playing certain Cards and is consumed when the unit takes damage.
- **Duration**: The number of turns remaining before a Status_Effect expires. Duration is decremented once at the start of the affected unit's turn.
- **ApplyStatusEffect**: An Effect subclass that applies a named Status_Effect to a target unit when a Card is played.
- **GainBlockEffect**: An Effect subclass that grants a fixed amount of Block to a target unit when a Card is played.
- **Unit**: Either the Mech or an Enemy node — any node that can have a StatusEffectManager attached.

---

## Requirements

### Requirement 1: Status Effect Data Model

**User Story:** As a designer, I want each status effect to be a self-contained data resource with a name and duration, so that new status effects can be authored in the Godot editor without writing new code for each one.

#### Acceptance Criteria

1. THE Status_Effect SHALL be implemented as a `Resource` subclass that stores: a `status_name` (String identifier), and a `duration` (integer number of turns remaining, ≥ 1).
2. THE Status_Effect SHALL expose an `apply(unit: Node) -> void` method that activates the effect's modifier on the target unit.
3. THE Status_Effect SHALL expose a `remove(unit: Node) -> void` method that reverses the effect's modifier on the target unit.
4. THE Status_Effect SHALL expose a `tick() -> void` method that decrements `duration` by 1.
5. WHEN `duration` reaches 0, THE Status_Effect SHALL be considered expired.
6. THE Status_Effect SHALL NOT encode removal logic in the StatusEffectManager; each Status_Effect subclass SHALL be responsible for reversing its own modifications in `remove()`.

---

### Requirement 2: Status Effect Manager Component

**User Story:** As a developer, I want a reusable Component that manages all status effects on a single unit, so that both the Mech and Enemy nodes can support status effects without duplicating logic.

#### Acceptance Criteria

1. THE StatusEffectManager SHALL be implemented as a Node script that can be attached to any unit node (Mech or Enemy).
2. THE StatusEffectManager SHALL maintain an internal list of active Status_Effects on its host unit.
3. THE StatusEffectManager SHALL expose an `add_effect(effect: StatusEffect) -> void` method that appends a new Status_Effect to the active list and calls `effect.apply(host)`.
4. WHEN `add_effect` is called with a `status_name` that already exists in the active list, THE StatusEffectManager SHALL add the new effect's `duration` to the existing effect's remaining `duration` rather than replacing it or stacking a second instance, and SHALL NOT call `apply` again.
5. THE StatusEffectManager SHALL expose a `tick_effects() -> void` method that calls `tick()` on every active Status_Effect, then removes and calls `remove(host)` on any effect whose `duration` has reached 0.
6. THE StatusEffectManager SHALL expose a `has_effect(status_name: String) -> bool` method that returns true if a Status_Effect with that name is currently active.
7. THE StatusEffectManager SHALL expose a `get_active_effects() -> Array` method that returns a copy of the current active effect list.
8. WHEN a Status_Effect is removed (expired or replaced), THE StatusEffectManager SHALL emit a `status_effect_removed` event on the EventBus with payload `{ "unit": host, "status_name": status_name }`.
9. WHEN a Status_Effect is applied, THE StatusEffectManager SHALL emit a `status_effect_applied` event on the EventBus with payload `{ "unit": host, "status_name": status_name, "duration": duration }`.

---

### Requirement 3: Turn-Based Duration Ticking

**User Story:** As a player, I want status effects to expire after the correct number of turns, so that temporary conditions feel fair and predictable.

#### Acceptance Criteria

1. WHEN a player turn begins, THE CombatTurnManager SHALL call `tick_effects()` on the Mech's StatusEffectManager before the player draws cards or takes any action.
2. WHEN an enemy turn begins, THE CombatTurnManager SHALL call `tick_effects()` on each Enemy's StatusEffectManager before that Enemy executes its behaviors.
3. THE duration tick SHALL occur at the start of the affected unit's own turn, so that a Status_Effect applied with `duration = 1` expires at the start of that unit's next turn, having been active for exactly one of the unit's turns.
4. IF a unit does not have a StatusEffectManager attached, THEN THE CombatTurnManager SHALL skip the tick step for that unit without error.

---

### Requirement 4: Pinned Status Effect

**User Story:** As a designer, I want a Pinned status effect that prevents a unit from moving, so that cards can create tactical positioning locks.

#### Acceptance Criteria

1. THE Pinned Status_Effect SHALL set a `is_pinned` flag to `true` on the target unit when applied.
2. WHILE a unit has the Pinned Status_Effect active, THE BattlefieldManager SHALL reject any move request from that unit and emit `move_rejected` with reason `"unit_pinned"`.
3. WHEN the Pinned Status_Effect expires or is removed, THE Pinned Status_Effect SHALL set the `is_pinned` flag to `false` on the target unit.
4. THE Pinned Status_Effect SHALL NOT prevent the unit from performing non-movement actions (playing cards, attacking).
5. WHEN the Mech is Pinned, THE APManager SHALL still allow AP to be spent on card plays; only movement AP expenditure SHALL be blocked.

---

### Requirement 5: Brittle Status Effect

**User Story:** As a designer, I want a Brittle status effect that reduces Block gains, so that cards can make enemies or the Mech more vulnerable to sustained damage.

#### Acceptance Criteria

1. THE Brittle Status_Effect SHALL set a `block_multiplier` property on the target unit to `0.5` when applied.
2. WHILE a unit has the Brittle Status_Effect active, any Block gained by that unit SHALL be multiplied by `0.5` and rounded down to the nearest integer before being applied.
3. WHEN the Brittle Status_Effect expires or is removed, THE Brittle Status_Effect SHALL restore the `block_multiplier` property on the target unit to `1.0`.
4. IF a unit gains 0 Block after the Brittle multiplier is applied, THE unit SHALL receive 0 Block (not negative Block).
5. THE Brittle Status_Effect SHALL affect all sources of Block gain on the target unit, regardless of which card or effect provided the Block.

---

### Requirement 6: Vulnerable Status Effect

**User Story:** As a designer, I want a Vulnerable status effect that increases damage received, so that cards can set up burst damage combos or punish enemies for aggressive positioning.

#### Acceptance Criteria

1. THE Vulnerable Status_Effect SHALL set a `damage_multiplier` property on the target unit to `1.25` when applied.
2. WHILE a unit has the Vulnerable Status_Effect active, all incoming damage to that unit SHALL be multiplied by `1.25` and rounded to the nearest integer before being applied to the unit's HP.
3. WHEN the Vulnerable Status_Effect expires or is removed, THE Vulnerable Status_Effect SHALL restore the `damage_multiplier` property on the target unit to `1.0`.
4. THE Vulnerable multiplier SHALL be applied after armor reduction (i.e., the damage pipeline is: raw damage → subtract armor → multiply by `damage_multiplier` → apply to HP).
5. THE Vulnerable Status_Effect SHALL affect all damage sources: card effects, enemy attacks, and any other source that calls `take_damage()` on the unit.

---

### Requirement 8: Block System

**User Story:** As a player, I want to play Cards that grant Block so I can absorb incoming damage on the enemy's turn, making defensive positioning a meaningful choice.

#### Acceptance Criteria

1. EACH unit (Mech and Enemy) SHALL have a `block` property (integer, default 0) that represents the amount of incoming damage it can absorb before HP is reduced.
2. WHEN a unit takes damage, THE damage pipeline SHALL first subtract the unit's current `block` value from the incoming damage; any remaining damage after block is consumed SHALL be applied to HP.
3. WHEN block absorbs damage, THE unit's `block` value SHALL be reduced by the amount absorbed, to a minimum of 0.
4. WHEN a unit's `block` value is greater than or equal to the incoming damage, THE unit SHALL take 0 HP damage and `block` SHALL be reduced by the damage amount.
5. THE `GainBlockEffect` SHALL be implemented as an `Effect` subclass with an exported `amount: int` property that adds `amount` to the target unit's `block` value, modified by the unit's `block_multiplier` (floored, clamped to 0).
6. THE `block` value SHALL NOT carry over between combat encounters; it SHALL reset to 0 at the start of each combat.
7. THE `block` value SHALL NOT carry over between turns; it SHALL reset to 0 at the start of the unit's own turn (before effects tick).

---

### Requirement 9: ApplyStatusEffect Card Effect

**User Story:** As a designer, I want a card Effect that applies a status effect to a target unit, so that I can author cards that inflict Pinned, Brittle, or Vulnerable purely through data without writing new code.

#### Acceptance Criteria

1. THE ApplyStatusEffect SHALL be implemented as an `Effect` subclass with exported properties: `status_effect_resource: StatusEffect` (the Status_Effect resource to apply) and `target_type: String` (one of `"target"`, `"caster"`, `"all_enemies"`).
2. WHEN `execute(context)` is called, THE ApplyStatusEffect SHALL retrieve the appropriate unit(s) from the context dictionary based on `target_type` and call `StatusEffectManager.add_effect(status_effect_resource.duplicate())` on each unit's StatusEffectManager.
3. IF the target unit does not have a StatusEffectManager, THEN THE ApplyStatusEffect SHALL log a warning and skip that unit without raising an error.
4. THE ApplyStatusEffect SHALL call `status_effect_resource.duplicate()` before applying, so that each application creates an independent instance with its own `duration` counter.
5. WHEN `target_type` is `"all_enemies"`, THE ApplyStatusEffect SHALL retrieve the enemy list from `context["enemies"]` and apply the Status_Effect to every living enemy.

---

### Requirement 10: Extensibility

**User Story:** As a developer, I want to add new status effects without modifying any existing Component, so that the system remains open for extension as new effects are designed.

#### Acceptance Criteria

1. WHEN a new Status_Effect type is needed, a developer SHALL be able to create it by subclassing `StatusEffect` and implementing `apply()`, `remove()`, and `tick()` without modifying THE StatusEffectManager, THE CombatTurnManager, or any existing Status_Effect subclass.
2. THE StatusEffectManager SHALL store Status_Effects as a generic `Array` and SHALL NOT contain any hard-coded conditionals that enumerate known status effect names.
3. THE CombatTurnManager SHALL invoke `tick_effects()` on StatusEffectManagers without any knowledge of which specific Status_Effect types are active.
4. THE ApplyStatusEffect SHALL apply any `StatusEffect` resource assigned to its `status_effect_resource` property without requiring code changes for new effect types.
5. THE EventBus events `status_effect_applied` and `status_effect_removed` SHALL carry the `status_name` string so that UI and other systems can react to any status effect by name without enumerating known types.
