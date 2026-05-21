## CardInspectPanel — shown when the player right-clicks a card.
## Displays tags, source item name, item flavor text, and definitions
## of any status conditions referenced by the card's effects.
extends PanelContainer

## Static definitions for all known status conditions.
const STATUS_DEFINITIONS: Dictionary = {
	"pinned": "Pinned: The unit cannot move for the duration.",
	"brittle": "Brittle: All Block gained by the unit is halved (floored) for the duration.",
	"vulnerable": "Vulnerable: The unit takes 25% more damage from all sources for the duration.",
	"retaliation": "Retaliation: When this unit takes damage, the attacker takes 1 damage per stack of Retaliation.",
}

@onready var _title_label: Label = $MarginContainer/VBox/TitleLabel
@onready var _tags_label: Label = $MarginContainer/VBox/TagsLabel
@onready var _item_label: Label = $MarginContainer/VBox/ItemLabel
@onready var _flavor_label: Label = $MarginContainer/VBox/FlavorLabel
@onready var _status_label: Label = $MarginContainer/VBox/StatusLabel
@onready var _close_button: Button = $MarginContainer/VBox/CloseButton

func _ready() -> void:
	_close_button.pressed.connect(hide)
	hide()

## Populate the panel with data from the given Card resource and show it.
func show_for_card(card: Card) -> void:
	if card == null:
		return

	_title_label.text = card.display_name

	# Tags — from the source item, not the card
	var item: Item = card.source_item as Item
	if item != null and not item.tags.is_empty():
		_tags_label.text = "Tags: " + ", ".join(item.tags)
	else:
		_tags_label.text = "Tags: —"

	# Source item name and flavor text
	if item != null:
		_item_label.text = "Item: " + item.display_name
		_flavor_label.text = item.flavor_text if item.flavor_text != "" else ""
		_flavor_label.visible = item.flavor_text != ""
	else:
		_item_label.text = "Item: —"
		_flavor_label.text = ""
		_flavor_label.visible = false

	# Status condition definitions
	var referenced_statuses: Array[String] = _collect_status_names(card)
	if referenced_statuses.is_empty():
		_status_label.text = ""
		_status_label.visible = false
	else:
		var lines: Array[String] = []
		for name in referenced_statuses:
			if STATUS_DEFINITIONS.has(name):
				lines.append(STATUS_DEFINITIONS[name])
		if lines.is_empty():
			_status_label.text = ""
			_status_label.visible = false
		else:
			_status_label.text = "\n".join(lines)
			_status_label.visible = true

	show()

## Collect the status_name values from any ApplyStatusEffect effects on the card.
func _collect_status_names(card: Card) -> Array[String]:
	var names: Array[String] = []
	for effect in card.effects:
		if effect is ApplyStatusEffect:
			var ase: ApplyStatusEffect = effect as ApplyStatusEffect
			if ase.status_effect_resource != null:
				var sname: String = ase.status_effect_resource.status_name
				if sname != "" and sname not in names:
					names.append(sname)
	return names
