## Where the Hud's movable parts go in the map area (map-overview-build-spec.md R20, R22): the Return button, the goods
## card, the Goods legend, the open action log's card and the toasts. All rects are screen px. The Return button sits in
## the middle of the map area's foot, and above the minimap where that foot has no room for it. The goods card sits bottom
## left, above the log's button; where it would run into something it takes another layout (no "soon" rows, more or fewer
## columns, fewer rows with a scroll bar), the legend moving out of its way before the card leaves its place; where there
## is no room for both the legend is left out. The log's open card and the toasts move clear of the card; the setting
## that holds the log open is not touched.
class_name HudLayout
extends RefCounted

const GAP := float(Tokens.S1)
## The card's and the legend's left edge in the map area.
const LEFT := 12.0
## The card's foot above the map area's, clear of the action log's button.
const CARD_FOOT := 94.0
## The Return button's foot above the map area's, and its height, as in hud.tscn.
const RETURN_FOOT := 46.0
const RETURN_H := 32.0
## The Return button keeps right of the action log's button.
const RETURN_LEFT_MIN := 60.0
## Half the toasts' width at home, as in hud.tscn.
const TOASTS_HALF := 220.0
## The open log card's heights, the full one first.
const LOG_HEIGHTS: Array[float] = [float(ActionLog.CARD_H), 220.0, 180.0, 140.0]
## The card's layouts, best first (GoodsCard.set_layout: columns, the soon rows or not, rows of buttons shown, 0 all):
## the FIRST_SCROLLED that show every good, then those that scroll, and from FIRST_NARROW the last resorts (a single row,
## or two columns).
const LAYOUTS: Array[Vector3i] = [
	Vector3i(6, 1, 0), Vector3i(6, 0, 0), Vector3i(8, 0, 0), Vector3i(5, 0, 0), Vector3i(4, 0, 0),
	Vector3i(6, 0, 2), Vector3i(5, 0, 3), Vector3i(4, 0, 3), Vector3i(3, 0, 4), Vector3i(5, 0, 2), Vector3i(4, 0, 2),
	Vector3i(3, 0, 3), Vector3i(3, 0, 2),
	Vector3i(4, 0, 1), Vector3i(3, 0, 1), Vector3i(2, 0, 3), Vector3i(2, 0, 2), Vector3i(2, 0, 1)]
const FIRST_SCROLLED := 5
const FIRST_NARROW := 13
## Past the last layout.
const END := 99
## What a pass of goods_plan does with the card and the legend: HOME has both at home, KEEP has the card at home and puts
## the legend where it then fits, STAYS leaves the legend at home and moves the card, MOVES puts the card at the top left
## and the legend where it then fits, OUT leaves the legend out.
enum Legend { HOME, KEEP, STAYS, MOVES, OUT }
## The passes, best first: [the first layout, the one after the last, what becomes of the legend].
const PASSES: Array[Array] = [
	[0, FIRST_SCROLLED, Legend.HOME], [0, FIRST_SCROLLED, Legend.KEEP], [0, FIRST_SCROLLED, Legend.STAYS],
	[0, FIRST_SCROLLED, Legend.MOVES], [FIRST_SCROLLED, FIRST_NARROW, Legend.KEEP],
	[FIRST_SCROLLED, FIRST_NARROW, Legend.STAYS], [0, FIRST_NARROW, Legend.OUT],
	[FIRST_NARROW, END, Legend.STAYS], [FIRST_NARROW, END, Legend.OUT]]


