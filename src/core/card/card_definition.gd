class_name CardDefinition
extends Resource

## Immutable source definition for a playable card.
## Runtime card instances must reference this by card_id instead of copying mutable data.

const TYPE_UNIT: StringName = &"unit"
const TYPE_SPELL: StringName = &"spell"
const TYPE_RESPONSE: StringName = &"response"

const SPEED_MAIN: StringName = &"main"
const SPEED_RESPONSE: StringName = &"response"

const STATUS_ACTIVE: StringName = &"active"
const STATUS_PROTOTYPE: StringName = &"prototype"
const STATUS_DISABLED: StringName = &"disabled"
const STATUS_DEPRECATED: StringName = &"deprecated"

@export var card_id: StringName = &""
@export var schema_version: int = 1
@export var name_key: StringName = &""
@export var rules_text_key: StringName = &""
@export var card_type: StringName = TYPE_SPELL
@export var speed: StringName = SPEED_MAIN
@export var base_cost: int = 0
@export var unit_attack: int = 0
@export var unit_health: int = 0
@export var targeting_profile_id: StringName = &""
@export var effect_refs: Array[EffectRef] = []
@export var tags: Array[StringName] = []
@export var status: StringName = STATUS_PROTOTYPE
@export var art_key: StringName = &""
@export var frame_key: StringName = &""
@export var audio_key: StringName = &""


## Returns deterministic data for card-data hashing.
func to_canonical_data() -> Dictionary:
	var effect_data: Array = []
	for effect_ref: EffectRef in effect_refs:
		effect_data.append(effect_ref.to_canonical_data() if effect_ref != null else {})
	var tag_data: Array[String] = []
	for tag: StringName in tags:
		tag_data.append(str(tag))
	tag_data.sort()
	return {
		"art_key": art_key,
		"audio_key": audio_key,
		"base_cost": base_cost,
		"card_id": card_id,
		"card_type": card_type,
		"effect_refs": effect_data,
		"frame_key": frame_key,
		"name_key": name_key,
		"rules_text_key": rules_text_key,
		"schema_version": schema_version,
		"speed": speed,
		"status": status,
		"tags": tag_data,
		"targeting_profile_id": targeting_profile_id,
		"unit_attack": unit_attack,
		"unit_health": unit_health,
	}


## Returns validation errors for this card definition.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if card_id == &"":
		errors.append("card_id is required")
	if schema_version < 1:
		errors.append("schema_version must be >= 1")
	if name_key == &"":
		errors.append("%s: name_key is required" % card_id)
	if rules_text_key == &"":
		errors.append("%s: rules_text_key is required" % card_id)
	if not [TYPE_UNIT, TYPE_SPELL, TYPE_RESPONSE].has(card_type):
		errors.append("%s: unsupported card_type %s" % [card_id, card_type])
	if not [SPEED_MAIN, SPEED_RESPONSE].has(speed):
		errors.append("%s: unsupported speed %s" % [card_id, speed])
	if base_cost < 0:
		errors.append("%s: base_cost cannot be negative" % card_id)
	if card_type == TYPE_UNIT:
		if unit_attack < 0:
			errors.append("%s: unit_attack cannot be negative" % card_id)
		if unit_health <= 0:
			errors.append("%s: unit_health must be positive for unit cards" % card_id)
	if targeting_profile_id == &"":
		errors.append("%s: targeting_profile_id is required" % card_id)
	if not [STATUS_ACTIVE, STATUS_PROTOTYPE, STATUS_DISABLED, STATUS_DEPRECATED].has(status):
		errors.append("%s: unsupported status %s" % [card_id, status])
	for effect_ref: EffectRef in effect_refs:
		if effect_ref == null:
			errors.append("%s: effect_refs cannot contain null" % card_id)
		else:
			for error: String in effect_ref.validate():
				errors.append("%s: %s" % [card_id, error])
	return errors
