# Requirements Document

## Introduction

MEXXX is a turn-based deckbuilder in which the player pilots a customizable Mech to defend a Base from waves of enemies on a square-tile Battlefield. The Mech is assembled from Items equipped into five named Slots. Each Item (except the Head Slot item) contributes a Set of Cards to the shared Deck. During combat the player spends Action Points to play Cards and move the Mech across the Battlefield. Between combat encounters the player manages the Base, advances time by season, and responds to random events that offer new Items.

This document covers the core systems: the Mech and its equipment model, the Card and Deck model, the combat loop, the Battlefield, and the out-of-combat Base phase. All systems are to be implemented in Godot 4 using GDScript with composition over inheritance — behaviour is attached to nodes as discrete Component scripts rather than encoded in deep class hierarchies.

---

## Glossary

- **Mech**: The player-controlled unit on the Battlefield, composed of five Slots.
- **Slot**: A named attachment point on the Mech. The five Slots are: `L_Arm`, `R_Arm`, `Legs`, `Back`, and `Head`.
- **Item**: A resource that occupies one or two Slots and carries a Set of Cards plus optional Passive effects.
- **Set**: The fixed collection of Cards that belongs to a single Item. Head Slot Items have no Set.
- **Card**: A single playable unit with an AP cost, one or more Effects, a Type, Tags, Rarity, and optional range or ammo values.
- **Deck**: The combined pool of all Cards drawn from all equipped Sets during combat.
- **Hand**: The subset of Cards drawn from the Deck at the start of each player turn.
- **Discard_Pile**: The collection of Cards that have been played or discarded from the Hand.
- **AP (Action Points)**: The per-turn resource spent to play Cards or move the Mech.
- **Battlefield**: The square-tile grid on which combat takes place.
- **Base**: The structure at one end of the Battlefield that the player must protect.
- **Enemy**: An AI-controlled unit that enters the Battlefield from the end opposite the Base.
- **Passive**: An always-active effect provided by a Head Slot Item; it requires no Card play.
- **Effect**: A discrete game action produced when a Card is played (e.g., deal damage, move, draw a card).
- **Tag**: A label on a Card that categorises its mechanical properties (e.g., `1H`, `2H`, `melee`, `ranged`, `heat`, `ammo`, `reload`).
- **Rarity**: A classification of an Item's likelihood of appearing in a given playthrough (`Common`, `Uncommon`, `Rare`, `Legendary`).
- **Card_Type**: A classification of a Card's primary purpose (`Attack`, `Defense`, `Movement`, `Utility`, `Combo`).
- **Season**: The unit of out-of-combat time. Four Seasons pass between each combat encounter.
- **Random_Event**: An out-of-combat occurrence that presents the player with choices, potentially including new Items.
- **Component**: A GDScript resource or Node attached to another Node to provide a discrete behaviour without inheritance.
- **SlotManager**: The Component responsible for managing the Mech's five Slots and enforcing equip rules.
- **DeckManager**: The Component responsible for assembling, shuffling, drawing, and recycling the Deck.
- **HandManager**: The Component responsible for tracking the Cards currently in the player's Hand.
- **CombatTurnManager**: The Component responsible for sequencing player and enemy turns during combat.
- **BattlefieldManager**: The Component responsible for the tile grid, unit positions, and movement validation.
- **APManager**: The Component responsible for tracking and spending Action Points.
- **BaseManager**: The Component responsible for Base health and out-of-combat phase progression.
- **EnemyBehavior**: A Component resource attached to an Enemy node that defines how that Enemy decides to act on its turn.
- **SlotRule**: A Component resource attached to the SlotManager that encodes a single equip constraint (e.g., 2H exclusivity, Slot type restrictions).
- **EventBus**: A singleton or shared Node that routes named game signals between Components without direct references.

---

## Requirements

### Requirement 1: Mech Slot System

**User Story:** As a player, I want to equip Items into my Mech's five named Slots, so that I can customise my loadout and build my Deck.

#### Acceptance Criteria

