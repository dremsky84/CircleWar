extends Node2D

# CircleWar - Echtzeit-Strategie mit Kreisen
# Hauptmenü -> Spielen (Einstellungen) oder Werkstatt (Verstärkungen, Armeetypen)
# -> Partie gegen die KI -> Ergebnis mit Münzen

enum State { MAIN, SETUP, WORKSHOP, PLAYING }

const DESIGN_SIZE := Vector2(720, 1280)
const EDGE_MARGIN := 80.0      # Abstand der Kreise zum seitlichen/unteren Rand
const TOP_MARGIN := 140.0      # oben bleibt Platz für die Statusleiste
const GAP := 28.0              # Mindestabstand zwischen Kreisrändern
const START_VALUE := 15.0      # Startarmee beider Spieler
const ARMY_SPEED := 160.0      # Pixel pro Sekunde für entsendete Armeen
const BASE_GROWTH := 1.0       # Armee pro Sekunde auf einem besetzten Kreis
const SEND_FRACTION := 0.5     # Anteil der vorhandenen Armee, der pro Wischen gesendet wird
const HOLD_DELAY := 0.4        # so lange auf dem Ziel halten, bis die Prozentanzeige erscheint
const HOLD_RAMP := 1.5         # danach steigt sie in dieser Zeit von 50 auf 100 %
const TAP_TOLERANCE := 16.0    # Trefferfläche = sichtbarer Kreis + dieser Rand
const MIN_HIT_RADIUS := 56.0   # auch kleine Kreise sind mindestens so gut treffbar
const RELEASE_SNAP := 30.0     # beim Loslassen zählt ein Kreis auch knapp daneben
const MIN_CIRCLES := 4
const MAX_CIRCLES := 30
const SETTINGS_PATH := "user://settings.cfg"
const SPEEDS := [0.5, 1.0, 2.0, 4.0]
const SPEED_LABELS := ["0.5", "1", "2", "4"]

const BG_COLOR := Color("#14181f")
const GOLD := Color("#ffd23f")
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
	{"label": "Leicht", "name": "Wächter", "mode": "attack", "interval": 3.5,
		"growth": 0.75, "margin": 1.6, "share": 0.0, "bonus": 1.0, "attacks": 1,
		"info": "Greift nur an, wenn der Sieg sicher ist."},
	{"label": "Mittel", "name": "Sturm", "mode": "attack", "interval": 3.8,
		"growth": 0.9, "margin": 1.4, "share": 0.7, "bonus": 1.3, "attacks": 1,
		"info": "Angriffslustig und schickt fast alles los."},
	{"label": "Schwer", "name": "Stratege", "mode": "attack", "interval": 1.0,
		"growth": 1.0, "margin": 1.1, "share": 0.0, "bonus": 1.5, "attacks": 2,
		"info": "Wählt günstige Ziele und rechnet genau."},
	{"label": "Unspielbar", "name": "Kollektiv", "mode": "attack", "interval": 0.5,
		"growth": 1.3, "margin": 1.1, "share": 0.0, "bonus": 2.0, "attacks": 3,
		"info": "Blitzschnell, greift mehrfach an und wächst schneller."},
]

# ---- Fortschritt ----
# Verstärkungen: je 10 Stufen, jede Stufe +5 %. Preis der nächsten Stufe = UPGRADE_COSTS[Stufe].
const MAX_LEVEL := 10
const UPGRADE_STEP := 0.05
const UPGRADE_COSTS := [100, 150, 200, 300, 400, 550, 700, 900, 1100, 1400]
const UPGRADE_IDS := ["power", "speed", "growth"]
const UPGRADE_INFO := {
	"power": {"label": "Kraft", "desc": "Deine Armee zählt im Kampf mehr."},
	"speed": {"label": "Tempo", "desc": "Deine Armeen sind schneller unterwegs."},
	"growth": {"label": "Wachstum", "desc": "Deine Kreise bauen schneller Armee auf."},
}

# Armeetypen: power = Kraft, speed = Tempo (Faktoren, Standard = 1)
const TYPE_IDS := ["standard", "tank", "star"]
const TYPES := {
	"standard": {"label": "Standard", "shape": "triangle", "shape_name": "Dreieck",
		"power": 1.0, "speed": 1.0, "cost": 0, "desc": "Ausgewogen, alle Werte auf 1."},
	"tank": {"label": "Tank", "shape": "square", "shape_name": "Quadrat",
		"power": 1.3, "speed": 0.7, "cost": 500, "desc": "Mehr Schaden, aber langsamer."},
	"star": {"label": "Schnell", "shape": "star", "shape_name": "Stern",
		"power": 0.8, "speed": 1.4, "cost": 500, "desc": "Weniger Schaden, aber schneller."},
}

# Münzen pro Sieg je Schwierigkeit (bei 12 Kreisen)
const REWARDS := [20, 40, 70, 110, 160]
const LOSS_FACTOR := 0.25          # Niederlage gibt diesen Anteil
const ENEMY_LEVEL_BONUS := 1.5     # Faktor, wenn "Gegner levelt mit" an ist
const REWARD_REF_CIRCLES := 12.0   # Bezugsgröße für die Kreisanzahl

# Einstellungen und Fortschritt (werden gespeichert)
var difficulty := 2
var circle_count := 12
var dev_mode := false
var enemy_levels_up := false
var selected_type := "standard"
var coins := 0
var upgrade_levels := {"power": 0, "speed": 0, "growth": 0}
var unlocked: Array = ["standard"]

