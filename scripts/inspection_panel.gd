class_name InspectionPanel
extends CanvasLayer

signal closed(from_click: bool)

const GROWTH_NAMES: Array[String] = ["Росток", "Молодое растение", "Взрослое растение"]

@onready var overlay: Control = $Overlay
@onready var title: Label = %Title
@onready var status: Label = %Status
@onready var action_button: Button = %ActionButton
@onready var reason: Label = %Reason
@onready var close_button: Button = %CloseButton

var _slot_number: int = 1
var game_state


func _ready() -> void:
	game_state = get_node_or_null("/root/GameState")


func open(slot_number: int) -> void:
	_slot_number = slot_number
	title.text = "Грядка № %d" % slot_number
	overlay.show()
	_refresh()
	if action_button.disabled:
		close_button.grab_focus()
	else:
		action_button.grab_focus()


func is_open() -> bool:
	return overlay.visible


func close(from_click: bool = false) -> void:
	overlay.hide()
	closed.emit(from_click)


func _refresh() -> void:
	if game_state == null:
		return
	var index: int = _slot_number - 1
	var plot: PlotState = game_state.get_plot(index)
	if plot == null:
		return

	if not plot.planted:
		status.text = "Пустая грядка"
		action_button.text = "Посадить · 1 семя"
		action_button.disabled = not game_state.can_plant(index)
		if game_state.seeds <= 0:
			reason.text = "Нет семян одуванчика."
		else:
			reason.text = "Свободная грядка готова к посадке."
	elif game_state.is_ready(index):
		status.text = "Взрослое растение · готово к сбору"
		action_button.text = "Собрать · +%d семени" % game_state.HARVEST_SEEDS
		action_button.disabled = false
		reason.text = "Сбор освободит грядку и вернёт семена."
	elif plot.watered_today:
		status.text = "%s · полито сегодня" % _growth_name(plot.growth)
		action_button.text = "Полить · 1 вода"
		action_button.disabled = true
		reason.text = "Уже полито сегодня. Рост произойдёт только после сна."
	else:
		status.text = "%s · не полито" % _growth_name(plot.growth)
		action_button.text = "Полить · 1 вода"
		action_button.disabled = not game_state.can_water(index)
		if game_state.water <= 0:
			reason.text = "Нет воды."
		else:
			reason.text = "Полив даст рост следующей ночью."

	if action_button.disabled and overlay.visible and not close_button.has_focus():
		close_button.grab_focus()


func _growth_name(growth: int) -> String:
	return GROWTH_NAMES[clampi(growth, 0, GROWTH_NAMES.size() - 1)]


func _on_action_pressed() -> void:
	if game_state == null:
		return
	var index: int = _slot_number - 1
	var plot: PlotState = game_state.get_plot(index)
	if plot == null:
		return
	if not plot.planted:
		game_state.plant(index)
	elif game_state.is_ready(index):
		game_state.harvest(index)
	else:
		game_state.water_plot(index)
	_refresh()


func _on_close_button_down() -> void:
	close(true)
