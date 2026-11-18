## ColourContrast (core/defs/colour_contrast.gd; docs/architecture/m2-build-spec.md section 4.6 and 10):
## CIE76 Lab distance, Machado 2009 simulations on Okabe-Ito, worst_delta_e, edge cases, and the 1480 neighbour pairs.
extends GutTest

const CB_PALETTE: Array[String] = [
	"#e69f00", "#56b4e9", "#009e73", "#f0e442",
	"#0072b2", "#d55e00", "#cc79a7", "#ebebeb",
]

# Reference Machado (2009) severity-1 simulated sRGB values for CB_PALETTE in the same order.
const CB_PROTAN_REF: Array[Color] = [
	Color(0.7257, 0.6368, 0.0),
	Color(0.6077, 0.7017, 0.9236),
	Color(0.6053, 0.5711, 0.4416),
	Color(0.9723, 0.8625, 0.1363),
	Color(0.3244, 0.4571, 0.7085),
	Color(0.5055, 0.4420, 0.0),
	Color(0.5000, 0.5447, 0.6614),
	Color(0.9216, 0.9216, 0.9216),
]
const CB_DEUTAN_REF: Array[Color] = [
	Color(0.7912, 0.7048, 0.0660),
	Color(0.5284, 0.6434, 0.9103),
	Color(0.5422, 0.5252, 0.4623),
	Color(0.9891, 0.8903, 0.3051),
	Color(0.2303, 0.4020, 0.6933),
	Color(0.6186, 0.5484, 0.0),
	Color(0.5823, 0.5978, 0.6464),
	Color(0.9216, 0.9216, 0.9216),
]
const CB_TRITAN_REF: Array[Color] = [
	Color(0.9853, 0.5475, 0.5306),
	Color(0.0, 0.7597, 0.7758),
	Color(0.0, 0.6210, 0.5735),
	Color(1.0, 0.8333, 0.7718),
	Color(0.0, 0.5089, 0.5387),
	Color(0.9196, 0.2528, 0.3143),
	Color(0.8403, 0.4704, 0.5395),
	Color(0.9216, 0.9216, 0.9216),
]

const COUNTRIES_1480: Dictionary = {
	&"FRA": ["#2846aa", 3], &"AUS": ["#e6e6e6", 4], &"SWI": ["#be3232", 1],
	&"SAV": ["#829678", 5], &"MLO": ["#3460b2", 3], &"VEN": ["#1ea08c", 5],
	&"GEN": ["#be3c6e", 1], &"TUS": ["#8c32a0", 3], &"PAP": ["#f0e6a0", 1],
	&"MAN": ["#cd9632", 1], &"FER": ["#78aadc", 4], &"SIE": ["#a0522d", 5],
	&"LUC": ["#d76e3c", 5],
}

const NEIGHBOUR_PAIRS_1480: Array[Array] = [
	[&"AUS", &"MLO"], [&"AUS", &"SWI"], [&"AUS", &"VEN"], [&"FER", &"LUC"], [&"FER", &"MAN"],
	[&"FER", &"MLO"], [&"FER", &"PAP"], [&"FER", &"TUS"], [&"FER", &"VEN"], [&"FRA", &"SAV"],
	[&"FRA", &"SWI"], [&"GEN", &"MLO"], [&"GEN", &"SAV"], [&"LUC", &"MLO"], [&"LUC", &"TUS"],
	[&"MAN", &"MLO"], [&"MAN", &"VEN"], [&"MLO", &"SAV"], [&"MLO", &"SWI"], [&"MLO", &"VEN"],
	[&"PAP", &"TUS"], [&"PAP", &"VEN"], [&"SAV", &"SWI"], [&"SIE", &"TUS"],
]


func test_black_white_and_identity() -> void:
	assert_almost_eq(ColourContrast.delta_e(Color.BLACK, Color.WHITE), 100.0, 0.01)
	assert_almost_eq(ColourContrast.delta_e(Color.WHITE, Color.BLACK), 100.0, 0.01)
	for hex: String in CB_PALETTE:
		var c := Color(hex)
		assert_eq(ColourContrast.delta_e(c, c), 0.0)
		assert_eq(ColourContrast.worst_delta_e(c, c), 0.0)
		assert_eq(ColourContrast.simulate(c, ColourContrast.Vision.NORMAL), c)


