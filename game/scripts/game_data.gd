# 전역 게임 데이터 (오토로드 싱글톤)
# 작물 정의, 플레이어 자원, 시간, 저장/불러오기를 담당한다.
extends Node

const CROPS := {
	"potato": {"name": "감자", "seed_price": 30, "sell_price": 80, "grow_days": 4},
	"carrot": {"name": "당근", "seed_price": 40, "sell_price": 110, "grow_days": 5},
	"strawberry": {"name": "딸기", "seed_price": 60, "sell_price": 170, "grow_days": 6},
	"pumpkin": {"name": "호박", "seed_price": 100, "sell_price": 320, "grow_days": 9},
}
const CROP_IDS := ["potato", "carrot", "strawberry", "pumpkin"]

const ENERGY_MAX := 100.0
const DAY_START := 6.0 * 60.0   # 오전 6시
const DAY_END := 26.0 * 60.0    # 새벽 2시 강제 취침

const SAVE_PATH := "user://kyojin_farm_save.json"

var day := 1
var minutes := DAY_START
var money := 500
var energy := ENERGY_MAX
var tool := "hoe"
var seed_index := 0
var seeds := {"potato": 5, "carrot": 0, "strawberry": 0, "pumpkin": 0}
var produce := {"potato": 0, "carrot": 0, "strawberry": 0, "pumpkin": 0}


func current_seed_id() -> String:
	return CROP_IDS[seed_index]


func clock_text() -> String:
	var m := int(minutes)
	var h := int(m / 60.0) % 24
	var ampm := "오전" if h < 12 else "오후"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	var mm := int((m % 60) / 10.0) * 10
	return "%s %d:%02d" % [ampm, h12, mm]


func save_game(grid_data: Array, player_pos: Vector2) -> void:
	var data := {
		"day": day,
		"minutes": minutes,
		"money": money,
		"energy": energy,
		"seeds": seeds,
		"produce": produce,
		"player": [player_pos.x, player_pos.y],
		"grid": grid_data,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return parsed
