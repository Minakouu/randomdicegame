extends RefCounted
# data/*.json dosyalarını okuyup oyun nesnelerine çevirir.
# Yeni içerik = JSON'a kayıt ekle + (istersen) assets/sprites/ altına png at.

const ItemData = preload("res://scripts/resources/item_data.gd")
const EnemyData = preload("res://scripts/resources/enemy_data.gd")
const DungeonData = preload("res://scripts/resources/dungeon_data.gd")

const DATA_DIR := "res://data/"
const SPRITE_DIR := "res://assets/sprites/"

static var _loaded := false
static var items: Dictionary = {}
static var enemies: Dictionary = {}
static var dungeon_list: Array = []
static var config: Dictionary = {}


static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	config = _read("player.json", {})
	for e in _read("enemies.json", []):
		var en = EnemyData.new()
		en.id = str(e.get("id", ""))
		en.enemy_name = str(e.get("name", en.id))
		en.base_hp = int(e.get("hp", 10))
		en.base_damage_mult = float(e.get("damage_mult", 1.0))
		en.defense_bonus = int(e.get("defense", 0))
		en.is_boss = bool(e.get("boss", false))
		en.abilities = e.get("abilities", [])
		en.sprite = load_texture(str(e.get("sprite", "")), "enemies", en.id)
		enemies[en.id] = en
	for i in _read("items.json", []):
		var it = ItemData.new()
		it.id = str(i.get("id", ""))
		it.item_name = str(i.get("name", it.id))
		var type_map := {"weapon": ItemData.Type.WEAPON, "armor": ItemData.Type.ARMOR, "rune": ItemData.Type.RUNE, "accessory": ItemData.Type.ACCESSORY}
		it.type = type_map.get(str(i.get("type", "weapon")), ItemData.Type.WEAPON)
		it.effects = i.get("effects", {})
		it.bonus = int(i.get("bonus", 0))
		it.multiplier = float(i.get("multiplier", 1.0))
		it.dice_count = int(i.get("dice_count", 1))
		it.price = int(i.get("price", 0))
		it.in_shop = bool(i.get("in_shop", false))
		it.description = str(i.get("description", ""))
		it.sprite = load_texture(str(i.get("sprite", "")), "items", it.id)
		items[it.id] = it
	for d in _read("dungeons.json", []):
		var dg = DungeonData.new()
		dg.id = str(d.get("id", ""))
		dg.dungeon_name = str(d.get("name", dg.id))
		dg.crowd_enemy = _enemy(d.get("crowd", ""), dg.id)
		dg.elite_enemy = _enemy(d.get("elite", ""), dg.id)
		dg.boss = _enemy(d.get("boss", ""), dg.id)
		for iid in d.get("boss_drops", []):
			var drop = items.get(str(iid))
			if drop: dg.boss_drops.append(drop)
			else: push_error("dungeons.json: '%s' için bilinmeyen item '%s'" % [dg.id, iid])
		dg.background = load_texture(str(d.get("background", "")), "dungeons", dg.id)
		if dg.crowd_enemy and dg.elite_enemy and dg.boss and not dg.boss_drops.is_empty():
			dungeon_list.append(dg)
		else:
			push_error("dungeons.json: '%s' eksik (düşman/drop), atlandı" % dg.id)


static func _enemy(id, dungeon_id: String) -> Resource:
	var e = enemies.get(str(id))
	if e == null:
		push_error("dungeons.json: '%s' için bilinmeyen düşman '%s'" % [dungeon_id, id])
	return e


static func _read(file: String, fallback):
	var path := DATA_DIR + file
	if not FileAccess.file_exists(path):
		push_error("Veri dosyası yok: " + path)
		return fallback
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed == null:
		push_error("JSON hatası: " + path)
		return fallback
	return parsed


# sprite alanı boşsa assets/sprites/<klasör>/<id>.png aranır. Yoksa null.
static func load_texture(explicit: String, folder: String, id: String) -> Texture2D:
	var candidates: Array[String] = []
	if explicit != "":
		candidates.append(explicit if explicit.begins_with("res://") else SPRITE_DIR + explicit)
	candidates.append("%s%s/%s.png" % [SPRITE_DIR, folder, id])
	for p in candidates:
		if ResourceLoader.exists(p):
			return load(p)
		if FileAccess.file_exists(p):
			var img := Image.load_from_file(p)
			if img:
				return ImageTexture.create_from_image(img)
	return null


# ---- erişim ----
static func cfg(key: String, default = null):
	ensure_loaded()
	return config.get(key, default)

static func dungeons() -> Array:
	ensure_loaded()
	return dungeon_list

static func item(id: String) -> Resource:
	ensure_loaded()
	return items.get(id)

static func enemy(id: String) -> Resource:
	ensure_loaded()
	return enemies.get(id)

static func shop_stock() -> Array:
	ensure_loaded()
	return items.values().filter(func(i): return i.in_shop)

static func starting_weapon() -> Resource:
	return item(str(cfg("starting_weapon", "")))

static func starting_armor() -> Resource:
	return item(str(cfg("starting_armor", "")))

static func final_boss() -> Resource:
	return enemy(str(cfg("final_boss", "")))

static func final_drop() -> Resource:
	return item(str(cfg("final_drop", "")))

static func player_sprite() -> Texture2D:
	ensure_loaded()
	return load_texture(str(config.get("sprite", "")), "players", "player")
