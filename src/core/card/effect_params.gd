class_name EffectParams
extends Resource

## Base class for typed effect parameter resources.
## Concrete effect systems should subclass this instead of storing raw dictionaries.


## Returns deterministic data used by card-data hashing and validation.
func to_canonical_data() -> Dictionary:
	return {}


## Returns validation errors for this parameter object.
func validate() -> Array[String]:
	return []
