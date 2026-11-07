extends SceneTree

## Weapon stages must remain readable and contained in every playable footprint.
const Visuals = preload("res://scripts/plant_visuals.gd")
const GardenCrops = preload("res://scripts/garden_crop_art.gd")
const Layout = preload("res://scripts/field_layout.gd")
const World = preload("res://scripts/garden_world.gd")
const DEFENDERS: Array[String] = ["nettle", "lavender", "pepper", "lotus"]

var checks: int = 0
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + message)


func _run() -> void:
	_test_stage_assets()
	_test_next_milestones()
	_test_crop_readability()
	for index in range(Layout.battle_plots().size()):
		var bounds: Rect2 = Layout.sprite_bounds(index)
		_check_footprint(bounds, "battle bed %d" % index)
		for kind in DEFENDERS:
			for level in range(1, 21):
				var sprite: Rect2 = Visuals.defense_sprite_rect(kind, level, bounds)
				_expect(Layout.plot_bounds(index).grow(0.001).encloses(sprite), "complete upgraded weapon stays inside its planting footprint")
	for index in range(World.NURSERY_PLOT_CENTERS.size()):
		_check_footprint(World.nursery_plot_rect(index).grow(-1), "nursery bed %d" % index)
	_check_footprint(Rect2(66, 271, 138, 145), "current-level preview")
	_check_footprint(Rect2(336, 271, 138, 145), "next-level preview")
	_check_footprint(Rect2(77, 292, 76, 76), "owned battle card")
	print("Weapon visuals: ", checks, " checks, ", failures, " failures")
	quit(0 if failures == 0 else 1)


func _test_stage_assets() -> void:
	_expect(Visuals.defense_stage(-10) == 1 and Visuals.defense_stage(0) == 1, "invalid low levels retain the small cannon stage")
	_expect(Visuals.defense_stage(1) == 1, "first level begins with a small cannon")
	for level in range(1, 7):
		_expect(Visuals.defense_stage(level) == 1, "levels one through six retain the small cannon stage")
	for level in range(7, 15):
		_expect(Visuals.defense_stage(level) == 2, "levels seven through fourteen use the large single cannon")
	for level in range(15, 21):
		_expect(Visuals.defense_stage(level) == 3, "the second barrel becomes a late milestone at level fifteen")
	_expect(Visuals.defense_stage(1000) == 3, "out-of-range high level cannot select a nonexistent weapon stage")
	var seen_regions: Dictionary = {}
	for kind in DEFENDERS:
		var stage_textures: Array[Texture2D] = []
		for level in [1, 7, 15]:
			var texture: Texture2D = Visuals.defense_texture(kind, level)
			_expect(texture != null, "every defender has a real sprite at each weapon stage")
			if texture == null:
				continue
			stage_textures.append(texture)
			_expect(texture is AtlasTexture, "weapon stage uses a bounded atlas sprite")
			if texture is AtlasTexture:
				var region: Rect2 = texture.region
				var atlas_bounds = Rect2(Vector2.ZERO, texture.atlas.get_size())
				_expect(atlas_bounds.encloses(region), "weapon atlas region stays inside its source PNG")
				_expect(absf(texture.get_size().x - texture.get_size().y) <= 1.0 and minf(region.size.x,region.size.y) >= 180, "alpha-bounded regions with virtual square margins preserve aspect and remove oversized transparent gutters")
				_expect(texture.atlas.resource_path.contains("botanical_refresh"), "all defender stages share the refreshed botanical art direction")

				var key: String = texture.atlas.resource_path + ":" + str(region)
				_expect(not seen_regions.has(key), "each plant and upgrade stage has its own artwork")
				seen_regions[key] = true
			_expect(not Visuals.defense_label(kind, level).is_empty(), "contextual upgrade menus can name the physical weapon stage")
		if stage_textures.size() == 3:
			_expect(stage_textures[0] != stage_textures[1] and stage_textures[1] != stage_textures[2], "upgrades replace the cannon artwork instead of only scaling the same picture")
			_expect(Visuals.defense_texture(kind, 20) == stage_textures[2], "higher individual levels retain the final two-barrel weapon")
	for kind in ["tomato", "marigold", "unknown"]:
		_expect(Visuals.defense_texture(kind, 1) == null, "non-defenders do not acquire cannon sprites")


