class_name PlayerDeckLoadout
extends RefCounted

## Immutable deck loadout bound to a player identity.
## This is the minimum local-match payload required to bind deck cards
## to deterministic opening/deck-zone simulation.

var player_id: StringName = &""
var deck_id: StringName = &""
var deck_fingerprint: String = ""
var ordered_card_ids: Array[StringName] = []
var declared_archetype_tags: Array[StringName] = []


## Returns deterministic deck-loadout data for replay and setup canonicalization.
func to_canonical_data() -> Dictionary:
	var ordered_cards: Array[String] = []
	for card_id: StringName in ordered_card_ids:
		ordered_cards.append(str(card_id))
	var archetypes: Array[String] = []
	for tag: StringName in declared_archetype_tags:
		archetypes.append(str(tag))
	archetypes.sort()
	return {
		"archetypes": archetypes,
		"deck_fingerprint": deck_fingerprint,
		"deck_id": str(deck_id),
		"ordered_card_ids": ordered_cards,
		"player_id": str(player_id),
	}
