## Micro timings of the preview's pieces on north Italy (fast to load): headless.
extends SceneTree

const RUNS := 200


func _avg(label: String, f: Callable) -> void:
	var t := Time.get_ticks_usec()
	for n: int in RUNS:
		f.call()
	print("%-44s %.3f ms" % [label, (Time.get_ticks_usec() - t) / 1000.0 / RUNS])


func _initialize() -> void:
	var d := load("res://data/defs/game_defs.tres") as GameDefs
	var g := Game.new_scenario(load("res://data/maps/north_italy.tres") as MapData, d, d.scenarios[d.scenarios.size() - 1], 1480)
	g.act("choose_country", {"tag": &"GEN"})
	g.improvement.clear(Vector2i(7, 12))
	g.districts.clear()
	g.version += 1
	var c := Countries.by_tag(g, &"GEN")
	var i := g.map.index_of(Vector2i(7, 12))
	var over := {i: Vector2i(7, 1)}
	var hex := Vector2i(7, 12)
	EconomyPreview.baseline(g, &"GEN", 4, 1)
	var own := StateView.of(g.state)
	var view := own.with(over)
	_avg("with {} lines", func() -> void: EconomyPreview.with(g, &"GEN", {}, 4))
	_avg("with {} no lines", func() -> void: EconomyPreview.with(g, &"GEN", {"lines": false}, 4))
	_avg("with change detail no lines", func() -> void: EconomyPreview.with(g, &"GEN", {"hexes": over, "detail": true, "lines": false}, 4))
	_avg("with change no detail no lines", func() -> void: EconomyPreview.with(g, &"GEN", {"hexes": over, "lines": false}, 4))
	_avg("district_base (own, wild hex)", func() -> void: Economy.district_base(g, own, hex))
	_avg("district_base (vineyard view)", func() -> void: Economy.district_base(g, view, hex))
	_avg("districts.base_of", func() -> void: g.districts.base_of(g, i))
	_avg("view.with(over)", func() -> void: own.with(over))
	_avg("_around", func() -> void: EconomyPreview._around(g, over.keys()))
	var rec: Dictionary = EconomyPreview.baseline(g, &"GEN", 4, 1)[0]
	var stock := c.stock.duplicate()
	_avg("_step no lines", func() -> void: EconomyPreview._step(g, c, 1, rec, own, stock, false))
	_avg("_step lines", func() -> void: EconomyPreview._step(g, c, 1, rec, own, stock, true))
	var needs := EconomySeason.needs_for(g, int(rec["town"]))
	var prices := Economy.market_prices(g, own, 1, stock)
	_avg("needs_for", func() -> void: EconomySeason.needs_for(g, int(rec["town"])))
	_avg("reserve_for", func() -> void: EconomySeason.reserve_for(g, needs))
	_avg("market_prices", func() -> void: Economy.market_prices(g, own, 1, stock))
	var reserve := EconomySeason.reserve_for(g, needs)
	_avg("goods_step", func() -> void: EconomySeason.goods_step(g, needs, reserve, stock, rec["made"] as PackedInt32Array, prices))
	_avg("money_lines", func() -> void: EconomySeason.money_lines(g, own, &"GEN", 1, 1000, 1000, rec, int(rec["town"]), int(rec["rest"])))
	var key := 0
	ImprovePreview.of(g, &"GEN", hex, {"action": Works.BUILD, "family": 7})
	_avg("of: _make, country base warm", func() -> void: ImprovePreview._make(g, &"GEN", hex, Works.BUILD, 7))
	_avg("of cached", func() -> void: ImprovePreview.of(g, &"GEN", hex, {"action": Works.BUILD, "family": 7}))
	_avg("options_of cold (version bump)", func() -> void:
		g.version += 1
		ImprovePreview.options_of(g, &"GEN", hex))
	_avg("options_of warm", func() -> void: ImprovePreview.options_of(g, &"GEN", hex))
	_avg("game.check build", func() -> void: g.check("build", {"hex": hex, "tag": &"GEN", "family": 7}))
	quit()
