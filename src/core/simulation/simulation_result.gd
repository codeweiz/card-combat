class_name SimulationResult
extends RefCounted

## Result returned by simulation initialization and command submission.

var accepted: bool = false
var error_code: StringName = &""
var message: String = ""
var state_hash: String = ""
var events: Array[String] = []


## Creates an accepted result.
static func accepted_result(hash_value: String, result_events: Array[String] = []) -> SimulationResult:
	var result := SimulationResult.new()
	result.accepted = true
	result.state_hash = hash_value
	result.events = result_events
	return result


## Creates a rejected result.
static func rejected_result(code: StringName, reason: String, hash_value: String = "") -> SimulationResult:
	var result := SimulationResult.new()
	result.accepted = false
	result.error_code = code
	result.message = reason
	result.state_hash = hash_value
	return result
