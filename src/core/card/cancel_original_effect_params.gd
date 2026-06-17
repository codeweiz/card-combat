class_name CancelOriginalEffectParams
extends EffectParams

## Typed params for response effects that cancel the pending original stack item.

@export var allowed_command_types: Array[StringName] = []


## Returns deterministic data used by card-data hashing and validation.
func to_canonical_data() -> Dictionary:
	var command_types: Array[String] = []
	for command_type: StringName in allowed_command_types:
		command_types.append(str(command_type))
	command_types.sort()
	return {
		"allowed_command_types": command_types,
	}


## Returns validation errors for this cancel parameter object.
func validate() -> Array[String]:
	var errors: Array[String] = []
	for command_type: StringName in allowed_command_types:
		if command_type == &"":
			errors.append("allowed_command_types cannot contain empty command type")
	return errors
