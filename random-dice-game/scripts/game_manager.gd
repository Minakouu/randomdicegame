extends Control
# Ana oyun akışı. UI kodla kurulur. State: ROLLING -> DECISION -> COMBAT -> (SHOP) ; DEAD

const Db = preload("res://scripts/data_db.gd")

enum S { ROLLING, DECISION, COMBAT, SHOP, DEAD }

var state: int = S.ROLLING
var dungeons: Array
var dungeon: Resource
var die1_done := false
var die2_done := false
var difficulty := 0
var final_mode := false

var enemy_name := ""
var enemy_hp := 0
var enemy_max_hp := 0
var enemy_mult := 1.0
var enemy_def := 0
var enemy_is_boss := false
var enemy_abilities: Array = []
var enemy_turns := 0
var busy := false
var shop_items: Array = []

const ABILITY_TEXT := {
	"heal": "iyileşir", "regen": "yenilenir", "double_hit": "çift vuruş",
	"pierce": "zırh deler", "enrage": "öfkelenir",
}

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
var btn_final: Button
var btn_new: Button
var btn_leave: Button


func _ready() -> void:
	dungeons = Db.dungeons()
	_build_ui()
	GameState.stats_changed.connect(_refresh)
	_log("[b]Random Ass Dice Game[/b] — iki zara da tıkla.")
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
	root.add_theme_constant_override("separation", 10)
	margin.add_child(root)

	lbl_stats = Label.new()
	lbl_stats.add_theme_font_size_override("font_size", 22)
	root.add_child(lbl_stats)

	lbl_equip = Label.new()
	lbl_equip.add_theme_color_override("font_color", Color("#9aa5b8"))
	root.add_child(lbl_equip)

	lbl_bosses = Label.new()
	lbl_bosses.add_theme_color_override("font_color", Color("#c9b458"))
	root.add_child(lbl_bosses)

	lbl_info = Label.new()
	lbl_info.add_theme_font_size_override("font_size", 26)
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
	btn_die1 = _btn("🎲 Zar 1\nDungeon", _on_die1, dice_row, Vector2(220, 90))
	btn_die2 = _btn("🎲 Zar 2\nZorluk", _on_die2, dice_row, Vector2(220, 90))

	action_row = HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 12)
	root.add_child(action_row)
	btn_enter = _btn("Enter", _on_enter, action_row)
	btn_flee = _btn("Flee (-5 stamina)", _on_flee, action_row)
	btn_attack = _btn("Attack", _on_attack, action_row)
	btn_potion = _btn("Can İksiri", _on_potion, action_row)
	btn_pass = _btn("Pass", _on_pass, action_row)
	btn_final = _btn("☠ Boss Yolu", _on_final, action_row)
	btn_new = _btn("Yeni Run", _on_new_run, action_row)

	shop_row = HFlowContainer.new()
	shop_row.alignment = FlowContainer.ALIGNMENT_CENTER
	shop_row.add_theme_constant_override("separation", 10)
	root.add_child(shop_row)


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


