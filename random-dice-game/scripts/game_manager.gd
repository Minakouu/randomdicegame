extends Control
# Ana oyun akışı. UI kodla kurulur. State: ROLLING -> DECISION -> COMBAT -> (SHOP) ; DEAD / VICTORY

const Db = preload("res://scripts/data_db.gd")

enum S { ROLLING, DECISION, COMBAT, SHOP, DEAD, VICTORY }

const ABILITY_TEXT := {
	"heal": "iyileşir", "regen": "yenilenir", "double_hit": "çift vuruş",
	"pierce": "zırh deler", "enrage": "öfkelenir",
}

var state: int = S.ROLLING
var dungeons: Array = []
var dungeon: Resource
var die1_done := false
var die2_done := false
var difficulty := 0
var final_mode := false

var enemy_name := ""
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_mult := 1.0
var enemy_def_mult := 1.0
var enemy_is_boss := false
var enemy_abilities: Array = []
var enemy_turns := 0
var player_attacks := 0
var enemy_burn := 0
var enemy_poison := 0
var busy := false
var shop_items: Array = []
var shop_item_btns: Array[Dictionary] = []

var lbl_stats: Label
var lbl_equip: Label
var lbl_bosses: Label
var lbl_info: Label
var log_box: RichTextLabel
var bg_tex: TextureRect
var player_tex: TextureRect
var enemy_tex: TextureRect
var player_name_lbl: Label
var enemy_name_lbl: Label
var cur_enemy: Resource
var dice_row: HBoxContainer
var action_row: HBoxContainer
var shop_row: HFlowContainer

var btn_die1: Button
var btn_die2: Button
var btn_enter: Button
var btn_flee: Button
var btn_attack: Button
var btn_potion: Button
var btn_pass: Button
var btn_bag: Button
var btn_final: Button
var btn_new: Button
var btn_shop_potion: Button

var inv_panel: PanelContainer
var inv_equipped_box: VBoxContainer
var inv_bag_box: VBoxContainer


func _ready() -> void:
	dungeons = Db.dungeons()
	_build_ui()
	GameState.stats_changed.connect(_refresh)
	_log("[b]Random Ass Dice Game[/b] — iki zara da tıkla.")
	if dungeons.is_empty():
		_log("[color=#e06666]Hata: Geçerli dungeon yüklenemedi (data/dungeons.json kontrol et).[/color]")
	_refresh()


# ---------------------------------------------------------------- UI kurulumu
func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("#14121a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	bg_tex = TextureRect.new()
	bg_tex.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg_tex.modulate = Color(1, 1, 1, 0.55)
	add_child(bg_tex)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)

	lbl_stats = Label.new()
	lbl_stats.add_theme_font_size_override("font_size", 21)
	root.add_child(lbl_stats)

	lbl_equip = Label.new()
	lbl_equip.add_theme_color_override("font_color", Color("#9aa5b8"))
	lbl_equip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(lbl_equip)

	lbl_bosses = Label.new()
	lbl_bosses.add_theme_color_override("font_color", Color("#c9b458"))
	lbl_bosses.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(lbl_bosses)

	lbl_info = Label.new()
	lbl_info.add_theme_font_size_override("font_size", 24)
	lbl_info.autowrap_mode = TextServer.AUTOWRAP_WORD
	root.add_child(lbl_info)

	var stage := HBoxContainer.new()
	stage.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stage.add_theme_constant_override("separation", 12)
	root.add_child(stage)

	var pbox := _sprite_box(stage)
	player_tex = pbox[0]
	player_name_lbl = pbox[1]
	player_tex.texture = Db.player_sprite()
	player_name_lbl.text = str(Db.cfg("name", "Oyuncu"))

	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage.add_child(log_box)

	var ebox := _sprite_box(stage)
	enemy_tex = ebox[0]
	enemy_name_lbl = ebox[1]

	dice_row = HBoxContainer.new()
	dice_row.alignment = BoxContainer.ALIGNMENT_CENTER
	dice_row.add_theme_constant_override("separation", 24)
	root.add_child(dice_row)
	btn_die1 = _btn("🎲 Zar 1\nDungeon", _on_die1, dice_row, Vector2(220, 86))
	btn_die2 = _btn("🎲 Zar 2\nZorluk", _on_die2, dice_row, Vector2(220, 86))

	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	root.add_child(action_row)
	btn_enter = _btn("Enter", _on_enter, action_row)
	btn_flee = _btn("Flee (-5 stamina)", _on_flee, action_row)
	btn_attack = _btn("Attack", _on_attack, action_row)
	btn_potion = _btn("Can İksiri", _on_potion, action_row)
	btn_pass = _btn("Pass", _on_pass, action_row)
	btn_bag = _btn("🎒 Çanta (0)", _toggle_bag, action_row)
	btn_final = _btn("☠ Boss Yolu", _on_final, action_row)
	btn_new = _btn("Yeni Run", _on_new_run, action_row)

	shop_row = HFlowContainer.new()
	shop_row.alignment = FlowContainer.ALIGNMENT_CENTER
	shop_row.add_theme_constant_override("separation", 10)
	root.add_child(shop_row)

	_build_inventory_overlay()


