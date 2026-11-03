extends Node2D

# Echtzeit-Strategie mit Kreisen - Prototyp (Kernspiel, ohne Menü)

const MAP_SIZE := Vector2(720, 1280)
const EDGE_MARGIN := 80.0      # Abstand der Kreise zum Kartenrand
const GAP := 28.0              # Mindestabstand zwischen Kreisrändern
const START_VALUE := 15.0      # Startarmee beider Spieler
const ARMY_SPEED := 160.0      # Pixel pro Sekunde für entsendete Armeen
const GROWTH_PER_SEC := 1.0    # Armee pro Sekunde auf einem besetzten Kreis
const FRACTIONS := [0.25, 0.5, 0.75, 1.0]
const TAP_TOLERANCE := 12.0    # Zusätzlicher Trefferbereich um Kreise (Finger)

const COLORS := {
	0: Color("#8a8f98"),  # neutral
	1: Color("#2d7ff9"),  # Spieler
	2: Color("#e5484d"),  # Gegner
}

# Gegnertypen: Intervall zwischen Entscheidungen, Vorsicht (Sicherheitsabstand)
const PROFILES := {
	"Kiesel": {"interval": 3.0, "margin": 1.0},
	"Wächter": {"interval": 2.5, "margin": 1.5},
	"Sturm": {"interval": 1.0, "margin": 1.0},
	"Stratege": {"interval": 2.0, "margin": 3.0},
	"Kollektiv": {"interval": 2.0, "margin": 2.0},
}

# Vor dem Spiel wählbar (später über ein Menü)
var circle_count := 12
var opponent_name := "Sturm"

var circles: Array = []   # {pos, value, owner, radius}
var armies: Array = []    # unterwegs: {from, to, owner, amount, target, progress}
var selected := -1
var press_index := -1
var drag_active := false
var drag_pos := Vector2.ZERO
var fraction_index := 1
var ai_timer := 0.0
var ai_profile: Dictionary = {}
var game_over := false
var winner := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	start_game()


func start_game() -> void:
	circles.clear()
	armies.clear()
	selected = -1
	press_index = -1
	drag_active = false
	game_over = false
	winner = 0
	ai_profile = PROFILES[opponent_name]
	ai_timer = ai_profile["interval"]
	_place_circles()
	queue_redraw()


func _place_circles() -> void:
	circles.append(_make_circle(Vector2(MAP_SIZE.x * 0.5, MAP_SIZE.y * 0.85), START_VALUE, 1))
	circles.append(_make_circle(Vector2(MAP_SIZE.x * 0.5, MAP_SIZE.y * 0.15), START_VALUE, 2))

	var attempts := 0
	while circles.size() < circle_count and attempts < 2000:
		attempts += 1
		var value := float(rng.randi_range(5, 20))
		var radius := _radius_for(value)
		var p := Vector2(
			rng.randf_range(EDGE_MARGIN, MAP_SIZE.x - EDGE_MARGIN),
			rng.randf_range(EDGE_MARGIN, MAP_SIZE.y - EDGE_MARGIN))
		if _fits(p, radius):
			circles.append(_make_circle(p, value, 0))


func _make_circle(pos: Vector2, value: float, owner: int) -> Dictionary:
	return {"pos": pos, "value": value, "owner": owner, "radius": _radius_for(value)}


func _radius_for(value: float) -> float:
	return 22.0 + value * 2.0


func _fits(p: Vector2, radius: float) -> bool:
	for c in circles:
		if p.distance_to(c["pos"]) < radius + c["radius"] + GAP:
			return false
	return true


# ---------- Eingabe ----------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_on_press(event.position)
		else:
			_on_release(event.position)
	elif event is InputEventMouseMotion and drag_active:
		drag_pos = event.position
		queue_redraw()


func _on_press(pos: Vector2) -> void:
	if game_over:
		return
	drag_active = true
	drag_pos = pos
	press_index = _circle_at(pos)
	if press_index >= 0 and circles[press_index]["owner"] == 1:
		selected = press_index
	queue_redraw()