func _btn(text: String, cb: Callable, parent: Node, min_size := Vector2(150, 50)) -> Button:
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
	lbl_stats.text = "❤ %d/%d    ⚡ %d/%d    💰 %d    🧪 %d    Tamamlanan: %d" % [
		gs.hp, gs.get_max_hp(), gs.stamina, gs.get_max_stamina(), gs.gold, gs.potions, gs.dungeons_cleared]
	lbl_equip.text = "Silah: %s   |   Zırh: %s   |   Rün: %s   |   Aksesuar: %s" % [
		gs.weapon.describe(), gs.armor.describe(),
		gs.rune.describe() if gs.rune else "—", gs.accessory.describe() if gs.accessory else "—"]

	var parts: Array[String] = []
	for d in dungeons:
		parts.append("%s %s" % [d.dungeon_name, "✓" if gs.defeated_bosses.has(d.dungeon_name) else "✗"])
	lbl_bosses.text = "Boss'lar:  " + "   ".join(parts)

	match state:
		S.ROLLING, S.DECISION:
			var t1 := "🎲 Dungeon: %s" % dungeon.dungeon_name if die1_done else "🎲 Zar 1\nDungeon"
			var t2 := "🎲 Zorluk: %d" % difficulty if die2_done else "🎲 Zar 2\nZorluk"
			btn_die1.text = t1
			btn_die2.text = t2
			btn_die1.disabled = die1_done
			btn_die2.disabled = die2_done
			if die1_done and die2_done:
				var e := _preview_enemy()
				lbl_info.text = "%s — zorluk %d: %s (%d can)%s" % [dungeon.dungeon_name, difficulty, e.enemy_name, _scaled_hp(e), _ability_text(e.abilities)]
			else:
				lbl_info.text = "Zarları at."
		S.COMBAT:
			lbl_info.text = "⚔ %s   ❤ %d/%d%s" % [enemy_name, enemy_hp, enemy_max_hp, _ability_text(enemy_abilities)]
		S.SHOP:
			lbl_info.text = "🛒 Mağaza"
		S.DEAD:
			pass

	var shown: Resource = null
	if state == S.COMBAT:
		shown = cur_enemy
	elif state == S.DECISION:
		shown = _preview_enemy()
	enemy_tex.texture = shown.sprite if shown else null
	enemy_name_lbl.text = shown.enemy_name if shown else ""
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
	btn_potion.disabled = gs.potions <= 0 or busy
	btn_pass.visible = state == S.COMBAT
	btn_final.visible = state == S.ROLLING and not die1_done and not die2_done and gs.defeated_bosses.size() >= dungeons.size()
	btn_new.visible = state == S.DEAD
	shop_row.visible = state == S.SHOP


# ---------------------------------------------------------------- Zarlar
func _on_die1() -> void:
	if busy or die1_done:
		return
	busy = true
	var result := GameState.roll(dungeons.size()) - 1
	for i in 10:
		btn_die1.text = "🎲 " + dungeons[randi() % dungeons.size()].dungeon_name
		await get_tree().create_timer(0.04 + i * 0.012).timeout
	dungeon = dungeons[result]
	die1_done = true
	busy = false
	_log("Zar 1 → [b]%s[/b]" % dungeon.dungeon_name)
	_after_dice()


func _on_die2() -> void:
	if busy or die2_done:
		return
	busy = true
	var result := GameState.roll(6)
	for i in 10:
		btn_die2.text = "🎲 %d" % GameState.roll(6)
		await get_tree().create_timer(0.04 + i * 0.012).timeout
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
	return dungeon.get_enemy(difficulty)


# Kademe içi ölçek: zorluk 1,3,5 taban; 2,4,6 biraz daha güçlü.
func _step() -> int:
	return (difficulty - 1) % 2


func _scaled_hp(e: Resource) -> int:
	var depth := 1.0 + GameState.depth_hp * GameState.dungeons_cleared
	return int(round(e.base_hp * (1.0 + 0.2 * _step()) * depth))


func _scaled_mult() -> float:
	return (1.0 + 0.1 * _step()) * (1.0 + GameState.depth_dmg * GameState.dungeons_cleared)


func _ability_text(abilities: Array) -> String:
	if abilities.is_empty():
		return ""
	var names: Array[String] = []
	for a in abilities:
		names.append(ABILITY_TEXT.get(a, str(a)))
	return "   [" + ", ".join(names) + "]"


func _on_flee() -> void:
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
	final_mode = false
	_start_combat(_preview_enemy(), _scaled_hp(_preview_enemy()), _scaled_mult())


func _on_final() -> void:
	final_mode = true
	difficulty = 6
	var e := Db.final_boss()
	_log("[color=#c9b458]Boss Yolu açıldı![/color]")
	_start_combat(e, e.base_hp, 1.0)


