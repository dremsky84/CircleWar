extends SceneTree

# Entwickler-Werkzeug: lässt einen Bot-Spieler gegen jede Schwierigkeitsstufe spielen
# und zählt die Siege. Aufruf (ohne Anzeige):
#   godot --headless --path . -s tools/sim.gd -- games=40 circles=12 bot=2.5,1.3
# optional: type=tank|star  upg=<Stufe 0-10>  enemy=1
# bot=<Reaktionszeit in s>,<Sicherheitsfaktor>   (größer = langsamer/vorsichtiger)

const Game := preload("res://scripts/game.gd")
const DT := 0.1
const MAX_TIME := 600.0


func _initialize() -> void:
	var games := 40
	var circles := 12
	var interval := 2.5
	var margin := 1.3
	var type_id := "standard"
	var upg := 0
	var enemy := false
	for arg in OS.get_cmdline_user_args():
		var kv := arg.split("=")
		if kv.size() != 2:
			continue
		match kv[0]:
			"games": games = int(kv[1])
			"circles": circles = int(kv[1])
			"type": type_id = kv[1]
			"upg": upg = int(kv[1])
			"enemy": enemy = kv[1] == "1"
			"botbuy": buy_chance = float(kv[1])
			"bot":
				var parts := kv[1].split(",")
				interval = float(parts[0])
				margin = float(parts[1])

	print("Bot: Reaktion %.1fs, Faktor %.2f, Kreise %d, Spiele je Stufe %d" % [interval, margin, circles, games])
	for lvl in Game.LEVELS.size():
		var wins := 0
		var losses := 0
		var timeouts := 0
		var total_time := 0.0
		for n in games:
			var res := _play(lvl, circles, 1000 + n, interval, margin, type_id, upg, enemy)
			total_time += res[1]
			match res[0]:
				1: wins += 1
				2: losses += 1
				_: timeouts += 1
		print("%-11s Siege %3d%%  (S %d / N %d / Zeit %d)  Dauer ~%ds" % [
			Game.LEVELS[lvl]["label"], int(100.0 * wins / games), wins, losses, timeouts,
			int(total_time / games)])
	quit()


# Rückgabe: [Ergebnis (1 Sieg, 2 Niederlage, 0 Zeitüberschreitung), Spielzeit]
func _play(lvl: int, count: int, seed_value: int, interval: float, margin: float,
		type_id: String = "standard", upg: int = 0, enemy: bool = false) -> Array:
	var g = Game.new()
	root.add_child(g)
	g.rng.seed = seed_value
	g.difficulty = lvl
	g.circle_count = count
	g.selected_type = type_id
	g.enemy_levels_up = enemy
	for id in g.UPGRADE_IDS:
		g.upgrade_levels[id] = upg
	g.start_game()

	var t := 0.0
	var bot_timer := interval
	while not g.game_over and t < MAX_TIME:
		g._tick(DT)
		t += DT
		bot_timer -= DT
		if bot_timer <= 0.0:
			var swipes: int = _bot_think(g, margin)
			bot_timer = interval * maxi(1, swipes)

	var result := 0
	if g.game_over:
		result = g.winner
	root.remove_child(g)
	g.free()
	return [result, t]


# Menschenähnlicher Spieler: jedes Wischen sendet 50 % der Armee des Quellkreises.
# Reicht ein Wischen nicht, wischt er bis zu dreimal hintereinander auf dasselbe Ziel
# (die Teilarmeen werden bei der Ankunft nacheinander abgezogen).
# Rückgabe: Anzahl der Wischer (für die Zeit, die das kostet).
func _bot_think(g, margin: float) -> int:
	var best_score := -1.0
	var best_src := -1
	var best_dst := -1
	var best_swipes := 1
	for dst in g.circles.size():
		if g.circles[dst]["owner"] == 1:
			continue
		for src in g.circles.size():
			if g.circles[src]["owner"] != 1:
				continue
			var dist: float = g.circles[src]["pos"].distance_to(g.circles[dst]["pos"])
			var need: float = g._needed(1, src, dst, false)
			need = need * margin + 1.0
			var remaining: float = g.circles[src]["value"]
			var total := 0.0
			for k in range(1, 4):
				var part: float = clampf(floorf(remaining * g.SEND_FRACTION), 1.0, maxf(floorf(remaining), 1.0))
				total += part
				remaining -= part
				if total >= need:
					# mehrere Wischer kosten Zeit: schlechter bewerten
					var score := 1.0 / (need + dist / 80.0) / k
					if score > best_score:
						best_score = score
						best_src = src
						best_dst = dst
						best_swipes = k
					break
	if best_src < 0:
		_bot_buy(g)
		return 0
	for i in best_swipes:
		g._try_send(1, best_src, best_dst, g.SEND_FRACTION)
	return best_swipes


# Bot kauft Upgrades wie die KI (mit Wahrscheinlichkeit buy_chance je Entscheidung)
var buy_chance := 0.4


func _bot_buy(g) -> void:
	if buy_chance <= 0.0:
		return
	for i in g.circles.size():
		var c: Dictionary = g.circles[i]
		if c["owner"] != 1 or g.rng.randf() > buy_chance:
			continue
		for kind in g.UP_KINDS:
			if int(c[kind]) < g.UP_MAX and c["value"] - float(g._up_cost(c, kind)) >= g.AI_KEEP:
				if g._shop_buy(1, i, kind):
					return
