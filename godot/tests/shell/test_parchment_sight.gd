## The parchment does not dim land out of sight (docs/architecture/map-overview-build-spec.md R14, the owner's decision of
## 2026-11-27): discovered land in sight and out of sight gets identical inputs. A shader's inputs are its samplers and
## its uniforms. The check reads both on every layer, lights the whole of the discovered land (nothing else the viewer
## knows changes) and reads them again. Each planted case (P) feeds the check a veil it must report.
extends GutTest

## The only textures a layer's shader may read: the two fog-masked fact textures and the countries' colours.
const SAMPLERS: Array[String] = ["owners", "goods", "palette"]


## A planted fault: the land out of sight is marked in its owner texel, a veil carried by the data.
class MarksUnseen:
	extends ParchmentMap

	func _write_facts() -> void:
		super()
		var sight := MapModes.sight_bytes(_game, _game.player)
		var marked := _owners.bytes.duplicate()
		for i: int in marked.size():
			if sight[i] == 0 and marked[i] != ParchmentView.UNKNOWN:
				marked[i] = marked[i] | 0x80
		_count(_owners.write(marked))


## A planted fault: the land's shader reads a sight texture again.
class ReadsSight:
	extends ParchmentMap

	func _init() -> void:
		super()
		var shader := Shader.new()
		shader.code = FILL_SHADER.code + "\nuniform sampler2D sight : filter_nearest, repeat_disable;\n"
		layer_material(&"land").shader = shader


## Every input of every layer's shader, "layer/uniform" -> its value (a texture: its sampler's name only), and the bytes
## of the two textures that hold one texel a hex.
func _inputs(node: ParchmentMap) -> Dictionary:
	var out := {"owners": node.owner_image().get_data(), "goods": node.goods_image().get_data()}
	for layer_name: StringName in ParchmentMap.LAYERS:
		var material_of := node.layer_material(layer_name)
		for uniform: Dictionary in material_of.shader.get_shader_uniform_list():
			var uniform_name := str(uniform["name"])
			var value: Variant = material_of.get_shader_parameter(StringName(uniform_name))
			out["%s/%s" % [layer_name, uniform_name]] = uniform_name if int(uniform["type"]) == TYPE_OBJECT else value
	return out


## What tells land in sight from land out of sight in a node's inputs, in Goods mode on the thin fixture.
func _sight_problems(node: ParchmentMap) -> Array[String]:
	var game := FogFixture.duel_thin()
	game.player = AiFixture.MILAN
	var viewer := Countries.by_tag(game, AiFixture.MILAN)
	add_child_autofree(node)
	node.begin(game)
	node.step(1.0e9)
	node.set_mode(MapModes.Mode.GOODS)
	var known := MapModes.discovered_bytes(game, game.player).duplicate()
	var sight := MapModes.sight_bytes(game, game.player).duplicate()
	var unseen := 0
	var seen := 0
	for i: int in game.map.hex_count():
		if game.map.land[i] == 1 and known[i] == 1:
			unseen += int(sight[i] == 0)
			seen += int(sight[i] == 1)
	assert_gt(unseen, 0, "discovered land out of sight")
	assert_gt(seen, 0, "discovered land in sight")
	var out: Array[String] = []
	for layer_name: StringName in ParchmentMap.LAYERS:
		for uniform: Dictionary in node.layer_material(layer_name).shader.get_shader_uniform_list():
			if int(uniform["type"]) == TYPE_OBJECT and not SAMPLERS.has(str(uniform["name"])):
				out.append("%s reads %s" % [layer_name, uniform["name"]])
	var before := _inputs(node)
	# The viewer's armies now see all it has discovered.
	game.sight.set_army_part({viewer.id: game.sight.discovered_of(game, viewer.id).duplicate()}, {})
	game.version += 1
	assert_eq(MapModes.discovered_bytes(game, game.player), known, "nothing new is discovered")
	var lit := MapModes.sight_bytes(game, game.player)
	for i: int in game.map.hex_count():
		if known[i] == 1:
			assert_eq(lit[i], 1, "all the discovered land is in sight")
			if lit[i] != 1:
				break
	var writes := node.texel_writes
	node.sync(game)
	var after := _inputs(node)
	for key: String in before:
		if after.get(key) != before[key]:
			out.append("%s follows the sight" % key)
	if node.texel_writes != writes:
		out.append("texels written for a change of sight")
	return out


func test_land_in_sight_and_out_of_sight_get_identical_inputs() -> void:
	assert_eq(_sight_problems(ParchmentMap.new()), [] as Array[String])


func test_p_a_veil_in_the_data_is_reported() -> void:
	var found := _sight_problems(MarksUnseen.new())
	assert_has(found, "owners follows the sight", "P: the unseen land marked in the owner texture")


func test_p_a_sight_texture_in_the_land_shader_is_reported() -> void:
	assert_has(_sight_problems(ReadsSight.new()), "land reads sight", "P: a sight sampler")
