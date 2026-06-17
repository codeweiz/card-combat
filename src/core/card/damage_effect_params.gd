class_name DamageEffectParams
extends EffectParams

## Typed params for integer damage effects.

const MAX_DAMAGE_AMOUNT_MVP: int = 10

@export var amount: int = 0


## Returns deterministic data used by card-data hashing and validation.
func to_canonical_data() -> Dictionary:
	return {
		"amount": amount,
	}


## Returns validation errors for this damage parameter object.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if amount < 0:
		errors.append("damage amount cannot be negative")
	if amount > MAX_DAMAGE_AMOUNT_MVP:
		errors.append("damage amount exceeds MVP cap %d" % MAX_DAMAGE_AMOUNT_MVP)
	return errors