## Lays the parts out for what `hud` shows now. Safe to call again and again: nothing moves while nothing changed.
static func arrange(layer: CanvasLayer) -> void:
	var hud := layer as Hud
	if not hud.is_inside_tree():
		return
	var area := Hud.screen_rect(hud.map_area())
	var screen := hud.map_area().get_viewport_rect()
	if not area.has_area():  # not laid out yet: the map area's resize asks again
		return
	var corner := _shown([hud.minimap(), hud.zoom_control(), hud.scale_bar()])
	var legend_top := Hud.LEGEND_TOP
	var debug := hud.debug_overlay()
	if debug.visible:
		legend_top = debug.offset_top + debug.size.y + Hud.LEGEND_GAP
	var card := hud.goods_card()
	var goods := card.is_visible_in_tree()
	var legend := hud.mode_legend()
	var legend_home := Rect2(Vector2(area.position.x + LEFT, area.position.y + legend_top),
			legend.get_combined_minimum_size())
	var back := _place_return(hud, area, screen, corner, legend_home if legend.is_wanted() else Rect2())
	if not goods:
		legend.set_crowded(false)
		_move_legend(legend, area, Vector2(area.position.x + LEFT, area.position.y + legend_top))
		hud.action_log().reset_card()
		_place_toasts(hud, area, back, Rect2(), [])
		return
	var left := maxf(area.position.x + LEFT, screen.position.x + GAP)
	var top := Hud.screen_rect(hud.top_bar()).end.y + 2.0
	var bounds := _rect_between(Vector2(left, top), Vector2(minf(area.end.x, screen.end.x), area.end.y) - Vector2(GAP, GAP))
	var taken := corner.duplicate()
	taken.append_array(_shown([hud.task_flag(), hud.key_hints()]))
	taken.append(back)
	taken.append(Hud.screen_rect(hud.action_log()))
	legend_home.position.x = left
	var sizes: Array[Vector2] = []
	for layout: Vector3i in LAYOUTS:
		sizes.append(card.size_for(layout))
	var log_widget := hud.action_log()
	var plan := goods_plan({"bounds": bounds, "taken": taken, "foot": area.end.y - CARD_FOOT, "sizes": sizes,
			"legend": legend_home if legend.is_wanted() else Rect2(),
			"log": log_widget.card_home() if log_widget.is_open() else Rect2()})
	_apply_card(card, area, plan["layout"] as Vector3i, plan["card"] as Rect2)
	var legend_rect := plan["legend"] as Rect2
	legend.set_crowded(legend.is_wanted() and not legend_rect.has_area())
	_move_legend(legend, area, legend_rect.position if legend_rect.has_area() else legend_home.position)
	if log_widget.is_open():
		log_widget.place_card(plan["log"] as Rect2)
	var by_toasts := corner.duplicate()
	by_toasts.append_array(_shown([hud.task_flag()]))
	by_toasts.append(plan["card"] as Rect2)
	if legend_rect.has_area():
		by_toasts.append(legend_rect)
	_place_toasts(hud, area, back, plan["card"] as Rect2, by_toasts)


## The spot for a part of `size` inside `bounds`, GAP clear of every rect of `taken`, the nearest to `near` (a top left
## corner); an empty Rect2 when there is none.
static func free_spot(size: Vector2, bounds: Rect2, taken: Array[Rect2], near: Vector2) -> Rect2:
	var xs: Array[float] = [near.x, bounds.position.x, bounds.end.x - size.x]
	var ys: Array[float] = [near.y, bounds.position.y, bounds.end.y - size.y]
	for r: Rect2 in taken:
		xs.append_array([r.end.x + GAP, r.position.x - GAP - size.x])
		ys.append_array([r.end.y + GAP, r.position.y - GAP - size.y])
	var best := Rect2()
	var best_far := INF
	for x: float in xs:
		for y: float in ys:
			var spot := Rect2(Vector2(x, y), size)
			var far := spot.position.distance_squared_to(near)
			if far < best_far and is_free(spot, bounds, taken):
				best = spot
				best_far = far
	return best


## Whether `spot` is inside `bounds` and GAP clear of every rect of `taken` (half a px of play).
static func is_free(spot: Rect2, bounds: Rect2, taken: Array[Rect2]) -> bool:
	if not bounds.grow(0.5).encloses(spot):
		return false
	for r: Rect2 in taken:
		if r.grow(GAP - 0.5).intersects(spot):
			return false
	return true


## Where the goods card, the legend and the open log card go. `room`: bounds; taken (what the card and the legend keep
## off: the minimap's corner, the task flag, the key hints, then the Return button and the log's button, last); foot (the
## card's foot at home); sizes (of LAYOUTS); legend (its home, empty: none wanted); log (its card's home, empty: closed).
## Returns {layout, card, legend (empty: left out), log (empty: closed)}. Where no layout leaves the open log a free spot,
## one is taken that lets it lie over all but the card and the two buttons; at the last the card is placed first.
static func goods_plan(room: Dictionary) -> Dictionary:
	var taken := room["taken"] as Array[Rect2]
	var buttons: Array[Rect2] = [taken[-2], taken[-1]]
	var plan := _search(room, taken)
	if plan.is_empty() and (room["log"] as Rect2).has_area():
		plan = _search(room, buttons)
	if not plan.is_empty():
		return plan
	var log_home := room["log"] as Rect2
	var without := room.duplicate()
	without["log"] = Rect2()
	plan = _search(without, taken)
	var bounds := room["bounds"] as Rect2
	if plan.is_empty():  # not even the smallest card has a free spot: it goes in the corner, over what is there
		var size := (room["sizes"] as Array[Vector2])[-1]
		plan = {"layout": LAYOUTS[-1], "card": Rect2(bounds.position, size), "legend": Rect2(), "log": Rect2()}
	if log_home.has_area():
		buttons.append(plan["card"] as Rect2)
		plan["log"] = _log_over(buttons, log_home, bounds)
		plan["legend"] = Rect2()
	return plan


