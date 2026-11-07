extends Node
## Prototype game session: day, shared supplies and one PlotState per bed.
## Autoloaded as GameState. Every mutation goes through this node, so resources
## cannot be spent twice by a duplicated UI action.

signal changed

const START_DAY: int = 1
const START_SEEDS: int = 6
const START_WATER: int = 24
const PLOT_COUNT: int = 6
const GROWTH_PER_NIGHT: int = 1
const READY_GROWTH: int = 2
const HARVEST_SEEDS: int = 2

var day: int = START_DAY
var seeds: int = START_SEEDS
var water: int = START_WATER
var plots: Array[PlotState] = []


func _ready() -> void:
	reset()


func reset() -> void:
	day = START_DAY
	seeds = START_SEEDS
	water = START_WATER
	plots.clear()
	for _i: int in range(PLOT_COUNT):
		plots.append(PlotState.new())
	changed.emit()


func get_plot(index: int) -> PlotState:
	if index < 0 or index >= plots.size():
		return null
	return plots[index]


func is_ready(index: int) -> bool:
	var plot: PlotState = get_plot(index)
	return plot != null and plot.planted and plot.growth >= READY_GROWTH


func can_plant(index: int) -> bool:
	var plot: PlotState = get_plot(index)
	return plot != null and not plot.planted and seeds > 0


func can_water(index: int) -> bool:
	var plot: PlotState = get_plot(index)
	return (
		plot != null
		and plot.planted
		and not is_ready(index)
		and not plot.watered_today
		and water > 0
	)


func can_harvest(index: int) -> bool:
	return is_ready(index)


func plant(index: int) -> bool:
	if not can_plant(index):
		return false
	seeds -= 1
	get_plot(index).plant()
	changed.emit()
	return true


func water_plot(index: int) -> bool:
	if not can_water(index):
		return false
	water -= 1
	get_plot(index).watered_today = true
	changed.emit()
	return true


func harvest(index: int) -> int:
	if not can_harvest(index):
		return 0
	get_plot(index).clear()
	seeds += HARVEST_SEEDS
	changed.emit()
	return HARVEST_SEEDS


func sleep() -> Dictionary:
	## Resolve exactly one night and return the short report for the sleep panel.
	var grown: int = 0
	var thirsty: int = 0
	for index: int in range(plots.size()):
		var plot: PlotState = plots[index]
		if not plot.planted:
			continue
		if plot.watered_today and not is_ready(index):
			plot.growth = mini(plot.growth + GROWTH_PER_NIGHT, READY_GROWTH)
			grown += 1
		elif not plot.watered_today and not is_ready(index):
			thirsty += 1
		plot.watered_today = false

	day += 1
	var ready: int = 0
	for plot: PlotState in plots:
		if plot.planted and plot.growth >= READY_GROWTH:
			ready += 1

	changed.emit()
	return {"grown": grown, "thirsty": thirsty, "ready": ready}
