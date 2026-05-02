# Design Document: MEXXX Mech Deckbuilder Core Systems

## Overview

MEXXX is a turn-based deckbuilder built in Godot 4 / GDScript. The player pilots a customisable Mech across a square-tile Battlefield, defending a Base from waves of enemies. The Mech is assembled from Items equipped into five named Slots; each non-Head Item contributes a Set of Cards to the shared Deck. During combat the player spends Action Points (AP) to play Cards and move. Between encounters the player manages the Base, advances Seasons, and responds to Random Events that offer new Items.

The entire codebase follows **composition over inheritance**. Every behaviour is a discrete Component script (a `Resource` subclass or a `Node` script) that can be attached to any host node. Managers never call each other's methods directly; they communicate exclusively through the **EventBus** singleton or direct Godot signals. This makes every system independently replaceable and testable.

### Key Design Principles

- **Composition over inheritance** — no deep class hierarchies; behaviour is assembled from Components.
- **Data-driven** — Cards, Items, Effects, Passives, SlotRules, and EnemyBehaviors are all `Resource` subclasses editable in the Godot inspector.
- **Decoupled communication** — managers talk via EventBus (string-named signals + Dictionary payloads) or direct Godot signals; no cross-manager method calls.
- **Open/closed extensibility** — new Effect types, Passive types, SlotRules, EnemyBehaviors, Tags, and Random Events are added by creating new resources, not by modifying existing code.

---

## Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         EventBus (Autoload)                     │
│          emit(event_name, payload)  /  subscribe(event, cb)     │
└──────────────────────────┬──────────────────────────────────────┘
                           │  signals (string-named)
        ┌──────────────────┼──────────────────────┐
        │                  │                      │
┌───────▼──────┐  ┌────────▼───────┐  ┌──────────▼──────────┐
│  SlotManager │  │  DeckManager   │  │  CombatTurnManager  │
│  (Node)      │  │  (Node)        │  │  (Node)             │
└───────┬──────┘  └────────┬───────┘  └──────────┬──────────┘
        │                  │                      │
        │         ┌────────▼───────┐  ┌──────────▼──────────┐
        │         │  HandManager   │  │  BattlefieldManager │
        │         │  (Node)        │  │  (Node)             │
        │         └────────────────┘  └─────────────────────┘
        │
┌───────▼──────┐  ┌─────────────────┐  ┌────────────────────┐
│  APManager   │  │  BaseManager    │  │  Enemy nodes       │
│  (Node)      │  │  (Node)         │  │  + EnemyBehavior[] │
└──────────────┘  └─────────────────┘  └────────────────────┘
```

### Scene / Node Hierarchy

```
Main (Node)
├── EventBus          ← Autoload singleton
├── GameState         ← Holds player inventory, season, etc.
│
├── CombatScene (Node)
│   ├── Mech (CharacterBody2D)
│   │   ├── SlotManager
│   │   ├── APManager
│   │   └── [Passive components applied at runtime]
│   ├── DeckManager
│   ├── HandManager
│   ├── CombatTurnManager
│   ├── BattlefieldManager
│   └── Enemies (Node)
│       └── Enemy (Node2D)  [0..N]
│           └── EnemyBehavior resources (attached as metadata)
│
└── BaseScene (Node)
    └── BaseManager
```

### Communication Flow

All inter-manager communication uses one of two patterns:

1. **EventBus signals** — for cross-cutting events where the emitter does not know who listens (e.g., `slot_changed`, `hand_updated`, `ap_changed`).
2. **Direct Godot signals** — for tightly scoped parent→child or sibling relationships wired in the scene tree (e.g., `CombatTurnManager` connecting to `APManager.ap_changed`).

No manager holds a typed reference to another manager and calls its methods directly.

---

## Components and Interfaces

### EventBus

The EventBus is an Autoload singleton. It wraps Godot's signal system with a dynamic string-keyed dispatch layer so that new event names can be introduced without modifying the EventBus.

```gdscript
# res://autoload/EventBus.gd
extends Node

# Internal registry: event_name -> Array[Callable]
var _listeners: Dictionary = {}

## Subscribe a callable to a named event.
func subscribe(event_name: String, callable: Callable) -> void:
    if not _listeners.has(event_name):
        _listeners[event_name] = []
    _listeners[event_name].append(callable)

## Unsubscribe a callable from a named event.
func unsubscribe(event_name: String, callable: Callable) -> void:
    if _listeners.has(event_name):
        _listeners[event_name].erase(callable)

