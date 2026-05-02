## Mech node — the player-controlled unit on the Battlefield.
## Extends CharacterBody2D; all behaviour is provided by attached Component scripts.
## Subscribes to the EventBus `slot_changed` event to apply/remove Passive effects
## when the Head Slot item changes.
## Requirements: 11.1, 11.2, 14.1
extends CharacterBody2D

## Maximum hit points for this Mech.
@export var max_hp: int = 100

## Current hit points; initialised to max_hp in _ready().
@export var current_hp: int = 0

## Flat armor bonus applied before incoming damage (modified by ArmorPassive).
@export var armor_bonus: int = 0

## HP regenerated per turn (modified by RegenPassive).
@export var regen_per_turn: int = 0

## Whether this Mech is pinned (cannot move). Set by PinnedEffect.
var is_pinned: bool = false

## Multiplier applied to block gains. Set by BrittleEffect (0.5 when brittle).
var block_multiplier: float = 1.0

## Multiplier applied to incoming damage. Set by VulnerableEffect (1.25 when vulnerable).
var damage_multiplier: float = 1.0

## Current block points. Absorbs incoming damage before armor and HP. Resets each turn.
var block: int = 0

# Tracks the currently equipped Head item so its passives can be removed on unequip.
var _head_item = null

func _ready() -> void:
	current_hp = max_hp
	EventBus.subscribe("slot_changed", _on_slot_changed)

## Handles slot_changed events from the EventBus.
## When the Head slot changes, removes passives from the previous Head item
## and applies passives from the new Head item (if any).
func _on_slot_changed(payload: Dictionary) -> void:
	if payload.get("slot") != "Head":
		return

	# Remove passives from the previously equipped Head item.
	if _head_item != null:
		for passive in _head_item.passives:
			passive.remove(self)

	var new_item = payload.get("item")
	_head_item = new_item

	# Apply passives from the newly equipped Head item.
	if new_item != null:
		for passive in new_item.passives:
			passive.apply(self)

## Reduce current_hp by the incoming amount, applying block absorption first,
## then armor reduction, then damage_multiplier (rounded to nearest).
func take_damage(amount: int) -> void:
	var absorbed: int = min(block, amount)
	block -= absorbed
	amount -= absorbed
	if amount <= 0:
		return
	var effective: int = max(0, amount - armor_bonus)
	effective = roundi(effective * damage_multiplier)
	current_hp = max(0, current_hp - effective)

## Returns true if the Mech still has HP remaining.
func is_alive() -> bool:
	return current_hp > 0
