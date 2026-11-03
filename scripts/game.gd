extends Node2D

# CircleWar - Echtzeit-Strategie mit Kreisen
# Menü (Schwierigkeit, Kreisanzahl) -> Partie gegen die KI -> Ergebnis

enum State { MENU, PLAYING }

const DESIGN_SIZE := Vector2(720, 1280)
const EDGE_MARGIN := 80.0      # Abstand der Kreise zum seitlichen/unteren Rand
const TOP_MARGIN := 140.0      # oben bleibt Platz für die Statusleiste
const GAP := 28.0              # Mindestabstand zwischen Kreisrändern
const START_VALUE := 15.0      # Startarmee beider Spieler
const ARMY_SPEED := 160.0      # Pixel pro Sekunde für entsendete Armeen
const BASE_GROWTH := 1.0       # Armee pro Sekunde auf einem besetzten Kreis
const FRACTIONS := [0.25, 0.5, 0.75, 1.0]
const TAP_TOLERANCE := 12.0    # Zusätzlicher Trefferbereich um Kreise (Finger)
const MIN_CIRCLES := 4
const MAX_CIRCLES := 30
const SETTINGS_PATH := "user://settings.cfg"

const BG_COLOR := Color("#14181f")
const COLORS := {
	0: Color("#8a8f98"),  # neutral
	1: Color("#2d7ff9"),  # Spieler
	2: Color("#e5484d"),  # Gegner
}

# Schwierigkeitsstufen = die fünf Gegner.
# interval: Sekunden zwischen KI-Entscheidungen, growth: Wachstumsfaktor der KI,
# margin: Sicherheitsfaktor beim Angriff (höher = vorsichtiger),
# share: Anteil der verfügbaren Armee, der mitgeschickt wird (0 = nur das Nötige),
# bonus: Vorliebe für Angriffe auf Spielerkreise, attacks: Angriffe pro Entscheidung.
const LEVELS := [
	{"label": "Sehr leicht", "name": "Kiesel", "mode": "random", "interval": 5.0,
		"growth": 0.6, "margin": 1.0, "share": 0.5, "bonus": 1.0, "attacks": 1,
		"info": "Greift selten und planlos an, wächst langsamer."},
	{"label": "Leicht", "name": "Wächter", "mode": "attack", "interval": 3.0,
		"growth": 0.85, "margin": 1.6, "share": 0.0, "bonus": 1.0, "attacks": 1,
		"info": "Greift nur an, wenn der Sieg sicher ist."},
	{"label": "Mittel", "name": "Sturm", "mode": "attack", "interval": 3.4,
		"growth": 1.0, "margin": 1.4, "share": 0.7, "bonus": 1.3, "attacks": 1,
		"info": "Angriffslustig und schickt fast alles los."},
	{"label": "Schwer", "name": "Stratege", "mode": "attack", "interval": 0.8,
		"growth": 1.1, "margin": 1.1, "share": 0.0, "bonus": 1.5, "attacks": 2,
		"info": "Wählt günstige Ziele und rechnet genau."},
	{"label": "Unspielbar", "name": "Kollektiv", "mode": "attack", "interval": 0.5,
		"growth": 1.3, "margin": 1.1, "share": 0.0, "bonus": 2.0, "attacks": 3,
		"info": "Blitzschnell, greift mehrfach an und wächst schneller."},
]

# Einstellungen (im Menü wählbar, werden gespeichert)
var difficulty := 2
var circle_count := 12

var state := State.MENU
var map_size := DESIGN_SIZE
var circles: Array = []   # {pos, value, owner, radius}
var armies: Array = []    # unterwegs: {from, to, owner, amount, target, progress}
var selected := -1
var press_index := -1
var press_button := ""
var drag_active := false
var drag_pos := Vector2.ZERO
var fraction_index := 1
var ai_timer := 0.0
var level: Dictionary = LEVELS[2]
var game_over := false
var winner := 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()
	_load_settings()
	_update_size()
	get_viewport().size_changed.connect(_update_size)