## Emit a named event with an arbitrary payload dictionary.
func emit(event_name: String, payload: Dictionary = {}) -> void:
    if not _listeners.has(event_name):
        return  # silently ignore unknown event names
    for cb in _listeners[event_name]:
        cb.call(payload)
```

**Key events emitted by each manager:**

| Event name            | Emitter              | Payload keys                              |
|-----------------------|----------------------|-------------------------------------------|
| `slot_changed`        | SlotManager          | `slot`, `item` (or null)                  |
| `equip_failed`        | SlotManager          | `slot`, `item`, `reason`                  |
| `hand_updated`        | DeckManager          | `hand`, `deck_size`, `discard_size`       |
| `card_played`         | HandManager          | `card`, `playable`                        |
| `ap_changed`          | APManager            | `current_ap`, `max_ap`                    |
| `action_rejected`     | APManager / BattlefieldManager | `reason`                        |
| `move_rejected`       | BattlefieldManager   | `from`, `to`, `reason`                    |
| `turn_started`        | CombatTurnManager    | `owner` (`"player"` or `"enemy"`)         |
| `combat_ended`        | CombatTurnManager    | `outcome` (`"victory"` or `"defeat"`)     |
| `enemy_action_taken`  | CombatTurnManager    | `enemy`, `action`                         |
| `ammo_changed`        | Item                 | `item_id`, `current_ammo`, `max_ammo`     |
| `base_health_changed` | BaseManager          | `current_hp`, `max_hp`                    |
| `season_advanced`     | BaseManager          | `season`                                  |

---

### SlotManager

Manages the Mech's five named Slots and enforces equip rules via a composable list of `SlotRule` resources.

```gdscript
# res://components/managers/SlotManager.gd
extends Node

const SLOT_NAMES := ["L_Arm", "R_Arm", "Legs", "Back", "Head"]

@export var slot_rules: Array[SlotRule] = []

# slot_name -> Item or null
var _slots: Dictionary = {
    "L_Arm": null, "R_Arm": null,
    "Legs": null,  "Back": null, "Head": null
}

## Attempt to equip an item into a slot.
func equip(slot: String, item: Item) -> bool

## Unequip the item from a slot.
func unequip(slot: String) -> void

## Return the item in a slot, or null.
func get_item(slot: String) -> Item

## Return a snapshot of all slots (used by SlotRules).
func get_slot_state() -> Dictionary
```

Equip flow:
1. Build `slot_state` snapshot.
2. Iterate `slot_rules`; call `rule.check(slot, item, slot_state)`.
3. If any rule returns `{ "permitted": false, "reason": "..." }`, emit `equip_failed` and return `false`.
4. Otherwise set `_slots[slot] = item`, emit `slot_changed`, return `true`.
5. For 2H items, also set `_slots["L_Arm"]` and `_slots["R_Arm"]` simultaneously.

---

### SlotRule (Resource Component)

```gdscript
# res://components/slot_rules/SlotRule.gd
extends Resource
class_name SlotRule

## Returns { "permitted": bool, "reason": String }
func check(slot: String, item: Item, slot_state: Dictionary) -> Dictionary:
    return { "permitted": true, "reason": "" }
```

Built-in SlotRule subclasses:

| Class                    | Enforces                                                    |
|--------------------------|-------------------------------------------------------------|
| `SlotOccupiedRule`       | Rejects equip if target slot is already occupied            |
| `TwoHandedExclusiveRule` | Rejects 2H equip if either Arm Slot is occupied; rejects 1H equip into an Arm Slot if a 2H item occupies both |
| `SlotTypeRule`           | Rejects equip if the item's `slot_type` does not match the target slot (Arm items → L_Arm/R_Arm only; Leg → Legs; Back → Back; Head → Head); emits `equip_failed` with reason `slot_type_mismatch` |

---

### DeckManager

Assembles, shuffles, and manages the three card collections (`deck`, `hand`, `discard_pile`).

```gdscript
# res://components/managers/DeckManager.gd
extends Node

var deck: Array[Card] = []
var hand: Array[Card] = []
var discard_pile: Array[Card] = []

## Build deck from all equipped non-Head sets; shuffle.
func build_deck(slot_manager: SlotManager) -> void

## Shuffle discard_pile into deck.
func recycle_discard() -> void

## Draw n cards from deck to hand; recycle if needed; emit hand_updated.
func draw(n: int) -> void

