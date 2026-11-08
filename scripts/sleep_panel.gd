class_name SleepPanel
extends CanvasLayer

signal confirmed
signal closed(from_click: bool)

@onready var overlay: Control = $Overlay
@onready var confirm_view: Control = %ConfirmView
@onready var confirm_title: Label = %ConfirmTitle
@onready var report_view: Control = %ReportView
@onready var report_title: Label = %ReportTitle
@onready var report_text: Label = %ReportText
@onready var hint: Label = %Hint
@onready var sleep_button: Button = %SleepButton
@onready var cancel_button: Button = %CancelButton
@onready var continue_button: Button = %ContinueButton

var _confirming: bool = false


func open_confirmation(day: int) -> void:
	_confirming = true
	confirm_title.text = "Завершить день %d?" % day
	confirm_view.show()
	report_view.hide()
	hint.text = "E — подтвердить   ·   Esc — отмена"
	overlay.show()
	sleep_button.disabled = false
	sleep_button.grab_focus()


func is_open() -> bool:
	return overlay.visible


func is_confirming() -> bool:
	return overlay.visible and _confirming


func confirm() -> void:
	if not is_confirming():
		return
	_confirming = false
	overlay.hide()
	confirmed.emit()


func show_report(day: int, report: Dictionary) -> void:
	_confirming = false
	report_title.text = "День %d" % day
	report_text.text = (
		"Выросло растений: %d\n"
		+ "Без полива осталось: %d\n"
		+ "Готово к сбору: %d"
	) % [report.grown, report.thirsty, report.ready]
	confirm_view.hide()
	report_view.show()
	hint.text = "E / Esc — продолжить"
	overlay.show()
	continue_button.grab_focus()


func close(from_click: bool = false) -> void:
	if not overlay.visible:
		return
	_confirming = false
	overlay.hide()
	closed.emit(from_click)


func _on_sleep_pressed() -> void:
	confirm()


func _on_cancel_pressed() -> void:
	close(true)


func _on_continue_pressed() -> void:
	close(true)