func _update_size() -> void:
	if is_inside_tree() and state == State.MENU:
		map_size = get_viewport_rect().size
		queue_redraw()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		difficulty = clampi(int(cfg.get_value("game", "difficulty", difficulty)), 0, LEVELS.size() - 1)
		circle_count = clampi(int(cfg.get_value("game", "circles", circle_count)), MIN_CIRCLES, MAX_CIRCLES)


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "circles", circle_count)
	cfg.save(SETTINGS_PATH)


func start_game() -> void:
	if is_inside_tree():
		map_size = get_viewport_rect().size
	circles.clear()
	armies.clear()
	selected = -1
	press_index = -1
	press_button = ""
	drag_active = false
	game_over = false
	winner = 0
	level = LEVELS[difficulty]
	ai_timer = level["interval"]
	state = State.PLAYING
	_place_circles()
	queue_redraw()


func _place_circles() -> void:
	var start_y := TOP_MARGIN + 40.0
	circles.append(_make_circle(Vector2(map_size.x * 0.5, map_size.y - start_y), START_VALUE, 1))
	circles.append(_make_circle(Vector2(map_size.x * 0.5, start_y), START_VALUE, 2))

	var attempts := 0
	while circles.size() < circle_count and attempts < 4000:
		attempts += 1
		var value := float(rng.randi_range(5, 20))
		var radius := _radius_for(value)
		var p := Vector2(
			rng.randf_range(EDGE_MARGIN, map_size.x - EDGE_MARGIN),
			rng.randf_range(TOP_MARGIN, map_size.y - EDGE_MARGIN))
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


# ---------- Menü- und Knopflayout ----------

func _menu_offset() -> float:
	return maxf(0.0, (map_size.y - DESIGN_SIZE.y) * 0.5)


# Liefert die aktuell sichtbaren Knöpfe als [{id, rect, label, sub}]
func _buttons() -> Array:
	var list := []
	var cx := map_size.x * 0.5
	if state == State.MENU:
		var off := _menu_offset()
		var bw := minf(map_size.x - 80.0, 600.0)
		for i in LEVELS.size():
			list.append({"id": "d%d" % i,
				"rect": Rect2(cx - bw * 0.5, off + 250.0 + i * 108.0, bw, 96.0),
				"label": LEVELS[i]["label"], "sub": LEVELS[i]["name"]})
		var row_y := off + 880.0
		list.append({"id": "minus", "rect": Rect2(cx - bw * 0.5, row_y, 110.0, 84.0), "label": "-", "sub": ""})
		list.append({"id": "plus", "rect": Rect2(cx + bw * 0.5 - 110.0, row_y, 110.0, 84.0), "label": "+", "sub": ""})
		list.append({"id": "start", "rect": Rect2(cx - bw * 0.5, off + 1020.0, bw, 120.0), "label": "Spiel starten", "sub": ""})
	elif game_over:
		var bw := 400.0
		list.append({"id": "again", "rect": Rect2(cx - bw * 0.5, map_size.y * 0.5 + 110.0, bw, 90.0), "label": "Nochmal", "sub": ""})
		list.append({"id": "tomenu", "rect": Rect2(cx - bw * 0.5, map_size.y * 0.5 + 220.0, bw, 90.0), "label": "Menü", "sub": ""})
	else:
		list.append({"id": "menu", "rect": Rect2(map_size.x - 170.0, 16.0, 150.0, 56.0), "label": "Menü", "sub": ""})
	return list


func _button_at(pos: Vector2) -> String:
	for b in _buttons():
		if b["rect"].has_point(pos):
			return b["id"]
	return ""