## Move a card from hand to discard_pile; emit hand_updated.
func discard_card(card: Card) -> void

## Move all hand cards to discard_pile; emit hand_updated.
func discard_hand() -> void

func deck_size() -> int
func hand_size() -> int
func discard_size() -> int
```

---

### HandManager

Tracks playability of cards in hand relative to current AP.

```gdscript
# res://components/managers/HandManager.gd
extends Node

## Called at turn start; requests draw from DeckManager via EventBus.
func on_turn_started(payload: Dictionary) -> void

## Attempt to play a card; checks AP and ammo; emits card_played.
func play_card(card: Card) -> bool

## Discard remaining hand at turn end.
func end_turn() -> void

## Returns cards in hand that are currently playable.
func get_playable_cards() -> Array[Card]
```

HandManager subscribes to `ap_changed` on the EventBus to refresh playability whenever AP changes.

---

### APManager

```gdscript
# res://components/managers/APManager.gd
extends Node

@export var max_ap: int = 4
var current_ap: int = 0

## Reset AP to max; emit ap_changed.
func reset() -> void

## Spend amount AP; emit ap_changed or action_rejected.
func spend(amount: int) -> bool

## Grant amount AP (capped at max); emit ap_changed.
func grant(amount: int) -> void
```

---

### BattlefieldManager

```gdscript
# res://components/managers/BattlefieldManager.gd
extends Node

@export var grid_width: int = 8
@export var grid_height: int = 6

# unit_id -> Vector2i
var _positions: Dictionary = {}

## Register a unit at a starting position.
func place_unit(unit_id: StringName, pos: Vector2i) -> void

## Attempt to move unit to dest; validate bounds + occupancy.
func move_unit(unit_id: StringName, dest: Vector2i) -> bool

## Return Chebyshev distance between two tile coords.
func tile_distance(a: Vector2i, b: Vector2i) -> int

## Validate that target is within card's range from caster position.
func validate_range(caster_id: StringName, target: Vector2i, range_val: int) -> bool

## Return position of a unit.
func get_position(unit_id: StringName) -> Vector2i

## Return true if tile is within bounds and unoccupied.
func is_tile_free(pos: Vector2i) -> bool
```

Chebyshev distance: `max(abs(a.x - b.x), abs(a.y - b.y))`.

---

### CombatTurnManager

Sequences player and enemy turns; checks end conditions after each action.

```gdscript
# res://components/managers/CombatTurnManager.gd
extends Node

enum TurnOwner { PLAYER, ENEMY }

var current_turn: TurnOwner = TurnOwner.PLAYER
var enemies: Array[Node] = []

## Start combat; emit turn_started for player.
func start_combat(enemy_nodes: Array[Node]) -> void

## Called when player presses "End Turn".
func end_player_turn() -> void

## Internal: process all enemy behaviors in sequence.
func _process_enemy_turn() -> void

## Check victory/defeat; emit combat_ended if met.
func _check_end_conditions() -> void
```

Turn sequence:
1. Emit `turn_started { owner: "player" }`.
2. EventBus → APManager resets AP.
3. EventBus → HandManager draws hand.
4. Player acts (plays cards, moves).
5. Player calls `end_player_turn()`.
6. EventBus → HandManager discards remaining hand.
7. Emit `turn_started { owner: "enemy" }`.
8. For each enemy: call each `EnemyBehavior.decide(context)` in order; emit `enemy_action_taken`.
9. Check end conditions.
10. Loop to step 1.

---

### BaseManager

```gdscript
# res://components/managers/BaseManager.gd
extends Node

@export var max_base_hp: int = 20
@export var seasons_per_combat: int = 4

var current_hp: int
var current_season: int = 0

## Advance season; trigger combat every seasons_per_combat.
func advance_season() -> void

## Generate random events for this season turn.
func generate_events() -> Array[RandomEvent]

## Apply the outcome of a chosen random event.
func apply_event_outcome(event: RandomEvent, choice_index: int) -> void

## Modify base HP; emit base_health_changed.
func modify_hp(delta: int) -> void
```

---

### EnemyBehavior (Resource Component)

```gdscript
# res://components/enemy_behaviors/EnemyBehavior.gd
extends Resource
class_name EnemyBehavior

## Execute this behavior for one enemy turn.
## context keys: "enemy", "mech", "battlefield_manager", "ap_manager", "event_bus"
func decide(context: Dictionary) -> void:
    pass  # override in subclasses
