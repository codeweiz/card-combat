class_name MoveUnitEffectParams
extends EffectParams

## Typed params for lane movement effects.

@export var allow_non_adjacent: bool = false


## Returns deterministic data used by card-data hashing and validation.
func to_canonical_data() -> Dictionary:
	return {
		"allow_non_adjacent": allow_non_adjacent,
	}


## Returns validation errors for this movement parameter object.
func validate() -> Array[String]:
	return []
