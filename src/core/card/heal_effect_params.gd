class_name HealEffectParams
extends EffectParams

## Typed params for integer unit healing effects.

const MAX_HEAL_AMOUNT_MVP: int = 10

@export var amount: int = 0


## Returns deterministic data used by card-data hashing and validation.
func to_canonical_data() -> Dictionary:
	return {
		"amount": amount,
	}


## Returns validation errors for this heal parameter object.
func validate() -> Array[String]:
	var errors: Array[String] = []
	if amount < 0:
		errors.append("heal amount cannot be negative")
	if amount > MAX_HEAL_AMOUNT_MVP:
		errors.append("heal amount exceeds MVP cap %d" % MAX_HEAL_AMOUNT_MVP)
	return errors