func _start_combat(e: Resource, hp: int, mult_scale: float) -> void:
	cur_enemy = e
	enemy_name = e.enemy_name
	enemy_hp = hp
	enemy_max_hp = hp
	enemy_mult = e.base_damage_mult * mult_scale
	enemy_def = e.defense_bonus
	enemy_is_boss = e.is_boss
	enemy_abilities = e.abilities
	enemy_turns = 0
	busy = false
	state = S.COMBAT
	_log("[b]%s[/b] ile savaş başladı. Sen ilk başlarsın." % enemy_name)
	_refresh()


func _on_attack() -> void:
	if busy or state != S.COMBAT:
		return
	var w := GameState.weapon
	var crit_n := int(GameState.effect("crit"))
	var total := 0.0
	var crit := false
	var rolls: Array[String] = []
	for i in w.dice_count:
		var r := GameState.roll(20)
		var v: float = (r + w.bonus) * w.multiplier
		if crit_n > 0 and r > 20 - crit_n:
			v *= 2.0
			crit = true
			rolls.append(str(r) + "!")
		else:
			rolls.append(str(r))
		total += v
	var dmg := int(round(total))
	var def := GameState.roll(10) + enemy_def
	var net := dmg - def
	if net <= 0:
		_log("Saldırı [%s] → %d, düşman savunması %d: [color=#8aa]savuşturdu[/color]." % [", ".join(rolls), dmg, def])
		_float(enemy_tex, "MISS", Color("#8899aa"))
	else:
		enemy_hp = max(0, enemy_hp - net)
		_log("Saldırı [%s] → %d − savunma %d = [color=#7fd17f]%d hasar[/color]%s." % [", ".join(rolls), dmg, def, net, " [b]KRİTİK![/b]" if crit else ""])
		_float(enemy_tex, str(net) + ("!" if crit else ""), Color("#ffd24a") if crit else Color("#ffffff"))
		_flash(enemy_tex)
		var ls := GameState.effect("lifesteal")
		if ls > 0.0:
			var got: int = max(1, int(round(net * ls)))
			GameState.heal(got)
			_log("  Can çaldın: +%d" % got)
			_float(player_tex, "+%d" % got, Color("#7fd17f"))
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
	if enemy_hp <= 0:
		_win()
		return
	busy = true
	_refresh()
	await get_tree().create_timer(0.5).timeout
	busy = false
	if state != S.COMBAT:
		return
	_enemy_turn()


func _enemy_turn() -> void:
	enemy_turns += 1
	if enemy_abilities.has("regen") and enemy_hp < enemy_max_hp:
		enemy_hp = min(enemy_max_hp, enemy_hp + 2)
		_log("%s yenileniyor (+2)." % enemy_name)
	if enemy_abilities.has("heal") and enemy_turns % 3 == 0:
		var h := int(round(enemy_max_hp * 0.2))
		enemy_hp = min(enemy_max_hp, enemy_hp + h)
		_log("[color=#c9b458]%s kendini iyileştirdi (+%d).[/color]" % [enemy_name, h])
		_float(enemy_tex, "+%d" % h, Color("#7fd17f"))
	var mult := enemy_mult
	if enemy_abilities.has("enrage") and enemy_hp * 2 < enemy_max_hp:
		mult *= 1.3
	var hits := 2 if (enemy_abilities.has("double_hit") and enemy_turns % 3 == 0) else 1
	if hits == 2:
		_log("[color=#c9b458]%s çift vuruş yapıyor![/color]" % enemy_name)
	for i in hits:
		_enemy_strike(mult)
		if GameState.hp <= 0:
			_die()
			return
	_refresh()


func _enemy_strike(mult: float) -> void:
	var r := GameState.roll(20)
	var dmg := int(round(r * mult))
	var a := GameState.armor
	var dbonus := int(GameState.effect("defense_bonus"))
	var def := int(round((GameState.roll(10) + a.bonus + dbonus) * a.multiplier))
	if enemy_abilities.has("pierce"):
		def = int(def / 2)
	var net := dmg - def
	if net <= 0:
		_log("%s saldırdı (%d), savunman %d: [color=#8aa]dodge![/color]" % [enemy_name, dmg, def])
		_float(player_tex, "DODGE", Color("#8899aa"))
	else:
		GameState.damage(net)
		_log("%s saldırdı (%d) − savunma %d = [color=#e06666]%d hasar[/color]." % [enemy_name, dmg, def, net])
		_float(player_tex, "-%d" % net, Color("#ff6666"))
		_flash(player_tex)