var state := State.MAIN
var map_size := DESIGN_SIZE
var circles: Array = []   # {pos, value, owner, radius}
var armies: Array = []    # unterwegs: {from, to, owner, amount, target, progress}
var stats: Dictionary = {}     # je Seite (1 = Spieler, 2 = Gegner): power, speed, growth, shape
var selected := -1
var press_index := -1
var press_button := ""
var drag_active := false
var drag_pos := Vector2.ZERO
var hold_target := -1          # Kreis, auf dem der Finger beim Zielen gerade liegt
var hold_time := 0.0           # wie lange schon (Sekunden)
var ai_timer := 0.0
var level: Dictionary = LEVELS[2]
var game_over := false
var winner := 0
var reward := 0                # Münzen der letzten Partie
var reward_paid := false
var rng := RandomNumberGenerator.new()

# Developer Mode (nur aktiv, wenn im Hauptmenü eingeschaltet)
var dev_open := false          # Panel sichtbar
var paused := false            # Pause-Menü im Spiel
var fx: Array = []             # Kampfeffekte (Funken/Blitze)
var dev_speed_index := 1
var dev_ai_frozen := false
var dev_info := false
var dev_tool := ""             # "", "owner", "plus", "minus"


func _ready() -> void:
	rng.randomize()
	_load_settings()
	_update_size()
	get_viewport().size_changed.connect(_update_size)


# Läuft eine Partie (auch wenn man gerade im Hauptmenü ist)?
func has_game() -> bool:
	return not circles.is_empty() and not game_over


func _update_size() -> void:
	if is_inside_tree() and not has_game():
		map_size = get_viewport_rect().size
		queue_redraw()


# ---------- Speichern ----------

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	difficulty = clampi(int(cfg.get_value("game", "difficulty", difficulty)), 0, LEVELS.size() - 1)
	circle_count = clampi(int(cfg.get_value("game", "circles", circle_count)), MIN_CIRCLES, MAX_CIRCLES)
	dev_mode = bool(cfg.get_value("game", "dev", false))
	enemy_levels_up = bool(cfg.get_value("game", "enemy_levels", false))
	coins = maxi(0, int(cfg.get_value("progress", "coins", 0)))
	for id in UPGRADE_IDS:
		upgrade_levels[id] = clampi(int(cfg.get_value("progress", "lvl_" + id, 0)), 0, MAX_LEVEL)
	unlocked = ["standard"]
	var saved: Array = cfg.get_value("progress", "unlocked", ["standard"])
	for tid in saved:
		if TYPES.has(tid) and not (tid in unlocked):
			unlocked.append(tid)
	var type_id := str(cfg.get_value("game", "type", "standard"))
	selected_type = type_id if (type_id in unlocked) else "standard"


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("game", "difficulty", difficulty)
	cfg.set_value("game", "circles", circle_count)
	cfg.set_value("game", "dev", dev_mode)
	cfg.set_value("game", "enemy_levels", enemy_levels_up)
	cfg.set_value("game", "type", selected_type)
	cfg.set_value("progress", "coins", coins)
	for id in UPGRADE_IDS:
		cfg.set_value("progress", "lvl_" + id, upgrade_levels[id])
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.save(SETTINGS_PATH)


# ---------- Verstärkungen, Typen, Münzen ----------

func _upgrade_mult(id: String) -> float:
	return 1.0 + UPGRADE_STEP * float(upgrade_levels[id])


# Werte beider Seiten für die kommende Partie. Der Gegner hat Standardwerte
# (mal Schwierigkeits-Wachstum); mit "Gegner levelt mit" bekommt er deine Verstärkungen.
func _compute_stats() -> void:
	var t: Dictionary = TYPES.get(selected_type, TYPES["standard"])
	var e_power := 1.0
	var e_speed := 1.0
	var e_growth := 1.0
	if enemy_levels_up:
		e_power = _upgrade_mult("power")
		e_speed = _upgrade_mult("speed")
		e_growth = _upgrade_mult("growth")
	var ai_growth: float = level["growth"]
	stats = {
		1: {"power": float(t["power"]) * _upgrade_mult("power"),
			"speed": float(t["speed"]) * _upgrade_mult("speed"),
			"growth": _upgrade_mult("growth"),
			"shape": t["shape"]},
		2: {"power": e_power, "speed": e_speed, "growth": ai_growth * e_growth,
			"shape": "triangle"},
	}


func _stat(owner: int, key: String, fallback: float) -> float:
	if owner == 0 or not stats.has(owner):
		return fallback
	return stats[owner][key]


func _power(owner: int) -> float:
	return _stat(owner, "power", 1.0)


func _speed(owner: int) -> float:
	return _stat(owner, "speed", 1.0)


func _growth(owner: int) -> float:
	return _stat(owner, "growth", 0.0)


func _buy_upgrade(id: String) -> bool:
	if not upgrade_levels.has(id):
		return false
	var lvl: int = upgrade_levels[id]
	if lvl >= MAX_LEVEL:
		return false
	var cost: int = UPGRADE_COSTS[lvl]
	if coins < cost:
		return false
	coins -= cost
	upgrade_levels[id] = lvl + 1
	_save_settings()
	return true


func _unlock_type(id: String) -> bool:
	if not TYPES.has(id) or id in unlocked:
		return false
	var cost: int = TYPES[id]["cost"]
	if coins < cost:
		return false
	coins -= cost
	unlocked.append(id)
	_save_settings()
	return true


# Münzen für eine Partie: Schwierigkeit, Sieg/Niederlage, Kreisanzahl, "Gegner levelt mit"
func _reward_for(won: bool) -> int:
	var base: float = REWARDS[difficulty]
	if not won:
		base *= LOSS_FACTOR
	base *= float(circle_count) / REWARD_REF_CIRCLES
	if enemy_levels_up:
		base *= ENEMY_LEVEL_BONUS
	return maxi(1, roundi(base))


func _pay_reward() -> void:
	reward_paid = true
	reward = _reward_for(winner == 1)
	coins += reward
	_save_settings()


# 1,3 statt 1.30
func _fmt(v: float) -> String:
	var s := "%.2f" % v
	if s.contains("."):
		s = s.rstrip("0").rstrip(".")
	return s.replace(".", ",")