func _activate(id: String) -> void:
	match id:
		"start":
			_save_settings()
			start_game()
		"minus":
			circle_count = maxi(MIN_CIRCLES, circle_count - 1)
		"plus":
			circle_count = mini(MAX_CIRCLES, circle_count + 1)
		"again":
			start_game()
		"menu", "tomenu":
			state = State.MENU
			game_over = false
			drag_active = false
			selected = -1
			_update_size()
		_:
			if id.begins_with("d"):
				difficulty = int(id.substr(1))


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
	press_button = _button_at(pos)
	if press_button != "":
		queue_redraw()
		return
	if state != State.PLAYING or game_over:
		return
	drag_active = true
	drag_pos = pos
	press_index = _circle_at(pos)
	if press_index >= 0 and circles[press_index]["owner"] == 1:
		selected = press_index
	queue_redraw()


func _on_release(pos: Vector2) -> void:
	if press_button != "":
		var id := press_button
		press_button = ""
		if _button_at(pos) == id:
			_activate(id)
		queue_redraw()
		return

	drag_active = false
	if state != State.PLAYING or game_over:
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

# Sendet einen Anteil der Armee von src nach dst.
func _try_send(owner: int, src: int, dst: int, fraction: float) -> bool:
	return _send_amount(owner, src, dst, floorf(circles[src]["value"] * fraction))


# Angriffe brauchen mehr Armee als das Ziel, Verstärkung eigener Kreise geht immer.
func _send_amount(owner: int, src: int, dst: int, amount: float) -> bool:
	if src == dst or circles[src]["owner"] != owner:
		return false
	amount = minf(amount, floorf(circles[src]["value"]))
	if amount < 1.0:
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
			drag_active = false
			selected = -1
			return


# ---------- Ablauf ----------

func _process(delta: float) -> void:
	if state == State.PLAYING and not game_over:
		_tick(delta)
	queue_redraw()


# Ein Simulationsschritt (auch für Testläufe ohne Anzeige nutzbar)
func _tick(delta: float) -> void:
	var ai_growth: float = level["growth"]
	for c in circles:
		if c["owner"] == 1:
			c["value"] += BASE_GROWTH * delta
		elif c["owner"] == 2:
			c["value"] += BASE_GROWTH * ai_growth * delta

	for army in armies.duplicate():
		var dist: float = maxf(army["from"].distance_to(army["to"]), 1.0)
		army["progress"] += ARMY_SPEED * delta / dist
		if army["progress"] >= 1.0:
			armies.erase(army)
			_resolve(army)

	ai_timer -= delta
	if ai_timer <= 0.0:
		ai_timer = level["interval"]
		_ai_think()

	_check_winner()


# ---------- Gegner-KI ----------

func _ai_think() -> void:
	var own := _indices_with_owner(2)
	var others := _indices_not_owner(2)
	if own.is_empty() or others.is_empty():
		return

	if level["mode"] == "random":
		_ai_random(own, others)
		return

	var attacks: int = level["attacks"]
	for i in attacks:
		if not _ai_attack(own, others):
			break


# Kiesel: zufälliger Kreis greift ein zufälliges Ziel an, nur wenn es klappt
func _ai_random(own: Array, others: Array) -> void:
	var src: int = own[rng.randi() % own.size()]
	var dst: int = others[rng.randi() % others.size()]
	var share: float = level["share"]
	_send_amount(2, src, dst, floorf(circles[src]["value"] * share))


# Bestes Quelle-Ziel-Paar suchen: günstig und nah. Rückgabe: wurde angegriffen?
func _ai_attack(own: Array, others: Array) -> bool:
	var margin: float = level["margin"]
	var bonus: float = level["bonus"]
	var share: float = level["share"]
	var best_score := -1.0
	var best_src := -1
	var best_dst := -1
	var best_need := 0.0

	for dst in others:
		for src in own:
			var spare: float = circles[src]["value"] - 1.0
			var need: float = _needed(src, dst) * margin + 1.0
			if spare < need:
				continue
			var dist: float = circles[src]["pos"].distance_to(circles[dst]["pos"])
			var score: float = 1.0 / (need + dist / 80.0)
			if circles[dst]["owner"] == 1:
				score *= bonus
			if score > best_score:
				best_score = score
				best_src = src
				best_dst = dst
				best_need = need

	if best_src < 0:
		return false
	var amount := ceilf(best_need)
	if share > 0.0:
		amount = maxf(amount, floorf((circles[best_src]["value"] - 1.0) * share))
	return _send_amount(2, best_src, best_dst, amount)


