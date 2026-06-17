class_name ResponseWindowState
extends RefCounted

## Deterministic state for the current MVP response window.

const STATE_CLOSED: StringName = &"closed"
const STATE_OPEN: StringName = &"open"
const STATE_RESOLVING: StringName = &"resolving"
const MAX_RESPONSES_PER_WINDOW_MVP: int = 1

var window_state: StringName = STATE_CLOSED
var window_id: StringName = &""
var defender_player_id: StringName = &""
var original_item: StackItem
var response_item: StackItem
var responses_used: int = 0


## Opens a response window around a pending original command.
func open_for_original(next_window_index: int, original_command: ActionCommand, defender_id: StringName) -> void:
	window_state = STATE_OPEN
	window_id = StringName("response_window_%04d" % next_window_index)
	defender_player_id = defender_id
	original_item = StackItem.from_command(StackItem.KIND_ORIGINAL, original_command)
	response_item = null
	responses_used = 0


## Clears all transient response-window state.
func clear() -> void:
	window_state = STATE_CLOSED
	window_id = &""
	defender_player_id = &""
	original_item = null
	response_item = null
	responses_used = 0


## Returns true while the defender must respond or pass.
func is_open() -> bool:
	return window_state == STATE_OPEN


## Returns true if this player currently owns response priority.
func has_priority(player_id: StringName) -> bool:
	return is_open() and defender_player_id == player_id


## Returns true if another response can be accepted in this window.
func can_accept_response(player_id: StringName) -> bool:
	return has_priority(player_id) and responses_used < MAX_RESPONSES_PER_WINDOW_MVP


## Returns deterministic response-window data.
func to_canonical_data() -> Dictionary:
	return {
		"defender_player_id": defender_player_id,
		"original_item": original_item.to_canonical_data() if original_item != null else null,
		"response_item": response_item.to_canonical_data() if response_item != null else null,
		"responses_used": responses_used,
		"window_id": window_id,
		"window_state": window_state,
	}