func _test_next_milestones() -> void:
	for kind in DEFENDERS:
		for level in range(1, 21):
			var milestone: Dictionary = Visuals.defense_next_milestone(kind, level)
			if level >= 15:
				_expect(milestone.is_empty(), "the final weapon stage has no invented further milestone")
				continue
			var expected_level: int = 7 if level < 7 else 15
			var expected_stage: int = 2 if level < 7 else 3
			_expect(int(milestone.get("level", 0)) == expected_level, "the upgrade menu points to the next attainable weapon threshold")
			_expect(int(milestone.get("stage", 0)) == expected_stage, "the milestone previews the correct next weapon form")
			_expect(not String(milestone.get("label", "")).is_empty(), "the next weapon milestone has a readable name")
		_expect(Visuals.defense_next_milestone(kind, 6).get("level") == 7, "the level before the large cannon still points to level seven")
		_expect(Visuals.defense_next_milestone(kind, 7).get("level") == 15, "after the first milestone the menu points to the second barrel")
	for kind in ["tomato", "marigold", "unknown"]:
		_expect(Visuals.defense_next_milestone(kind, 1).is_empty(), "income crops and unknown plants have no cannon milestone")


func _check_footprint(bounds: Rect2, context: String) -> void:
	for kind in DEFENDERS:
		var previous_bottom: float = NAN
		var previous_size: Vector2 = Vector2.ZERO
		for level in range(1, 21):
			var sprite: Rect2 = Visuals.defense_sprite_rect(kind, level, bounds)
			_expect(sprite.has_area() and sprite.position.is_finite() and sprite.size.is_finite(), context + ": upgraded sprite has usable finite geometry")
			_expect(bounds.grow(0.001).encloses(sprite), context + ": all cannon stages fit the reserved sprite rectangle")
			_expect(absf(sprite.get_center().x - bounds.get_center().x) <= 1.0, context + ": weapon stays centered on its bed")
			if is_finite(previous_bottom):
				_expect(absf(sprite.end.y - previous_bottom) <= 1.0, context + ": roots do not jump vertically when upgrading")
			previous_bottom = sprite.end.y
			_expect(sprite.size.x >= previous_size.x and sprite.size.y >= previous_size.y, context + ": growing plants never shrink when a weapon milestone is crossed")
			previous_size = sprite.size
			var muzzles: Array[Vector2] = Visuals.weapon_muzzles(kind, level, bounds)
			var expected_count: int = 1 if level < 15 else 2
			_expect(muzzles.size() == expected_count, context + ": one or two firing origins match the visible cannon stage")
			if muzzles.size() != expected_count:
				return
			for muzzle in muzzles:
				_expect(muzzle.is_finite() and sprite.grow(0.001).has_point(muzzle), context + ": firing starts inside the rendered weapon")
			if muzzles.size() == 2:
				_expect(muzzles[0].distance_to(muzzles[1]) > 1.0, context + ": double cannons have distinct firing origins")


func _test_crop_readability() -> void:
	for index in range(World.PLOT_CENTERS.size()):
		var bed: Rect2 = World.plot_rect(index)
		for kind in GardenCrops.ECONOMIC_KINDS:
			var crops: Array[Rect2] = GardenCrops.crop_rects(bed, kind)
			_expect(crops.size() == 4, "each real income planting supplies a compact two-by-two crop patch")
			for crop_index in range(crops.size()):
				var crop: Rect2 = crops[crop_index]
				_expect(World.plot_visual_rect(index).grow(0.001).encloses(crop), "complete crop crowns stay inside the existing planting footprint")
				_expect(minf(crop.size.x,crop.size.y) * World.DEFAULT_ZOOM >= 30.0, "the dense crop sprites remain readable at the default camera zoom")
				_expect(crop.end.y <= bed.end.y, "crop roots remain inside their playable cell")
				for other in range(crop_index):
					_expect(not crop.intersects(crops[other]),"dense crop sprites never overlap a neighboring stalk")
