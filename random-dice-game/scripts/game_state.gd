extends Node
# Autoload: oyuncu durumu, seviye/XP, çoklu slot ve sınırsız çanta. Ölünce reset() ile sıfırlanır.

const Db = preload("res://scripts/data_db.gd")

signal stats_changed

# Temel değerler data/player.json'dan gelir. Efektli itemler ve seviyeler üstüne eklenir.
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

var xp_base := 20
var xp_growth := 15
var hp_per_level := 3
var stamina_per_level := 2
var slot_unlock_interval := 2
var max_extra_slots := 2
var sell_ratio := 0.5
var min_sell_gold := 12

var hp := 20
var stamina := 20
var gold := 0
var potions := 1
var dungeons_cleared := 0
var level := 1
var xp := 0

var weapon: Resource
var armor: Resource
var runes: Array[Resource] = []
var accessories: Array[Resource] = []
var inventory: Array[Resource] = []
var defeated_bosses: Array[String] = []


func _ready() -> void:
	randomize()
	reset()


func reset() -> void:
	base_max_hp = int(Db.cfg("max_hp", 20))
	base_max_stamina = int(Db.cfg("max_stamina", 20))
	base_flee_cost = int(Db.cfg("flee_cost", 5))
	shop_every = maxi(1, int(Db.cfg("shop_every", 5)))
	potion_heal = int(Db.cfg("potion_heal", 10))
	potion_price = int(Db.cfg("potion_price", 10))
	stamina_rest_base = int(Db.cfg("stamina_rest_base", 10))
	base_hp_regen = int(Db.cfg("hp_regen", 5))
	depth_hp = float(Db.cfg("depth_hp", 0.0))
	depth_dmg = float(Db.cfg("depth_dmg", 0.0))

	xp_base = maxi(5, int(Db.cfg("xp_base", 20)))
	xp_growth = maxi(0, int(Db.cfg("xp_growth", 15)))
	hp_per_level = maxi(0, int(Db.cfg("hp_per_level", 3)))
	stamina_per_level = maxi(0, int(Db.cfg("stamina_per_level", 2)))
	slot_unlock_interval = maxi(1, int(Db.cfg("slot_unlock_interval", 2)))
	max_extra_slots = maxi(0, int(Db.cfg("max_extra_slots", 2)))
	sell_ratio = float(Db.cfg("sell_ratio", 0.5))
	min_sell_gold = maxi(1, int(Db.cfg("min_sell_gold", 12)))

	level = 1
	xp = 0
	weapon = Db.starting_weapon()
	armor = Db.starting_armor()
	runes.clear()
	accessories.clear()
	inventory.clear()
	hp = get_max_hp()
	stamina = get_max_stamina()
	gold = int(Db.cfg("start_gold", 0))
	potions = int(Db.cfg("start_potions", 1))
	dungeons_cleared = 0
	defeated_bosses.clear()
	stats_changed.emit()


func roll(sides: int) -> int:
	if sides <= 1:
		return 1
	return randi_range(1, sides)


# ---- Seviye & Slotlar ----
func xp_to_next() -> int:
	return xp_base + (level - 1) * xp_growth


func _extra_unlocks() -> int:
	return mini(max_extra_slots * 2, int(level / float(slot_unlock_interval)))


func get_max_rune_slots() -> int:
	return 1 + int(_extra_unlocks() / 2.0)


func get_max_accessory_slots() -> int:
	return 1 + int((_extra_unlocks() + 1) / 2.0)


func add_xp(amount: int) -> Array[Dictionary]:
	var gains: Array[Dictionary] = []
	xp += maxi(0, amount)
	while xp >= xp_to_next():
		var prev_runes := get_max_rune_slots()
		var prev_accs := get_max_accessory_slots()
		xp -= xp_to_next()
		level += 1
		hp = mini(get_max_hp(), hp + hp_per_level)
		stamina = mini(get_max_stamina(), stamina + stamina_per_level)
		var unlocked := ""
		if get_max_accessory_slots() > prev_accs:
			unlocked = "+1 Aksesuar Slotu"
		elif get_max_rune_slots() > prev_runes:
			unlocked = "+1 Rün Slotu"
		gains.append({"level": level, "unlocked": unlocked})
	stats_changed.emit()
	return gains


# ---- Efektler: takılı tüm itemlerin aynı efektini toplar ----
func equipped() -> Array:
	var list: Array = []
	if weapon != null:
		list.append(weapon)
	if armor != null:
		list.append(armor)
	for r in runes:
		if r != null:
			list.append(r)
	for a in accessories:
		if a != null:
			list.append(a)
	return list


func effect(key: String) -> float:
	var total := 0.0
	for it in equipped():
		if it.effects is Dictionary:
			total += float(it.effects.get(key, 0))
	return total


func get_max_hp() -> int:
	return maxi(1, base_max_hp + (level - 1) * hp_per_level + int(effect("max_hp")))


