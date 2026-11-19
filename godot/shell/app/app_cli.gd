## The command line of the App (after "--"): --new-game [--scenario=ID] [--country=TAG] [--seed=N], --sandbox, --plain-ui.
## A missing or bad seed becomes a random one (the shell's own luck; core/ is not involved).
class_name AppCli
extends RefCounted

const DEFAULT_SCENARIO := "north_italy_1480"


static func parse(args: PackedStringArray) -> Dictionary:
	var sandbox := false
	var new_game := false
	var scenario := DEFAULT_SCENARIO
	var country := ""
	var plain_ui := false
	var seed_val := -1
	var i := 0
	while i < args.size():
		var arg := args[i]
		if arg == "--sandbox":
			sandbox = true
		elif arg == "--new-game":
			new_game = true
		elif arg.begins_with("--scenario="):
			scenario = arg.substr(11)
		elif arg.begins_with("--country="):
			country = arg.substr(10).to_upper()
		elif arg == "--plain-ui":
			plain_ui = true
		elif arg.begins_with("--seed="):
			var raw := arg.substr(7)
			if raw.is_valid_int():
				seed_val = raw.to_int()
		elif arg == "--seed" and i + 1 < args.size():
			var next_raw := args[i + 1]
			if next_raw.is_valid_int():
				seed_val = next_raw.to_int()
				i += 1
		i += 1
	if seed_val < 0:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		seed_val = rng.randi_range(Sandbox.RANDOM_SEED_MIN, Sandbox.RANDOM_SEED_MAX)
	return {
		"sandbox": sandbox, "new_game": new_game, "scenario": scenario, "country": country,
		"plain_ui": plain_ui, "seed": seed_val,
	}
