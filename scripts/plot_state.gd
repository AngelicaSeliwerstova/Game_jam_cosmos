class_name PlotState
extends RefCounted
## Mutable state of one planting bed. Owned by GameState, never shared between beds.

var planted: bool = false
var growth: int = 0
var watered_today: bool = false


func plant() -> void:
	planted = true
	growth = 0
	watered_today = false


func clear() -> void:
	planted = false
	growth = 0
	watered_today = false
