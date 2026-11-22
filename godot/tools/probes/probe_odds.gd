## The odds calibration probe (docs/architecture/m7-build-spec.md 4.6, D50; M7 plan B18): prints, for every pair of company counts
## 1 to 6 (pikemen, 500 men) on every ground of data/defs/war.tres, the odds word of the card and the attacker's win share over
## OddsGrid.SEEDS seeds, then the table per word (the cells, the mean, the lowest and highest win share, the value range). The
## numbers are the input of the test tests/core/test_odds_calibration.gd. Always exits 0; prints the time taken.
## Run: godot --headless --path godot -s res://tools/probes/probe_odds.gd   (optional: -- --seeds=100 --sizes=6)
extends SceneTree


func _initialize() -> void:  # not _init: the classes are known to the parser only from here on
	var seeds := OddsGrid.SEEDS
	var sizes := OddsGrid.SIZES_MAX
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seeds = maxi(int(arg.substr(8)), 1)
		elif arg.begins_with("--sizes="):
			sizes = clampi(int(arg.substr(8)), 1, OddsGrid.SIZES_MAX)
	var war := CombatFixture.war()
	var started := Time.get_ticks_usec()
	var cells := OddsGrid.grid(war, seeds, sizes)
	var spent := float(Time.get_ticks_usec() - started) / 1000.0
	print("## Odds grid: %d cells, %d seeds each, %.0f ms" % [cells.size(), seeds, spent])
	print("ground | att v def | ratio | value | word | win %")
	for c: Dictionary in cells:
		print("%s | %d v %d | %d | %d | %s | %d" % [c["ground"], c["attackers"], c["defenders"], c["ratio"], c["value"],
			c["word"], c["win_pct"]])
	print("")
	print("| Word | cells | mean win % | lowest | highest | value range |")
	print("|---|---|---|---|---|---|")
	for row: Dictionary in OddsGrid.by_word(war, cells):
		print("| %s | %d | %d | %d | %d | %d to %d |" % [row["word"], row["cells"], row["mean"], row["low"], row["high"],
			row["value_low"], row["value_high"]])
	quit(0)
