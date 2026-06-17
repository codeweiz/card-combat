class_name MatchSetup
extends RefCounted

## Immutable setup payload used to initialize a deterministic match.

var rule_set_version: int = 1
var card_data_hash: String = ""
var player_ids: Array[StringName] = []
var initial_seed: int = 0
var format_id: StringName = &"mvp_local"


## Returns deterministic data for match initialization.
func to_canonical_data() -> Dictionary:
	var players: Array[String] = []
	for player_id: StringName in player_ids:
		players.append(str(player_id))
	return {
		"card_data_hash": card_data_hash,
		"format_id": format_id,
		"initial_seed": initial_seed,
		"player_ids": players,
		"rule_set_version": rule_set_version,
	}