func get_max_stamina() -> int:
	return maxi(0, base_max_stamina + (level - 1) * stamina_per_level + int(effect("max_stamina")))


func get_flee_cost() -> int:
	return maxi(0, base_flee_cost + int(effect("flee_cost")))


func get_hp_regen() -> int:
	return base_hp_regen + int(effect("hp_regen"))


func get_stamina_regen() -> int:
	return int(effect("stamina_regen"))


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
	hp = maxi(0, hp - maxi(0, n))
	stats_changed.emit()


func heal(n: int) -> void:
	hp = mini(get_max_hp(), hp + maxi(0, n))
	stats_changed.emit()


func use_potion() -> bool:
	if potions <= 0:
		return false
	potions -= 1
	hp = mini(get_max_hp(), hp + potion_heal)
	stats_changed.emit()
	return true


# Dungeon sonrası: altın + dinlenme (stamina_regen efekti dahil). Gerçek kazanılan altını döndürür.
func finish_dungeon(difficulty: int, reward_gold: int) -> int:
	var g := int(round(reward_gold * (1.0 + effect("gold_mult"))))
	gold += g
	dungeons_cleared += 1
	var stam_gain := (stamina_rest_base - difficulty) + get_stamina_regen()
	stamina = clampi(stamina + stam_gain, 0, get_max_stamina())
	hp = clampi(hp + get_hp_regen(), 0, get_max_hp())
	stats_changed.emit()
	return g


func shop_due() -> bool:
	return dungeons_cleared > 0 and dungeons_cleared % shop_every == 0


# ---- Ekipman & Çanta ----
func acquire_item(item: Resource) -> Dictionary:
	if item == null:
		return {"equipped": false, "slot": ""}
	var t := int(item.type)
	if t == 0 and weapon == null:
		weapon = item
		_clamp_vitals()
		stats_changed.emit()
		return {"equipped": true, "slot": "Silah"}
	if t == 1 and armor == null:
		armor = item
		_clamp_vitals()
		stats_changed.emit()
		return {"equipped": true, "slot": "Zırh"}
	if t == 2 and runes.size() < get_max_rune_slots():
		runes.append(item)
		_clamp_vitals()
		stats_changed.emit()
		return {"equipped": true, "slot": "Rün"}
	if t == 3 and accessories.size() < get_max_accessory_slots():
		accessories.append(item)
		_clamp_vitals()
		stats_changed.emit()
		return {"equipped": true, "slot": "Aksesuar"}
	inventory.append(item)
	stats_changed.emit()
	return {"equipped": false, "slot": ""}


func equip(item: Resource) -> void:
	if item == null:
		return
	var t := int(item.type)
	match t:
		0:
			if weapon != null:
				inventory.append(weapon)
			weapon = item
		1:
			if armor != null:
				inventory.append(armor)
			armor = item
		2:
			if runes.size() < get_max_rune_slots():
				runes.append(item)
			else:
				var old: Resource = runes[0]
				runes[0] = item
				inventory.append(old)
		_:
			if accessories.size() < get_max_accessory_slots():
				accessories.append(item)
			else:
				var old: Resource = accessories[0]
				accessories[0] = item
				inventory.append(old)
	_clamp_vitals()
	stats_changed.emit()


func equip_from_bag(bag_idx: int) -> bool:
	if bag_idx < 0 or bag_idx >= inventory.size():
		return false
	var item: Resource = inventory[bag_idx]
	inventory.remove_at(bag_idx)
	equip(item)
	return true


func unequip_rune(idx: int) -> bool:
	if idx < 0 or idx >= runes.size():
		return false
	inventory.append(runes[idx])
	runes.remove_at(idx)
	_clamp_vitals()
	stats_changed.emit()
	return true


func unequip_accessory(idx: int) -> bool:
	if idx < 0 or idx >= accessories.size():
		return false
	inventory.append(accessories[idx])
	accessories.remove_at(idx)
	_clamp_vitals()
	stats_changed.emit()
	return true


func sell_price(item: Resource) -> int:
	if item == null:
		return 0
	var p := int(item.price)
	if p <= 0:
		return min_sell_gold
	return maxi(min_sell_gold, int(round(p * sell_ratio)))


func sell_from_bag(bag_idx: int) -> int:
	if bag_idx < 0 or bag_idx >= inventory.size():
		return 0
	var item: Resource = inventory[bag_idx]
	var gained := sell_price(item)
	inventory.remove_at(bag_idx)
	gold += gained
	stats_changed.emit()
	return gained


func _clamp_vitals() -> void:
	hp = mini(hp, get_max_hp())
	stamina = mini(stamina, get_max_stamina())


func add_gold(amount: int) -> void:
	gold += maxi(0, amount)
	stats_changed.emit()


func spend(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	stats_changed.emit()
	return true