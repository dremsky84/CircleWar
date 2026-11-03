extends SceneTree

# Logiktests: godot --headless --path . -s tools/tests.gd
const Game := preload("res://scripts/game.gd")
var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func _initialize() -> void:
	var g = Game.new()
	root.add_child(g)
	g.coins = 0
	g.upgrade_levels = {"power": 0, "speed": 0, "growth": 0}
	g.unlocked = ["standard"]
	check(not g._buy_upgrade("power"), "kein Kauf ohne Münzen")
	g.coins = 100
	check(g._buy_upgrade("power") and g.coins == 0 and g.upgrade_levels["power"] == 1, "Kauf Stufe 1")
	check(absf(g._upgrade_mult("power") - 1.05) < 0.001, "x1.05")
	check(not g._unlock_type("tank"), "Tank zu teuer")
	g.coins = 500
	check(g._unlock_type("tank") and "tank" in g.unlocked, "Tank frei")
	g.selected_type = "tank"
	g.upgrade_levels["power"] = 0
	g.map_size = Vector2(720, 1280)
	g.difficulty = 2
	g.circle_count = 12
	g.start_game()
	check(absf(g._power(1) - 1.3) < 0.001 and absf(g._speed(1) - 0.7) < 0.001, "Tank-Werte")
	check(g._power(2) == 1.0, "Gegner Standard")
	# Kampf: 10 Einheiten Kraft 1.3 gegen 12 Verteidiger Kraft 1 -> 13 > 12, Rest 1/1.3
	g.circles[2]["owner"] = 2; g.circles[2]["value"] = 12.0
	g._resolve({"owner": 1, "target": 2, "amount": 10.0})
	check(g.circles[2]["owner"] == 1 and absf(g.circles[2]["value"] - 1.0 / 1.3) < 0.01, "Angriff mit Kraft")
	# Verteidigung: Spieler-Kreis 10 (Kraft 1.3) gegen 12 Gegner -> 13 vs 12 -> hält
	g.circles[3]["owner"] = 1; g.circles[3]["value"] = 10.0
	g._resolve({"owner": 2, "target": 3, "amount": 12.0})
	check(g.circles[3]["owner"] == 1 and absf(g.circles[3]["value"] - 1.0 / 1.3) < 0.01, "Verteidigung mit Kraft")
	# Gegner levelt mit
	g.enemy_levels_up = true
	g.upgrade_levels["power"] = 10
	g.start_game()
	check(absf(g._power(2) - 1.5) < 0.001, "Gegner levelt mit")
	# Belohnung
	g.enemy_levels_up = false
	g.difficulty = 4; g.circle_count = 12
	check(g._reward_for(true) == 160 and g._reward_for(false) == 40, "Belohnung")
	g.enemy_levels_up = true
	check(g._reward_for(true) == 240, "Belohnung x1.5")
	g.coins = 0
	g.start_game()
	g.winner = 1; g.game_over = true
	g._process(0.01)
	check(g.coins == 240 and g.reward == 240, "Auszahlung")
	g._process(0.01)
	check(g.coins == 240, "nur einmal")
	# Speichern/Laden
	g._save_settings()
	var h = Game.new()
	h._load_settings()
	check(h.coins == 240 and "tank" in h.unlocked and h.upgrade_levels["power"] == 10 and h.selected_type == "tank", "Laden")
	# Buttons je Zustand
	for st in [Game.State.MAIN, Game.State.SETUP, Game.State.WORKSHOP]:
		h.state = st
		check(h._buttons().size() > 0, "Buttons %d" % st)
	h.free()
	print("Tests fertig, Fehler: ", fails)
	quit(1 if fails > 0 else 0)