func _build_inventory_overlay() -> void:
	inv_panel = PanelContainer.new()
	inv_panel.visible = false
	inv_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#181520ee")
	style.border_color = Color("#c9b458")
	style.set_border_width_all(2)
	style.set_content_margin_all(20)
	inv_panel.add_theme_stylebox_override("panel", style)
	add_child(inv_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	inv_panel.add_child(vbox)

	var header := HBoxContainer.new()
	vbox.add_child(header)
	var title := Label.new()
	title.text = "🎒 Ekipman & Çanta"
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("#c9b458"))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_btn("Kapat", _toggle_bag, header, Vector2(110, 40))

	var eq_title := Label.new()
	eq_title.text = "Takılı Ekipmanlar (Rün/Aksesuar slotları her 2 seviyede bir açılır)"
	eq_title.add_theme_color_override("font_color", Color("#9aa5b8"))
	vbox.add_child(eq_title)

	inv_equipped_box = VBoxContainer.new()
	inv_equipped_box.add_theme_constant_override("separation", 6)
	vbox.add_child(inv_equipped_box)

	var bag_title := Label.new()
	bag_title.text = "Çantadaki Eşyalar (Mağazada satabilirsin)"
	bag_title.add_theme_color_override("font_color", Color("#9aa5b8"))
	vbox.add_child(bag_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(scroll)

	inv_bag_box = VBoxContainer.new()
	inv_bag_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inv_bag_box.add_theme_constant_override("separation", 6)
	scroll.add_child(inv_bag_box)


func _sprite_box(parent: Node) -> Array:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(220, 0)
	parent.add_child(box)
	var tex := TextureRect.new()
	tex.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(tex)
	var lbl := Label.new()
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	return [tex, lbl]


func _btn(text: String, cb: Callable, parent: Node, min_size := Vector2(150, 48)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _log(t: String) -> void:
	log_box.append_text(t + "\n")


# ---------------------------------------------------------------- Görünüm
func _refresh() -> void:
	var gs := GameState
	lbl_stats.text = "Lv %d (%d/%d XP)   |   ❤ %d/%d   ⚡ %d/%d   💰 %d   🧪 %d   Tamamlanan: %d" % [
		gs.level, gs.xp, gs.xp_to_next(),
		gs.hp, gs.get_max_hp(), gs.stamina, gs.get_max_stamina(),
		gs.gold, gs.potions, gs.dungeons_cleared]

	var rune_names: Array[String] = []
	for r in gs.runes:
		rune_names.append(str(r.item_name))
	var acc_names: Array[String] = []
	for a in gs.accessories:
		acc_names.append(str(a.item_name))
	var rune_txt := ", ".join(rune_names) if not rune_names.is_empty() else "—"
	var acc_txt := ", ".join(acc_names) if not acc_names.is_empty() else "—"

	lbl_equip.text = "Silah: %s   |   Zırh: %s   |   Rün (%d/%d): %s   |   Aksesuar (%d/%d): %s" % [
		gs.weapon.describe() if gs.weapon else "—",
		gs.armor.describe() if gs.armor else "—",
		gs.runes.size(), gs.get_max_rune_slots(), rune_txt,
		gs.accessories.size(), gs.get_max_accessory_slots(), acc_txt]

	var parts: Array[String] = []
	for d in dungeons:
		parts.append("%s %s" % [d.dungeon_name, "✓" if gs.defeated_bosses.has(d.dungeon_name) else "✗"])
	lbl_bosses.text = "Boss'lar:  " + "   ".join(parts)

	match state:
		S.ROLLING, S.DECISION:
			var t1 := "🎲 Dungeon: %s" % str(dungeon.dungeon_name) if (die1_done and dungeon != null) else "🎲 Zar 1\nDungeon"
			var t2 := "🎲 Zorluk: %d" % difficulty if die2_done else "🎲 Zar 2\nZorluk"
			btn_die1.text = t1
			btn_die2.text = t2
			btn_die1.disabled = die1_done or busy or dungeons.is_empty()
			btn_die2.disabled = die2_done or busy or dungeons.is_empty()
			if die1_done and die2_done and dungeon != null:
				var e := _preview_enemy()
				if e != null:
					var atk_m := float(e.base_damage_mult) * _scaled_mult()
					var def_m := float(e.defense_mult) * _diff_def_scale()
					var xp_est := _calc_xp(e)
					lbl_info.text = "%s — Zorluk %d: %s (❤ %d | ⚔ ×%.2f | 🛡 ×%.2f | +%d XP)%s" % [
						dungeon.dungeon_name, difficulty, e.enemy_name,
						_scaled_hp(e), atk_m, def_m, xp_est, _ability_text(e.abilities)]
			else:
				lbl_info.text = "Zarları at."
		S.COMBAT:
			var dot_txt := ""
			if enemy_burn > 0:
				dot_txt += "   🔥 Yanma:%d" % enemy_burn
			if enemy_poison > 0:
				dot_txt += "   ☠ Zehir:%d" % enemy_poison
			lbl_info.text = "⚔ %s   ❤ %d/%d   (🛡 ×%.2f)%s%s" % [
				enemy_name, enemy_hp, enemy_max_hp, enemy_def_mult, dot_txt, _ability_text(enemy_abilities)]
		S.SHOP:
			lbl_info.text = "🛒 Mağaza (Eşya satmak için Çanta'yı açabilirsin)"
			_refresh_shop()
		S.DEAD:
			lbl_info.text = "☠ Öldün"
		S.VICTORY:
			lbl_info.text = "🏆 Kazandın!"

	var shown: Resource = null
	if state == S.COMBAT:
		shown = cur_enemy
	elif state == S.DECISION and dungeon != null:
		shown = _preview_enemy()
	enemy_tex.texture = shown.sprite if shown else null
	enemy_name_lbl.text = str(shown.enemy_name) if shown else ""
	var show_bg := dungeon != null and not final_mode and (state == S.DECISION or state == S.COMBAT)
	bg_tex.texture = dungeon.background if show_bg else null

	dice_row.visible = state == S.ROLLING or state == S.DECISION
	btn_enter.visible = state == S.DECISION
	btn_flee.visible = state == S.DECISION
	btn_flee.disabled = not gs.can_flee() or busy
	btn_flee.text = "Flee (-%d stamina)" % gs.get_flee_cost()
	btn_enter.disabled = busy
	btn_attack.disabled = busy
	btn_pass.disabled = busy
	btn_attack.visible = state == S.COMBAT
	btn_potion.visible = state == S.COMBAT
	btn_potion.text = "🧪 Can İksiri (%d)" % gs.potions
	btn_potion.disabled = gs.potions <= 0 or busy
	btn_pass.visible = state == S.COMBAT

	btn_bag.visible = state == S.ROLLING or state == S.DECISION or state == S.SHOP
	btn_bag.text = "🎒 Çanta (%d)" % gs.inventory.size()
	btn_bag.disabled = busy

	btn_final.visible = state == S.ROLLING and not die1_done and not die2_done and not dungeons.is_empty() and gs.defeated_bosses.size() >= dungeons.size()
	btn_final.disabled = busy
	btn_new.visible = state == S.DEAD or state == S.VICTORY
	shop_row.visible = state == S.SHOP

	if state == S.COMBAT or state == S.DEAD or state == S.VICTORY:
		inv_panel.visible = false
	elif inv_panel.visible:
		_refresh_inventory_ui()


# ---------------------------------------------------------------- Çanta UI
func _toggle_bag() -> void:
	if busy or state == S.COMBAT or state == S.DEAD or state == S.VICTORY:
		return
	inv_panel.visible = not inv_panel.visible
	if inv_panel.visible:
		_refresh_inventory_ui()


func _refresh_inventory_ui() -> void:
	for c in inv_equipped_box.get_children():
		c.queue_free()
	for c in inv_bag_box.get_children():
		c.queue_free()

	var gs := GameState
	_add_equipped_line("Silah", gs.weapon, Callable())
	_add_equipped_line("Zırh", gs.armor, Callable())

	for i in gs.get_max_rune_slots():
		var item: Resource = gs.runes[i] if i < gs.runes.size() else null
		_add_equipped_line("Rün %d" % (i + 1), item, _on_unequip_rune.bind(i) if item != null else Callable())

	for i in gs.get_max_accessory_slots():
		var item: Resource = gs.accessories[i] if i < gs.accessories.size() else null
		_add_equipped_line("Aksesuar %d" % (i + 1), item, _on_unequip_accessory.bind(i) if item != null else Callable())

	if gs.inventory.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Çanta boş."
		empty_lbl.add_theme_color_override("font_color", Color("#9aa5b8"))
		inv_bag_box.add_child(empty_lbl)
		return

	for idx in gs.inventory.size():
		var it: Resource = gs.inventory[idx]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		inv_bag_box.add_child(row)

		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture = it.sprite
		row.add_child(icon)

		var lbl := Label.new()
		lbl.text = "[%s] %s" % [it.type_label(), it.describe()]
		lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(lbl)

		_btn("Kuşan", _on_equip_bag_item.bind(idx), row, Vector2(95, 36))

		if state == S.SHOP:
			var sg := gs.sell_price(it)
			_btn("Sat (+%dg)" % sg, _on_sell_bag_item.bind(idx), row, Vector2(120, 36))


func _on_unequip_rune(idx: int) -> void:
	GameState.unequip_rune(idx)


func _on_unequip_accessory(idx: int) -> void:
	GameState.unequip_accessory(idx)


func _on_equip_bag_item(idx: int) -> void:
	if idx < 0 or idx >= GameState.inventory.size():
		return
	var it: Resource = GameState.inventory[idx]
	if GameState.equip_from_bag(idx):
		_log("Kuşandın: %s" % it.describe())


func _on_sell_bag_item(idx: int) -> void:
	if state != S.SHOP or idx < 0 or idx >= GameState.inventory.size():
		return
	var it: Resource = GameState.inventory[idx]
	var gained := GameState.sell_from_bag(idx)
	if gained > 0:
		_log("Satıldı: %s (+%d altın)" % [it.item_name, gained])


func _add_equipped_line(slot_label: String, item: Resource, unequip_cb: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	inv_equipped_box.add_child(row)

	var lbl := Label.new()
	lbl.text = "%s: %s" % [slot_label, item.describe() if item != null else "— Boş —"]
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if item == null:
		lbl.add_theme_color_override("font_color", Color("#7c8496"))
	row.add_child(lbl)

	if unequip_cb.is_valid():
		_btn("Çıkar", unequip_cb, row, Vector2(95, 34))


# ---------------------------------------------------------------- Zarlar
func _on_die1() -> void:
	if busy or die1_done or state != S.ROLLING or dungeons.is_empty():
		return
	busy = true
	_refresh()
	var result := GameState.roll(dungeons.size()) - 1
	for i in 10:
		btn_die1.text = "🎲 " + str(dungeons[randi() % dungeons.size()].dungeon_name)
		await get_tree().create_timer(0.04 + i * 0.012).timeout
		if not is_inside_tree() or state != S.ROLLING:
			busy = false
			return
	dungeon = dungeons[result]
	die1_done = true
	busy = false
	_log("Zar 1 → [b]%s[/b]" % dungeon.dungeon_name)
	_after_dice()


func _on_die2() -> void:
	if busy or die2_done or state != S.ROLLING or dungeons.is_empty():
		return
	busy = true
	_refresh()
	var result := GameState.roll(6)
	for i in 10:
		btn_die2.text = "🎲 %d" % GameState.roll(6)
		await get_tree().create_timer(0.04 + i * 0.012).timeout
		if not is_inside_tree() or state != S.ROLLING:
			busy = false
			return
	difficulty = result
	die2_done = true
	busy = false
	_log("Zar 2 → zorluk [b]%d[/b]" % difficulty)
	_after_dice()


func _after_dice() -> void:
	if die1_done and die2_done:
		state = S.DECISION
		if not GameState.can_flee():
			_log("[color=#e08a4a]Stamina düşük, kaçamazsın![/color]")
	_refresh()


func _preview_enemy() -> Resource:
	if dungeon == null:
		return null
	return dungeon.get_enemy(difficulty)


# Kademe içi ölçek: zorluk 1,3,5 taban; 2,4,6 daha güçlü. Savunma çarpanı 1..6 arası kademeli artar (0.8x -> 1.6x).
func _step() -> int:
	return (difficulty - 1) % 2


func _diff_def_scale() -> float:
	return 0.80 + float(maxi(1, difficulty) - 1) * 0.16


func _scaled_hp(e: Resource) -> int:
	var depth := 1.0 + GameState.depth_hp * GameState.dungeons_cleared
	return int(round(float(e.base_hp) * (1.0 + 0.25 * _step()) * depth))


func _scaled_mult() -> float:
	return (1.0 + 0.15 * _step()) * (1.0 + GameState.depth_dmg * GameState.dungeons_cleared)


func _calc_xp(e: Resource) -> int:
	if e != null and int(e.xp) > 0:
		return int(e.xp)
	var is_b := bool(e.is_boss) if e != null else false
	return difficulty * 6 + (12 if is_b else 0) + (20 if final_mode else 0)


func _ability_text(abilities: Array) -> String:
	if abilities.is_empty():
		return ""
	var names: Array[String] = []
	for a in abilities:
		names.append(str(ABILITY_TEXT.get(a, str(a))))
	return "   [" + ", ".join(names) + "]"


func _on_flee() -> void:
	if busy or state != S.DECISION:
		return
	if GameState.flee():
		_log("Kaçtın. (-%d stamina)" % GameState.get_flee_cost())
		_reset_rolls()


func _reset_rolls() -> void:
	die1_done = false
	die2_done = false
	state = S.ROLLING
	_refresh()


# ---------------------------------------------------------------- Dungeon / Combat
func _on_enter() -> void:
	if busy or state != S.DECISION or dungeon == null:
		return
	var e := _preview_enemy()
	if e == null:
		return
	final_mode = false
	_start_combat(e, _scaled_hp(e), _scaled_mult(), _diff_def_scale())


func _on_final() -> void:
	if busy or state != S.ROLLING or die1_done or die2_done:
		return
	var e := Db.final_boss()
	if e == null:
		_log("[color=#e06666]Final boss yüklenemedi![/color]")
		return
	final_mode = true
	difficulty = 6
	_log("[color=#c9b458]Boss Yolu açıldı![/color]")
	_start_combat(e, int(e.base_hp), 1.0, _diff_def_scale())


func _start_combat(e: Resource, hp: int, mult_scale: float, def_scale: float) -> void:
	cur_enemy = e
	enemy_name = str(e.enemy_name)
	enemy_hp = hp
	enemy_max_hp = hp
	enemy_mult = float(e.base_damage_mult) * mult_scale
	enemy_def_mult = float(e.defense_mult) * def_scale
	enemy_is_boss = bool(e.is_boss)
	enemy_abilities = e.abilities
	enemy_turns = 0
	player_attacks = 0
	enemy_burn = 0
	enemy_poison = 0
	busy = false
	inv_panel.visible = false
	state = S.COMBAT
	_log("[b]%s[/b] ile savaş başladı. Sen ilk başlarsın." % enemy_name)
	_refresh()


func _on_attack() -> void:
	if busy or state != S.COMBAT:
		return
	var w := GameState.weapon
	var w_dice: int = int(w.dice_count) if w else 1
	var w_bonus: float = float(w.bonus) if w else 0.0
	var w_mult: float = float(w.multiplier) if w else 1.0
	var crit_n := int(GameState.effect("crit"))
	var first_bonus := int(GameState.effect("first_strike")) if player_attacks == 0 else 0
	player_attacks += 1

	var total := 0.0
	var crit := false
	var rolls: Array[String] = []
	for i in w_dice:
		var r := GameState.roll(20)
		var v: float = (r + w_bonus) * w_mult
		if crit_n > 0 and r > 20 - crit_n:
			v *= 2.0
			crit = true
			rolls.append(str(r) + "!")
		else:
			rolls.append(str(r))
		total += v

	var dmg := int(round(total)) + first_bonus
	var def := int(round(GameState.roll(10) * enemy_def_mult))
	var net := dmg - def
	var fs_note := " (+%d İlk Vuruş)" % first_bonus if first_bonus > 0 else ""

	if net <= 0:
		_log("Saldırı [%s]%s → %d, düşman savunması %d (×%.2f): [color=#8aa]savuşturdu[/color]." % [
			", ".join(rolls), fs_note, dmg, def, enemy_def_mult])
		_float(enemy_tex, "MISS", Color("#8899aa"))
	else:
		enemy_hp = maxi(0, enemy_hp - net)
		_log("Saldırı [%s]%s → %d − savunma %d = [color=#7fd17f]%d hasar[/color]%s." % [
			", ".join(rolls), fs_note, dmg, def, net, " [b]KRİTİK![/b]" if crit else ""])
		_float(enemy_tex, str(net) + ("!" if crit else ""), Color("#ffd24a") if crit else Color("#ffffff"))
		_flash(enemy_tex)

		var ls := GameState.effect("lifesteal")
		if ls > 0.0:
			var got: int = maxi(1, int(round(net * ls)))
			GameState.heal(got)
			_log("  Can çaldın: +%d" % got)
			_float(player_tex, "+%d" % got, Color("#7fd17f"))

		var burn_add := int(GameState.effect("burn"))
		if burn_add > 0 and enemy_hp > 0:
			enemy_burn += burn_add
			_log("  [color=#fb923c]🔥 +%d Yanma uygulandı (toplam %d)[/color]" % [burn_add, enemy_burn])

		var poison_add := int(GameState.effect("poison"))
		if poison_add > 0 and enemy_hp > 0:
			enemy_poison += poison_add
			_log("  [color=#4ade80]☠ +%d Zehir uygulandı (toplam %d)[/color]" % [poison_add, enemy_poison])

	_after_player_turn()


func _on_potion() -> void:
	if busy or state != S.COMBAT:
		return
	if GameState.use_potion():
		_log("🧪 İksir içtin (+%d can). Turun gitti." % GameState.potion_heal)
		_float(player_tex, "+%d" % GameState.potion_heal, Color("#7fd17f"))
		_after_player_turn()


func _on_pass() -> void:
	if busy or state != S.COMBAT:
		return
	_log("Turu pas geçtin.")
	_after_player_turn()


func _after_player_turn() -> void:
	busy = true
	_refresh()
	if enemy_hp <= 0:
		await get_tree().create_timer(0.25).timeout
		if not is_inside_tree() or state != S.COMBAT:
			busy = false
			return
		busy = false
		_win()
		return
	await get_tree().create_timer(0.45).timeout
	if not is_inside_tree() or state != S.COMBAT:
		busy = false
		return
	await _enemy_turn()
	if state == S.COMBAT:
		busy = false
		_refresh()


func _enemy_turn() -> void:
	enemy_turns += 1

	# Yanma ve Zehir hasarı
	if enemy_burn > 0:
		enemy_hp = maxi(0, enemy_hp - enemy_burn)
		_log("[color=#fb923c]🔥 %s yanmadan %d hasar aldı.[/color]" % [enemy_name, enemy_burn])
		_float(enemy_tex, "🔥-%d" % enemy_burn, Color("#fb923c"))
		_flash(enemy_tex)
		enemy_burn = maxi(0, enemy_burn - 1)
		_refresh()
		if enemy_hp <= 0:
			await get_tree().create_timer(0.25).timeout
			if is_inside_tree() and state == S.COMBAT:
				busy = false
				_win()
			return

	if enemy_poison > 0:
		enemy_hp = maxi(0, enemy_hp - enemy_poison)
		_log("[color=#4ade80]☠ %s zehirden %d hasar aldı.[/color]" % [enemy_name, enemy_poison])
		_float(enemy_tex, "☠-%d" % enemy_poison, Color("#4ade80"), -24.0)
		_flash(enemy_tex)
		_refresh()
		if enemy_hp <= 0:
			await get_tree().create_timer(0.25).timeout
			if is_inside_tree() and state == S.COMBAT:
				busy = false
				_win()
			return

	if enemy_abilities.has("regen") and enemy_hp < enemy_max_hp:
		enemy_hp = mini(enemy_max_hp, enemy_hp + 2)
		_log("%s yenileniyor (+2)." % enemy_name)
	if enemy_abilities.has("heal") and enemy_turns % 3 == 0:
		var h := int(round(enemy_max_hp * 0.2))
		enemy_hp = mini(enemy_max_hp, enemy_hp + h)
		_log("[color=#c9b458]%s kendini iyileştirdi (+%d).[/color]" % [enemy_name, h])
		_float(enemy_tex, "+%d" % h, Color("#7fd17f"))

	var mult := enemy_mult
	if enemy_abilities.has("enrage") and enemy_hp * 2 < enemy_max_hp:
		mult *= 1.3
	var hits := 2 if (enemy_abilities.has("double_hit") and enemy_turns % 3 == 0) else 1
	if hits == 2:
		_log("[color=#c9b458]%s çift vuruş yapıyor![/color]" % enemy_name)
	for i in hits:
		if i > 0:
			await get_tree().create_timer(0.3).timeout
			if not is_inside_tree() or state != S.COMBAT:
				return
		_enemy_strike(mult, -28.0 * i)
		if GameState.hp <= 0:
			_die()
			return
		if enemy_hp <= 0:
			await get_tree().create_timer(0.25).timeout
			if is_inside_tree() and state == S.COMBAT:
				busy = false
				_win()
			return


func _enemy_strike(mult: float, float_offset_y := 0.0) -> void:
	var r := GameState.roll(20)
	var dmg := int(round(r * mult))
	var a := GameState.armor
	var a_bonus: float = float(a.bonus) if a else 0.0
	var a_mult: float = float(a.multiplier) if a else 1.0
	var dbonus := float(GameState.effect("defense_bonus"))
	var def := int(round((GameState.roll(10) + a_bonus + dbonus) * a_mult))
	if enemy_abilities.has("pierce"):
		def = int(def / 2.0)
	var net := dmg - def
	if net <= 0:
		_log("%s saldırdı (%d), savunman %d: [color=#8aa]dodge![/color]" % [enemy_name, dmg, def])
		_float(player_tex, "DODGE", Color("#8899aa"), float_offset_y)
	else:
		GameState.damage(net)
		_log("%s saldırdı (%d) − savunma %d = [color=#e06666]%d hasar[/color]." % [enemy_name, dmg, def, net])
		_float(player_tex, "-%d" % net, Color("#ff6666"), float_offset_y)
		_flash(player_tex)
		var thorns := int(GameState.effect("thorns"))
		if thorns > 0 and GameState.hp > 0:
			enemy_hp = maxi(0, enemy_hp - thorns)
			_log("  [color=#c084fc]🌵 Diken: %s %d hasar yansıdı.[/color]" % [enemy_name, thorns])
			_float(enemy_tex, "🌵-%d" % thorns, Color("#c084fc"))
			_flash(enemy_tex)


# ---------------------------------------------------------------- Efektler
func _float(target: Control, text: String, color: Color, offset_y := 0.0) -> void:
	if not is_instance_valid(target):
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 32)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.global_position = target.global_position + Vector2(target.size.x * 0.35, target.size.y * 0.3 + offset_y)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 70.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _flash(target: Control) -> void:
	if not is_instance_valid(target):
		return
	var prev = target.get_meta("flash_tw", null)
	if prev is Tween and prev.is_valid():
		prev.kill()
	target.modulate = Color.WHITE
	target.scale = Vector2.ONE
	target.pivot_offset = target.size / 2.0
	var tw := create_tween()
	target.set_meta("flash_tw", tw)
	tw.tween_property(target, "modulate", Color(1, 0.35, 0.35), 0.07)
	tw.parallel().tween_property(target, "scale", Vector2(1.12, 1.12), 0.07)
	tw.tween_property(target, "modulate", Color.WHITE, 0.15)
	tw.parallel().tween_property(target, "scale", Vector2.ONE, 0.15)


func _die() -> void:
	state = S.DEAD
	busy = false
	_log("[color=#e06666][b]Öldün.[/b] %d dungeon tamamladın. Her şey sıfırlanacak.[/color]" % GameState.dungeons_cleared)
	_refresh()


func _win() -> void:
	_log("[color=#7fd17f][b]%s yenildi![/b][/color]" % enemy_name)
	var xp_gain := _calc_xp(cur_enemy)
	var levelups := GameState.add_xp(xp_gain)
	_log("+%d XP." % xp_gain)
	for lv in levelups:
		var unlock_txt := (", " + str(lv["unlocked"])) if str(lv["unlocked"]) != "" else ""
		_log("[color=#67e8f9][b]SEVİYE ATLADIN! Lv %d[/b] (+%d Maks Can, +%d Maks Stamina%s)[/color]" % [
			int(lv["level"]), GameState.hp_per_level, GameState.stamina_per_level, unlock_txt])
		_float(player_tex, "LV %d!" % int(lv["level"]), Color("#67e8f9"), -24.0)

	if final_mode:
		var final_item := Db.final_drop()
		if final_item != null:
			GameState.acquire_item(final_item)
			_log("[color=#c9b458][b]OYUNU BİTİRDİN![/b] Ödül: %s[/color]" % final_item.describe())
		else:
			_log("[color=#c9b458][b]OYUNU BİTİRDİN![/b][/color]")
		state = S.VICTORY
		_refresh()
		return

	var base_gold := difficulty * 4 + randi_range(0, 5) + (20 if enemy_is_boss else 0)
	var gold := GameState.finish_dungeon(difficulty, base_gold)
	var stamina_gain := (GameState.stamina_rest_base - difficulty) + GameState.get_stamina_regen()
	_log("+%d altın, %+d stamina, +%d can." % [gold, stamina_gain, GameState.get_hp_regen()])

	die1_done = false
	die2_done = false

	if enemy_is_boss and dungeon != null:
		var dname := str(dungeon.dungeon_name)
		if not GameState.defeated_bosses.has(dname):
			GameState.defeated_bosses.append(dname)
		if not dungeon.boss_drops.is_empty():
			var drop: Resource = dungeon.boss_drops.pick_random()
			var res := GameState.acquire_item(drop)
			if res["equipped"]:
				_log("Boss düşürdü: [color=#c9b458]%s[/color] (otomatik kuşanıldı)" % drop.describe())
			else:
				_log("Boss düşürdü: [color=#c9b458]%s[/color] (çantaya eklendi)" % drop.describe())

	if GameState.shop_due():
		_open_shop()
	else:
		state = S.ROLLING
		_refresh()


# ---------------------------------------------------------------- Mağaza
func _open_shop() -> void:
	state = S.SHOP
	_log("[color=#c9b458]Mağaza açıldı.[/color]")
	shop_items = Db.shop_stock()
	shop_items.shuffle()
	shop_items = shop_items.slice(0, 5)
	_build_shop()
	_refresh()


func _build_shop() -> void:
	for c in shop_row.get_children():
		c.queue_free()
	shop_item_btns.clear()
	btn_shop_potion = _btn("🧪 Can İksiri (%dg)" % GameState.potion_price, _buy_potion, shop_row, Vector2(160, 64))
	for it in shop_items:
		var entry := {"btn": null, "item": it, "bought": false}
		var b := _btn("%s (%dg)" % [it.describe(), int(it.price)], _buy_item.bind(entry), shop_row, Vector2(240, 72))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.icon = it.sprite
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 32)
		b.tooltip_text = str(it.description) if str(it.description) != "" else it.describe()
		entry["btn"] = b
		shop_item_btns.append(entry)
	_btn("Çık", _leave_shop, shop_row, Vector2(100, 64))


func _refresh_shop() -> void:
	if is_instance_valid(btn_shop_potion):
		btn_shop_potion.text = "🧪 Can İksiri (%dg)" % GameState.potion_price
		btn_shop_potion.disabled = GameState.gold < GameState.potion_price
	for entry in shop_item_btns:
		var b: Button = entry["btn"]
		if not is_instance_valid(b):
			continue
		var it: Resource = entry["item"]
		var bought: bool = entry["bought"]
		if bought:
			b.text = "✓ Alındı: %s" % str(it.item_name)
			b.disabled = true
		else:
			b.disabled = GameState.gold < int(it.price)


func _buy_potion() -> void:
	if state != S.SHOP:
		return
	if GameState.spend(GameState.potion_price):
		GameState.potions += 1
		GameState.stats_changed.emit()
		_log("İksir aldın.")
	else:
		_log("Yeterli altının yok.")


func _buy_item(entry: Dictionary) -> void:
	if state != S.SHOP or entry["bought"]:
		return
	var it: Resource = entry["item"]
	if GameState.gold < int(it.price):
		_log("Yeterli altının yok.")
		return
	entry["bought"] = true
	if GameState.spend(int(it.price)):
		var res := GameState.acquire_item(it)
		if res["equipped"]:
			_log("Satın alıp kuşandın: %s" % it.describe())
		else:
			_log("Satın alıp çantaya ekledin: %s" % it.describe())
		_refresh_shop()


func _leave_shop() -> void:
	if state != S.SHOP:
		return
	inv_panel.visible = false
	state = S.ROLLING
	_refresh()


# ---------------------------------------------------------------- Yeni run
func _on_new_run() -> void:
	busy = false
	final_mode = false
	dungeon = null
	cur_enemy = null
	die1_done = false
	die2_done = false
	enemy_burn = 0
	enemy_poison = 0
	player_attacks = 0
	inv_panel.visible = false
	shop_items.clear()
	shop_item_btns.clear()
	GameState.reset()
	log_box.clear()
	_log("Yeni run başladı.")
	state = S.ROLLING
	_refresh()