class_name StableHash
extends RefCounted

## Utility for deterministic canonical serialization and stable hashing.
## This is intentionally independent from Godot scene state.


## Returns a deterministic string representation for supported simulation data.
static func canonical_string(value: Variant) -> String:
	match typeof(value):
		TYPE_NIL:
			return "null"
		TYPE_BOOL:
			return "true" if value else "false"
		TYPE_INT:
			return str(value)
		TYPE_FLOAT:
			return str(value)
		TYPE_STRING:
			return JSON.stringify(value)
		TYPE_STRING_NAME:
			return JSON.stringify(str(value))
		TYPE_ARRAY:
			var parts: Array[String] = []
			for item: Variant in value:
				parts.append(canonical_string(item))
			return "[" + ",".join(parts) + "]"
		TYPE_DICTIONARY:
			var keys: Array = value.keys()
			keys.sort_custom(func(a: Variant, b: Variant) -> bool: return str(a) < str(b))
			var parts: Array[String] = []
			for key: Variant in keys:
				parts.append(JSON.stringify(str(key)) + ":" + canonical_string(value[key]))
			return "{" + ",".join(parts) + "}"
		TYPE_OBJECT:
			if value != null and value.has_method("to_canonical_data"):
				return canonical_string(value.to_canonical_data())
			return JSON.stringify(str(value))
		_:
			return JSON.stringify(str(value))


## Returns a SHA-256 hash for the canonical representation.
static func stable_hash(value: Variant) -> String:
	var text: String = canonical_string(value)
	return text.sha256_text()