1. THE SlotManager SHALL maintain exactly five Slots: `L_Arm`, `R_Arm`, `Legs`, `Back`, and `Head`.
2. THE SlotManager SHALL enforce slot-type restrictions: Arm items (`1H` or `2H`) may only be equipped into `L_Arm` or `R_Arm`; Leg items may only be equipped into `Legs`; Back items may only be equipped into `Back`; Head items may only be equipped into `Head`. IF a player attempts to equip an Item into a Slot that does not match the Item's designated slot type, THEN THE SlotManager SHALL reject the equip action and emit an `equip_failed` signal with the reason `slot_type_mismatch`.
3. THE SlotManager SHALL allow at most one Item to occupy a single-Slot position at any time.
4. WHEN a 2H Item is equipped, THE SlotManager SHALL occupy both the `L_Arm` and `R_Arm` Slots simultaneously and prevent any other Item from being equipped in either Arm Slot until the 2H Item is removed.
5. WHEN a 1H Item is equipped into `L_Arm` or `R_Arm`, THE SlotManager SHALL allow a separate 1H Item to occupy the other Arm Slot independently.
6. IF a player attempts to equip an Item into a Slot that is already occupied, THEN THE SlotManager SHALL reject the equip action and emit an `equip_failed` signal with the reason `slot_occupied`.
7. IF a player attempts to equip a 2H Item when either Arm Slot is occupied, THEN THE SlotManager SHALL reject the equip action and emit an `equip_failed` signal with the reason `arm_slots_occupied`.
8. WHEN an Item is unequipped from a Slot, THE SlotManager SHALL mark that Slot as empty and emit a `slot_changed` signal.
9. THE SlotManager SHALL expose a query method that returns the Item currently occupying a given Slot, or null if the Slot is empty.

---

### Requirement 2: Item Data Model

**User Story:** As a designer, I want Items to carry all their data as a self-contained resource, so that Items can be authored in the Godot editor and composed onto the Mech without subclassing.

#### Acceptance Criteria

1. THE Item SHALL store: a unique identifier, a display name, a Rarity value, a `slot_type` (one of `Arm`, `Leg`, `Back`, `Head`) that declares which Slot the Item belongs to, a list of Tags, a list of Passive effects (may be empty), and a reference to its Set (may be null for Head Slot Items).
2. THE Item SHALL declare whether it is `1H` or `2H` via a Tag, and THE SlotManager SHALL read this Tag to enforce Arm Slot rules.
3. WHERE an Item's `slot_type` is `Head`, THE Item SHALL have a null Set reference and one or more Passive effects.
4. WHERE an Item's `slot_type` is not `Head`, THE Item SHALL have a non-null Set reference containing five or more Cards.
5. THE Item SHALL be implemented as a `Resource` subclass so that it can be serialised, saved, and loaded using Godot's built-in resource system.

---

### Requirement 3: Card Data Model

**User Story:** As a designer, I want each Card to carry all its mechanical data as a self-contained resource, so that Cards can be authored in the editor and composed into Sets without subclassing.

#### Acceptance Criteria

1. THE Card SHALL store: a display name, an AP cost (integer ≥ 0), a Card_Type, a list of Tags, a Rarity (inherited from its parent Item), a list of Effects, and a reference to the Item it belongs to.
2. WHEN a Card has the `ranged` Tag, THE Card SHALL store a range value (integer ≥ 1) representing the maximum tile distance at which its Effects can be applied.
3. WHEN a Card has the `ammo` Tag, THE Card SHALL store an ammo count (integer ≥ 1) representing the number of attack uses available before a reload is required.
4. THE Card SHALL be implemented as a `Resource` subclass so that it can be serialised, saved, and loaded using Godot's built-in resource system.
5. THE Card SHALL NOT encode its own play logic; Effects SHALL be separate Component resources attached to the Card.

---

### Requirement 4: Set and Deck Assembly

**User Story:** As a player, I want my Deck to be automatically assembled from the Sets of all my equipped Items, so that my loadout directly determines what Cards I can draw in combat.

#### Acceptance Criteria

