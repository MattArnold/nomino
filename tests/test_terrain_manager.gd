# test_terrain_manager.gd
# Unit tests for TerrainManager
extends GutTest

const TerrainManagerForTest = preload("res://scripts/terrain_manager.gd")

func test_generate_terrain_and_elevation_returns_expected_keys():
	var terrain_noise = FastNoiseLite.new()
	var elevation_noise = FastNoiseLite.new()
	var result = TerrainManagerForTest.generate_terrain_and_elevation(4, 4, 0, 0, -0.5, terrain_noise, elevation_noise)
	assert_true(result.has("terrain_map"), "Result should have 'terrain_map' key")
	assert_true(result.has("elevation_map"), "Result should have 'elevation_map' key")

func test_decorate_terrain_promotes_grass_to_plants():
	var terrain_map = [
		["grass", "grass", "grass"],
		["grass", "grass", "grass"],
		["grass", "grass", "grass"]
	]
	TerrainManagerForTest.decorate_terrain(terrain_map, 3)
	# Center tile should be promoted to plants
	assert_eq(terrain_map[1][1], "plants", "Center tile should be 'plants'")

func test_decorate_terrain_does_not_promote_edge():
	var terrain_map = [
		["grass", "grass", "grass"],
		["grass", "grass", "sand"],
		["grass", "grass", "grass"]
	]
	TerrainManagerForTest.decorate_terrain(terrain_map, 3)
	# Edge and non-surrounded grass tiles should not be promoted
	assert_eq(terrain_map[0][0], "grass", "Edge tile should remain 'grass'")
	assert_eq(terrain_map[1][2], "sand", "Non-grass tile should remain unchanged")

func test_create_tile_sprite_returns_null_for_missing_texture():
	var terrain_map = [["unknown"]]
	var elevation_map = [[0]]
	var tile_textures = {}
	var tile_width = 32.0
	var screen_pos = Vector2(0, 0)
	var screen_offset = Vector2(0, 0)
	var sprite = TerrainManagerForTest.create_tile_sprite(0, 0, terrain_map, elevation_map, tile_textures, tile_width, screen_pos, screen_offset)
	assert_eq(sprite, null, "Should return null if texture is missing")

func test_create_tile_sprite_returns_sprite_for_valid_texture():
	var terrain_map = [["grass"]]
	var elevation_map = [[0]]
	var dummy_texture = ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	var tile_textures = {"grass": dummy_texture}
	var tile_width = 32.0
	var screen_pos = Vector2(0, 0)
	var screen_offset = Vector2(0, 0)
	var sprite = TerrainManagerForTest.create_tile_sprite(0, 0, terrain_map, elevation_map, tile_textures, tile_width, screen_pos, screen_offset)
	assert_not_null(sprite, "Should return a Sprite2D if texture is present")
	assert_eq(sprite.texture, dummy_texture, "Sprite2D should have the correct texture")

func test_create_tile_sprite_scale_and_position():
	var terrain_map = [["grass"]]
	var elevation_map = [[0]]
	var dummy_texture = ImageTexture.create_from_image(Image.create(16, 16, false, Image.FORMAT_RGBA8))
	var tile_textures = {"grass": dummy_texture}
	var tile_width = 32.0
	var screen_pos = Vector2(10, 20)
	var screen_offset = Vector2(5, 5)
	var sprite = TerrainManagerForTest.create_tile_sprite(0, 0, terrain_map, elevation_map, tile_textures, tile_width, screen_pos, screen_offset)
	assert_not_null(sprite, "Should return a Sprite2D if texture is present")
	assert_eq(sprite.scale, Vector2(2, 2), "Sprite2D should be scaled to tile_width/texture_size")
	assert_eq(sprite.position, Vector2(15, 25), "Sprite2D position should be screen_pos + screen_offset")

func test_create_tile_sprite_elevation_offset():
	var terrain_map = [["grass"]]
	var elevation_map = [[3]]
	var dummy_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var tile_textures = {"grass": dummy_texture}
	var tile_width = 16.0
	var screen_pos = Vector2(0, 0)
	var screen_offset = Vector2(0, 0)
	var sprite = TerrainManagerForTest.create_tile_sprite(0, 0, terrain_map, elevation_map, tile_textures, tile_width, screen_pos, screen_offset)
	assert_not_null(sprite, "Should return a Sprite2D if texture is present")
	assert_eq(sprite.position.y, -18, "Sprite2D position.y should be offset by elevation * 6")
