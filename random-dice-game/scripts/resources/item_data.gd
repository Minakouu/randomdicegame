extends Resource

enum Type { WEAPON, ARMOR, RUNE, ACCESSORY }

var id: String = ""
var item_name: String = ""
var type: int = Type.WEAPON
var bonus: int = 0              # her hasar/savunma zarına ayrı eklenir
var multiplier: float = 1.0
var dice_count: int = 1         # Double Dagger = 2
var price: int = 0
var in_shop: bool = false
var description: String = ""
var effects: Dictionary = {}    # lifesteal, crit, max_hp, max_stamina, flee_cost, gold_mult, defense_bonus, hp_regen, thorns, burn, poison, stamina_regen, first_strike
var sprite: Texture2D

const EFFECT_NAMES := {
	"lifesteal": "can çalma",
	"crit": "kritik",
	"max_hp": "maks can",
	"max_stamina": "maks stamina",
	"flee_cost": "kaçış bedeli",
	"gold_mult": "altın",
	"defense_bonus": "savunma",
	"hp_regen": "dinlenme canı",
	"thorns": "diken",
	"burn": "yanma",
	"poison": "zehir",
	"stamina_regen": "stamina yenileme",
	"first_strike": "ilk vuruş",
}

const TYPE_NAMES := {
	Type.WEAPON: "Silah",
	Type.ARMOR: "Zırh",
	Type.RUNE: "Rün",
	Type.ACCESSORY: "Aksesuar",
}


func type_label() -> String:
	return str(TYPE_NAMES.get(type, "Eşya"))


func effect_text() -> String:
	var parts: Array[String] = []
	for k in effects:
		var v = effects[k]
		match k:
			"lifesteal": parts.append("%s %%%d" % [EFFECT_NAMES[k], int(round(float(v) * 100))])
			"gold_mult": parts.append("%s +%%%d" % [EFFECT_NAMES[k], int(round(float(v) * 100))])
			"crit": parts.append("%s D20 %d+" % [EFFECT_NAMES[k], 21 - int(v)])
			_: parts.append("%s %+d" % [EFFECT_NAMES.get(k, k), int(v)])
	return ", ".join(parts)


func describe() -> String:
	var s := item_name
	if type == Type.WEAPON or type == Type.ARMOR:
		s += " (+%d ×%s" % [bonus, str(multiplier)]
		if dice_count > 1:
			s += ", %d zar" % dice_count
		s += ")"
	if not effects.is_empty():
		s += " [%s]" % effect_text()
	return s