1. WHEN combat begins, THE DeckManager SHALL collect all Sets from all non-Head Slots that contain an equipped Item and combine their Cards into a single Deck.
2. THE DeckManager SHALL shuffle the Deck using a uniform random permutation before the first Hand is drawn.
3. THE DeckManager SHALL maintain three distinct collections at all times during combat: `deck`, `hand`, and `discard_pile`.
4. WHEN a Card is played, THE DeckManager SHALL move that Card from `hand` to `discard_pile`.
5. WHEN the player ends their turn, THE DeckManager SHALL move all remaining Cards in `hand` to `discard_pile`.
6. IF the `deck` is empty at the start of a player turn draw step, THEN THE DeckManager SHALL shuffle all Cards in `discard_pile` into `deck` before drawing.
7. THE DeckManager SHALL expose a `draw(n: int)` method that moves the top `n` Cards from `deck` to `hand` and emits a `hand_updated` signal.
8. THE DeckManager SHALL expose query methods for the current sizes of `deck`, `hand`, and `discard_pile`.

---

### Requirement 5: Hand Management

**User Story:** As a player, I want to draw a new Hand at the start of each turn and have unplayed Cards discarded automatically, so that each turn feels fresh and I must manage my resources carefully.

#### Acceptance Criteria

1. WHEN a new player turn begins, THE HandManager SHALL request a draw of the configured hand size from THE DeckManager.
2. THE HandManager SHALL track which Cards in the Hand are playable given the current AP total.
3. WHEN the player plays a Card, THE HandManager SHALL remove that Card from the Hand and notify THE DeckManager to move it to the Discard_Pile.
4. WHEN the player ends their turn, THE HandManager SHALL pass all remaining Hand Cards to THE DeckManager for discarding and then clear the Hand.
5. THE HandManager SHALL emit a `card_played` signal carrying the played Card reference whenever a Card is successfully played.

---

### Requirement 6: Action Points

**User Story:** As a player, I want a pool of Action Points each turn that I spend on playing Cards and moving, so that I must make meaningful tactical decisions about how to use my turn.

#### Acceptance Criteria

1. THE APManager SHALL initialise the AP pool to a configured maximum value at the start of each player turn.
2. WHEN a Card is played, THE APManager SHALL deduct the Card's AP cost from the current AP pool.
3. WHEN the Mech moves one tile, THE APManager SHALL deduct 1 AP from the current AP pool.
4. IF a player attempts to play a Card whose AP cost exceeds the current AP pool, THEN THE APManager SHALL reject the action and emit an `action_rejected` signal with the reason `insufficient_ap`.
5. IF a player attempts to move when the current AP pool is 0, THEN THE APManager SHALL reject the movement and emit an `action_rejected` signal with the reason `insufficient_ap`.
6. WHEN a Card Effect grants AP, THE APManager SHALL add the granted amount to the current AP pool, capped at the configured maximum.
7. THE APManager SHALL emit an `ap_changed` signal whenever the AP pool value changes.

---

### Requirement 7: Battlefield Grid

**User Story:** As a player, I want to move my Mech across a square-tile grid and target enemies at specific positions, so that positioning and range matter tactically.

#### Acceptance Criteria

1. THE BattlefieldManager SHALL represent the Battlefield as a two-dimensional grid of square tiles with configurable width and height.
2. THE BattlefieldManager SHALL designate one edge of the grid as the Base end and the opposite edge as the Enemy entry end.
3. THE BattlefieldManager SHALL track the grid position of every unit (Mech and Enemies) as a `Vector2i` tile coordinate.
4. WHEN the Mech moves, THE BattlefieldManager SHALL validate that the destination tile is within grid bounds and unoccupied by another unit before confirming the move.
5. IF a move destination is out of bounds or occupied, THEN THE BattlefieldManager SHALL reject the move and emit a `move_rejected` signal with the reason.
6. THE BattlefieldManager SHALL expose a `tile_distance(a: Vector2i, b: Vector2i) -> int` method that returns the Chebyshev distance between two tile coordinates.
7. WHEN a ranged Card is played, THE BattlefieldManager SHALL verify that the target tile is within the Card's range value before the Effect is applied.
8. IF the target tile is outside the Card's range, THEN THE BattlefieldManager SHALL reject the action and emit an `action_rejected` signal with the reason `out_of_range`.

---