```

Built-in subclasses:

| Class                    | Behaviour                                              |
|--------------------------|--------------------------------------------------------|
| `MoveTowardBaseBehavior` | Moves enemy one tile toward the Base end each turn     |
| `AttackMechIfInRangeBehavior` | Attacks the Mech if within attack range           |
| `MoveAndAttackBehavior`  | Composite: move first, then attack if in range         |

---

## Data Models

### Item (Resource)

```gdscript
# res://data/Item.gd
extends Resource
class_name Item

@export var id: StringName = ""
@export var display_name: String = ""
@export var rarity: Rarity = Rarity.COMMON
@export var slot_type: SlotType = SlotType.ARM   # ARM | LEG | BACK | HEAD
@export var tags: Array[String] = []          # includes "1H" or "2H"
@export var passives: Array[Passive] = []     # empty for non-Head items
@export var card_set: CardSet = null          # null for Head items
@export var max_ammo: int = 0                 # 0 = not ammo-based
var current_ammo: int = 0

signal ammo_changed(item_id: StringName, current: int, maximum: int)

func has_tag(tag: String) -> bool:
    return tag in tags

func decrement_ammo() -> void:
    current_ammo = max(0, current_ammo - 1)
    ammo_changed.emit(id, current_ammo, max_ammo)

func reload_ammo() -> void:
    current_ammo = max_ammo
    ammo_changed.emit(id, current_ammo, max_ammo)
```

### Card (Resource)

```gdscript
# res://data/Card.gd
extends Resource
class_name Card

@export var display_name: String = ""
@export var ap_cost: int = 0
@export var card_type: CardType = CardType.UTILITY
@export var tags: Array[String] = []
@export var rarity: Rarity = Rarity.COMMON
@export var effects: Array[Effect] = []
@export var source_item: Item = null
@export var range_value: int = 0    # >0 only when has_tag("ranged")
@export var ammo_count: int = 0     # >0 only when has_tag("ammo")

func has_tag(tag: String) -> bool:
    return tag in tags
```

### CardSet (Resource)

```gdscript
# res://data/CardSet.gd
extends Resource
class_name CardSet

@export var cards: Array[Card] = []  # minimum 5 cards
```

### Effect (Resource Component)

```gdscript
# res://components/effects/Effect.gd
extends Resource
class_name Effect

## Execute this effect.
## context keys: "caster", "target", "battlefield_manager",
##               "ap_manager", "deck_manager", "event_bus"
func execute(context: Dictionary) -> void:
    pass  # override in subclasses
```

Built-in Effect subclasses (all exported properties configurable in editor):

| Class              | Exported properties          | Behaviour                              |
|--------------------|------------------------------|----------------------------------------|
| `DamageEffect`     | `amount: int`                | Deal damage to target unit             |
| `HealEffect`       | `amount: int`                | Restore HP to target unit              |
| `DrawEffect`       | `count: int`                 | Draw `count` cards from deck           |
| `GrantAPEffect`    | `amount: int`                | Grant AP via APManager                 |
| `MoveEffect`       | `tiles: int`                 | Move caster N tiles toward target      |
| `ReloadEffect`     | *(none)*                     | Restore ammo on source item            |
| `ApplyPassiveEffect` | `passive: Passive`         | Apply a passive to a target node       |

### Passive (Resource Component)

```gdscript
# res://components/passives/Passive.gd
extends Resource
class_name Passive

## Apply this passive to a target node.
func apply(target: Node) -> void:
    pass

## Remove this passive from a target node.
func remove(target: Node) -> void:
    pass
```

### RandomEvent (Resource)

```gdscript
# res://data/RandomEvent.gd
extends Resource
class_name RandomEvent

@export var description: String = ""
@export var choices: Array[EventChoice] = []
```

```gdscript
# res://data/EventChoice.gd
extends Resource
class_name EventChoice

@export var label: String = ""
@export var item_reward: Item = null   # null if no item reward
@export var outcome_script: GDScript = null  # optional custom outcome
```

### Enumerations

```gdscript
# res://data/Enums.gd  (or in a global autoload)

