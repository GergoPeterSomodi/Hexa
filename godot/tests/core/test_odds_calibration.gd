@warning_ignore_start("integer_division")
## The odds words against the measured win shares (docs/architecture/m7-build-spec.md 4.6, D50; M7 plan B18). Every cell is the
## grid of OddsGrid (pikemen, 1 to 6 companies a side, 100 fixed seeds): the attacker's win share on plains (open ground, the
## factor 1,000, so the word reads the plain ratio). On plains the five words must rise in order, and each word's cells must sit
## in its band. The rough grounds are not pinned: their factors (odds_ground, the owner's and Opus's refit) read one word low on
## marsh, mountains and snow (tools/probes/probe_odds.gd prints it), so the all-ground order is pending, as the 4 v 2 band is.
## The thresholds in data/defs/war.tres (odds_words) are not changed by this test: the plains already fit them.
extends GutTest

## The band of each word on plains, in the attacker's win share (inclusive): measured on the grid, with a margin.
const BANDS := {
	"Hopeless": [0, 35],
	"Poor": [15, 40],
	"Even": [35, 60],
	"Favourable": [60, 100],
	"Overwhelming": [95, 100],
}

var _war: WarDef
var _plains: Array[Dictionary] = []
var _words: Array[Dictionary] = []


func before_all() -> void:
	_war = CombatFixture.war()
	var plains: Array[String] = ["open"]
	_plains = OddsGrid.grid(_war, OddsGrid.SEEDS, OddsGrid.SIZES_MAX, plains)
	_words = OddsGrid.by_word(_war, _plains)


func test_grid_covers_every_word_on_plains() -> void:
	assert_eq(_plains.size(), OddsGrid.SIZES_MAX * OddsGrid.SIZES_MAX, "one plains cell per pair of sizes")
	for row: Dictionary in _words:
		assert_gt(int(row["cells"]), 0, "%s has a plains cell" % str(row["word"]))


func test_plains_means_rise_through_the_words() -> void:
	for i: int in range(1, _words.size()):
		var lower: Dictionary = _words[i - 1]
		var higher: Dictionary = _words[i]
		assert_gt(int(higher["mean"]), int(lower["mean"]), "%s (%d%%) wins more than %s (%d%%) on plains" % [
			str(higher["word"]), int(higher["mean"]), str(lower["word"]), int(lower["mean"])])


func test_plains_cells_sit_in_their_word_band() -> void:
	for c: Dictionary in _plains:
		var word := str(c["word"])
		var band: Array = BANDS[word]
		var pct := int(c["win_pct"])
		assert_true(pct >= int(band[0]) and pct <= int(band[1]),
				"%d v %d on plains: %s at %d%%, band %d to %d" % [int(c["attackers"]), int(c["defenders"]), word, pct,
				int(band[0]), int(band[1])])


func test_plains_value_matches_the_word_thresholds() -> void:
	for c: Dictionary in _plains:
		assert_eq(str(c["word"]), Combat.odds_word(_war, int(c["value"])), "the word of %d v %d follows its value" % [
			int(c["attackers"]), int(c["defenders"])])


## Known open: the rough grounds read one word low (marsh, mountains, snow: Hopeless cells at 50% or more, Poor cells at 60% or
## more). The factors of data/defs/war.tres odds_ground are the refit's (D50): the band cannot be pinned until the owner and
## Opus fit them. The measured table is in tools/probes/probe_odds.gd's output (pull request of B18).
func test_all_grounds_rise_through_the_words() -> void:
	pending("rough grounds' odds_ground factors not refit (D50): the word reads one band low on marsh, mountains and snow")