### Requirement 8: Combat Turn Sequence

**User Story:** As a player, I want a clear alternating turn structure between my actions and the enemies' actions, so that I can plan and react without ambiguity.

#### Acceptance Criteria

1. THE CombatTurnManager SHALL sequence turns as: player turn → enemy turn → player turn → … until combat ends.
2. WHEN a player turn begins, THE CombatTurnManager SHALL signal THE APManager to reset AP, then signal THE HandManager to draw a new Hand.
3. WHEN the player ends their turn, THE CombatTurnManager SHALL signal THE HandManager to discard the remaining Hand, then begin the enemy turn.
4. DURING the enemy turn, THE CombatTurnManager SHALL process each Enemy's action in sequence: move toward the Base, attack the Mech if in range, or both.
5. WHEN all Enemies have acted, THE CombatTurnManager SHALL begin the next player turn.
6. THE CombatTurnManager SHALL emit a `turn_started` signal carrying the turn owner (`player` or `enemy`) at the start of each turn.
7. THE CombatTurnManager SHALL emit a `combat_ended` signal carrying the outcome (`victory` or `defeat`) when a combat end condition is met.

---

### Requirement 9: Combat End Conditions

**User Story:** As a player, I want combat to end clearly when I destroy all enemies or my Base is destroyed, so that I always know the stakes.

#### Acceptance Criteria

1. WHEN all Enemies on the Battlefield are destroyed, THE CombatTurnManager SHALL emit `combat_ended` with outcome `victory`.
2. WHEN the Base's health reaches 0, THE CombatTurnManager SHALL emit `combat_ended` with outcome `defeat`.
3. THE CombatTurnManager SHALL check end conditions after every Enemy action and after every Card play.

---

### Requirement 10: Ammo and Reload System

**User Story:** As a player, I want attack Cards for ammo-based Items to consume ammo charges, so that I must manage ammunition and play reload Cards strategically.

#### Acceptance Criteria

1. WHEN an attack Card with the `ammo` Tag is played, THE Item's ammo counter SHALL be decremented by 1.
2. IF the ammo counter for an Item is 0, THEN attack Cards belonging to that Item with the `ammo` Tag SHALL be unplayable until a reload Effect is applied.
3. WHEN a Card with the `reload` Tag is played, THE Item's ammo counter SHALL be restored to its configured maximum ammo value.
4. THE Item SHALL emit an `ammo_changed` signal whenever its ammo counter changes.
5. THE HandManager SHALL mark ammo-depleted attack Cards as unplayable and reflect this state in the `card_played` signal payload.

---

### Requirement 11: Passive Effects

**User Story:** As a player, I want the Item in my Head Slot to provide a constant passive benefit, so that my Head Slot choice meaningfully shapes my playstyle without requiring card plays.

#### Acceptance Criteria

1. WHEN an Item with Passive effects is equipped in the `Head` Slot, THE Mech SHALL apply all of that Item's Passive effects immediately.
2. WHEN the Head Slot Item is unequipped, THE Mech SHALL remove all Passive effects that were applied by that Item.
3. THE Passive effect SHALL be implemented as a Component resource that exposes `apply(target: Node)` and `remove(target: Node)` methods.
4. THE Mech SHALL NOT require subclassing to support new Passive effect types; new Passives SHALL be added by creating new Component resources.

---

### Requirement 12: Out-of-Combat Base Phase

**User Story:** As a player, I want to manage my Base between combat encounters and make decisions each Season, so that the out-of-combat phase feels meaningful and strategic.

#### Acceptance Criteria

