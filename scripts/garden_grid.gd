class_name GardenGrid
extends RefCounted

## The single address system for plantings, equipment and reserved structures.
## Saved arrays keep their IDs; only their cell addresses describe the layout.
const CELL_SIZE: int = 96
const ORIGIN := Vector2.ZERO
const BLOCK_SIDE: int = 6
const BLOCK_PLOT_COUNT: int = BLOCK_SIDE * BLOCK_SIDE
const HOME_BLOCK_ORIGINS: Array[Vector2i] = [Vector2i(2,5),Vector2i(9,5),Vector2i(2,12),Vector2i(9,12)]
const NURSERY_BLOCK_ORIGINS: Array[Vector2i] = [Vector2i(20,4),Vector2i(27,4),Vector2i(20,11),Vector2i(27,11)]
const HOME_CELLS: Array[Vector2i] = [
	Vector2i(2,5),Vector2i(3,5),Vector2i(4,5),Vector2i(5,5),Vector2i(6,5),Vector2i(7,5),
	Vector2i(2,6),Vector2i(3,6),Vector2i(4,6),Vector2i(5,6),Vector2i(6,6),Vector2i(7,6),
	Vector2i(2,7),Vector2i(3,7),Vector2i(4,7),Vector2i(5,7),Vector2i(6,7),Vector2i(7,7),
	Vector2i(2,8),Vector2i(3,8),Vector2i(4,8),Vector2i(5,8),Vector2i(6,8),Vector2i(7,8),
	Vector2i(2,9),Vector2i(3,9),Vector2i(4,9),Vector2i(5,9),Vector2i(6,9),Vector2i(7,9),
	Vector2i(2,10),Vector2i(3,10),Vector2i(4,10),Vector2i(5,10),Vector2i(6,10),Vector2i(7,10),
	Vector2i(9,5),Vector2i(10,5),Vector2i(11,5),Vector2i(12,5),Vector2i(13,5),Vector2i(14,5),
	Vector2i(9,6),Vector2i(10,6),Vector2i(11,6),Vector2i(12,6),Vector2i(13,6),Vector2i(14,6),
	Vector2i(9,7),Vector2i(10,7),Vector2i(11,7),Vector2i(12,7),Vector2i(13,7),Vector2i(14,7),
	Vector2i(9,8),Vector2i(10,8),Vector2i(11,8),Vector2i(12,8),Vector2i(13,8),Vector2i(14,8),
	Vector2i(9,9),Vector2i(10,9),Vector2i(11,9),Vector2i(12,9),Vector2i(13,9),Vector2i(14,9),
	Vector2i(9,10),Vector2i(10,10),Vector2i(11,10),Vector2i(12,10),Vector2i(13,10),Vector2i(14,10),
	Vector2i(2,12),Vector2i(3,12),Vector2i(4,12),Vector2i(5,12),Vector2i(6,12),Vector2i(7,12),
	Vector2i(2,13),Vector2i(3,13),Vector2i(4,13),Vector2i(5,13),Vector2i(6,13),Vector2i(7,13),
	Vector2i(2,14),Vector2i(3,14),Vector2i(4,14),Vector2i(5,14),Vector2i(6,14),Vector2i(7,14),
	Vector2i(2,15),Vector2i(3,15),Vector2i(4,15),Vector2i(5,15),Vector2i(6,15),Vector2i(7,15),
	Vector2i(2,16),Vector2i(3,16),Vector2i(4,16),Vector2i(5,16),Vector2i(6,16),Vector2i(7,16),
	Vector2i(2,17),Vector2i(3,17),Vector2i(4,17),Vector2i(5,17),Vector2i(6,17),Vector2i(7,17),
	Vector2i(9,12),Vector2i(10,12),Vector2i(11,12),Vector2i(12,12),Vector2i(13,12),Vector2i(14,12),
	Vector2i(9,13),Vector2i(10,13),Vector2i(11,13),Vector2i(12,13),Vector2i(13,13),Vector2i(14,13),
	Vector2i(9,14),Vector2i(10,14),Vector2i(11,14),Vector2i(12,14),Vector2i(13,14),Vector2i(14,14),
	Vector2i(9,15),Vector2i(10,15),Vector2i(11,15),Vector2i(12,15),Vector2i(13,15),Vector2i(14,15),
	Vector2i(9,16),Vector2i(10,16),Vector2i(11,16),Vector2i(12,16),Vector2i(13,16),Vector2i(14,16),
	Vector2i(9,17),Vector2i(10,17),Vector2i(11,17),Vector2i(12,17),Vector2i(13,17),Vector2i(14,17),
]
const NURSERY_CELLS: Array[Vector2i] = [
	Vector2i(20,4),Vector2i(21,4),Vector2i(22,4),Vector2i(23,4),Vector2i(24,4),Vector2i(25,4),
	Vector2i(20,5),Vector2i(21,5),Vector2i(22,5),Vector2i(23,5),Vector2i(24,5),Vector2i(25,5),
	Vector2i(20,6),Vector2i(21,6),Vector2i(22,6),Vector2i(23,6),Vector2i(24,6),Vector2i(25,6),
	Vector2i(20,7),Vector2i(21,7),Vector2i(22,7),Vector2i(23,7),Vector2i(24,7),Vector2i(25,7),
	Vector2i(20,8),Vector2i(21,8),Vector2i(22,8),Vector2i(23,8),Vector2i(24,8),Vector2i(25,8),
	Vector2i(20,9),Vector2i(21,9),Vector2i(22,9),Vector2i(23,9),Vector2i(24,9),Vector2i(25,9),
	Vector2i(27,4),Vector2i(28,4),Vector2i(29,4),Vector2i(30,4),Vector2i(31,4),Vector2i(32,4),
	Vector2i(27,5),Vector2i(28,5),Vector2i(29,5),Vector2i(30,5),Vector2i(31,5),Vector2i(32,5),
	Vector2i(27,6),Vector2i(28,6),Vector2i(29,6),Vector2i(30,6),Vector2i(31,6),Vector2i(32,6),
	Vector2i(27,7),Vector2i(28,7),Vector2i(29,7),Vector2i(30,7),Vector2i(31,7),Vector2i(32,7),
	Vector2i(27,8),Vector2i(28,8),Vector2i(29,8),Vector2i(30,8),Vector2i(31,8),Vector2i(32,8),
	Vector2i(27,9),Vector2i(28,9),Vector2i(29,9),Vector2i(30,9),Vector2i(31,9),Vector2i(32,9),
	Vector2i(20,11),Vector2i(21,11),Vector2i(22,11),Vector2i(23,11),Vector2i(24,11),Vector2i(25,11),
	Vector2i(20,12),Vector2i(21,12),Vector2i(22,12),Vector2i(23,12),Vector2i(24,12),Vector2i(25,12),
	Vector2i(20,13),Vector2i(21,13),Vector2i(22,13),Vector2i(23,13),Vector2i(24,13),Vector2i(25,13),
	Vector2i(20,14),Vector2i(21,14),Vector2i(22,14),Vector2i(23,14),Vector2i(24,14),Vector2i(25,14),
	Vector2i(20,15),Vector2i(21,15),Vector2i(22,15),Vector2i(23,15),Vector2i(24,15),Vector2i(25,15),
	Vector2i(20,16),Vector2i(21,16),Vector2i(22,16),Vector2i(23,16),Vector2i(24,16),Vector2i(25,16),
	Vector2i(27,11),Vector2i(28,11),Vector2i(29,11),Vector2i(30,11),Vector2i(31,11),Vector2i(32,11),
	Vector2i(27,12),Vector2i(28,12),Vector2i(29,12),Vector2i(30,12),Vector2i(31,12),Vector2i(32,12),
	Vector2i(27,13),Vector2i(28,13),Vector2i(29,13),Vector2i(30,13),Vector2i(31,13),Vector2i(32,13),
	Vector2i(27,14),Vector2i(28,14),Vector2i(29,14),Vector2i(30,14),Vector2i(31,14),Vector2i(32,14),
	Vector2i(27,15),Vector2i(28,15),Vector2i(29,15),Vector2i(30,15),Vector2i(31,15),Vector2i(32,15),
	Vector2i(27,16),Vector2i(28,16),Vector2i(29,16),Vector2i(30,16),Vector2i(31,16),Vector2i(32,16),
]
const POND_CELLS: Array[Vector2i] = [
	Vector2i(29,20),Vector2i(30,20),Vector2i(31,20),
	Vector2i(29,21),Vector2i(30,21),Vector2i(31,21),
]
const HELPER_CELLS: Dictionary = {"irrigation":Vector2i(7,24),"compost":Vector2i(8,24),"harvest_crate":Vector2i(9,24)}
const COTTAGE_RECT := Rect2(192,144,336,240)
const NURSERY_RECT := Rect2(1632,96,288,384)
const GREENHOUSE_RECT := Rect2(288,2208,288,288)
const GATE_RECT := Rect2(1440,768,96,96)
const GATE_ART_RECT := Rect2(1448,768,80,96)
const POND_RECT := Rect2(2688,1824,576,384)
const POND_BENCH_RECT := Rect2(2592,2016,96,96)
# Kept as an empty compatibility landmark; the retired berry area is not drawn.
const BERRY_BENCH_RECT := Rect2()
const WELL_RECT := Rect2(576,2592,96,96)


