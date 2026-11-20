extends Resource

var id: String = ""
var dungeon_name: String = ""
var crowd_enemy: Resource   # zorluk 1-2
var elite_enemy: Resource   # zorluk 3-4
var boss: Resource          # zorluk 5-6
var boss_drops: Array = []
var background: Texture2D

func get_enemy(difficulty: int) -> Resource:
	if difficulty <= 2: return crowd_enemy
	if difficulty <= 4: return elite_enemy
	return boss