## The first pass and layout that find room; the open log card keeps off `log_off`, the card and the legend.
static func _search(room: Dictionary, log_off: Array[Rect2]) -> Dictionary:
	var sizes := room["sizes"] as Array[Vector2]
	for step: Array in PASSES:
		for i: int in range(step[0] as int, mini(step[1] as int, LAYOUTS.size())):
			var plan := _try(room, step[2] as Legend, sizes[i], log_off)
			if not plan.is_empty():
				plan["layout"] = LAYOUTS[i]
				return plan
	return {}


## One size of the card in one pass: {card, legend, log}, or {} when something finds no room.
static func _try(room: Dictionary, how: Legend, size: Vector2, log_off: Array[Rect2]) -> Dictionary:
	var bounds := room["bounds"] as Rect2
	var legend := room["legend"] as Rect2
	var taken: Array[Rect2] = (room["taken"] as Array[Rect2]).duplicate()
	var stays := legend.has_area() and (how == Legend.HOME or how == Legend.STAYS)
	var card_home := how == Legend.HOME or how == Legend.KEEP
	if stays:
		if not is_free(legend, bounds, taken):
			return {}
		taken.append(legend)
	var home := Vector2(bounds.position.x, float(room["foot"]) - size.y)
	var card := Rect2(home, size)
	if card_home:
		if not is_free(card, bounds, taken):
			return {}
	else:
		card = free_spot(size, bounds, taken, bounds.position if how == Legend.MOVES else home)
		if not card.has_area():
			return {}
	taken.append(card)
	var legend_spot := legend if stays else Rect2()
	if (how == Legend.KEEP or how == Legend.MOVES) and legend.has_area():
		legend_spot = free_spot(legend.size, bounds, taken, legend.position)
		if not legend_spot.has_area():
			return {}
		taken.append(legend_spot)
	var log_home := room["log"] as Rect2
	if not log_home.has_area():
		return {"card": card, "legend": legend_spot, "log": Rect2()}
	var off: Array[Rect2] = log_off.duplicate()
	off.append(card)
	if legend_spot.has_area():
		off.append(legend_spot)
	var spot := _log_spot(card, log_home, bounds, off)
	return {"card": card, "legend": legend_spot, "log": spot} if spot.has_area() else {}


## The open log card's free spot, the tallest height first: at home, else beside the goods card at home's height, else
## the free spot nearest home. An empty Rect2 when there is none.
static func _log_spot(card: Rect2, log_home: Rect2, bounds: Rect2, taken: Array[Rect2]) -> Rect2:
	for height: float in LOG_HEIGHTS:
		var size := Vector2(log_home.size.x, height)
		var near := Vector2(log_home.position.x, log_home.end.y - height)
		for at: Vector2 in [near, Vector2(card.end.x + GAP, near.y)]:
			if is_free(Rect2(at, size), bounds, taken):
				return Rect2(at, size)
		var spot := free_spot(size, bounds, taken, near)
		if spot.has_area():
			return spot
	return Rect2()


## Where no layout leaves the open log room: a spot, wider than the map area if it must be, off `keep` (the Return
## button, the log's button, then the goods card); else off the Return button and the card; else off the card; at the
## last, at home at its lowest.
static func _log_over(keep: Array[Rect2], log_home: Rect2, bounds: Rect2) -> Rect2:
	var wide := Rect2(bounds.position, Vector2(maxf(bounds.size.x, log_home.size.x), bounds.size.y))
	var no_log_button: Array[Rect2] = [keep[0], keep[-1]]
	var only_card: Array[Rect2] = [keep[-1]]
	for off: Array[Rect2] in [keep, no_log_button, only_card]:
		var spot := _log_spot(keep[-1], log_home, wide, off)
		if spot.has_area():
			return spot
	var height := LOG_HEIGHTS[-1]
	return Rect2(log_home.position.x, log_home.end.y - height, log_home.size.x, height)