1. THE BaseManager SHALL track the current Season number and advance it by 1 each time the player ends a Season turn.
2. THE BaseManager SHALL trigger a combat encounter after every fourth Season turn.
3. WHEN a Season turn begins, THE BaseManager SHALL generate zero or more Random_Events and present them to the player.
4. THE BaseManager SHALL expose a method to apply the outcome of a Random_Event (e.g., adding an Item to the player's inventory).
5. THE BaseManager SHALL track the Base's current health value and emit a `base_health_changed` signal whenever it changes.
6. THE BaseManager SHALL emit a `season_advanced` signal carrying the new Season number whenever a Season turn ends.

---

### Requirement 13: Item Discovery via Random Events

**User Story:** As a player, I want Random Events to offer me new Items, so that my loadout evolves over the course of a playthrough.

#### Acceptance Criteria

1. WHEN a Random_Event that offers Items is generated, THE BaseManager SHALL select candidate Items using a weighted random draw that respects each Item's Rarity.
2. THE BaseManager SHALL present the player with a choice among the candidate Items.
3. WHEN the player selects an Item from a Random_Event, THE BaseManager SHALL add that Item to the player's inventory.
4. THE BaseManager SHALL NOT automatically equip a newly acquired Item; equipping is a separate player action.

---

### Requirement 14: Composition Architecture

**User Story:** As a developer, I want all game systems implemented as composable Components rather than deep inheritance hierarchies, so that behaviours can be mixed, replaced, and tested independently.

#### Acceptance Criteria

1. THE Mech node SHALL NOT use GDScript inheritance beyond extending a base Godot node type (`Node2D` or `CharacterBody2D`); all Mech behaviour SHALL be provided by attached Component scripts.
2. THE Card resource SHALL NOT use GDScript inheritance beyond extending `Resource`; all Card behaviour SHALL be provided by attached Effect Component resources.
3. THE Item resource SHALL NOT use GDScript inheritance beyond extending `Resource`; all Item behaviour SHALL be provided by attached Component resources.
4. WHEN a new Card Effect type is needed, a developer SHALL be able to add it by creating a new Effect Component resource without modifying any existing class.
5. WHEN a new Passive effect type is needed, a developer SHALL be able to add it by creating a new Passive Component resource without modifying any existing class.
6. THE SlotManager, DeckManager, HandManager, CombatTurnManager, BattlefieldManager, APManager, and BaseManager SHALL each be implemented as a separate script that can be attached to any Node, with no cross-manager dependencies beyond signal connections.
7. WHEN a new Card_Type value is needed, a developer SHALL be able to introduce it by adding an entry to the Card_Type enumeration without modifying any Component that processes existing Card_Types.
8. WHEN a new Random_Event type is needed, a developer SHALL be able to add it by creating a new Random_Event resource without modifying THE BaseManager or any existing Random_Event resource.

---

### Requirement 15: Extensible Tag System

**User Story:** As a designer, I want to add new Tags to Cards and Items without touching core system code, so that new mechanics can be introduced purely through data authoring.

#### Acceptance Criteria

1. THE Tag system SHALL represent each Tag as a string identifier so that new Tags can be introduced by defining a new string constant without modifying any existing Component.
2. WHEN a Component queries whether a Card or Item has a specific Tag, THE Component SHALL perform a membership test against the Tag list and SHALL NOT use hard-coded conditionals that enumerate all known Tags.
3. WHEN a new Tag is added to a Card or Item resource, THE SlotManager, DeckManager, HandManager, APManager, and BattlefieldManager SHALL each continue to function correctly for all existing Tags without modification.
4. THE Card resource SHALL expose a `has_tag(tag: String) -> bool` method that Components use for all Tag queries, so that Tag-checking logic is centralised in one place.

---

### Requirement 16: Data-Driven and Composable Effect System

**User Story:** As a designer, I want Card Effects to be defined as data resources that can be combined freely, so that new card behaviours can be created by composing existing Effect types without writing new code.

#### Acceptance Criteria

1. THE Effect SHALL be implemented as a `Resource` subclass that exposes an `execute(context: Dictionary) -> void` method, where `context` carries all runtime state the Effect needs (caster, target, battlefield, managers).
2. WHEN a Card is played, THE Card's Effect list SHALL be iterated and each Effect's `execute` method SHALL be called in order, so that multi-Effect Cards are supported without special-casing.
3. WHEN a new Effect type is needed, a developer SHALL be able to create it by subclassing the Effect resource and implementing `execute` without modifying THE HandManager, THE DeckManager, or any other existing Component.
4. THE Effect resource SHALL store all tunable parameters (damage amount, AP grant, draw count, heal amount, etc.) as exported properties so that Effect instances can be configured in the Godot editor without code changes.
5. WHEN two or more Effect resources of different types are attached to a single Card, THE Card SHALL apply all Effects in sequence and each Effect SHALL operate independently on the shared `context`.

---

### Requirement 17: Extensible Enemy Behavior System

**User Story:** As a designer, I want to add new enemy AI behaviors by attaching new Component resources to Enemy nodes, so that enemy variety can grow without modifying the combat loop.

#### Acceptance Criteria

1. THE Enemy node SHALL delegate its turn logic entirely to one or more attached EnemyBehavior Component resources; THE CombatTurnManager SHALL invoke a `decide(context: Dictionary) -> void` method on each EnemyBehavior in sequence rather than encoding enemy logic directly.
2. WHEN a new enemy AI pattern is needed, a developer SHALL be able to create it by subclassing EnemyBehavior and implementing `decide` without modifying THE CombatTurnManager or any existing EnemyBehavior.
3. THE EnemyBehavior resource SHALL receive all necessary runtime state through the `context` dictionary (battlefield positions, player Mech reference, AP pool) so that EnemyBehavior resources have no hard-coded dependencies on specific manager singletons.
4. WHEN multiple EnemyBehavior resources are attached to a single Enemy, THE Enemy SHALL execute each behavior's `decide` method in list order, allowing composite AI patterns to be assembled from simple reusable behaviors.
5. THE CombatTurnManager SHALL emit a `enemy_action_taken` signal carrying the Enemy reference and the action descriptor after each EnemyBehavior executes, so that new behaviors are automatically observable by UI and other systems without modification.

---

### Requirement 18: Extensible Event and Signal System

**User Story:** As a developer, I want the inter-system communication layer to support new event types without requiring changes to existing listeners, so that new features can broadcast and subscribe to events freely.

#### Acceptance Criteria

1. THE EventBus SHALL route signals by string event name so that a new event type can be introduced by emitting a new name without modifying THE EventBus or any existing listener.
2. WHEN a Component subscribes to an event on THE EventBus, THE Component SHALL specify only the event names it cares about; THE EventBus SHALL deliver only those events to that Component and SHALL silently ignore unknown event names for all other subscribers.
3. WHEN a new Component emits a previously unknown event name on THE EventBus, existing Components that do not subscribe to that name SHALL continue to function without modification or error.
4. THE EventBus SHALL accept an arbitrary `payload: Dictionary` argument with each emitted event so that new events can carry any data without requiring changes to the EventBus interface.
5. THE SlotManager, DeckManager, HandManager, CombatTurnManager, BattlefieldManager, APManager, and BaseManager SHALL each communicate state changes exclusively through THE EventBus or direct Godot signals, with no direct method calls between managers, so that any manager can be replaced or extended without updating its callers.

---

### Requirement 19: Extensible Slot Rules

**User Story:** As a designer, I want equip constraints to be defined as composable SlotRule resources rather than hard-coded conditionals, so that new equipment restrictions can be added without modifying the SlotManager.

#### Acceptance Criteria

1. THE SlotManager SHALL maintain a list of SlotRule Component resources and evaluate each rule in sequence when an equip action is requested.
2. EACH SlotRule resource SHALL expose a `check(slot: String, item: Item, slot_state: Dictionary) -> Dictionary` method that returns a result indicating whether the equip is permitted and, if not, the reason for rejection.
3. WHEN a new equip constraint is needed, a developer SHALL be able to add it by creating a new SlotRule resource and appending it to THE SlotManager's rule list without modifying THE SlotManager or any existing SlotRule.
4. IF any SlotRule in the list rejects an equip action, THEN THE SlotManager SHALL reject the action and emit an `equip_failed` signal carrying the reason returned by the rejecting SlotRule.
5. WHEN no SlotRule rejects an equip action, THE SlotManager SHALL complete the equip and emit a `slot_changed` signal.
6. THE SlotManager SHALL include a built-in `SlotTypeRule` that reads the Item's `slot_type` property and rejects any equip attempt where the Item's `slot_type` does not match the target Slot (e.g., a `Back` item cannot be equipped into `L_Arm`), emitting `equip_failed` with reason `slot_type_mismatch`.
