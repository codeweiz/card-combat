class_name CardValidationReport
extends RefCounted

## Validation result for card data loading.

var errors: Array[String] = []
var warnings: Array[String] = []


## Returns true when no blocking validation errors were found.
func is_valid() -> bool:
	return errors.is_empty()


## Adds a blocking validation error.
func add_error(message: String) -> void:
	errors.append(message)


## Adds a non-blocking validation warning.
func add_warning(message: String) -> void:
	warnings.append(message)


## Returns a human-readable summary.
func summarize() -> String:
	return "CardValidationReport(valid=%s, errors=%d, warnings=%d)" % [is_valid(), errors.size(), warnings.size()]
