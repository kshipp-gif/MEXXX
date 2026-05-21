## Draws a number of cards from the deck via DeckManager.
extends Effect
class_name DrawEffect

## Number of cards to draw.
@export var count: int = 1

## Calls deck_manager.draw(count) if deck_manager is present in context.
func execute(context: Dictionary) -> void:
	if not context.has("deck_manager"):
		return
	var deck_manager = context["deck_manager"]
	if deck_manager != null:
		deck_manager.draw(count)
