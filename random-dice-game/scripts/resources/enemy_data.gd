extends Resource

var id: String = ""
var enemy_name: String = ""
var base_hp: int = 10
var base_damage_mult: float = 1.0
var defense_mult: float = 1.0
var xp: int = 0
var is_boss: bool = false
var abilities: Array = []   # heal, regen, double_hit, pierce, enrage
var sprite: Texture2D