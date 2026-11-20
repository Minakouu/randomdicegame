extends Node
# Autoload: oyuncu durumu. Ölünce reset() ile sıfırlanır.

const Db = preload("res://scripts/data_db.gd")

signal stats_changed

# Temel değerler data/player.json'dan gelir. Efektli itemler üstüne eklenir (bkz. get_*).
var base_max_hp := 20
var base_max_stamina := 20
var base_flee_cost := 5
var shop_every := 5
var potion_heal := 10
var potion_price := 10
var stamina_rest_base := 10
var base_hp_regen := 5
var depth_hp := 0.0
var depth_dmg := 0.0

var hp := 20
var stamina := 20
var gold := 0
var potions := 1
var dungeons_cleared := 0
var weapon: Resource
var armor: Resource
var rune: Resource
var accessory: Resource
var defeated_bosses: Array[String] = []

func _ready() -> void:
	randomize()
	reset()

func reset() -> void:
	base_max_hp = int(Db.cfg("max_hp", 20))
	base_max_stamina = int(Db.cfg("max_stamina", 20))
	base_flee_cost = int(Db.cfg("flee_cost", 5))
	shop_every = int(Db.cfg("shop_every", 5))
	potion_heal = int(Db.cfg("potion_heal", 10))
	potion_price = int(Db.cfg("potion_price", 10))
	stamina_rest_base = int(Db.cfg("stamina_rest_base", 10))
	base_hp_regen = int(Db.cfg("hp_regen", 5))
	depth_hp = float(Db.cfg("depth_hp", 0.0))
	depth_dmg = float(Db.cfg("depth_dmg", 0.0))
	weapon = Db.starting_weapon()
	armor = Db.starting_armor()
	rune = null
	accessory = null
	hp = get_max_hp()
	stamina = get_max_stamina()
	gold = int(Db.cfg("start_gold", 0))
	potions = int(Db.cfg("start_potions", 1))
	dungeons_cleared = 0
	defeated_bosses.clear()
	stats_changed.emit()

func roll(sides: int) -> int:
	return randi_range(1, sides)

# ---- Efektler: takılı tüm itemlerin aynı efektini toplar ----
func equipped() -> Array:
	return [weapon, armor, rune, accessory].filter(func(i): return i != null)

func effect(key: String) -> float:
	var total := 0.0
	for it in equipped():
		total += float(it.effects.get(key, 0))
	return total

func get_max_hp() -> int:
	return base_max_hp + int(effect("max_hp"))

func get_max_stamina() -> int:
	return base_max_stamina + int(effect("max_stamina"))

func get_flee_cost() -> int:
	return max(0, base_flee_cost + int(effect("flee_cost")))

func get_hp_regen() -> int:
	return base_hp_regen + int(effect("hp_regen"))

# ---- Flee ----
func can_flee() -> bool:
	return stamina >= get_flee_cost()

func flee() -> bool:
	if not can_flee():
		return false
	stamina -= get_flee_cost()
	stats_changed.emit()
	return true

# ---- Can ----
func damage(n: int) -> void:
	hp = max(0, hp - n)
	stats_changed.emit()

func heal(n: int) -> void:
	hp = min(get_max_hp(), hp + n)
	stats_changed.emit()

func use_potion() -> bool:
	if potions <= 0:
		return false
	potions -= 1
	hp = min(get_max_hp(), hp + potion_heal)
	stats_changed.emit()
	return true

# Dungeon sonrası: altın (efektle çarpılır) + dinlenme. Gerçek kazanılan altını döndürür.
func finish_dungeon(difficulty: int, reward_gold: int) -> int:
	var g := int(round(reward_gold * (1.0 + effect("gold_mult"))))
	gold += g
	dungeons_cleared += 1
	stamina = min(get_max_stamina(), stamina + (stamina_rest_base - difficulty))
	hp = min(get_max_hp(), hp + get_hp_regen())
	stats_changed.emit()
	return g

func shop_due() -> bool:
	return dungeons_cleared > 0 and dungeons_cleared % shop_every == 0

# ---- Ekipman ----
func slot_item(item: Resource) -> Resource:
	match item.type:
		0: return weapon
		1: return armor
		2: return rune
		_: return accessory

func score(item: Resource) -> float:
	var base := 10.5 if item.type == 0 else 5.5
	return (base + item.bonus) * item.multiplier * item.dice_count

# Silah/zırh: daha güçlüyse takar. Rune/aksesuar: slot boşsa takar. Takıldı mı döndürür.
func equip_if_better(item: Resource) -> bool:
	var cur := slot_item(item)
	var better := cur == null or (item.type <= 1 and score(item) > score(cur))
	if better:
		equip(item)
	return better

func equip(item: Resource) -> void:
	match item.type:
		0: weapon = item
		1: armor = item
		2: rune = item
		_: accessory = item
	hp = min(hp, get_max_hp())
	stamina = min(stamina, get_max_stamina())
	stats_changed.emit()

func spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	stats_changed.emit()
	return true