# ---------- Spielstart ----------

func start_game() -> void:
	if is_inside_tree():
		map_size = get_viewport_rect().size
	circles.clear()
	armies.clear()
	selected = -1
	press_index = -1
	press_button = ""
	drag_active = false
	hold_target = -1
	hold_time = 0.0
	game_over = false
	winner = 0
	reward = 0
	reward_paid = false
	paused = false
	fx.clear()
	level = LEVELS[difficulty]
	_compute_stats()
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


func _panel_rect() -> Rect2:
	var h := 3.0 * 70.0 + 20.0
	return Rect2(0.0, map_size.y - h, map_size.x, h)


func _btn(id: String, rect: Rect2, label: String, size: int = 34, lines: Array = [],
		enabled: bool = true) -> Dictionary:
	return {"id": id, "rect": rect, "label": label, "size": size, "lines": lines, "enabled": enabled}


# Knöpfe des Developer-Panels im Spiel (3 Reihen à 4 Knöpfe)
func _dev_buttons() -> Array:
	var p := _panel_rect()
	var bw := (map_size.x - 50.0) / 4.0
	var rows := [
		[["dev_speed", "Tempo x" + SPEED_LABELS[dev_speed_index]],
			["dev_ai", "KI: aus" if dev_ai_frozen else "KI: an"],
			["dev_info", "Infos: an" if dev_info else "Infos: aus"]],
		[["dev_map", "Neue Karte"], ["dev_level", "Gegner +"], ["dev_win", "Sieg"], ["dev_lose", "Niederlage"]],
		[["dev_tool_owner", "Besitzer"], ["dev_tool_plus", "+10"], ["dev_tool_minus", "-10"], ["dev_tool_off", "Werkzeug aus"]],
	]
	var list := []
	for r in rows.size():
		for c in rows[r].size():
			list.append(_btn(rows[r][c][0],
				Rect2(10.0 + c * (bw + 10.0), p.position.y + 10.0 + r * 70.0, bw, 60.0),
				rows[r][c][1], 22))
	return list


# Zeilen der Werkstatt: 3 Verstärkungen, 2 freischaltbare Armeetypen
func _workshop_rows() -> Array:
	var rows := []
	var off := _menu_offset()
	var bw := minf(map_size.x - 40.0, 680.0)
	var x := (map_size.x - bw) * 0.5
	for i in UPGRADE_IDS.size():
		var id: String = UPGRADE_IDS[i]
		var lvl: int = upgrade_levels[id]
		var maxed := lvl >= MAX_LEVEL
		var cost := 0 if maxed else int(UPGRADE_COSTS[lvl])
		rows.append({
			"id": "buy_" + id,
			"rect": Rect2(x, off + 205.0 + i * 120.0, bw, 110.0),
			"title": UPGRADE_INFO[id]["label"],
			"sub": "Stufe %d von %d  ·  aktuell ×%s" % [lvl, MAX_LEVEL, _fmt(_upgrade_mult(id))],
			"desc": UPGRADE_INFO[id]["desc"],
			"btn": "Max" if maxed else "Kaufen: %d" % cost,
			"enabled": (not maxed) and coins >= cost,
		})
	var buyable := ["tank", "star"]
	for i in buyable.size():
		var tid: String = buyable[i]
		var t: Dictionary = TYPES[tid]
		var owned := tid in unlocked
		var cost2: int = t["cost"]
		rows.append({
			"id": "unlock_" + tid,
			"rect": Rect2(x, off + 635.0 + i * 120.0, bw, 110.0),
			"title": "%s (%s)" % [t["label"], t["shape_name"]],
			"sub": "Kraft ×%s  ·  Tempo ×%s" % [_fmt(t["power"]), _fmt(t["speed"])],
			"desc": t["desc"],
			"btn": "Freigeschaltet" if owned else "%d Münzen" % cost2,
			"enabled": (not owned) and coins >= cost2,
		})
	return rows