func _on_release(pos: Vector2) -> void:
	drag_active = false
	if game_over:
		start_game()
		return

	var target := _circle_at(pos)
	if press_index >= 0 and circles[press_index]["owner"] == 1:
		if target == press_index:
			# Tippen: Anteil der Armee umschalten (25, 50, 75, 100 %)
			fraction_index = (fraction_index + 1) % FRACTIONS.size()
		elif target >= 0:
			_try_send(1, press_index, target, FRACTIONS[fraction_index])
	else:
		selected = -1
	press_index = -1
	queue_redraw()


func _circle_at(pos: Vector2) -> int:
	for i in circles.size():
		if pos.distance_to(circles[i]["pos"]) <= circles[i]["radius"] + TAP_TOLERANCE:
			return i
	return -1


# ---------- Spielregeln ----------

# Sendet einen Anteil der Armee von src nach dst. Angriffe brauchen mehr Armee als das Ziel.
func _try_send(owner: int, src: int, dst: int, fraction: float) -> bool:
	if src == dst or circles[src]["owner"] != owner:
		return false
	var amount := floor(circles[src]["value"] * fraction)
	if amount < 1:
		return false
	var dst_circle: Dictionary = circles[dst]
	if dst_circle["owner"] != owner and amount <= dst_circle["value"]:
		return false

	circles[src]["value"] -= amount
	armies.append({
		"from": circles[src]["pos"],
		"to": dst_circle["pos"],
		"owner": owner,
		"amount": amount,
		"target": dst,
		"progress": 0.0,
	})
	return true


func _resolve(army: Dictionary) -> void:
	var dst: Dictionary = circles[army["target"]]
	if dst["owner"] == army["owner"]:
		dst["value"] += army["amount"]
	elif army["amount"] > dst["value"]:
		dst["owner"] = army["owner"]
		dst["value"] = army["amount"] - dst["value"]
	else:
		dst["value"] -= army["amount"]


func _check_winner() -> void:
	for owner in [1, 2]:
		var alive := false
		for c in circles:
			if c["owner"] == owner:
				alive = true
				break
		for a in armies:
			if a["owner"] == owner:
				alive = true
				break
		if not alive:
			game_over = true
			winner = 3 - owner
			return


# ---------- Ablauf ----------

func _process(delta: float) -> void:
	if game_over:
		queue_redraw()
		return

	for c in circles:
		if c["owner"] != 0:
			c["value"] += GROWTH_PER_SEC * delta

	for army in armies.duplicate():
		var dist: float = max(army["from"].distance_to(army["to"]), 1.0)
		army["progress"] += ARMY_SPEED * delta / dist
		if army["progress"] >= 1.0:
			armies.erase(army)
			_resolve(army)

	ai_timer -= delta
	if ai_timer <= 0.0:
		ai_timer = ai_profile["interval"]
		_ai_think()

	_check_winner()
	queue_redraw()


