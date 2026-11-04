extends SceneTree

# Netzwerktest auf einem Rechner (zwei Prozesse):
#   godot --headless --path . -s tools/net_test.gd -- host &
#   godot --headless --path . -s tools/net_test.gd -- client
const Game := preload("res://scripts/game.gd")
var fails := 0

func check(c: bool, msg: String) -> void:
	if not c:
		fails += 1
		print("FAIL: ", msg)

func wait(sec: float) -> void:
	await create_timer(sec).timeout

func _initialize() -> void:
	var role := "host"
	for a in OS.get_cmdline_user_args():
		role = a
	var g = Game.new()
	g.name = "Main"
	root.add_child(g)
	await process_frame
	g.map_size = Vector2(720, 1280)
	if role == "host":
		g.circle_count = 8
		g._mp_host()
		for i in 100:
			await wait(0.1)
			if g.state == Game.State.PLAYING:
				break
		check(g.state == Game.State.PLAYING and g.mp_status == "playing", "Host: Spiel gestartet")
		await wait(3.0)
		# Befehl des Clients muss angekommen sein: Armee des Gegners unterwegs oder Kreis erobert
		var enemy_sent := false
		for a in g.armies:
			if a["owner"] == 2:
				enemy_sent = true
		check(enemy_sent or g.circles[1]["value"] < 15.0, "Host: Befehl vom Client wirkt")
		await wait(2.0)
		g._force_end(1)
		await wait(1.0)
	else:
		g._mp_join("127.0.0.1")
		for i in 100:
			await wait(0.1)
			if g.state == Game.State.PLAYING:
				break
		check(g.state == Game.State.PLAYING, "Client: Spiel gestartet")
		await wait(0.5)
		check(g.circles.size() == 8, "Client: 8 Kreise")
		# Gespiegelt: eigener Kreis (Besitzer 1) unten, Gegner oben
		var mine := -1
		var theirs := -1
		for i in g.circles.size():
			if g.circles[i]["owner"] == 1: mine = i
			if g.circles[i]["owner"] == 2: theirs = i
		check(mine >= 0 and theirs >= 0, "Client: beide Seiten da")
		check(g.circles[mine]["pos"].y > g.circles[theirs]["pos"].y, "Client: eigener Kreis unten")
		# Angriff auf einen neutralen Kreis senden
		var target := -1
		for i in g.circles.size():
			if g.circles[i]["owner"] == 0: target = i
		g._player_send(mine, target, 50)
		await wait(1.0)
		check(g.armies.size() > 0 or g.circles[mine]["value"] < 14.0, "Client: Armee sichtbar")
		await wait(3.5)
		check(g.game_over and g.winner == 2, "Client: Spielende (Host-Sieg = Client verliert)")
	print(role, " fertig, Fehler: ", fails)
	quit(1 if fails > 0 else 0)