# Liefert die aktuell sichtbaren Knöpfe als [{id, rect, label, size, lines, enabled}]
func _buttons() -> Array:
	var list := []
	var cx := map_size.x * 0.5
	var off := _menu_offset()
	var bw := minf(map_size.x - 80.0, 600.0)
	match state:
		State.MAIN:
			if has_game():
				list.append(_btn("resume", Rect2(cx - bw * 0.5, off + 390.0, bw, 120.0), "Fortfahren", 42,
					["laufende Partie"]))
				list.append(_btn("go_setup", Rect2(cx - bw * 0.5, off + 530.0, bw, 100.0), "Neues Spiel", 34))
				list.append(_btn("go_workshop", Rect2(cx - bw * 0.5, off + 650.0, bw, 100.0), "Werkstatt", 34))
			else:
				list.append(_btn("go_setup", Rect2(cx - bw * 0.5, off + 400.0, bw, 130.0), "Spielen", 44))
				list.append(_btn("go_workshop", Rect2(cx - bw * 0.5, off + 560.0, bw, 110.0), "Werkstatt", 38))
			if dev_mode:
				var w := (bw - 20.0) / 3.0
				list.append(_btn("dev_coins", Rect2(cx - bw * 0.5, off + 1070.0, w, 70.0), "+1000", 22, ["Münzen"]))
				list.append(_btn("dev_unlock", Rect2(cx - bw * 0.5 + w + 10.0, off + 1070.0, w, 70.0), "Alles", 22, ["freischalten"]))
				list.append(_btn("dev_reset", Rect2(cx - bw * 0.5 + 2.0 * (w + 10.0), off + 1070.0, w, 70.0), "Fortschritt", 22, ["zurücksetzen"]))
			list.append(_btn("dev_toggle", Rect2(cx - bw * 0.5, off + 1160.0, bw, 60.0),
				"Developer Mode: " + ("An" if dev_mode else "Aus"), 22))
		State.SETUP:
			list.append(_btn("back", Rect2(20.0, off + 16.0, 150.0, 56.0), "Zurück", 26))
			for i in LEVELS.size():
				list.append(_btn("d%d" % i, Rect2(cx - bw * 0.5, off + 198.0 + i * 84.0, bw, 76.0),
					LEVELS[i]["label"], 28, ["Gegner: " + LEVELS[i]["name"]]))
			var row_y := off + 712.0
			list.append(_btn("minus", Rect2(cx - bw * 0.5, row_y, 110.0, 70.0), "-"))
			list.append(_btn("plus", Rect2(cx + bw * 0.5 - 110.0, row_y, 110.0, 70.0), "+"))
			var tw := (bw - 20.0) / 3.0
			for i in TYPE_IDS.size():
				var tid: String = TYPE_IDS[i]
				var t: Dictionary = TYPES[tid]
				var is_open := tid in unlocked
				var lines := ["Kraft ×" + _fmt(t["power"]), "Tempo ×" + _fmt(t["speed"])] if is_open \
					else ["gesperrt", "(Werkstatt)"]
				var b := _btn("type_" + tid, Rect2(cx - bw * 0.5 + i * (tw + 10.0), off + 842.0, tw, 112.0),
					t["label"], 26, lines, is_open)
				b["shape"] = t["shape"]
				list.append(b)
			list.append(_btn("enemy_toggle", Rect2(cx - bw * 0.5, off + 966.0, bw, 76.0),
				"Gegner levelt mit: " + ("An" if enemy_levels_up else "Aus"), 26,
				["Gegner bekommt deine Verstärkungen, Münzen ×1,5"]))
			list.append(_btn("start", Rect2(cx - bw * 0.5, off + 1058.0, bw, 108.0), "Spiel starten", 34))
		State.WORKSHOP:
			list.append(_btn("back", Rect2(20.0, off + 16.0, 150.0, 56.0), "Zurück", 26))
			for row in _workshop_rows():
				var r: Rect2 = row["rect"]
				list.append(_btn(row["id"], Rect2(r.position.x + r.size.x - 210.0, r.position.y + 20.0, 190.0, 70.0),
					row["btn"], 22, [], row["enabled"]))
		State.PLAYING:
			if game_over:
				var gw := 400.0
				list.append(_btn("again", Rect2(cx - gw * 0.5, map_size.y * 0.5 + 110.0, gw, 90.0), "Nochmal"))
				list.append(_btn("tomenu", Rect2(cx - gw * 0.5, map_size.y * 0.5 + 220.0, gw, 90.0), "Menü"))
			else:
				if paused:
					var pw := 400.0
					var py := map_size.y * 0.5 - 130.0
					list.append(_btn("resume", Rect2(cx - pw * 0.5, py, pw, 100.0), "Fortfahren", 38))
					list.append(_btn("menu", Rect2(cx - pw * 0.5, py + 120.0, pw, 90.0), "Menü"))
					if dev_mode:
						list.append(_btn("dev", Rect2(cx - pw * 0.5, py + 230.0, pw, 80.0), "Developer", 28))
						if dev_open:
							list.append_array(_dev_buttons())
				else:
					list.append(_btn("pause", Rect2(map_size.x - 170.0, 16.0, 150.0, 56.0), "Pause", 26))
	return list


func _button_at(pos: Vector2) -> String:
	for b in _buttons():
		if b["enabled"] and b["rect"].has_point(pos):
			return b["id"]
	return ""


# Ist ein Schalter-Knopf gerade "an"? (für die Hervorhebung)
func _is_active(id: String) -> bool:
	if id == "d%d" % difficulty:
		return true
	if id.begins_with("type_"):
		return id.substr(5) == selected_type
	match id:
		"dev": return dev_open
		"dev_ai": return dev_ai_frozen
		"dev_info": return dev_info
		"dev_toggle": return dev_mode
		"enemy_toggle": return enemy_levels_up
		"dev_tool_owner": return dev_tool == "owner"
		"dev_tool_plus": return dev_tool == "plus"
		"dev_tool_minus": return dev_tool == "minus"
		"dev_tool_off": return dev_tool == ""
	return false


func _activate(id: String) -> void:
	match id:
		"go_setup":
			state = State.SETUP
		"go_workshop":
			state = State.WORKSHOP
		"back":
			state = State.MAIN
		"start":
			_save_settings()
			start_game()
		"minus":
			circle_count = maxi(MIN_CIRCLES, circle_count - 1)
		"plus":
			circle_count = mini(MAX_CIRCLES, circle_count + 1)
		"enemy_toggle":
			enemy_levels_up = not enemy_levels_up
			_save_settings()
		"again":
			start_game()
		"pause":
			paused = true
			drag_active = false
			selected = -1
			hold_target = -1
			hold_time = 0.0
		"resume":
			state = State.PLAYING
			paused = false
			dev_open = false
		"menu", "tomenu":
			# Eine laufende Partie bleibt erhalten ("Fortfahren" im Hauptmenü)
			state = State.MAIN
			paused = true
			drag_active = false
			selected = -1
			_update_size()
		"dev_toggle":
			dev_mode = not dev_mode
			_reset_dev()
			_save_settings()
		"dev_coins":
			coins += 1000
			_save_settings()
		"dev_unlock":
			unlocked = TYPE_IDS.duplicate()
			for uid in UPGRADE_IDS:
				upgrade_levels[uid] = MAX_LEVEL
			_save_settings()
		"dev_reset":
			coins = 0
			unlocked = ["standard"]
			selected_type = "standard"
			for uid in UPGRADE_IDS:
				upgrade_levels[uid] = 0
			_save_settings()
		"dev":
			dev_open = not dev_open
		"dev_speed":
			dev_speed_index = (dev_speed_index + 1) % SPEEDS.size()
		"dev_ai":
			dev_ai_frozen = not dev_ai_frozen
		"dev_info":
			dev_info = not dev_info
		"dev_map":
			start_game()
		"dev_level":
			difficulty = (difficulty + 1) % LEVELS.size()
			level = LEVELS[difficulty]
			_compute_stats()
			ai_timer = level["interval"]
		"dev_win":
			_force_end(1)
		"dev_lose":
			_force_end(2)
		"dev_tool_owner":
			dev_tool = "owner"
		"dev_tool_plus":
			dev_tool = "plus"
		"dev_tool_minus":
			dev_tool = "minus"
		"dev_tool_off":
			dev_tool = ""
		_:
			if id.begins_with("buy_"):
				_buy_upgrade(id.substr(4))
			elif id.begins_with("unlock_"):
				_unlock_type(id.substr(7))
			elif id.begins_with("type_"):
				var tid := id.substr(5)
				if tid in unlocked:
					selected_type = tid
					_save_settings()
			elif id.begins_with("d") and id.length() == 2:
				difficulty = int(id.substr(1))