# Armee, die ein Angriff von src auf dst mindestens braucht (inkl. Wachstum unterwegs)
func _needed(src: int, dst: int) -> float:
	var dist: float = circles[src]["pos"].distance_to(circles[dst]["pos"])
	var v: float = circles[dst]["value"]
	var dst_owner: int = circles[dst]["owner"]
	if dst_owner == 1:
		v += BASE_GROWTH * dist / ARMY_SPEED
	for a in armies:
		if a["target"] == dst and a["owner"] == 2:
			v -= a["amount"]
	return maxf(v, 0.0)


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


# ---------- Darstellung ----------

func _text(font: Font, y: float, text: String, size: int, color: Color) -> void:
	draw_string(font, Vector2(0.0, y), text, HORIZONTAL_ALIGNMENT_CENTER, map_size.x, size, color)


func _draw_button(font: Font, b: Dictionary, selected_btn: bool, pressed: bool, primary: bool) -> void:
	var r: Rect2 = b["rect"]
	var fill := Color("#232a36")
	if primary:
		fill = Color("#2d7ff9")
	if selected_btn:
		fill = Color("#2d7ff9")
	if pressed:
		fill = fill.lightened(0.2)
	draw_rect(r, fill, true)
	draw_rect(r, Color(1, 1, 1, 0.25), false, 2.0)
	var label: String = b["label"]
	var sub: String = b["sub"]
	if sub == "":
		draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + 12.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color.WHITE)
	else:
		draw_string(font, Vector2(r.position.x, r.position.y + 42.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 34, Color.WHITE)
		draw_string(font, Vector2(r.position.x, r.position.y + 74.0), "Gegner: " + sub,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.75))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, map_size), BG_COLOR, true)
	if state == State.MENU:
		_draw_menu(font)
	else:
		_draw_game(font)


func _draw_menu(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 120.0, "CircleWar", 64, Color.WHITE)
	_text(font, off + 170.0, "Erobere alle Kreise", 26, Color(1, 1, 1, 0.7))
	_text(font, off + 232.0, "Schwierigkeit", 24, Color(1, 1, 1, 0.7))

	for b in _buttons():
		var id: String = b["id"]
		var is_selected := id == "d%d" % difficulty
		_draw_button(font, b, is_selected, id == press_button, id == "start")

	_text(font, off + 818.0, level_info(), 22, Color(1, 1, 1, 0.85))
	_text(font, off + 872.0, "Anzahl Kreise", 24, Color(1, 1, 1, 0.7))
	_text(font, off + 935.0, str(circle_count), 44, Color.WHITE)


func level_info() -> String:
	return LEVELS[difficulty]["name"] + ": " + LEVELS[difficulty]["info"]


func _draw_game(font: Font) -> void:
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
		"Du: %d   %s: %d" % [player_count, level["name"], enemy_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, Vector2(20, 76),
		"Anteil: %d %%  (eigenen Kreis antippen)" % int(FRACTIONS[fraction_index] * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))

	for b in _buttons():
		if b["id"] == "menu":
			_draw_button(font, b, false, "menu" == press_button, false)

	if game_over:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0, 0, 0, 0.6), true)
		var text := "Gewonnen!" if winner == 1 else "Verloren"
		_text(font, map_size.y * 0.5 - 20.0, text, 64, Color.WHITE)
		_text(font, map_size.y * 0.5 + 30.0, "%s (%s)" % [level["label"], level["name"]], 26, Color(1, 1, 1, 0.8))
		for b in _buttons():
			_draw_button(font, b, false, b["id"] == press_button, b["id"] == "again")