enum Rarity    { COMMON, UNCOMMON, RARE, LEGENDARY }
enum CardType  { ATTACK, DEFENSE, MOVEMENT, UTILITY, COMBO }
enum SlotType  { ARM, LEG, BACK, HEAD }
```

---

## Data Flow for Key Operations

### 1. Equipping an Item

```
Player UI
  → SlotManager.equip("R_Arm", sword_item)
      → build slot_state snapshot
      → for each SlotRule: rule.check("R_Arm", sword_item, slot_state)
          SlotTypeRule: sword_item.slot_type == ARM, "R_Arm" is an Arm slot → permitted
          SlotOccupiedRule: slot is empty → permitted
          TwoHandedExclusiveRule: item is 1H, no 2H in arms → permitted
      → _slots["R_Arm"] = sword_item
      → EventBus.emit("slot_changed", { slot: "R_Arm", item: sword_item })
          ← DeckManager hears slot_changed (if in combat, rebuilds deck)
          ← UI hears slot_changed (updates loadout display)
```

If the Head Slot item is being equipped:
```
      → _slots["Head"] = helm_item
      → EventBus.emit("slot_changed", { slot: "Head", item: helm_item })
          ← Mech node hears slot_changed
              → for passive in helm_item.passives: passive.apply(mech_node)
```

### 2. Playing a Card

```
Player UI
  → HandManager.play_card(fireball_card)
      → APManager.spend(fireball_card.ap_cost)
          → if insufficient: EventBus.emit("action_rejected", { reason: "insufficient_ap" }) → return false
          → current_ap -= cost; EventBus.emit("ap_changed", { current_ap, max_ap })
      → if card has "ammo" tag:
          → fireball_card.source_item.decrement_ammo()
          → if ammo == 0: mark card unplayable
      → for each effect in fireball_card.effects:
          → effect.execute(context)   # context carries all managers
      → DeckManager.discard_card(fireball_card)
          → EventBus.emit("hand_updated", { hand, deck_size, discard_size })
      → EventBus.emit("card_played", { card: fireball_card, playable: true })
      → CombatTurnManager._check_end_conditions()
```

### 3. Combat Turn Sequence

```
CombatTurnManager.start_combat(enemy_nodes)
  → current_turn = PLAYER
  → EventBus.emit("turn_started", { owner: "player" })
      ← APManager.reset()  → EventBus.emit("ap_changed", ...)
      ← HandManager.on_turn_started() → DeckManager.draw(hand_size)
            → if deck empty: DeckManager.recycle_discard()
            → EventBus.emit("hand_updated", ...)

  [Player acts: plays cards, moves mech]

CombatTurnManager.end_player_turn()
  → EventBus.emit("turn_started", { owner: "enemy" })
      ← HandManager.end_turn() → DeckManager.discard_hand()
  → _process_enemy_turn()
      → for each enemy in enemies:
          → context = { enemy, mech, battlefield_manager, ap_manager, event_bus }
          → for each behavior in enemy.behaviors:
              → behavior.decide(context)
          → EventBus.emit("enemy_action_taken", { enemy, action })
          → _check_end_conditions()
  → [if no end condition] loop back to player turn
```

### 4. Deck Recycling

```
DeckManager.draw(n)
  → while cards_to_draw > 0:
      → if deck is empty:
          → recycle_discard()
              → deck = discard_pile.duplicate()
              → deck.shuffle()
              → discard_pile.clear()
      → hand.append(deck.pop_back())
      → cards_to_draw -= 1
  → EventBus.emit("hand_updated", { hand, deck_size(), discard_size() })
