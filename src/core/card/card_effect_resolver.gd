class_name CardEffectResolver
extends RefCounted

## Deterministic interpreter for typed card effect references.

const EFFECT_DEAL_DAMAGE: StringName = &"deal_damage"
const EFFECT_HEAL_UNIT: StringName = &"heal_unit"
const EFFECT_MOVE_UNIT_ADJACENT: StringName = &"move_unit_adjacent"
const EFFECT_CANCEL_ORIGINAL: StringName = &"cancel_original"


## Returns true when the effect id is an MVP-supported schema.
static func is_supported_effect_id(effect_id: StringName) -> bool:
	return [
		EFFECT_DEAL_DAMAGE,
		EFFECT_HEAL_UNIT,
		EFFECT_MOVE_UNIT_ADJACENT,
		EFFECT_CANCEL_ORIGINAL,
	].has(effect_id)


## Returns true when params match the required effect schema.
static func params_match_effect(effect_id: StringName, params: EffectParams) -> bool:
	if effect_id == EFFECT_DEAL_DAMAGE:
		return params is DamageEffectParams
	if effect_id == EFFECT_HEAL_UNIT:
		return params is HealEffectParams
	if effect_id == EFFECT_MOVE_UNIT_ADJACENT:
		return params is MoveUnitEffectParams
	if effect_id == EFFECT_CANCEL_ORIGINAL:
		return params is CancelOriginalEffectParams
	return false


## Resolves all effect refs on a card definition against the current match state.
func resolve_card_effects(definition: CardDefinition, state: MatchState, source_item: StackItem) -> Array[String]:
	var events: Array[String] = []
	if definition == null:
		events.append("effect_batch_fizzled:missing_definition")
		return events
	if source_item == null:
		events.append("effect_batch_fizzled:missing_source_item")
		return events
	for effect_ref: EffectRef in definition.effect_refs:
		events.append_array(resolve_effect_ref(effect_ref, state, source_item))
	return events


## Resolves one effect ref against the current match state.
func resolve_effect_ref(effect_ref: EffectRef, state: MatchState, source_item: StackItem) -> Array[String]:
	if effect_ref == null:
		return _single_event("effect_fizzled:null_effect_ref")
	if state == null:
		return _single_event("effect_fizzled:missing_state")
	if source_item == null:
		return _single_event("effect_fizzled:missing_source_item")
	if effect_ref.effect_id == EFFECT_CANCEL_ORIGINAL:
		return _resolve_cancel_original(effect_ref, state, source_item)
	if effect_ref.effect_id == EFFECT_DEAL_DAMAGE:
		return _resolve_deal_damage(effect_ref, state, source_item)
	if effect_ref.effect_id == EFFECT_HEAL_UNIT:
		return _resolve_heal_unit(effect_ref, state, source_item)
	if effect_ref.effect_id == EFFECT_MOVE_UNIT_ADJACENT:
		return _resolve_move_unit_adjacent(effect_ref, state, source_item)
	return _single_event("effect_fizzled:unsupported_runtime_effect:%s" % effect_ref.effect_id)


func _resolve_deal_damage(effect_ref: EffectRef, state: MatchState, source_item: StackItem) -> Array[String]:
	var params := effect_ref.params as DamageEffectParams
	if params == null:
		return _single_event("effect_fizzled:deal_damage:invalid_params")
	if source_item.target_id == &"":
		return _damage_player_life(state, source_item.actor_player_id, params.amount)
	var unit: UnitInstance = state.board.find_unit(source_item.target_id)
	if unit == null:
		return _single_event("effect_fizzled:deal_damage:unknown_target:%s" % source_item.target_id)
	unit.health -= params.amount
	if unit.health <= 0:
		var removed_unit: UnitInstance = state.board.remove_unit(source_item.target_id)
		if removed_unit != null:
			return [
				"unit_damaged:%s:%d" % [source_item.target_id, params.amount],
				"unit_destroyed:%s" % removed_unit.unit_instance_id,
			]
	return ["unit_damaged:%s:%d" % [source_item.target_id, params.amount]]


