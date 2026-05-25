## Deals damage to all units occupying tiles in the pattern.
## Unoccupied tiles and out-of-bounds tiles are skipped silently.
##
## This effect extends MultiTileEffect to apply damage to multiple tiles simultaneously.
## The damage amount is configurable via the exported damage property (range 1-999).
##
## Execution behavior:
##   - For each tile in the pattern, checks if the tile is within battlefield bounds
##   - Queries the BattlefieldManager for a unit at that position
##   - If a unit exists and has a take_damage method, applies the configured damage
##   - Skips tiles that are out of bounds, unoccupied, or have units without take_damage
##
## Requirements validated: 2.1, 2.3
extends MultiTileEffect
class_name MultiTileDamageEffect

## Amount of damage to deal to each unit in the pattern.
## Valid range: 1 to 999 damage points.
@export_range(1, 999) var damage: int = 1

## Apply damage to the unit at tile_position, if any.
##
## This method implements the per-tile logic for the damage effect:
##   1. Validates tile is within battlefield bounds (0 <= x < grid_width, 0 <= y < grid_height)
##   2. Queries BattlefieldManager for a unit at the tile position
##   3. If a unit exists and has a take_damage method, calls unit.take_damage(damage, caster)
##   4. Skips silently if tile is out of bounds, unoccupied, or unit lacks take_damage method
##
## Parameters:
##   - tile_position: The absolute position of the tile to apply damage to
##   - context: The Effect_Context dictionary containing game state (includes "caster" key)
##   - battlefield_manager: Reference to the BattlefieldManager for bounds checking and unit queries
func apply_to_tile(tile_position: Vector2i, context: Dictionary, battlefield_manager: Node) -> void:
	# Skip out-of-bounds tiles
	if tile_position.x < 0 or tile_position.x >= battlefield_manager.grid_width:
		return
	if tile_position.y < 0 or tile_position.y >= battlefield_manager.grid_height:
		return
	
	# Query for unit at this tile
	var unit_node: Node = battlefield_manager.get_unit_node_at(tile_position)
	if unit_node == null:
		return  # Tile is unoccupied
	
	# Apply damage if the unit supports take_damage
	if unit_node.has_method("take_damage"):
		var caster = context.get("caster")
		unit_node.take_damage(damage, caster)
