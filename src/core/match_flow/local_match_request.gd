class_name LocalMatchRequest
extends RefCounted

## Public request shape for local MVP match start.
## Keep this narrow: exactly two validated loadouts are required.

const DEFAULT_FORMAT: StringName = &"mvp_local"

var match_id: StringName = &""
var rule_set_version: int = 1
var format_id: StringName = DEFAULT_FORMAT
var initial_seed: int = 0
var player_ids: Array[StringName] = []
var player_loadouts: Array = []
var card_data_hash: String = ""


## Returns deterministic request data for reproducible flow setup.
func to_canonical_data() -> Dictionary:
	var players: Array[String] = []
	for player_id: StringName in player_ids:
		players.append(str(player_id))
	var loadouts: Array = []
	for loadout in player_loadouts:
		loadouts.append(loadout.to_canonical_data())
	return {
		"card_data_hash": card_data_hash,
		"format_id": str(format_id),
		"initial_seed": initial_seed,
		"match_id": str(match_id),
		"player_ids": players,
		"player_loadouts": loadouts,
		"rule_set_version": rule_set_version,
	}