func _reset_dev() -> void:
	dev_open = false
	dev_speed_index = 1
	dev_ai_frozen = false
	dev_info = false
	dev_tool = ""


# Developer: Partie sofort beenden (ohne Münzen)
func _force_end(winning_owner: int) -> void:
	game_over = true
	winner = winning_owner
	reward = 0
	reward_paid = true
	drag_active = false
	selected = -1


# Developer-Werkzeug auf einen Kreis anwenden: Besitzer wechseln, +10 / -10 Armee
func _apply_dev_tool(i: int) -> void:
	if i < 0:
		return
	var c: Dictionary = circles[i]
	match dev_tool:
		"owner":
			c["owner"] = (int(c["owner"]) + 1) % 3
		"plus":
			c["value"] += 10.0
		"minus":
			c["value"] = maxf(1.0, c["value"] - 10.0)


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
	if paused and dev_mode and dev_open and _panel_rect().has_point(pos):
		return  # Berührungen auf dem Panel gehen nicht ins Spielfeld durch
	if dev_mode and dev_tool != "":
		_apply_dev_tool(_circle_at(pos))
		return
	if paused:
		return
	drag_active = true
	drag_pos = pos
	hold_target = -1
	hold_time = 0.0
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

	var target := _circle_at(pos, RELEASE_SNAP)
	if press_index >= 0 and circles[press_index]["owner"] == 1:
		if target >= 0 and target != press_index:
			# Auf dem Ziel gehalten? Dann zählt der angezeigte Prozentwert, sonst 50 %.
			var percent := 50
			if target == hold_target:
				percent = _hold_percent()
			_send_amount(1, press_index, target, _amount_for_percent(press_index, percent))
	else:
		selected = -1
	press_index = -1
	hold_target = -1
	hold_time = 0.0
	queue_redraw()


# Trefferradius eines Kreises: sichtbarer Kreis plus Rand, mindestens MIN_HIT_RADIUS
func _hit_radius(c: Dictionary) -> float:
	return maxf(c["radius"] + TAP_TOLERANCE, MIN_HIT_RADIUS)


# Kreis an dieser Position. extra erweitert die Trefferfläche (beim Loslassen).
# Bei mehreren Treffern gewinnt der Kreis mit dem kleinsten Abstand zu seinem Rand.
func _circle_at(pos: Vector2, extra: float = 0.0) -> int:
	var best := -1
	var best_gap := INF
	for i in circles.size():
		var gap: float = pos.distance_to(circles[i]["pos"]) - _hit_radius(circles[i])
		if gap <= extra and gap < best_gap:
			best_gap = gap
			best = i
	return best


# ---------- Spielregeln ----------

# Menge, die ein Anteil der Armee von src ergibt (mindestens 1, höchstens alles)
func _amount_for(src: int, fraction: float) -> float:
	var v: float = floorf(circles[src]["value"])
	return clampf(floorf(circles[src]["value"] * fraction), 1.0, maxf(v, 1.0))


# Prozentwert beim Halten auf dem Ziel: 50 % bis zur Anzeige, danach in 5-%-Schritten
# bis 100 % (HOLD_RAMP Sekunden). Ohne Halten immer 50.
func _hold_percent() -> int:
	if hold_target < 0 or hold_time < HOLD_DELAY:
		return 50
	var t := clampf((hold_time - HOLD_DELAY) / HOLD_RAMP, 0.0, 1.0)
	return 50 + roundi(t * 10.0) * 5


# Läuft jeden Frame: misst, wie lange der Finger beim Zielen auf demselben Kreis liegt.
func _update_hold(delta: float) -> void:
	var hover := -1
	if drag_active and selected >= 0:
		hover = _circle_at(drag_pos, RELEASE_SNAP)
		if hover == selected:
			hover = -1
	if hover < 0:
		hold_target = -1
		hold_time = 0.0
	elif hover != hold_target:
		hold_target = hover
		hold_time = 0.0
	else:
		hold_time += delta


# Menge für einen Prozentwert: 100 % sendet alles bis auf 1, sonst der gerundete Anteil
func _amount_for_percent(src: int, percent: int) -> float:
	if percent >= 100:
		var v: float = floorf(circles[src]["value"])
		return clampf(v - 1.0, 1.0, maxf(v, 1.0))
	return _amount_for(src, percent / 100.0)


# Sendet einen Anteil der Armee von src nach dst.
func _try_send(owner: int, src: int, dst: int, fraction: float) -> bool:
	if src < 0 or src >= circles.size():
		return false
	return _send_amount(owner, src, dst, _amount_for(src, fraction))