```

---

## File / Folder Structure

```
res://
├── autoload/
│   ├── EventBus.gd              # Autoload singleton
│   └── GameState.gd             # Player inventory, season, run state
│
├── data/
│   ├── Card.gd
│   ├── CardSet.gd
│   ├── Item.gd
│   ├── RandomEvent.gd
│   ├── EventChoice.gd
│   └── Enums.gd
│
├── components/
│   ├── managers/
│   │   ├── SlotManager.gd
│   │   ├── DeckManager.gd
│   │   ├── HandManager.gd
│   │   ├── APManager.gd
│   │   ├── BattlefieldManager.gd
│   │   ├── CombatTurnManager.gd
│   │   └── BaseManager.gd
│   │
│   ├── effects/
│   │   ├── Effect.gd             # Base class
│   │   ├── DamageEffect.gd
│   │   ├── HealEffect.gd
│   │   ├── DrawEffect.gd
│   │   ├── GrantAPEffect.gd
│   │   ├── MoveEffect.gd
│   │   ├── ReloadEffect.gd
│   │   └── ApplyPassiveEffect.gd
│   │
│   ├── passives/
│   │   ├── Passive.gd            # Base class
│   │   ├── ArmorPassive.gd
│   │   └── RegenPassive.gd
│   │
│   ├── slot_rules/
│   │   ├── SlotRule.gd           # Base class
│   │   ├── SlotOccupiedRule.gd
│   │   ├── TwoHandedExclusiveRule.gd
│   │   └── SlotTypeRule.gd
│   │
│   └── enemy_behaviors/
│       ├── EnemyBehavior.gd      # Base class
│       ├── MoveTowardBaseBehavior.gd
│       ├── AttackMechIfInRangeBehavior.gd
│       └── MoveAndAttackBehavior.gd
│
├── scenes/
│   ├── Main.tscn
│   ├── CombatScene.tscn
│   └── BaseScene.tscn
│
├── nodes/
│   ├── Mech.gd / Mech.tscn
│   └── Enemy.gd / Enemy.tscn
│
└── resources/
    ├── items/                    # .tres files for each Item
    ├── cards/                    # .tres files for each Card
    ├── sets/                     # .tres files for each CardSet
    └── events/                   # .tres files for RandomEvents
```

---

## Design Patterns Used

| Pattern | Where applied |
|---------|---------------|
| **Component / Composition** | All managers, Effects, Passives, SlotRules, EnemyBehaviors are discrete scripts attached to nodes |
| **Observer / Event Bus** | EventBus singleton routes all cross-manager communication |
| **Strategy** | Effect.execute(), EnemyBehavior.decide(), SlotRule.check() — interchangeable algorithms behind a common interface |
| **Chain of Responsibility** | SlotManager iterates SlotRule list; first rejection wins |
| **Data Object** | Card, Item, CardSet, RandomEvent are pure data Resources with no behaviour beyond `has_tag()` |
| **Template Method** | Effect, Passive, EnemyBehavior, SlotRule base classes define the interface; subclasses fill in the logic |

---

## Error Handling

- **Equip failures** — SlotManager emits `equip_failed` with a `reason` string; UI listens and displays feedback. No exception is thrown.
- **Insufficient AP** — APManager emits `action_rejected { reason: "insufficient_ap" }`; HandManager and UI listen to block the action.
- **Out-of-range targeting** — BattlefieldManager emits `action_rejected { reason: "out_of_range" }` before any Effect executes.
- **Invalid move** — BattlefieldManager emits `move_rejected { from, to, reason }`.
- **Ammo depletion** — Item emits `ammo_changed`; HandManager marks affected cards unplayable; UI greys them out.
- **Empty deck draw** — DeckManager silently recycles discard pile before drawing; if both deck and discard are empty, draw stops early (hand may be smaller than requested size).
- **Unknown EventBus event** — EventBus silently ignores events with no subscribers; no error is raised.
- **Null slot query** — `SlotManager.get_item()` returns `null` for empty slots; callers must null-check before use.

---

## Testing Strategy

### Dual Testing Approach

Unit tests cover specific examples, edge cases, and error conditions. Property-based tests verify universal invariants across many generated inputs. Both are needed for comprehensive coverage.

### Unit Tests (GUT framework or gdUnit4)

Focus areas:
- SlotManager: equip/unequip with each SlotRule combination; 2H exclusivity; Head slot restrictions.
- DeckManager: deck assembly from slot state; shuffle produces all cards; draw/discard/recycle cycle.
- HandManager: playability filtering by AP; card play removes from hand; end-turn discards all.
- APManager: reset, spend, grant, cap at max, rejection on insufficient AP.
- BattlefieldManager: Chebyshev distance calculation; bounds checking; occupancy checking; range validation.
- CombatTurnManager: turn sequence ordering; end condition detection after each action.
- BaseManager: season advancement; combat trigger every 4 seasons; rarity-weighted item selection.
- Effect subclasses: each Effect's execute() produces the expected state change given a mock context.
- SlotRule subclasses: each rule returns the correct permitted/rejected result for boundary inputs.

### Property-Based Tests (Hypothesis-style via gdUnit4 or a custom PBT harness)

See Correctness Properties section below. Each property test runs a minimum of 100 iterations with randomly generated inputs.

Tag format for each property test:
`# Feature: mech-deckbuilder-core-systems, Property {N}: {property_text}`

### Integration Tests

