## Probe G1: measures per-season TileSet texture memory (RENDER_TEXTURE_MEM_USED / RENDER_VIDEO_MEM_USED)
## plus steady-state next-season preload pairs and Studiolo menu/kit texture footprint
## (docs/architecture/ui-and-controls-spec.md section 6.3; ui-and-controls-plan.md G1;
## ui-style-and-feedback-plan.md G1).
##
## Run windowed (live GPU / Compatibility GL):
##   godot --path godot -s res://tools/probes/probe_textures.gd
## Run headless: reports texture dimensions/estimated RGBA8 bytes alongside Performance monitors and exits 0.
extends SceneTree

const MB := 1048576.0
const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]
const MENU_ASSETS: Array[String] = [
	"res://assets/ui/menu/menu_bg.png",
	"res://assets/ui/menu/menu_shade.png",
]


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	var headless := DisplayServer.get_name() == "headless"
	print("## Probe G1: Texture Memory (%s)" % ("headless" if headless else "windowed"))
	print("Renderer: %s / %s / %s" % [
		DisplayServer.get_name(),
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
	])

	var base_tex := _tex_mb()
	var base_vid := _vid_mb()
	print("Baseline: RENDER_TEXTURE_MEM_USED=%.2f MB, RENDER_VIDEO_MEM_USED=%.2f MB" % [base_tex, base_vid])
	print("")
	print("| Season | Delta Tex Mem (MB) | Delta Video Mem (MB) | Unique Atlases | Total Atlas RGBA8 Est (MB) |")
	print("|---|---|---|---|---|")

	var loaded_builders: Dictionary[String, TilesetBuilder] = {}
	for season_name: String in SEASONS:
		var t_before := _tex_mb()
		var v_before := _vid_mb()
		var builder := TilesetBuilder.load_season(season_name)
		loaded_builders[season_name] = builder
		await process_frame
		await process_frame
		var t_delta := _tex_mb() - t_before
		var v_delta := _vid_mb() - v_before
		var atlas_stats := _tileset_rgba_estimate(builder.tile_set)
		print("| %s | %.2f | %.2f | %d | %.2f |" % [
			season_name, t_delta, v_delta, int(atlas_stats["count"]), float(atlas_stats["mb"])
		])
		loaded_builders.erase(season_name)
		builder = null
		await process_frame

	# Steady-state pairs (active season + preloaded next season)
	print("")
	print("| Steady-state Pair | Delta Tex Mem (MB) | Delta Video Mem (MB) | Combined Atlas RGBA8 Est (MB) |")
	print("|---|---|---|---|")
	for pair: Array in [["summer", "autumn"], ["winter", "spring"]]:
		var s1 := str(pair[0])
		var s2 := str(pair[1])
		var t_before := _tex_mb()
		var v_before := _vid_mb()
		var b1 := TilesetBuilder.load_season(s1)
		var b2 := TilesetBuilder.load_season(s2)
		await process_frame
		await process_frame
		var t_delta := _tex_mb() - t_before
		var v_delta := _vid_mb() - v_before
		var est := float(_tileset_rgba_estimate(b1.tile_set)["mb"]) + float(_tileset_rgba_estimate(b2.tile_set)["mb"])
		print("| %s + %s | %.2f | %.2f | %.2f |" % [s1, s2, t_delta, v_delta, est])
		b1 = null
		b2 = null
		await process_frame

	# Menu art footprint (lazy-loaded on MainMenu and released on game start)
	var menu_est_mb := 0.0
	var menu_t_before := _tex_mb()
	var menu_refs: Array[Texture2D] = []
	for path: String in MENU_ASSETS:
		if ResourceLoader.exists(path):
			var tex := ResourceLoader.load(path) as Texture2D
			if tex != null:
				menu_refs.append(tex)
				var sz := tex.get_size()
				menu_est_mb += (sz.x * sz.y * 4.0) / MB
	await process_frame
	var menu_t_delta := _tex_mb() - menu_t_before
	menu_refs.clear()
	print("")
	print("Menu art (menu_bg + menu_shade): delta RENDER_TEXTURE_MEM_USED=%.2f MB, RGBA8 est=%.2f MB" % [
		menu_t_delta, menu_est_mb
	])
	if headless:
		print("probe_textures: note — dummy headless renderer reports 0.00 MB for GPU texture monitors; run windowed for live VRAM numbers.")
	print("probe_textures: done")
	quit(0)


func _tex_mb() -> float:
	return Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / MB


func _vid_mb() -> float:
	return Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / MB


func _tileset_rgba_estimate(ts: TileSet) -> Dictionary:
	if ts == null:
		return {"count": 0, "mb": 0.0}
	var seen: Dictionary[int, bool] = {}
	var total_bytes := 0.0
	for idx: int in range(ts.get_source_count()):
		var sid := ts.get_source_id(idx)
		var src := ts.get_source(sid) as TileSetAtlasSource
		if src == null or src.texture == null:
			continue
		var rid := src.texture.get_instance_id()
		if seen.has(rid):
			continue
		seen[rid] = true
		var sz := src.texture.get_size()
		total_bytes += sz.x * sz.y * 4.0
	return {"count": seen.size(), "mb": total_bytes / MB}