# Man darf jederzeit senden. Ist die Armee kleiner als das Ziel, wird sie bei der
# Ankunft einfach von dessen Armee abgezogen.
func _send_amount(owner: int, src: int, dst: int, amount: float) -> bool:
	if src == dst or circles[src]["owner"] != owner:
		return false
	amount = minf(amount, floorf(circles[src]["value"]))
	if amount < 1.0:
		return false

	circles[src]["value"] -= amount
	armies.append({
		"from": circles[src]["pos"],
		"to": circles[dst]["pos"],
		"owner": owner,
		"amount": amount,
		"target": dst,
		"progress": 0.0,
	})
	return true


# Kampf bei Ankunft. Beide Seiten zählen ihre Armee mal ihrer Kraft; die Differenz
# entscheidet, der Rest wird in Armee der Siegerseite zurückgerechnet.
func _resolve(army: Dictionary) -> void:
	var dst: Dictionary = circles[army["target"]]
	var owner: int = army["owner"]
	if dst["owner"] == owner:
		dst["value"] += army["amount"]
		return
	var atk: float = army["amount"] * _power(owner)
	var dfn: float = dst["value"] * _power(dst["owner"])
	_spawn_fx(dst, owner, atk > dfn)
	if atk > dfn:
		dst["owner"] = owner
		dst["value"] = (atk - dfn) / _power(owner)
	else:
		dst["value"] = (dfn - atk) / _power(dst["owner"])


# Kampfeffekt: Blitze und Funken um den umkämpften Kreis (nicht im Headless-Betrieb)
func _spawn_fx(dst: Dictionary, attacker: int, conquered: bool) -> void:
	if DisplayServer.get_name() == "headless" or fx.size() > 60:
		return
	var r: float = dst["radius"]
	var bolts := []
	var count := 10 if conquered else 7
	for k in count:
		var ang := rng.randf() * TAU
		var length := rng.randf_range(28.0, 46.0) * (1.4 if conquered else 1.0)
		var pts := PackedVector2Array()
		var segs := 4
		for j in segs + 1:
			var rr := r + 2.0 + length * float(j) / float(segs)
			var a := ang + (rng.randf_range(-0.14, 0.14) if j > 0 else 0.0)
			pts.append(Vector2.RIGHT.rotated(a) * rr)
		bolts.append(pts)
	fx.append({"pos": dst["pos"], "radius": r, "color": COLORS[attacker], "bolts": bolts,
		"age": 0.0, "dur": 0.7 if conquered else 0.5, "big": conquered})


func _update_fx(delta: float) -> void:
	for e in fx.duplicate():
		e["age"] += delta
		if e["age"] >= e["dur"]:
			fx.erase(e)


func _draw_fx() -> void:
	for e in fx:
		var t: float = e["age"] / e["dur"]
		var a := 1.0 - t
		var p: Vector2 = e["pos"]
		var col: Color = e["color"]
		draw_arc(p, e["radius"] + 4.0 + t * (46.0 if e["big"] else 30.0), 0.0, TAU, 48,
			Color(col.lightened(0.4), a * 0.7), 4.0 * a + 1.0)
		var flicker := 1.0 if int(e["age"] * 40.0) % 2 == 0 else 0.6
		for pts in e["bolts"]:
			var moved := PackedVector2Array()
			for q in pts:
				moved.append(p + q)
			draw_polyline(moved, Color(col, a * 0.55 * flicker), 11.0)
			draw_polyline(moved, Color(1.0, 0.96, 0.7, a * flicker), 4.0)
			draw_circle(moved[moved.size() - 1], 3.0 * a + 1.0, Color(1, 1, 0.8, a))


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
	if state == State.PLAYING and game_over and not reward_paid:
		_pay_reward()
	var running := state == State.PLAYING and not game_over and not paused
	if running:
		_update_hold(delta)
		_tick(delta * SPEEDS[dev_speed_index])
	if state == State.PLAYING and not paused:
		_update_fx(delta)
	queue_redraw()


# Ein Simulationsschritt (auch für Testläufe ohne Anzeige nutzbar)
func _tick(delta: float) -> void:
	for c in circles:
		var o: int = c["owner"]
		if o != 0:
			c["value"] += BASE_GROWTH * _growth(o) * delta

	for army in armies.duplicate():
		var dist: float = maxf(army["from"].distance_to(army["to"]), 1.0)
		army["progress"] += ARMY_SPEED * _speed(army["owner"]) * delta / dist
		if army["progress"] >= 1.0:
			armies.erase(army)
			_resolve(army)

	if not dev_ai_frozen:
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


# Kiesel: zufälliger Kreis schickt einen Teil seiner Armee auf ein zufälliges Ziel
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
			var need: float = _needed(2, src, dst) * margin + 1.0
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


# Armee (in Einheiten von owner), die ein Angriff von src auf dst mindestens braucht:
# Zielarmee samt Wachstum unterwegs, mit Kraft beider Seiten verrechnet.
func _needed(owner: int, src: int, dst: int, count_inflight: bool = true) -> float:
	var dist: float = circles[src]["pos"].distance_to(circles[dst]["pos"])
	var v: float = circles[dst]["value"]
	var dst_owner: int = circles[dst]["owner"]
	var atk := _power(owner)
	if dst_owner != 0 and dst_owner != owner:
		v += BASE_GROWTH * _growth(dst_owner) * dist / (ARMY_SPEED * _speed(owner))
	var eff := v * _power(dst_owner)
	if count_inflight:
		for a in armies:
			if a["target"] == dst and a["owner"] == owner:
				eff -= a["amount"] * atk
	return maxf(eff, 0.0) / atk


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