- Full combat turn cycle: build deck → draw → play cards → end turn → enemy acts → check state.
- Equip → combat deck assembly: equip items → start combat → verify deck contains exactly the right cards.
- Passive apply/remove: equip Head item → verify passive applied; unequip → verify passive removed.
- Base phase: advance 4 seasons → verify combat triggered; random event item selection respects rarity weights.

---

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

---

### Property 1: Slot set is always exactly the five named slots

*For any* sequence of equip and unequip operations on the SlotManager, the set of slot names returned by `get_slot_state()` SHALL always equal exactly `{"L_Arm", "R_Arm", "Legs", "Back", "Head"}` — no more, no fewer.

**Validates: Requirements 1.1**

---

### Property 2: Equipping then querying a slot returns the same item (round-trip)

*For any* item equipped into any valid slot, calling `get_item(slot)` SHALL return that exact item, and calling `unequip(slot)` followed by `get_item(slot)` SHALL return `null`.

**Validates: Requirements 1.8, 1.9**

---

### Property 3: Occupied slot rejects any equip attempt

*For any* slot that already contains an item, attempting to equip any other item into that slot SHALL return `false` and emit `equip_failed` with reason `"slot_occupied"`, leaving the slot's contents unchanged.

**Validates: Requirements 1.3, 1.6**

---

### Property 4: 2H item occupies both arm slots; 2H equip fails if either arm is occupied

*For any* 2H item equipped into an arm slot when both arm slots are empty, both `L_Arm` and `R_Arm` SHALL be occupied by that item afterward. Conversely, *for any* 2H item and any state where at least one arm slot is already occupied, the equip SHALL return `false` and emit `equip_failed` with reason `"arm_slots_occupied"`.

**Validates: Requirements 1.4, 1.7**

---

### Property 5: Card partition invariant — every card is in exactly one collection

*For any* sequence of `draw`, `discard_card`, `discard_hand`, and `recycle_discard` operations, the multiset union of `deck + hand + discard_pile` SHALL always equal the original deck multiset assembled at combat start. No card SHALL appear in more than one collection simultaneously.

**Validates: Requirements 4.3, 4.7, 4.8**

---

### Property 6: Deck assembly contains exactly the cards from all equipped non-Head sets

*For any* loadout of equipped non-Head items, calling `build_deck(slot_manager)` SHALL produce a deck whose multiset of cards equals the union of all cards from each equipped item's `CardSet`, with no cards added or removed.

**Validates: Requirements 4.1**

---

### Property 7: Shuffle preserves deck contents

*For any* deck, after shuffling, the multiset of cards in the deck SHALL be identical to the multiset before shuffling (only order may differ).

**Validates: Requirements 4.2**

---

### Property 8: Discard recycle round-trip

*For any* non-empty `discard_pile` with an empty `deck`, after `recycle_discard()`, the `deck` SHALL contain exactly the cards that were in `discard_pile` and `discard_pile` SHALL be empty.

**Validates: Requirements 4.6**

---

### Property 9: Card playability reflects current AP and ammo state