static func cell_center(cell: Vector2i) -> Vector2:
	return ORIGIN+(Vector2(cell)+Vector2.ONE*0.5)*CELL_SIZE


static func cell_rect(cell: Vector2i) -> Rect2:
	return aligned_rect(cell)


static func cell_at(position: Vector2) -> Vector2i:
	return Vector2i(((position-ORIGIN)/CELL_SIZE).floor())


static func aligned_rect(cell: Vector2i, span: Vector2i = Vector2i.ONE) -> Rect2:
	return Rect2(ORIGIN+Vector2(cell)*CELL_SIZE,Vector2(span)*CELL_SIZE)


static func block_origins(area: String) -> Array[Vector2i]:
	return HOME_BLOCK_ORIGINS if area == "home" else NURSERY_BLOCK_ORIGINS if area == "nursery" else []


static func block_rects(area: String) -> Array[Rect2]:
	var result: Array[Rect2] = []
	for origin in block_origins(area): result.append(aligned_rect(origin,Vector2i(BLOCK_SIDE,BLOCK_SIDE)))
	return result


static func block_index(area: String, slot: int) -> int:
	return slot / BLOCK_PLOT_COUNT if (area == "home" or area == "nursery") and slot >= 0 and slot < planting_cells(area).size() else -1


static func planting_cells(area: String) -> Array[Vector2i]:
	return HOME_CELLS if area == "home" else NURSERY_CELLS if area == "nursery" else POND_CELLS if area == "pond" else []


