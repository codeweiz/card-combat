class_name CardDatabase
extends RefCounted

## In-memory card definition database with deterministic validation and hashing.

var _definitions: Dictionary = {}


## Adds a card definition if its id is unique.
func add_definition(definition: CardDefinition) -> bool:
	if definition == null:
		return false
	if definition.card_id == &"":
		return false
	if _definitions.has(definition.card_id):
		return false
	_definitions[definition.card_id] = definition
	return true


## Returns the card definition for the given id, or null if missing.
func get_card_definition(card_id: StringName) -> CardDefinition:
	return _definitions.get(card_id, null)


## Returns all card ids sorted by their string value.
func get_card_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for key: Variant in _definitions.keys():
		ids.append(key)
	ids.sort_custom(func(a: StringName, b: StringName) -> bool: return str(a) < str(b))
	return ids


## Validates the currently loaded card definitions.
func validate() -> CardValidationReport:
	var report := CardValidationReport.new()
	for card_id: StringName in get_card_ids():
		var definition: CardDefinition = _definitions[card_id]
		for error: String in definition.validate():
			report.add_error(error)
	if _definitions.is_empty():
		report.add_warning("Card database is empty")
	return report


## Returns canonical data for hashing and diagnostics.
func to_canonical_data() -> Dictionary:
	var cards: Array = []
	for card_id: StringName in get_card_ids():
		cards.append(_definitions[card_id].to_canonical_data())
	return {
		"cards": cards,
		"count": cards.size(),
	}


## Returns a deterministic hash for the loaded card data.
func get_card_data_hash() -> String:
	return StableHash.stable_hash(to_canonical_data())