*For any* hand of cards and any current AP value, `get_playable_cards()` SHALL return exactly the subset of hand cards where `ap_cost <= current_ap` AND (the card does not have the `"ammo"` tag OR the source item's `current_ammo > 0`).

**Validates: Requirements 5.2, 10.2, 10.5**

---

### Property 10: AP spend is exact and rejects insufficient funds

*For any* `current_ap >= 0` and any `cost >= 0`: if `cost <= current_ap`, then `spend(cost)` SHALL return `true` and reduce `current_ap` by exactly `cost`; if `cost > current_ap`, then `spend(cost)` SHALL return `false`, emit `action_rejected` with reason `"insufficient_ap"`, and leave `current_ap` unchanged.

**Validates: Requirements 6.2, 6.3, 6.4, 6.5**

---

### Property 11: AP grant is capped at max_ap

*For any* `current_ap`, `max_ap`, and `grant_amount >= 0`, after `grant(grant_amount)`, `current_ap` SHALL equal `min(current_ap + grant_amount, max_ap)`.

**Validates: Requirements 6.6**

---

### Property 12: Chebyshev distance is symmetric and correct

*For any* two tile coordinates `a` and `b`, `tile_distance(a, b)` SHALL equal `tile_distance(b, a)` (symmetry), `tile_distance(a, a)` SHALL equal `0` (identity), and `tile_distance(a, b)` SHALL equal `max(|a.x - b.x|, |a.y - b.y|)` (correctness).

**Validates: Requirements 7.6**

---

### Property 13: Out-of-bounds and occupied moves are rejected

*For any* unit and any destination tile that is either outside the grid bounds (`x < 0`, `x >= width`, `y < 0`, or `y >= height`) or already occupied by another unit, `move_unit()` SHALL return `false` and emit `move_rejected` with the appropriate reason, leaving all unit positions unchanged.

**Validates: Requirements 7.1, 7.4, 7.5**

---

### Property 14: Range validation matches Chebyshev distance

*For any* caster position, target position, and range value `r`, `validate_range(caster_id, target, r)` SHALL return `true` if and only if `tile_distance(caster_pos, target) <= r`. When it returns `false`, `action_rejected` with reason `"out_of_range"` SHALL be emitted.

**Validates: Requirements 7.7, 7.8**

---

### Property 15: Ammo decrement and reload round-trip

*For any* item with `max_ammo > 0` and any `current_ammo > 0`, after `decrement_ammo()`, `current_ammo` SHALL decrease by exactly `1`. After `reload_ammo()`, `current_ammo` SHALL equal `max_ammo` regardless of its prior value.

**Validates: Requirements 10.1, 10.3**

---

### Property 16: Passive apply/remove round-trip

*For any* Head item with one or more Passive effects, equipping it SHALL cause `apply(mech)` to be called on every passive. Subsequently unequipping it SHALL cause `remove(mech)` to be called on every passive that was applied, restoring the mech to its pre-equip state.

**Validates: Requirements 11.1, 11.2**

---

### Property 17: Season advances by exactly 1 each turn; combat triggers every 4 seasons

*For any* starting `current_season` value, after `advance_season()`, `current_season` SHALL equal the prior value plus `1`. *For any* season number that is a positive multiple of `seasons_per_combat`, `advance_season()` SHALL trigger a combat encounter.

**Validates: Requirements 12.1, 12.2**

---

### Property 18: has_tag is a correct membership test

*For any* card or item with any set of tags, `has_tag(t)` SHALL return `true` if and only if `t` is present in the `tags` array. Adding a tag to the array SHALL cause `has_tag` to return `true` for that tag; removing it SHALL cause `has_tag` to return `false`.

**Validates: Requirements 15.2, 15.4**

---

### Property 19: All effects on a card are executed in order

*For any* card with `N` effects, playing that card SHALL result in each effect's `execute(context)` being called exactly once, in list order (index 0 through N-1), with the same context dictionary passed to each.

**Validates: Requirements 16.2, 16.5**

---

### Property 20: All enemy behaviors are invoked in order during enemy turn

*For any* enemy with `N` EnemyBehavior resources, during that enemy's turn, each behavior's `decide(context)` SHALL be called exactly once, in list order, with a context dictionary containing the required keys (`"enemy"`, `"mech"`, `"battlefield_manager"`, `"ap_manager"`, `"event_bus"`).

**Validates: Requirements 17.1, 17.4**

---

### Property 21: EventBus delivers events only to matching subscribers with correct payload

*For any* event name `E`, callable `C` subscribed to `E`, and payload dictionary `P`: emitting `EventBus.emit(E, P)` SHALL invoke `C` with exactly `P`. Emitting any event name `F ≠ E` SHALL NOT invoke `C`. Emitting an event with no subscribers SHALL produce no error.

**Validates: Requirements 18.1, 18.2, 18.3, 18.4**

---

### Property 22: SlotRule chain — any rejection blocks equip; unanimous permit allows equip

*For any* list of SlotRule resources and any equip attempt: if at least one rule's `check()` returns `{ "permitted": false, "reason": R }`, then `equip()` SHALL return `false` and emit `equip_failed` with reason `R`, without modifying slot state. If all rules return `{ "permitted": true }`, then `equip()` SHALL return `true`, update slot state, and emit `slot_changed`.

**Validates: Requirements 19.1, 19.4, 19.5**

---

### Property 23: SlotTypeRule rejects items equipped into the wrong slot type

*For any* item with a given `slot_type` and any target slot whose type does not match (e.g., a `Back` item targeting `L_Arm`, or a `Leg` item targeting `Head`), `SlotTypeRule.check()` SHALL return `{ "permitted": false, "reason": "slot_type_mismatch" }`. Conversely, *for any* item whose `slot_type` matches the target slot, `SlotTypeRule.check()` SHALL return `{ "permitted": true }`.

**Validates: Requirements 1.2, 19.6**