static func planting_cell(area: String, index: int) -> Vector2i:
	var cells: Array[Vector2i] = planting_cells(area)
	return cells[index] if index >= 0 and index < cells.size() else Vector2i(-1,-1)


static func planting_rect(area: String, index: int) -> Rect2:
	var cell: Vector2i = planting_cell(area,index)
	return cell_rect(cell) if cell.x >= 0 else Rect2()


static func centers(area: String) -> Array[Vector2]:
	var result: Array[Vector2] = []
	for cell in planting_cells(area): result.append(cell_center(cell))
	return result


static func helper_cell(id: String) -> Vector2i:
	return HELPER_CELLS.get(id,Vector2i(-1,-1))


static func helper_rect(id: String) -> Rect2:
	var cell: Vector2i = helper_cell(id)
	return cell_rect(cell) if cell.x >= 0 else Rect2()


static func occupied_areas() -> Dictionary:
	return {"cottage":COTTAGE_RECT,"nursery":NURSERY_RECT,"greenhouse":GREENHOUSE_RECT,"gate":GATE_RECT,
		"pond_bench":POND_BENCH_RECT,"well":WELL_RECT,
		"irrigation":helper_rect("irrigation"),"compost":helper_rect("compost"),"harvest_crate":helper_rect("harvest_crate")}
