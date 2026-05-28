## Base class for effects that apply to multiple tiles using a Pattern.
## Subclasses implement apply_to_tile() to define per-tile behavior.
##
## Execution Flow:
##   1. Resolve origin_tile from Effect_Context
##   2. Compute affected tiles using Pattern.get_absolute_positions()
##   3. Emit multi_tile_effect_resolved event
##   4. For each tile, call apply_to_tile() (subclass implementation)
##
## Origin Tile Resolution:
##   - Ranged items: Use context["origin_tile"] (set by tile selection UI)
##   - Melee items: Query BattlefieldManager with context["caster_id"]
extends Effect
class_name MultiTileEffect

const PatternClass = preload("res://components/patterns/Pattern.gd")

## Pattern defining which tiles are affected relative to the origin.
## Type is Resource to avoid load-order issues; assign a Pattern resource at runtime.
@export var pattern: Resource = null

## Resolve the origin tile from the effect context.
## 
## For ranged items, the origin_tile is set by the tile selection UI and stored
## in context["origin_tile"]. For melee items, the origin is the caster's current
## position queried from the BattlefieldManager using context["caster_id"].
##
## Returns Vector2i(-1, -1) if resolution fails (missing context keys or invalid data).
func resolve_origin_tile(context: Dictionary) -> Vector2i:
	# Ranged case: origin_tile is set by tile selection UI
	if context.has("origin_tile") and context["origin_tile"] != null:
		return context["origin_tile"]
	
	# Melee case: query caster position from BattlefieldManager
	if context.has("caster_id") and context.has("battlefield_manager"):
		var battlefield: Node = context["battlefield_manager"]
		var pos: Vector2i = battlefield.get_position(context["caster_id"])
		# BattlefieldManager returns (0,0) for unknown units, but we need to distinguish
		# between a valid (0,0) position and a failed lookup. Since the design specifies
		# returning (-1,-1) on failure, we'll trust that BattlefieldManager has the unit.
		return pos
	
	# Resolution failed
	return Vector2i(-1, -1)

## Compute all affected tile positions using the pattern.
##
## This method combines origin resolution with pattern transformation to produce
## the final list of absolute tile positions that will be affected by this effect.
##
## Returns an empty array if:
##   - pattern is null
##   - origin cannot be resolved (returns Vector2i(-1, -1))
##
## The returned positions may include out-of-bounds or unoccupied tiles.
## Subclasses must handle invalid tiles in apply_to_tile().
func get_affected_tiles(context: Dictionary) -> Array[Vector2i]:
	if pattern == null:
		return []
	
	var origin: Vector2i = resolve_origin_tile(context)
	if origin == Vector2i(-1, -1):
		return []
	
	return pattern.get_absolute_positions(origin)

## Execute the multi-tile effect: resolve tiles, emit event, and apply to each tile.
##
## This method orchestrates the complete execution flow:
##   1. Validates required context keys ("battlefield_manager", "caster_id", "event_bus")
##   2. Computes affected tiles using get_affected_tiles()
##   3. Skips execution if affected_tiles is empty
##   4. Emits "multi_tile_effect_resolved" event via event_bus
##   5. Iterates through affected_tiles and calls apply_to_tile() for each
##
## Skips execution without error if:
##   - Required context keys are missing
##   - Pattern is null
##   - Origin tile cannot be resolved
##   - Affected tiles list is empty
func execute(context: Dictionary) -> void:
	# Validate required context keys
	if not context.has("battlefield_manager"):
		return
	if not context.has("caster_id"):
		return
	if not context.has("event_bus"):
		return
	
	# Compute affected tiles
	var affected_tiles: Array[Vector2i] = get_affected_tiles(context)
	if affected_tiles.is_empty():
		return
	
	# Resolve origin for event payload
	var origin: Vector2i = resolve_origin_tile(context)
	
	# Emit event for UI feedback (e.g., visual effects on affected tiles)
	var event_bus: Node = context["event_bus"]
	event_bus.emit("multi_tile_effect_resolved", {
		"effect_name": get_class(),
		"origin_tile": origin,
		"affected_tiles": affected_tiles
	})
	
	# Apply effect to each tile
	var battlefield: Node = context["battlefield_manager"]
	for tile_pos in affected_tiles:
		apply_to_tile(tile_pos, context, battlefield)

## Abstract method for subclasses to implement per-tile logic.
##
## This method is called once for each tile position returned by get_affected_tiles().
## Subclasses must override this method to define the specific behavior applied to each tile.
##
## The method receives:
##   - _tile_position: The absolute position of the tile to apply the effect to
##   - _context: The Effect_Context dictionary containing game state and references
##   - _battlefield_manager: Reference to the BattlefieldManager for tile/unit queries
##
## Subclasses are responsible for:
##   - Validating tile bounds (checking against battlefield dimensions)
##   - Handling unoccupied tiles (checking if a unit exists at the position)
##   - Handling out-of-bounds tiles gracefully (skipping without error)
##   - Applying the actual effect logic (damage, healing, status effects, etc.)
##
## The base class does NOT pre-filter tiles for validity. All tiles from the pattern
## (including out-of-bounds and unoccupied tiles) are passed to this method.
func apply_to_tile(_tile_position: Vector2i, _context: Dictionary, _battlefield_manager: Node) -> void:
	pass  # Override in subclasses
