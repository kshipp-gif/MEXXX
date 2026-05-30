## MultiTargetDamageEffect — deals damage a fixed number of times to player-selected
## targets, with optional movement between hits. Generalizes any "pick targets then
## deal damage in sequence" pattern.
##
## The player selects targets first (up to max_targets adjacent enemies, total of
## total_hits picks — can pick the same enemy multiple times). Damage is then dealt
## in the order chosen.
##
## Examples:
##   - Serpent Dance: damage=3, hits=3, max_targets=3, allow_movement=true
##   - Flurry: damage=2, hits=5, max_targets=5, allow_movement=false
##   - Focused Strike: damage=6, hits=2, max_targets=1, allow_movement=false
##
## NOTE: Full multi-target selection requires UI support. Current simplified
## implementation deals all hits to the single target from context.
extends Effect
class_name MultiTargetDamageEffect

## Damage dealt per hit.
@export var damage_per_hit: int = 0

## Total number of hits to distribute across targets.
@export var total_hits: int = 1

## Maximum number of distinct targets the player can select.
@export var max_targets: int = 1

## Whether the player may move 1 tile between hits.
@export var allow_movement_between_hits: bool = false

func execute(context: Dictionary) -> void:
	var target = context.get("target")
	if target == null or not target.has_method("take_damage"):
		return

	var caster = context.get("caster")

	# Simplified implementation: deal all hits to the single target.
	# Full implementation will use multi-target selection UI to build a hit list,
	# then iterate through it with optional movement prompts between each hit.
	for _i in range(total_hits):
		if target.has_method("is_alive") and not target.is_alive():
			break
		target.take_damage(damage_per_hit, caster)
