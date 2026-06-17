class_name EffectRef
extends Resource

## Immutable reference from a card definition to an effect schema plus typed params.

@export var effect_id: StringName = &""
@export var params: EffectParams


## Returns deterministic data for card hashing.
func to_canonical_data() -> Dictionary:
	return {
		"effect_id": effect_id,
		"params": params.to_canonical_data() if params != null else {},
	}


## Returns validation errors for this effect reference.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if effect_id == &"":
		errors.append("effect_id is required")
	elif not CardEffectResolver.is_supported_effect_id(effect_id):
		errors.append("unsupported effect_id %s" % effect_id)
	elif not CardEffectResolver.params_match_effect(effect_id, params):
		errors.append("%s params do not match required effect schema" % effect_id)
	if params != null:
		errors.append_array(params.validate())
	return errors
