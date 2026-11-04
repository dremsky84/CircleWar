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
		await wait(2.0)
		# Befehl des Clients muss angekommen sein
		var sent := false
		for a in g.armies:
			if a["owner"] == 2:
				sent = true
		check(sent or g.circles[1]["value"] < 15.0, "Host: Befehl vom Client wirkt")
		# Upgrade-Pause: Client öffnet Planet und kauft ein Schutzschild
		for i in 100:
			await wait(0.1)
			if g.shop_pause:
				break
		check(g.shop_pause, "Host: Pause durch Client")
		var frozen: float = g.circles[0]["value"]
		for i in 100:
			await wait(0.1)
			if g.circles[1]["shield"] == 1:
				break
		check(g.circles[1]["shield"] == 1, "Host: Kauf des Clients angekommen")
		check(absf(g.circles[0]["value"] - frozen) < 0.01, "Host: Spiel steht in der Pause")
		g._shop_open(0)
		g._shop_vote_self()
		await wait(0.6)
		check(g.shop_pause, "Host: wartet auf Client-Weiter")
		for i in 100:
			await wait(0.1)
			if not g.shop_pause:
				break
		check(not g.shop_pause, "Host: Spiel läuft nach beiden Weiter weiter")
		await wait(1.0)
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
		# Upgrade-Pause: Client öffnet den eigenen Planeten und kauft ein Schutzschild
		for i in 100:
			if g.circles[mine]["value"] >= 8.0:
				break
			await wait(0.1)
		g._shop_open(mine)
		await wait(0.5)
		check(g.shop_pause, "Client: Pause aktiv")
		g._shop_buy_request("shield")
		for i in 50:
			await wait(0.1)
			if g.circles[mine]["shield"] == 1:
				break
		check(g.circles[mine]["shield"] == 1, "Client: Schild sichtbar")
		await wait(2.0)
		check(g.shop_pause, "Client: Pause hält, bis beide Weiter drücken")
		g._shop_vote_self()
		for i in 60:
			await wait(0.1)
			if not g.shop_pause:
				break
		check(not g.shop_pause, "Client: Spiel läuft weiter")
		for i in 50:
			if g.game_over:
				break
			await wait(0.1)
		check(g.game_over and g.winner == 2, "Client: Spielende (Host-Sieg = Client verliert)")
	print(role, " fertig, Fehler: ", fails)
	quit(1 if fails > 0 else 0)
