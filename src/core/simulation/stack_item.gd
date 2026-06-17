class_name StackItem
extends RefCounted

## Deterministic record for one pending or resolving stack item.

const KIND_ORIGINAL: StringName = &"original"
const KIND_RESPONSE: StringName = &"response"

var item_kind: StringName = KIND_ORIGINAL
var command_id: StringName = &""
var actor_player_id: StringName = &""
var command_type: StringName = &""
var card_id: StringName = &""
var target_id: StringName = &""
var target_lane: StringName = &""
var canceled: bool = false
var fizzled: bool = false
var resolved: bool = false
var outcome_reason: StringName = &"pending"


## Creates a stack item snapshot from an accepted command.
static func from_command(kind: StringName, command: ActionCommand) -> StackItem:
	var item := StackItem.new()
	item.item_kind = kind
	item.command_id = command.command_id
	item.actor_player_id = command.actor_player_id
	item.command_type = command.command_type
	item.card_id = command.card_id
	item.target_id = command.target_id
	item.target_lane = command.target_lane
	return item


## Returns deterministic stack item data.
func to_canonical_data() -> Dictionary:
	return {
		"actor_player_id": actor_player_id,
		"canceled": canceled,
		"card_id": card_id,
		"command_id": command_id,
		"command_type": command_type,
		"fizzled": fizzled,
		"item_kind": item_kind,
		"outcome_reason": outcome_reason,
		"resolved": resolved,
		"target_id": target_id,
		"target_lane": target_lane,
	}