# ---------------------------------------------------------------- Efektler
func _float(target: Control, text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 34)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 8)
	add_child(l)
	l.global_position = target.global_position + Vector2(target.size.x * 0.4, target.size.y * 0.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y - 70.0, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _flash(target: Control) -> void:
	target.pivot_offset = target.size / 2.0
	var tw := create_tween()
	tw.tween_property(target, "modulate", Color(1, 0.35, 0.35), 0.07)
	tw.parallel().tween_property(target, "scale", Vector2(1.12, 1.12), 0.07)
	tw.tween_property(target, "modulate", Color.WHITE, 0.15)
	tw.parallel().tween_property(target, "scale", Vector2.ONE, 0.15)


func _die() -> void:
	state = S.DEAD
	busy = false
	lbl_info.text = "☠ Öldün"
	_log("[color=#e06666][b]Öldün.[/b] %d dungeon tamamladın. Her şey sıfırlanacak.[/color]" % GameState.dungeons_cleared)
	_refresh()
	lbl_info.text = "☠ Öldün"


func _win() -> void:
	_log("[color=#7fd17f][b]%s yenildi![/b][/color]" % enemy_name)
	if final_mode:
		var drop := Db.final_drop()
		GameState.equip(drop)
		state = S.DEAD
		_log("[color=#c9b458][b]OYUNU BİTİRDİN![/b] Ödül: %s[/color]" % drop.describe())
		_refresh()
		lbl_info.text = "🏆 Kazandın!"
		return

	var base_gold := difficulty * 4 + randi_range(0, 5) + (20 if enemy_is_boss else 0)
	var gold := GameState.finish_dungeon(difficulty, base_gold)
	_log("+%d altın, +%d stamina, +%d can." % [gold, GameState.stamina_rest_base - difficulty, GameState.get_hp_regen()])

	if enemy_is_boss:
		if not GameState.defeated_bosses.has(dungeon.dungeon_name):
			GameState.defeated_bosses.append(dungeon.dungeon_name)
		var drop: Resource = dungeon.boss_drops.pick_random()
		if GameState.equip_if_better(drop):
			_log("Boss düşürdü: [color=#c9b458]%s[/color] (takıldı)" % drop.describe())
		else:
			_log("Boss düşürdü: %s (mevcut ekipman daha iyi / slot dolu, bırakıldı)" % drop.describe())

	die1_done = false
	die2_done = false
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
	shop_items = shop_items.slice(0, 4)
	_build_shop()
	_refresh()


func _build_shop() -> void:
	for c in shop_row.get_children():
		c.queue_free()
	_btn("Can İksiri (%dg)" % GameState.potion_price, _buy_potion, shop_row, Vector2(150, 60))
	for it in shop_items:
		var b := _btn("%s (%dg)" % [it.describe(), it.price], _buy_item.bind(it), shop_row, Vector2(260, 70))
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.icon = it.sprite
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 32)
	_btn("Çık", _leave_shop, shop_row, Vector2(100, 60))


func _buy_potion() -> void:
	if GameState.spend(GameState.potion_price):
		GameState.potions += 1
		GameState.stats_changed.emit()
		_log("İksir aldın.")
	else:
		_log("Yeterli altının yok.")


func _buy_item(it: Resource) -> void:
	if GameState.spend(it.price):
		GameState.equip(it)
		_log("Satın alıp kuşandın: %s" % it.describe())
	else:
		_log("Yeterli altının yok.")


func _leave_shop() -> void:
	state = S.ROLLING
	_refresh()


# ---------------------------------------------------------------- Yeni run
func _on_new_run() -> void:
	GameState.reset()
	log_box.clear()
	_log("Yeni run başladı.")
	die1_done = false
	die2_done = false
	state = S.ROLLING
	_refresh()