func test_okabe_ito_simulations_match_reference() -> void:
	for i: int in CB_PALETTE.size():
		var c := Color(CB_PALETTE[i])
		var cases: Array[Array] = [
			[ColourContrast.Vision.PROTAN, CB_PROTAN_REF[i], "protan"],
			[ColourContrast.Vision.DEUTAN, CB_DEUTAN_REF[i], "deutan"],
			[ColourContrast.Vision.TRITAN, CB_TRITAN_REF[i], "tritan"],
		]
		for row: Array in cases:
			var vision: ColourContrast.Vision = row[0]
			var ref: Color = row[1]
			var label: String = row[2]
			var got := ColourContrast.simulate(c, vision)
			assert_lt(ColourContrast.delta_e(got, ref), 0.5, "%s %s ΔE" % [CB_PALETTE[i], label])
			assert_almost_eq(got.r, ref.r, 0.002, "%s %s r" % [CB_PALETTE[i], label])
			assert_almost_eq(got.g, ref.g, 0.002, "%s %s g" % [CB_PALETTE[i], label])
			assert_almost_eq(got.b, ref.b, 0.002, "%s %s b" % [CB_PALETTE[i], label])


func test_worst_delta_e_is_minimum_over_four_visions() -> void:
	for i: int in CB_PALETTE.size():
		for j: int in range(i + 1, CB_PALETTE.size()):
			var a := Color(CB_PALETTE[i])
			var b := Color(CB_PALETTE[j])
			var expected := ColourContrast.delta_e(a, b)
			for v: ColourContrast.Vision in [
				ColourContrast.Vision.PROTAN,
				ColourContrast.Vision.DEUTAN,
				ColourContrast.Vision.TRITAN,
			]:
				expected = minf(expected, ColourContrast.delta_e(
					ColourContrast.simulate(a, v),
					ColourContrast.simulate(b, v)))
			assert_almost_eq(ColourContrast.worst_delta_e(a, b), expected, 1e-5)


func test_edge_cases_and_threshold_boundaries() -> void:
	# sRGB linear segment below and above 0.04045, plus dark ink vs light vellum.
	var dark_low := Color(0.02, 0.02, 0.02, 0.5)
	var dark_high := Color(0.05, 0.05, 0.05, 1.0)
	assert_gt(ColourContrast.delta_e(dark_low, dark_high), 0.0)
	var ink := Color("#1c140d")
	var vellum := Color("#efeadf")
	assert_gt(ColourContrast.delta_e(ink, vellum), 80.0)
	# Alpha does not alter Lab distance, and simulate preserves alpha & clamps RGB to [0, 1].
	var a_opaque := Color(0.2, 0.4, 0.6, 1.0)
	var a_translucent := Color(0.2, 0.4, 0.6, 0.25)
	assert_eq(ColourContrast.delta_e(a_opaque, a_translucent), 0.0)
	for primary: Color in [Color.RED, Color.GREEN, Color.BLUE]:
		for v: ColourContrast.Vision in [
			ColourContrast.Vision.PROTAN,
			ColourContrast.Vision.DEUTAN,
			ColourContrast.Vision.TRITAN,
		]:
			var sim := ColourContrast.simulate(Color(primary.r, primary.g, primary.b, 0.4), v)
			assert_almost_eq(sim.a, 0.4, 1e-5)
			assert_between(sim.r, 0.0, 1.0)
			assert_between(sim.g, 0.0, 1.0)
			assert_between(sim.b, 0.0, 1.0)


func test_1480_neighbour_palettes_meet_contrast_thresholds() -> void:
	var min_normal := INF
	var min_normal_pair := ""
	var min_cb := INF
	var min_cb_pair := ""
	for pair: Array in NEIGHBOUR_PAIRS_1480:
		var a_tag: StringName = pair[0]
		var b_tag: StringName = pair[1]
		var a_info: Array = COUNTRIES_1480[a_tag]
		var b_info: Array = COUNTRIES_1480[b_tag]
		var de := ColourContrast.delta_e(Color(a_info[0] as String), Color(b_info[0] as String))
		assert_gte(de, 30.0, "normal contrast %s-%s" % [a_tag, b_tag])
		if de < min_normal:
			min_normal = de
			min_normal_pair = "%s-%s" % [a_tag, b_tag]
		var cb_de := ColourContrast.worst_delta_e(
			Color(CB_PALETTE[int(a_info[1])]),
			Color(CB_PALETTE[int(b_info[1])]))
		assert_gte(cb_de, 20.0, "CB contrast %s-%s" % [a_tag, b_tag])
		if cb_de < min_cb:
			min_cb = cb_de
			min_cb_pair = "%s-%s" % [a_tag, b_tag]
	assert_eq(min_normal_pair, "FER-MLO")
	assert_almost_eq(min_normal, 35.6, 0.1)
	assert_eq(min_cb_pair, "AUS-SWI")
	assert_almost_eq(min_cb, 24.8, 0.1)