## The Return button: in the middle of the map area's foot, moved left of what it would run into there (the minimap's
## corner); where that leaves no room right of the log's button, above the minimap. Returns its rect, empty while it is
## hidden.
static func _place_return(hud: Hud, area: Rect2, screen: Rect2, corner: Array[Rect2], legend: Rect2) -> Rect2:
	var button := hud.return_button()
	if not button.visible:
		return Rect2()
	var need := button.get_combined_minimum_size()
	need.y = maxf(need.y, RETURN_H)
	var spot := Rect2(Vector2(area.position.x + (area.size.x - need.x) * 0.5, area.end.y - RETURN_FOOT - need.y), need)
	for r: Rect2 in corner:
		if r.position.y < spot.end.y and r.end.y > spot.position.y:
			spot.position.x = minf(spot.position.x, r.position.x - need.x - Tokens.S2)
	if spot.position.x < area.position.x + RETURN_LEFT_MIN:
		spot.position.x = area.position.x + RETURN_LEFT_MIN
		var left := maxf(area.position.x, screen.position.x) + GAP
		var bounds := _rect_between(Vector2(left, area.position.y),
				Vector2(minf(area.end.x, screen.end.x), area.end.y) - Vector2(GAP, GAP))
		var taken := corner.duplicate()
		taken.append_array(_shown([hud.task_flag(), hud.key_hints()]))
		taken.append(Hud.screen_rect(hud.action_log()))
		if not is_free(spot, bounds, taken):
			var above := bounds.end.y
			for r: Rect2 in corner:
				above = minf(above, r.position.y)
			var middle := bounds.get_center().x if corner.is_empty() else corner[0].get_center().x  # the minimap's
			var near := Vector2(middle - need.x * 0.5, above - Tokens.S2 - need.y)
			var with_legend := taken.duplicate()
			if legend.has_area():
				with_legend.append(legend)
			var raised := free_spot(need, bounds, with_legend, near)
			if not raised.has_area():
				raised = free_spot(need, bounds, taken, near)
			if raised.has_area():
				spot = raised
	button.offset_left = spot.position.x - area.position.x
	button.offset_right = button.offset_left + need.x
	button.offset_bottom = spot.end.y - area.end.y
	button.offset_top = button.offset_bottom - need.y
	return spot


## The toasts keep above the Return button: lifted by its height at the foot, and over it where it was raised. Where they
## would lie over the goods card (`card`, empty: not shown) they take the free spot nearest home that keeps off `taken`
## (the card and what else shows; the legend, last, gives way where nothing else is free).
static func _place_toasts(hud: Hud, area: Rect2, back: Rect2, card: Rect2, taken: Array[Rect2]) -> void:
	var bottom := Hud.TOASTS_BOTTOM
	if back.has_area():
		bottom -= hud.return_button().get_combined_minimum_size().y + Tokens.S2
		if back.end.y < area.end.y - RETURN_FOOT - 0.5:
			bottom = minf(bottom, back.position.y - area.end.y - Tokens.S2)
	var toasts := hud.toast_host()
	var need := toasts.get_combined_minimum_size()
	var middle := area.get_center().x
	var home := Rect2(Vector2(middle - need.x * 0.5, area.end.y + bottom - need.y), need)
	if need.x > 0.0 and card.has_area() and home.intersects(card):
		var foot := area.end.y - GAP if not back.has_area() else back.position.y - Tokens.S2
		var bounds := _rect_between(Vector2(area.position.x + GAP, Hud.screen_rect(hud.top_bar()).end.y + 2.0),
				Vector2(area.end.x - GAP, foot))
		var spot := free_spot(need, bounds, taken, home.position)
		if not spot.has_area() and taken[-1] != card:
			spot = free_spot(need, bounds, taken.slice(0, -1), home.position)
		if spot.has_area():
			toasts.offset_left = spot.position.x - middle
			toasts.offset_right = spot.end.x - middle
			toasts.offset_top = spot.position.y - area.end.y
			toasts.offset_bottom = spot.end.y - area.end.y
			return
	toasts.offset_left = -TOASTS_HALF
	toasts.offset_right = TOASTS_HALF
	toasts.offset_top = bottom - (Hud.TOASTS_BOTTOM - Hud.TOASTS_TOP)
	toasts.offset_bottom = bottom


static func _apply_card(card: GoodsCard, area: Rect2, layout: Vector3i, rect: Rect2) -> void:
	card.set_layout(layout)
	card.offset_left = rect.position.x - area.position.x
	card.offset_right = card.offset_left + rect.size.x
	card.offset_bottom = rect.end.y - area.end.y
	card.offset_top = card.offset_bottom - rect.size.y


static func _move_legend(legend: ModeLegend, area: Rect2, at: Vector2) -> void:
	legend.offset_left = at.x - area.position.x
	legend.offset_right = legend.offset_left + ModeLegend.WIDTH
	legend.offset_top = at.y - area.position.y
	legend.offset_bottom = legend.offset_top


## The rect from `from` to `to`, empty (never negative) where `to` is not past `from`.
static func _rect_between(from: Vector2, to: Vector2) -> Rect2:
	return Rect2(from, (to - from).max(Vector2.ZERO))


static func _shown(parts: Array) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for part: Control in parts:
		if part.is_visible_in_tree():
			out.append(Hud.screen_rect(part))
	return out
