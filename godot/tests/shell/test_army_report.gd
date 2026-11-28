## The report's Armies section (docs/architecture/m6-build-spec.md 4.14, 6.10; L22): drawn from the fixture and from a real
## season, its nav entry, its army links selecting the army (never a look at the hex), and no section in a quiet season.
extends GutTest

const SCENE := "res://shell/screens/season_report.tscn"

var _harness: UIHarness = null
var _requests: Array[Array] = []


func before_each() -> void:
	Bindings.reset_defaults()
	_harness = UIHarness.new()
	_harness.mount(self)
	_harness.stack.theme = KitTheme.load_for(1.0)
	_requests = []
	_harness.ctx.app_requested.connect(func(what: StringName, args: Dictionary) -> void: _requests.append([what, args]))


func after_each() -> void:
	if _harness != null and _harness.stack != null:
		_harness.stack.clear()
	_harness = null
	Session.end_game()
	Bindings.reset_defaults()


func _open(summary: Dictionary) -> SeasonReport:
	var report := (load(SCENE) as PackedScene).instantiate() as SeasonReport
	report.show_summary(summary)
	_harness.stack.push(report)
	return report


func _requested(what: StringName) -> Array:
	return _requests.filter(func(r: Array) -> bool: return r[0] == what)


func _section(summary: Dictionary, id: StringName) -> Dictionary:
	for s: Dictionary in summary.get("sections", []):
		if s["id"] == id:
			return s
	return {}


## The link buttons inside the Armies section.
func _armies_links(report: SeasonReport) -> Array[Button]:
	var out: Array[Button] = []
	var box := report.sheet().section_box(&"armies")
	if box == null:
		return out
	for node: Node in box.find_children("Link*", "Button", true, false):
		out.append(node as Button)
	return out


func _label_texts(report: SeasonReport) -> Array[String]:
	var out: Array[String] = []
	var box := report.sheet().section_box(&"armies")
	if box == null:
		return out
	for node: Node in box.find_children("*", "Label", true, false):
		out.append((node as Label).text)
	return out


## A town of the player's, made rich, with its game (the raise of test_season_armies).
func _rich_town_game() -> Game:
	var g := ArmyFixture.game()
	ArmyFixture.rich(g)
	ArmyFixture.town(g, ArmyFixture.find_town(g))
	return g


func test_the_fixture_draws_the_armies_section_with_its_nav_entry() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	assert_not_null(report.sheet().section_box(&"armies"), "the section is drawn")
	var heading := report.sheet().section_box(&"armies").get_parent().get_node("Heading") as Label
	assert_eq(heading.text, "Armies")
	var nav := report.sheet().nav()
	assert_not_null(nav.button_for(&"armies"), "the nav has an Armies entry")
	assert_eq((nav.button_for(&"armies").get_node("Count") as Label).text, "4")


func test_the_section_renders_its_lines_and_sub_lines() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var links := _armies_links(report)
	var link_texts: Array[String] = []
	for btn: Button in links:
		link_texts.append(btn.text)
	assert_true(link_texts.has("Army of Genoa: Genoa (8, 13) → Savona (6, 13), 900 men."), str(link_texts))
	var labels := _label_texts(report)
	assert_true(labels.has("Upkeep: 12 ducats a season."), "a sub line is drawn")
	assert_true(labels.has("Your armies ate 1 grain from the stores."), "the food line is drawn")


func test_an_army_link_selects_the_army_and_does_not_look_at_the_hex() -> void:
	var report := _open(ReportSample.genoa_spring())
	await _harness.wait_frames(self, 2)
	var links := _armies_links(report)
	assert_eq(links.size(), 2, "the two army lines are links")
	links[0].pressed.emit()
	await _harness.wait_frames(self, 2)
	assert_eq(_harness.stack.count(), 0, "the report closes")
	assert_eq(_requested(&"select_army").size(), 1)
	var args: Dictionary = _requested(&"select_army")[0][1]
	assert_eq(args["army"], 1)
	assert_eq(args["hex"], Vector2i(6, 13), "the line's hex comes with the army")
	assert_eq(_requested(&"look_at").size(), 0, "the army's own selection glides, not a look at the hex")
	assert_eq(_requested(&"report_closed").size(), 1)


func test_a_quiet_season_has_no_armies_section() -> void:
	var report := _open(ReportSample.quiet_season())
	await _harness.wait_frames(self, 2)
	assert_null(report.sheet().section_box(&"armies"), "no section")
	assert_null(report.sheet().nav().button_for(&"armies"), "no nav entry")


func test_a_real_raise_season_draws_the_section_with_army_links() -> void:
	var g := _rich_town_game()
	var hex := ArmyFixture.find_town(g)
	assert_true(bool(ArmyFixture.raise_now(g, {"hex": hex, "kind": 0, "count": 2, "tag": ArmyFixture.TAG})["ok"]))
	Season.run(g)
	var summary := SeasonSummary.of(g, ArmyFixture.TAG, g.turn - 1)
	assert_false(_section(summary, &"armies").is_empty(), "the season has the Armies section")
	var report := _open(summary)
	await _harness.wait_frames(self, 2)
	assert_not_null(report.sheet().nav().button_for(&"armies"))
	var links := _armies_links(report)
	assert_gt(links.size(), 0, "the raised army is a link")
	links[0].pressed.emit()
	await _harness.wait_frames(self, 2)
	var a := Armies.of_country(g, ArmyFixture.TAG)[0]
	assert_eq(_requested(&"select_army").size(), 1)
	var args: Dictionary = _requested(&"select_army")[0][1]
	assert_eq(args["army"], a.id)
	assert_eq(args["hex"], a.hex)


func test_a_real_season_with_no_army_has_no_armies_section() -> void:
	var g := ArmyFixture.game()
	Season.run(g)
	var summary := SeasonSummary.of(g, ArmyFixture.TAG, g.turn - 1)
	assert_false(summary.is_empty(), "a report of the season")
	assert_true(_section(summary, &"armies").is_empty(), "no army, no section")
	var report := _open(summary)
	await _harness.wait_frames(self, 2)
	assert_null(report.sheet().section_box(&"armies"))
	assert_null(report.sheet().nav().button_for(&"armies"))