func _draw_button(font: Font, b: Dictionary, active: bool, pressed: bool, primary: bool) -> void:
	var r: Rect2 = b["rect"]
	var enabled: bool = b.get("enabled", true)
	var fill := Color("#232a36")
	if primary or active:
		fill = Color("#2d7ff9")
	if not enabled:
		fill = Color("#1a1f28")
	elif pressed:
		fill = fill.lightened(0.2)
	draw_rect(r, fill, true)
	draw_rect(r, Color(1, 1, 1, 0.25 if enabled else 0.1), false, 2.0)
	var text_color := Color.WHITE if enabled else Color(1, 1, 1, 0.4)
	var label: String = b["label"]
	var lines: Array = b.get("lines", [])
	var fs: int = b.get("size", 34)
	var has_shape: bool = b.has("shape")
	if has_shape:
		_draw_shape(b["shape"], r.position + Vector2(r.size.x * 0.5, 20.0), Vector2.RIGHT, 9.0,
			COLORS[1] if enabled else Color(0.45, 0.47, 0.5))
	if lines.is_empty():
		draw_string(font, Vector2(r.position.x, r.position.y + r.size.y * 0.5 + fs * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, text_color)
	else:
		var y := r.position.y + fs + 6.0 + (16.0 if has_shape else 0.0)
		draw_string(font, Vector2(r.position.x, y), label,
			HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, text_color)
		for i in lines.size():
			draw_string(font, Vector2(r.position.x, y + 24.0 + 22.0 * i), lines[i],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 18, Color(text_color, text_color.a * 0.75))


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, map_size), BG_COLOR, true)
	match state:
		State.MAIN:
			_draw_main(font)
		State.SETUP:
			_draw_setup(font)
		State.WORKSHOP:
			_draw_workshop(font)
		State.PLAYING:
			_draw_game(font)


func _draw_buttons(font: Font) -> void:
	for b in _buttons():
		var id: String = b["id"]
		_draw_button(font, b, _is_active(id), id == press_button, id == "start" or id == "resume" or (id == "go_setup" and not has_game()))


func _draw_coins(font: Font, off: float) -> void:
	draw_string(font, Vector2(0.0, off + 52.0), "Münzen: %d" % coins,
		HORIZONTAL_ALIGNMENT_RIGHT, map_size.x - 20.0, 28, GOLD)


func _draw_main(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 140.0, "CircleWar", 64, Color.WHITE)
	_text(font, off + 190.0, "Erobere alle Kreise", 26, Color(1, 1, 1, 0.7))
	_text(font, off + 330.0, "Münzen: %d" % coins, 40, GOLD)
	_draw_buttons(font)
	_text(font, off + 1256.0, "Danke an B4Players und N4Players!", 22, Color(GOLD, 0.85))
	if dev_mode:
		_text(font, off + 1058.0, "Developer", 18, Color(1, 1, 1, 0.5))


func _draw_setup(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 130.0, "Spielen", 48, Color.WHITE)
	_draw_coins(font, off)
	_text(font, off + 186.0, "Schwierigkeit", 22, Color(1, 1, 1, 0.7))
	_draw_buttons(font)
	_text(font, off + 646.0, level_info(), 20, Color(1, 1, 1, 0.85))
	_text(font, off + 700.0, "Anzahl Kreise", 22, Color(1, 1, 1, 0.7))
	_text(font, off + 712.0 + 48.0, str(circle_count), 40, Color.WHITE)
	_text(font, off + 832.0, "Armeetyp", 22, Color(1, 1, 1, 0.7))


func _draw_workshop(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 130.0, "Werkstatt", 48, Color.WHITE)
	_draw_coins(font, off)
	_text(font, off + 190.0, "Verstärkungen", 22, Color(1, 1, 1, 0.7))
	_text(font, off + 620.0, "Armeetypen", 22, Color(1, 1, 1, 0.7))
	for row in _workshop_rows():
		var r: Rect2 = row["rect"]
		draw_rect(r, Color("#1b2029"), true)
		draw_rect(r, Color(1, 1, 1, 0.12), false, 2.0)
		draw_string(font, r.position + Vector2(20, 38), row["title"], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		draw_string(font, r.position + Vector2(20, 68), row["sub"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.85))
		draw_string(font, r.position + Vector2(20, 94), row["desc"], HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.6))
	_draw_buttons(font)
	_text(font, off + 950.0, "Münzen verdienst du in Partien.", 20, Color(1, 1, 1, 0.6))


func level_info() -> String:
	return LEVELS[difficulty]["name"] + ": " + LEVELS[difficulty]["info"]


# Form (Dreieck, Quadrat oder Stern) mit weißem Rand, "vorne" zeigt in Richtung dir
func _draw_shape(shape: String, p: Vector2, dir: Vector2, s: float, color: Color) -> void:
	var perp := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array()
	match shape:
		"square":
			var h := s * 0.95
			pts = PackedVector2Array([
				p + dir * h + perp * h, p + dir * h - perp * h,
				p - dir * h - perp * h, p - dir * h + perp * h])
		"star":
			for i in 10:
				var r := s * (1.35 if i % 2 == 0 else 0.6)
				pts.append(p + dir.rotated(i * PI / 5.0) * r)
		_:
			pts = PackedVector2Array([
				p + dir * s * 1.3,
				p - dir * s * 0.8 + perp * s * 0.85,
				p - dir * s * 0.8 - perp * s * 0.85])
	draw_colored_polygon(pts, color)
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1, 1, 1, 0.9), 2.0)


# Armee unterwegs: kleine Form (je nach Armeetyp) in Bewegungsrichtung, Zahl darüber
func _draw_army(font: Font, a: Dictionary) -> void:
	var p: Vector2 = a["from"].lerp(a["to"], a["progress"])
	var dir: Vector2 = (a["to"] - a["from"]).normalized()
	var s: float = clampf(8.0 + sqrt(a["amount"]) * 1.6, 10.0, 22.0)
	var shape := "triangle"
	if stats.has(a["owner"]):
		shape = stats[a["owner"]]["shape"]
	_draw_shape(shape, p, dir, s, COLORS[a["owner"]])
	draw_string(font, p + Vector2(-20.0, -s - 6.0), str(int(a["amount"])),
		HORIZONTAL_ALIGNMENT_CENTER, 40, 20, Color.WHITE)


