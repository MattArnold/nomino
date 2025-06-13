# terrain_generator.gd
# Utility for procedural terrain and elevation generation
extends Object

class_name TerrainGenerator

static func generate_terrain_and_elevation(world_width: int, world_height: int, world_offset_x: int, world_offset_y: int, sea_level: float, terrain_noise: FastNoiseLite, elevation_noise: FastNoiseLite) -> Dictionary:
	var terrain_map := []
	var elevation_map := []
	for x in range(world_width):
		terrain_map.append([])
		elevation_map.append([])
		for y in range(world_height):
			var world_x = x + world_offset_x
			var world_y = y + world_offset_y

			# Terrain type noise
			var t_raw = terrain_noise.get_noise_2d(world_x * 0.1, world_y * 0.1)
			var t = (t_raw + 1.0) / 2.0
			var terrain = "sand" if t > 0.5 else "grass"

			# Elevation noise
			var e = elevation_noise.get_noise_2d(world_x + 1000, world_y + 1000)
			var elevation = int(round(e * 3))

			if elevation < sea_level:
				terrain = "water"
				elevation = sea_level

			terrain_map[x].append(terrain)
			elevation_map[x].append(elevation)
	return {"terrain_map": terrain_map, "elevation_map": elevation_map}
