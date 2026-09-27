class_name FloorMap
extends RefCounted
## Kachelkarte einer Etage (entspricht FloorMap in src/engine/types.ts).

var width: int
var height: int
## Kachelnamen wie in TypeScript: "wall", "floor", "door", "dooropen", "stairs" …
var tiles: PackedStringArray


func _init(w: int = 0, h: int = 0, t: PackedStringArray = PackedStringArray()) -> void:
	width = w
	height = h
	tiles = t


static func from_dict(d: Dictionary) -> FloorMap:
	return FloorMap.new(int(d.width), int(d.height), PackedStringArray(d.tiles))


func idx(x: int, y: int) -> int:
	return y * width + x


func in_bounds(x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < width and y < height


func tile_at(x: int, y: int) -> String:
	return tiles[idx(x, y)] if in_bounds(x, y) else "wall"


func is_walkable(x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return t == "floor" or t == "stairs" or t == "dooropen"


## Wände und geschlossene Türen blockieren die Sicht.
func blocks_sight(x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return t == "wall" or t == "door"


func is_door(x: int, y: int) -> bool:
	var t := tile_at(x, y)
	return t == "door" or t == "dooropen"