func _draw_game(font: Font) -> void:
	for i in circles.size():
		var c: Dictionary = circles[i]
		draw_circle(c["pos"], c["radius"], COLORS[c["owner"]])
		if i == selected:
			draw_arc(c["pos"], c["radius"] + 8.0, 0.0, TAU, 48, Color.WHITE, 3.0)
		var label := "%.1f" % c["value"] if (dev_mode and dev_info) else str(int(c["value"]))
		var label_size := 24 if (dev_mode and dev_info) else 28
		draw_string(font, c["pos"] + Vector2(-c["radius"], label_size * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, c["radius"] * 2.0, label_size, Color.WHITE)
		if dev_mode and dev_info:
			draw_arc(c["pos"], _hit_radius(c), 0.0, TAU, 48, Color(1, 1, 0, 0.35), 1.5)

	for a in armies:
		_draw_army(font, a)
	_draw_fx()

	if drag_active and selected >= 0:
		var end := drag_pos
		var hover := _circle_at(drag_pos, RELEASE_SNAP)
		if hover >= 0 and hover != selected:
			var hc: Dictionary = circles[hover]
			end = hc["pos"]
			draw_arc(hc["pos"], hc["radius"] + 10.0, 0.0, TAU, 48, Color.WHITE, 3.0)
			var pct := _hold_percent()
			var label_y: float = -hc["radius"] - 18.0
			if hold_target == hover and hold_time >= HOLD_DELAY:
				# Halte-Anzeige: Bogen um das Ziel füllt sich von 50 auf 100 %
				var arc_r: float = hc["radius"] + 24.0
				var frac := float(pct - 50) / 50.0
				draw_arc(hc["pos"], arc_r, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 8.0)
				if frac > 0.0:
					draw_arc(hc["pos"], arc_r, -PI * 0.5, -PI * 0.5 + TAU * frac, 64, GOLD, 8.0)
				draw_rect(Rect2(hc["pos"] + Vector2(-48.0, label_y - 68.0), Vector2(96.0, 74.0)),
					Color(BG_COLOR, 0.88), true)
				draw_string(font, hc["pos"] + Vector2(-60.0, label_y - 32.0), "%d %%" % pct,
					HORIZONTAL_ALIGNMENT_CENTER, 120, 34, GOLD)
				label_y -= 8.0
			draw_string(font, hc["pos"] + Vector2(-60.0, label_y),
				"-> %d" % int(_amount_for_percent(selected, pct)),
				HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color.WHITE)
		draw_line(circles[selected]["pos"], end, Color(1, 1, 1, 0.5), 3.0)

	var player_count := _indices_with_owner(1).size()
	var enemy_count := _indices_with_owner(2).size()
	draw_string(font, Vector2(20, 40),
		"Du: %d   %s: %d" % [player_count, level["name"], enemy_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, Vector2(20, 76),
		"Wischen = %d %%, Ziel halten = mehr" % int(SEND_FRACTION * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.8))

	if dev_mode:
		_draw_dev_overlay(font)

	if not game_over:
		if paused:
			draw_rect(Rect2(Vector2.ZERO, map_size), Color(0, 0, 0, 0.55), true)
			_text(font, map_size.y * 0.5 - 170.0, "Pause", 56, Color.WHITE)
			if dev_mode and dev_open:
				draw_rect(_panel_rect(), Color(0, 0, 0, 0.78), true)
		for b in _buttons():
			var id: String = b["id"]
			_draw_button(font, b, _is_active(id), id == press_button, id == "resume")

	if game_over:
		draw_rect(Rect2(Vector2.ZERO, map_size), Color(0, 0, 0, 0.6), true)
		var text := "Gewonnen!" if winner == 1 else "Verloren"
		_text(font, map_size.y * 0.5 - 20.0, text, 64, Color.WHITE)
		_text(font, map_size.y * 0.5 + 30.0, "%s (%s)" % [level["label"], level["name"]], 26, Color(1, 1, 1, 0.8))
		if reward > 0:
			_text(font, map_size.y * 0.5 + 78.0, "+%d Münzen" % reward, 30, GOLD)
		for b in _buttons():
			_draw_button(font, b, false, b["id"] == press_button, b["id"] == "again")


# Developer-Anzeigen: Werkzeug, Pause und (optional) Diagnosewerte
func _draw_dev_overlay(font: Font) -> void:
	var y := 102.0
	if dev_tool != "":
		draw_string(font, Vector2(20, y), "Werkzeug: " + dev_tool_label() + " (Kreis antippen)",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 20, GOLD)
		y += 26.0
	if dev_info:
		var lines := [
			"FPS %d   Kreise %d   Armeen unterwegs %d" % [Engine.get_frames_per_second(), circles.size(), armies.size()],
			"KI %s: alle %.1fs, nächste in %.1fs%s" % [level["name"], level["interval"], maxf(ai_timer, 0.0),
				" (eingefroren)" if dev_ai_frozen else ""],
			"Tempo x%s   Wachstum KI x%.2f" % [SPEED_LABELS[dev_speed_index], _growth(2)],
			"Du: Kraft x%.2f Tempo x%.2f Wachstum x%.2f" % [_power(1), _speed(1), _growth(1)],
			"KI: Kraft x%.2f Tempo x%.2f" % [_power(2), _speed(2)],
		]
		for line in lines:
			draw_string(font, Vector2(20, y), line, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, GOLD)
			y += 24.0


func dev_tool_label() -> String:
	match dev_tool:
		"owner": return "Besitzer wechseln"
		"plus": return "+10 Armee"
		"minus": return "-10 Armee"
	return ""
