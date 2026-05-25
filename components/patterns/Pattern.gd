## Defines a reusable tile pattern as a set of offsets from an origin tile.
## Patterns are Resources that can be created in the Godot inspector and
## shared across multiple effects.
##
## Coordinate System:
##   - X axis: increases rightward (0 to 7)
##   - Y axis: increases downward (0 to 5)
##   - Offset resolution: absolute_pos = origin_tile + offset
##   - Battlefield bounds: x ∈ [0,7], y ∈ [0,5]
##
## Example Patterns:
##   - Horizontal line: [Vector2i(-1,0), Vector2i(0,0), Vector2i(1,0)]
##   - Cross: [Vector2i(0,0), Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]
##   - Cone: [Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(1,-1), Vector2i(1,1),
##            Vector2i(2,-1), Vector2i(2,1), Vector2i(2,-2), Vector2i(2,2)]
extends Resource
class_name Pattern

## Array of tile offsets relative to the origin tile.
## Each offset is a Vector2i with x and y in range [-99, 99].
## Maximum 100 offsets per pattern.
@export var tile_offsets: Array[Vector2i] = []

func _init() -> void:
	tile_offsets = []

## Compute absolute tile positions by adding each offset to the origin tile.
## 
## This method transforms relative offsets into absolute battlefield positions.
## For example, if origin_tile is (3, 2) and tile_offsets contains [(0, 0), (1, 0), (-1, 0)],
## the result will be [(3, 2), (4, 2), (2, 2)].
##
## Parameters:
##   origin_tile: The center position from which offsets are calculated
##
## Returns:
##   Array[Vector2i] of absolute positions. Returns empty array if tile_offsets is empty.
##   Does not filter for battlefield bounds — caller must validate positions.
##
## Examples:
##   var pattern = Pattern.new()
##   pattern.tile_offsets = [Vector2i(-1, 0), Vector2i(0, 0), Vector2i(1, 0)]
##   var positions = pattern.get_absolute_positions(Vector2i(3, 2))
##   # positions = [Vector2i(2, 2), Vector2i(3, 2), Vector2i(4, 2)]
func get_absolute_positions(origin_tile: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in tile_offsets:
		result.append(origin_tile + offset)
	return result
