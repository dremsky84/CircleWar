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
	# Pause / Menü / Fortfahren
	g.start_game()
	check(g.has_game() and not g.paused, "Spiel läuft")
	g._activate("pause")
	check(g.paused, "pausiert")
	var v: float = g.circles[0]["value"]
	g._process(1.0)
	check(g.circles[0]["value"] == v, "Pause friert ein")
	g._activate("menu")
	check(g.state == Game.State.MAIN and g.has_game(), "Menü, Spiel bleibt")
	var ids := []
	for b in g._buttons():
		ids.append(b["id"])
	check("resume" in ids, "Fortfahren im Menü")
	g._activate("resume")
	check(g.state == Game.State.PLAYING and not g.paused, "zurück im Spiel")
	g._process(1.0)
	check(g.circles[0]["value"] > v, "läuft weiter")
	g.dev_mode = true
	g._activate("pause")
	ids.clear()
	for b in g._buttons():
		ids.append(b["id"])
	check("dev" in ids and "resume" in ids, "Developer im Pause-Menü")
	g.winner = 1; g.game_over = true
	check(not g.has_game(), "nach Ende kein Fortfahren")
	# Geheimcode
	var d = Game.new()
	root.add_child(d)
	d.dev_mode = false
	d.state = Game.State.MAIN
	d.map_size = Vector2(720, 1280)
	var tp: Vector2 = d._title_rect().get_center()
	for i in 4:
		d._on_press(tp)
	check(not d.dev_mode, "4 Tipper reichen nicht")
	d._on_press(tp)
	check(d.dev_mode, "5 Tipper aktivieren")
	for i in 5:
		d._on_press(tp)
	check(not d.dev_mode, "5 Tipper deaktivieren")
	d._on_press(tp); d._on_press(tp); d._on_press(Vector2(10, 700)); d._on_press(tp); d._on_press(tp); d._on_press(tp)
	check(not d.dev_mode, "Unterbrechung setzt zurück")
	d.free()
	# Planeten-Upgrades
	var u = Game.new()
	root.add_child(u)
	u.map_size = Vector2(720, 1280)
	u.rng.seed = 3
	u.difficulty = 2; u.circle_count = 8
	u.start_game()
	u.ai_timer = 1e9
	var c0: Dictionary = u.circles[0]
	c0["value"] = 30.0
	check(u._shop_buy(1, 0, "shield") and c0["value"] == 24.0 and c0["shield"] == 1, "Schild gekauft (6)")
	check(not u._shop_buy(2, 0, "gun"), "fremder Planet nicht kaufbar")
	c0["value"] = 7.0
	check(not u._shop_buy(1, 0, "shield"), "zu wenig Armee (Stufe 2 kostet 10)")
	check(not u._shop_buy(1, 0, "gun") , "Geschütz 8 > 7-1")
	c0["value"] = 20.0; c0["shield"] = 3
	check(not u._shop_buy(1, 0, "shield"), "Stufe 3 ist Maximum")
	# Schutzschild: 10 Verteidiger x1.6 = 16 gegen 15 Angreifer -> hält
	c0["value"] = 10.0
	u._resolve({"owner": 2, "target": 0, "amount": 15.0})
	check(u.circles[0]["owner"] == 1 and absf(u.circles[0]["value"] - 1.0 / 1.6) < 0.01, "Schild verteidigt")
	# Eroberung löscht Upgrades
	c0["value"] = 3.0
	u._resolve({"owner": 2, "target": 0, "amount": 20.0})
	check(u.circles[0]["owner"] == 2 and c0["shield"] == 0, "Upgrades weg nach Eroberung")
	# Beschleunigung: Armee bekommt Faktor
	var c1: Dictionary = u.circles[1]
	c1["owner"] = 2; c1["value"] = 20.0; c1["boost"] = 2
	u._send_amount(2, 1, 3, 5.0)
	check(absf(u.armies[u.armies.size() - 1]["boost"] - 1.5) < 0.001, "Boost-Faktor")
	# Geschütz schießt auf feindliche Armee in Reichweite
	u.armies.clear()
	var pos3: Vector2 = u.circles[3]["pos"]
	u.circles[3]["owner"] = 1; u.circles[3]["gun"] = 2; u.circles[3]["gun_t"] = 0.0
	u.armies.append({"from": pos3 + Vector2(60, 0), "to": pos3 + Vector2(600, 0), "owner": 2, "amount": 10.0,
		"target": 0, "src": 1, "progress": 0.0, "boost": 1.0})
	u._guns(0.1)
	check(absf(u.armies[0]["amount"] - 7.0) < 0.001, "Geschütz Stufe 2: 3 Schaden")
	u._guns(0.1)
	check(absf(u.armies[0]["amount"] - 7.0) < 0.001, "Feuerpause")
	u.armies[0]["amount"] = 2.0; u.circles[3]["gun_t"] = 0.0
	u._guns(0.1)
	check(u.armies.is_empty(), "Armee zerstört")
	# Pause: Antippen eines eigenen Planeten, Spiel steht, Weiter setzt fort
	var v2: float = u.circles[2]["value"]
	u.circles[2]["owner"] = 1
	u._shop_open(2)
	check(u.shop_pause and u.shop_planet == 2, "Upgrade-Pause an")
	u._process(1.0)
	check(u.circles[2]["value"] == v2, "Spiel steht in der Upgrade-Pause")
	u._shop_vote_self()
	check(not u.shop_pause, "Solo: Weiter setzt fort")
	# KI kauft (Schwer)
	u.level = Game.LEVELS[4]
	u.circles[1]["value"] = 40.0; u.circles[1]["owner"] = 2
	for k in 40:
		u._ai_buy([1])
	check(u.circles[1]["shield"] + u.circles[1]["gun"] + u.circles[1]["boost"] > 0, "KI kauft")
	check(u.circles[1]["value"] >= Game.AI_KEEP - 0.01, "KI behält Reserve")
	u.free()
	# Sammelangriff: über eigene Planeten wischen, Armeen reisen gemeinsam zum letzten Ziel
	var q = Game.new()
	root.add_child(q)
	q.map_size = Vector2(720, 1280)
	q.circles.clear()
	var spots := [Vector2(100, 1000), Vector2(300, 1000), Vector2(500, 1000), Vector2(300, 300)]
	var owners := [1, 1, 1, 2]
	for k in 4:
		q.circles.append(q._make_circle(spots[k], 20.0, owners[k]))
	q.state = Game.State.PLAYING
	q.level = Game.LEVELS[0]
	q._compute_stats()
	q.ai_timer = 1e9
	q._on_press(spots[0])
	q._chain_track(spots[0], spots[1])
	q._chain_track(spots[1], spots[2])
	check(q.chain == [0, 1, 2], "Kette A-B-C")
	q._chain_track(spots[2], spots[0])
	check(q.chain.size() == 3, "keine Doppelten")
	q._chain_track(spots[2], spots[3])
	q._on_release(spots[3])
	check(q.armies.size() == 3, "3 Armeen zum Gegner")
	var okay := true
	for a in q.armies:
		if a["target"] != 3 or absf(a["amount"] - 10.0) > 0.01:
			okay = false
	check(okay, "je 50 %% zum letzten Ziel")
	check(q.chain.is_empty(), "Kette geleert")
	# Ende auf eigenem Planeten: A und B sammeln auf C
	q.armies.clear()
	for k in 3:
		q.circles[k]["value"] = 20.0
	q._on_press(spots[0])
	q._chain_track(spots[0], spots[1])
	q._chain_track(spots[1], spots[2])
	q._on_release(spots[2])
	check(q.armies.size() == 2, "A und B sammeln auf C")
	var to_c := true
	for a in q.armies:
		if a["target"] != 2:
			to_c = false
	check(to_c, "Ziel ist C")
	# einfaches Wischen und Antippen wie bisher
	q.armies.clear()
	q._on_press(spots[0])
	q._chain_track(spots[0], spots[3])
	q._on_release(spots[3])
	check(q.armies.size() == 1, "einfaches Wischen")
	q._on_press(spots[1])
	q._on_release(spots[1])
	check(q.shop_pause and q.shop_planet == 1, "Antippen öffnet Upgrades")
	q.free()
	h.free()
	print("Tests fertig, Fehler: ", fails)
	quit(1 if fails > 0 else 0)