# Gegner-KI: je Typ eine eigene Strategie
func _ai_think() -> void:
	var own := _indices_with_owner(2)
	var others := _indices_not_owner(2)
	if own.is_empty() or others.is_empty():
		return

	match opponent_name:
		"Kiesel":
			# Zufällig: zufälliger eigener Kreis greift zufälliges Ziel an
			_try_send(2, own.pick_random(), others.pick_random(), 1.0)

		"Wächter":
			# Vorsichtig: nur mit deutlichem Vorsprung, schickt etwas zurück
			for src in own:
				var dst := _nearest(circles[src]["pos"], others)
				if circles[src]["value"] > circles[dst]["value"] * ai_profile["margin"]:
					if _try_send(2, src, dst, 0.8):
						return

		"Sturm":
			# Aggressiv: stärkster Kreis greift den schwächsten erreichbaren an
			var src := _biggest(own)
			var dst := others[0]
			for o in others:
				if circles[o]["value"] < circles[dst]["value"]:
					dst = o
			_try_send(2, src, dst, 1.0)

		"Stratege":
			# Plant: bestes Verhältnis aus Kosten und Entfernung, wartet auf genug Armee
			var best_score := -1.0
			var best_src := -1
			var best_dst := -1
			for dst in others:
				var src := _nearest(circles[dst]["pos"], own)
				var dist: float = max(circles[src]["pos"].distance_to(circles[dst]["pos"]), 1.0)
				var score: float = 1.0 / (circles[dst]["value"] + 1.0) / dist
				if score > best_score and circles[src]["value"] > circles[dst]["value"] + ai_profile["margin"]:
					best_score = score
					best_src = src
					best_dst = dst
			if best_src >= 0:
				_try_send(2, best_src, best_dst, 1.0)

		"Kollektiv":
			# Sammelt: alle starken Kreise greifen gemeinsam dasselbe Ziel an
			var dst := _nearest(circles[_biggest(own)]["pos"], others)
			for src in own:
				if circles[src]["value"] > circles[dst]["value"] + ai_profile["margin"]:
					_try_send(2, src, dst, 1.0)


func _indices_with_owner(owner: int) -> Array:
	var result := []
	for i in circles.size():
		if circles[i]["owner"] == owner:
			result.append(i)
	return result


func _indices_not_owner(owner: int) -> Array:
	var result := []
	for i in circles.size():
		if circles[i]["owner"] != owner:
			result.append(i)
	return result


func _nearest(pos: Vector2, indices: Array) -> int:
	var best := -1
	var best_dist := INF
	for i in indices:
		var d := pos.distance_to(circles[i]["pos"])
		if d < best_dist:
			best_dist = d
			best = i
	return best


func _biggest(indices: Array) -> int:
	var best: int = indices[0]
	for i in indices:
		if circles[i]["value"] > circles[best]["value"]:
			best = i
	return best


# ---------- Darstellung ----------

func _draw() -> void:
	var font := ThemeDB.fallback_font

	for i in circles.size():
		var c: Dictionary = circles[i]
		draw_circle(c["pos"], c["radius"], COLORS[c["owner"]])
		if i == selected:
			draw_arc(c["pos"], c["radius"] + 8.0, 0.0, TAU, 48, Color.WHITE, 3.0)
		draw_string(font, c["pos"] + Vector2(-c["radius"], 10.0), str(int(c["value"])),
			HORIZONTAL_ALIGNMENT_CENTER, c["radius"] * 2.0, 28, Color.WHITE)

	for a in armies:
		var p: Vector2 = a["from"].lerp(a["to"], a["progress"])
		draw_circle(p, 9.0, COLORS[a["owner"]])
		draw_string(font, p + Vector2(-20, -14), str(int(a["amount"])),
			HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color.WHITE)

	if drag_active and selected >= 0:
		draw_line(circles[selected]["pos"], drag_pos, Color(1, 1, 1, 0.5), 3.0)

	var player_count := _indices_with_owner(1).size()
	var enemy_count := _indices_with_owner(2).size()
	draw_string(font, Vector2(20, 40),
		"Du: %d Kreise   %s: %d Kreise" % [player_count, opponent_name, enemy_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, Vector2(20, 76),
		"Anteil: %d %%  (Kreis antippen zum Ändern)" % int(FRACTIONS[fraction_index] * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))

	if game_over:
		var text := "Gewonnen!" if winner == 1 else "Verloren"
		draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0, 0, 0, 0.5))
		draw_string(font, MAP_SIZE * 0.5 + Vector2(-200, 0), text,
			HORIZONTAL_ALIGNMENT_CENTER, 400, 56, Color.WHITE)
		draw_string(font, MAP_SIZE * 0.5 + Vector2(-200, 60), "Tippen für neue Partie",
			HORIZONTAL_ALIGNMENT_CENTER, 400, 24, Color(1, 1, 1, 0.8))
