## Autoload singleton that tracks global run state for the player.
## Requirements: 12.1, 13.3
extends Node

## Player's current item inventory (items acquired but not necessarily equipped).
var inventory: Array[Item] = []

## Current season number (advances each turn in the base phase).
var current_season: int = 0

## Whether a run is currently active.
var run_active: bool = false

## Add an item to the player's inventory.
func add_item(item: Item) -> void:
	inventory.append(item)

## Remove an item from the player's inventory.
func remove_item(item: Item) -> void:
	inventory.erase(item)