func _resolve_heal_unit(effect_ref: EffectRef, state: MatchState, source_item: StackItem) -> Array[String]:
	var params := effect_ref.params as HealEffectParams
	if params == null:
		return _single_event("effect_fizzled:heal_unit:invalid_params")
	if source_item.target_id == &"":
		return _single_event("effect_fizzled:heal_unit:missing_target")
	var unit: UnitInstance = state.board.find_unit(source_item.target_id)
	if unit == null:
		return _single_event("effect_fizzled:heal_unit:unknown_target:%s" % source_item.target_id)
	unit.health = min(unit.health + params.amount, unit.max_health)
	return ["unit_healed:%s:%d" % [source_item.target_id, params.amount]]


func _resolve_move_unit_adjacent(effect_ref: EffectRef, state: MatchState, source_item: StackItem) -> Array[String]:
	var params := effect_ref.params as MoveUnitEffectParams
	if params == null:
		return _single_event("effect_fizzled:move_unit_adjacent:invalid_params")
	if source_item.target_id == &"":
		return _single_event("effect_fizzled:move_unit_adjacent:missing_target")
	var from_lane: StringName = state.board.find_unit_lane(source_item.target_id)
	if from_lane == &"":
		return _single_event("effect_fizzled:move_unit_adjacent:unknown_unit:%s" % source_item.target_id)
	var lane_candidates: Array[StringName] = []
	var lane_order: Array = state.board.lane_order
	var current_index: int = lane_order.find(from_lane)
	if current_index < 0:
		return _single_event("effect_fizzled:move_unit_adjacent:invalid_lane_state")
	if params.allow_non_adjacent:
		for lane_id: StringName in lane_order:
			if lane_id != from_lane:
				lane_candidates.append(lane_id)
	else:
		if current_index > 0:
			lane_candidates.append(lane_order[current_index - 1])
		if current_index < lane_order.size() - 1:
			lane_candidates.append(lane_order[current_index + 1])
	for lane_id: StringName in lane_candidates:
		if state.board.move_unit(source_item.target_id, lane_id):
			return ["unit_moved:%s:%s:%s" % [source_item.target_id, from_lane, lane_id]]
	return _single_event("effect_fizzled:move_unit_adjacent:no_adjacent_slot")


func _damage_player_life(state: MatchState, source_player_id: StringName, amount: int) -> Array[String]:
	if amount < 0:
		return _single_event("effect_fizzled:deal_damage:negative_amount")
	var target_player: StringName = _opponent_of(source_player_id, state.player_ids)
	if target_player == &"":
		return _single_event("effect_fizzled:deal_damage:missing_target_player")
	if not state.board.player_life_by_id.has(target_player):
		return _single_event("effect_fizzled:deal_damage:invalid_target_player:%s" % target_player)
	state.board.player_life_by_id[target_player] -= amount
	return ["player_damaged:%s:%d" % [target_player, amount]]


func _opponent_of(player_id: StringName, player_ids: Array[StringName]) -> StringName:
	for candidate_id: StringName in player_ids:
		if candidate_id != player_id:
			return candidate_id
	return &""


func _resolve_cancel_original(effect_ref: EffectRef, state: MatchState, source_item: StackItem) -> Array[String]:
	if state == null or not state.response_window.is_open():
		return _single_event("effect_fizzled:cancel_original:no_response_window")
	if state.response_window.original_item == null:
		return _single_event("effect_fizzled:cancel_original:missing_original")
	var params := effect_ref.params as CancelOriginalEffectParams
	if params == null:
		return _single_event("effect_fizzled:cancel_original:invalid_params")
	var original: StackItem = state.response_window.original_item
	if not _allows_command_type(params, original.command_type):
		return _single_event("effect_fizzled:cancel_original:disallowed_command:%s" % original.command_type)
	original.canceled = true
	original.outcome_reason = &"canceled_by_response"
	source_item.resolved = true
	source_item.outcome_reason = &"resolved"
	return _single_event("effect_resolved:cancel_original:%s" % original.command_id)


func _allows_command_type(params: CancelOriginalEffectParams, command_type: StringName) -> bool:
	return params.allowed_command_types.is_empty() or params.allowed_command_types.has(command_type)


func _single_event(event_text: String) -> Array[String]:
	var events: Array[String] = []
	events.append(event_text)
	return events
