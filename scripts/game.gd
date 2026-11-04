extends Node2D

# Circle-Wars - Echtzeit-Strategie mit Kreisen
# Hauptmenü -> Spielen (Einstellungen) oder Werkstatt (Verstärkungen, Armeetypen)
# -> Partie gegen die KI -> Ergebnis mit Münzen

enum State { MAIN, SETUP, WORKSHOP, PLAYING, MULTI, EDITOR }

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
const CHAIN_DWELL := 0.3       # so lange auf einem eigenen Planeten verweilen, um ihn in die Kette aufzunehmen
const MASS_DELAY := 0.5        # so lange ruhig auf einem Planeten halten, bis der Massenangriff startet
const MASS_CANCEL_RADIUS := 70.0  # Trefferfläche des roten X
const TAP_TOLERANCE := 16.0    # Trefferfläche = sichtbarer Kreis + dieser Rand
const MIN_HIT_RADIUS := 56.0   # auch kleine Kreise sind mindestens so gut treffbar
const RELEASE_SNAP := 30.0     # beim Loslassen zählt ein Kreis auch knapp daneben
const MIN_CIRCLES := 4
const MAX_CIRCLES := 30
const NET_PORT := 24600          # Mehrspieler (ENet) im WLAN
const DISCOVERY_PORT := 24601    # Broadcast, damit Spiele im WLAN gefunden werden
const SNAPSHOT_RATE := 15.0      # Zustandsübertragungen pro Sekunde
const MUSIC_VOLUME_DB := -9.0
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
		"growth": 0.6, "margin": 1.0, "share": 0.5, "bonus": 1.0, "attacks": 1, "buy": 0.0,
		"info": "Greift selten und planlos an, wächst langsamer."},
	{"label": "Leicht", "name": "Wächter", "mode": "attack", "interval": 3.5,
		"growth": 0.75, "margin": 1.6, "share": 0.0, "bonus": 1.0, "attacks": 1, "buy": 0.0,
		"info": "Greift nur an, wenn der Sieg sicher ist."},
	{"label": "Mittel", "name": "Sturm", "mode": "attack", "interval": 3.8,
		"growth": 0.9, "margin": 1.4, "share": 0.7, "bonus": 1.3, "attacks": 1, "buy": 0.25,
		"info": "Angriffslustig und schickt fast alles los."},
	{"label": "Schwer", "name": "Stratege", "mode": "attack", "interval": 1.0,
		"growth": 1.0, "margin": 1.1, "share": 0.0, "bonus": 1.5, "attacks": 2, "buy": 0.5,
		"info": "Wählt günstige Ziele und rechnet genau."},
	{"label": "Unspielbar", "name": "Kollektiv", "mode": "attack", "interval": 0.5,
		"growth": 1.3, "margin": 1.1, "share": 0.0, "bonus": 2.0, "attacks": 3, "buy": 0.8,
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

# Planeten-Upgrades (bezahlt mit der Armee auf dem Planeten, je 3 Stufen, gehen bei Eroberung verloren)
const UP_KINDS := ["shield", "gun", "boost"]
const UP_MAX := 3
const UP_COSTS := {"shield": [6, 10, 15], "gun": [8, 12, 18], "boost": [5, 8, 12]}
const UP_INFO := {
	"shield": {"label": "Schutzschild", "desc": "Verteidigung ×1,2 · ×1,4 · ×1,6"},
	"gun": {"label": "Abwehrgeschütz", "desc": "Beschießt Feinde in Reichweite: 2 · 3 · 4 Schaden"},
	"boost": {"label": "Beschleunigungsfeld", "desc": "Entsandte Armeen +25 · +50 · +75 % schneller"},
}
const SHIELD_MULT := [1.0, 1.2, 1.4, 1.6]
const GUN_DAMAGE := [0.0, 2.0, 3.0, 4.0]
const GUN_RANGE := [0.0, 100.0, 120.0, 140.0]   # Reichweite ab Kreisrand
const GUN_INTERVAL := 0.9
const BOOST_MULT := [1.0, 1.25, 1.5, 1.75]
const AI_KEEP := 10.0          # so viel Armee lässt die KI nach einem Kauf mindestens übrig

# Levelarten
const KIND_NORMAL := 0
const KIND_GOLD := 1
const KIND_DEAD := 2
const KIND_HILL := 3
const KIND_MULT := [1.0, 2.0, 0.0, 1.0]   # Wachstumsfaktor je Planetenart
const LEVEL_TYPE_IDS := ["classic", "rush", "resource", "hill", "custom"]
const LEVEL_TYPES := {
	"classic": {"label": "Classic", "reward": 1.0, "desc": "Zufällige Karte wie gewohnt."},
	"rush": {"label": "Rush", "reward": 0.8, "desc": "26 kleine Planeten, Wachstum ×1,8: kurz und hektisch."},
	"resource": {"label": "Rohstoff", "reward": 1.0, "desc": "Goldplaneten wachsen ×2, ausgebrannte gar nicht."},
	"hill": {"label": "Hügel", "reward": 1.2, "desc": "Halte den Planeten in der Mitte 60 s, dann gewinnst du."},
	"custom": {"label": "Eigene", "reward": 0.5, "desc": "Eigene Level aus dem Editor."},
}
const LEVELS_PATH := "user://levels.json"
const ED_TOP := 140.0            # Editor: oben Platz für die Leiste
const ED_BOTTOM := 232.0         # Editor: unten Platz für das Werkzeugfeld
const ED_GAP := 6.0
const ED_MAX_PLANETS := 40
const ED_MAX_LEVELS := 20
const RUSH_CIRCLES := 26
const RUSH_START := 10.0
const RUSH_GROWTH := 1.8
const RUSH_AI_SLOWDOWN := 1.8   # mit so vielen kleinen Planeten denkt die KI langsamer (sonst überrennt sie alles)
const HILL_GOAL := 60.0
const GOLD_COUNT := 2
const DEAD_COUNT := 3

# Münzen pro Sieg je Schwierigkeit (bei 12 Kreisen)
const REWARDS := [20, 40, 70, 110, 160]
const LOSS_FACTOR := 0.25          # Niederlage gibt diesen Anteil
const ENEMY_LEVEL_BONUS := 1.5     # Faktor, wenn "Gegner levelt mit" an ist
const REWARD_REF_CIRCLES := 12.0   # Bezugsgröße für die Kreisanzahl

# Einstellungen und Fortschritt (werden gespeichert)
var difficulty := 2
var circle_count := 12
var level_type := "classic"
var custom_levels: Array = []  # [{name, circles: [[x, y, value, owner, kind], ...]}], Koordinaten 0..1
var selected_custom := 0
var ed_circles: Array = []     # Editor: Planeten in Bildschirmkoordinaten
var ed_sel := -1
var ed_drag := -1
var ed_slot := -1              # Index des gerade bearbeiteten gespeicherten Levels (-1 = neu)
var ed_testing := false
var ed_test_level: Dictionary = {}
var ed_prev_type := "classic"
var name_edit: LineEdit = null
var hill_owner := 0            # wer den Hügel gerade hält (lokale Seite)
var hill_time := 0.0           # wie lange schon, in Sekunden
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
# Mehrspieler: Host rechnet das Spiel, der Client zeigt es gespiegelt an und schickt Befehle
var mp_role := ""              # "", "host", "client"
var mp_status := ""            # "", "hosting", "connecting", "waiting", "playing"
var mp_peer: ENetMultiplayerPeer = null
var mp_udp_send: PacketPeerUDP = null
var mp_udp_recv: PacketPeerUDP = null
var mp_found: Dictionary = {}  # IP -> zuletzt gesehen (ms)
var mp_bcast_timer := 0.0
var mp_snap_timer := 0.0
var mp_end_sent := false
var last_ip := ""
var ip_edit: LineEdit = null
# Audio
var music_on := true
var sfx_on := true
var audio_enabled := false
var music_player: AudioStreamPlayer = null
var sfx_players: Array = []
var audio_cache: Dictionary = {}
var sfx_last: Dictionary = {}
var music_track := ""
var over_sound := false
# Upgrade-Pause: Spiel steht, solange jemand Upgrades kauft; alle Spieler müssen "Weiter" drücken
var shop_pause := false
var shop_planet := -1
var shop_votes := {1: false, 2: true}   # lokal: 1 = ich, 2 = Gegner (KI zählt immer als bereit)
var press_pos := Vector2.ZERO
# Massenangriff: lange auf einen Planeten drücken -> Prozentzähler, Loslassen schickt von allen eigenen Planeten
var press_time := 0.0
var press_moved := false
var mass_active := false
var mass_target := -1
var mass_time := 0.0
var chain_cand := -1           # eigener Planet unter dem Finger, der gerade aufgenommen wird
var chain_time := 0.0
var chain: Array = []          # eigene Planeten, über die gewischt wurde (Sammelangriff)
var title_taps := 0            # Geheimcode: 5x auf den Titel tippen
var title_tap_time := 0
var toast := ""
var toast_time := 0.0


func _ready() -> void:
	rng.randomize()
	ip_edit = LineEdit.new()
	ip_edit.placeholder_text = "IP-Adresse, z. B. 192.168.1.20"
	ip_edit.add_theme_font_size_override("font_size", 28)
	ip_edit.visible = false
	add_child(ip_edit)
	name_edit = LineEdit.new()
	name_edit.placeholder_text = "Levelname"
	name_edit.max_length = 24
	name_edit.add_theme_font_size_override("font_size", 26)
	name_edit.visible = false
	add_child(name_edit)
	_load_levels()
	_load_settings()
	_setup_audio()
	ip_edit.text = last_ip
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
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
	last_ip = str(cfg.get_value("net", "ip", ""))
	var lt := str(cfg.get_value("game", "level_type", "classic"))
	level_type = lt if LEVEL_TYPES.has(lt) else "classic"
	selected_custom = maxi(0, int(cfg.get_value("game", "custom_index", 0)))
	music_on = bool(cfg.get_value("audio", "music", true))
	sfx_on = bool(cfg.get_value("audio", "sfx", true))
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
	cfg.set_value("net", "ip", last_ip)
	cfg.set_value("game", "level_type", level_type)
	cfg.set_value("game", "custom_index", selected_custom)
	cfg.set_value("audio", "music", music_on)
	cfg.set_value("audio", "sfx", sfx_on)
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
	if mp_role != "":
		# Mehrspieler: beide Seiten mit Standardwerten, ohne Verstärkungen
		var base := {"power": 1.0, "speed": 1.0, "growth": 1.0, "shape": "triangle"}
		stats = {1: base.duplicate(), 2: base.duplicate()}
		return
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
	base *= float(circles.size() if level_type == "custom" else circle_count) / REWARD_REF_CIRCLES
	base *= float(LEVEL_TYPES[level_type]["reward"])
	if enemy_levels_up:
		base *= ENEMY_LEVEL_BONUS
	return maxi(1, roundi(base))


func _pay_reward() -> void:
	reward_paid = true
	if ed_testing:
		reward = 0
		return
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
	over_sound = false
	shop_pause = false
	shop_planet = -1
	hill_owner = 0
	hill_time = 0.0
	shop_votes = {1: false, 2: mp_role == ""}
	fx.clear()
	level = LEVELS[difficulty]
	_compute_stats()
	ai_timer = level["interval"]
	state = State.PLAYING
	_place_circles()
	queue_redraw()


func _place_circles() -> void:
	if level_type == "custom":
		var lv := _current_custom()
		if not lv.is_empty():
			for arr in lv["circles"]:
				circles.append(_make_circle(Vector2(float(arr[0]) * map_size.x, float(arr[1]) * map_size.y),
					float(arr[2]), int(arr[3]), int(arr[4])))
			return
	var start_y := TOP_MARGIN + 40.0
	var count := circle_count
	var vmin := 5
	var vmax := 20
	var start_value := START_VALUE
	if level_type == "rush":
		count = RUSH_CIRCLES
		vmin = 3
		vmax = 10
		start_value = RUSH_START
	circles.append(_make_circle(Vector2(map_size.x * 0.5, map_size.y - start_y), start_value, 1))
	circles.append(_make_circle(Vector2(map_size.x * 0.5, start_y), start_value, 2))
	if level_type == "hill":
		circles.append(_make_circle(Vector2(map_size.x * 0.5, map_size.y * 0.5), 20.0, 0, KIND_HILL))

	var attempts := 0
	while circles.size() < count and attempts < 4000:
		attempts += 1
		var value := float(rng.randi_range(vmin, vmax))
		var radius := _radius_for(value)
		var p := Vector2(
			rng.randf_range(EDGE_MARGIN, map_size.x - EDGE_MARGIN),
			rng.randf_range(TOP_MARGIN, map_size.y - EDGE_MARGIN))
		if _fits(p, radius):
			circles.append(_make_circle(p, value, 0))

	if level_type == "resource":
		# Gold- und ausgebrannte Planeten unter den neutralen verteilen
		var neutral := []
		for i in circles.size():
			if circles[i]["owner"] == 0:
				neutral.append(i)
		for k in neutral.size():  # mischen
			var j := rng.randi_range(k, neutral.size() - 1)
			var tmp: int = neutral[k]
			neutral[k] = neutral[j]
			neutral[j] = tmp
		var gold := mini(GOLD_COUNT, neutral.size() / 3)
		var dead := mini(DEAD_COUNT, neutral.size() / 3)
		for k in gold:
			circles[neutral[k]]["kind"] = KIND_GOLD
		for k in dead:
			circles[neutral[gold + k]]["kind"] = KIND_DEAD


func _make_circle(pos: Vector2, value: float, owner: int, kind: int = KIND_NORMAL) -> Dictionary:
	return {"pos": pos, "value": value, "owner": owner, "radius": _radius_for(value),
		"shield": 0, "gun": 0, "boost": 0, "gun_t": 0.0, "kind": kind}


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


# Panel mit den Upgrades des gewählten Planeten: auf der Hälfte, in der der Planet nicht liegt
func _shop_panel_rect() -> Rect2:
	var h := 330.0
	if shop_planet >= 0 and shop_planet < circles.size() and circles[shop_planet]["pos"].y > map_size.y * 0.5:
		return Rect2(20.0, 110.0, map_size.x - 40.0, h)
	return Rect2(20.0, map_size.y - h - 110.0, map_size.x - 40.0, h)


func _up_cost(c: Dictionary, kind: String) -> int:
	var lvl: int = c[kind]
	return 0 if lvl >= UP_MAX else int(UP_COSTS[kind][lvl])


func _shop_rows() -> Array:
	var rows := []
	if shop_planet < 0 or shop_planet >= circles.size():
		return rows
	var c: Dictionary = circles[shop_planet]
	var pr := _shop_panel_rect()
	for i in UP_KINDS.size():
		var kind: String = UP_KINDS[i]
		var lvl: int = c[kind]
		var cost := _up_cost(c, kind)
		var maxed := lvl >= UP_MAX
		rows.append({
			"kind": kind,
			"rect": Rect2(pr.position.x + 12.0, pr.position.y + 62.0 + i * 86.0, pr.size.x - 24.0, 80.0),
			"title": "%s  (Stufe %d/%d)" % [UP_INFO[kind]["label"], lvl, UP_MAX],
			"desc": UP_INFO[kind]["desc"],
			"btn": "Max" if maxed else "%d Armee" % cost,
			"enabled": (not maxed) and c["value"] - float(cost) >= 1.0,
		})
	return rows


# Kreisanzahl (- / +), bei "Eigene" stattdessen Levelwahl (< / >)
func _count_buttons(cx: float, bw: float, y: float) -> Array:
	if level_type == "custom":
		var has := custom_levels.size() > 1
		return [_btn("cl_prev", Rect2(cx - bw * 0.5, y, 110.0, 70.0), "<", 34, [], has),
			_btn("cl_next", Rect2(cx + bw * 0.5 - 110.0, y, 110.0, 70.0), ">", 34, [], has)]
	return [_btn("minus", Rect2(cx - bw * 0.5, y, 110.0, 70.0), "-", 34, [], level_type != "rush"),
		_btn("plus", Rect2(cx + bw * 0.5 - 110.0, y, 110.0, 70.0), "+", 34, [], level_type != "rush")]


# Knöpfe zur Wahl der Levelart
func _level_type_buttons(cx: float, bw: float, y: float) -> Array:
	var out := []
	var w := (bw - 40.0) / 5.0
	for i in LEVEL_TYPE_IDS.size():
		var id: String = LEVEL_TYPE_IDS[i]
		out.append(_btn("lt_" + id, Rect2(cx - bw * 0.5 + i * (w + 10.0), y, w, 70.0),
			LEVEL_TYPES[id]["label"], 20))
	return out


# Liefert die aktuell sichtbaren Knöpfe als [{id, rect, label, size, lines, enabled}]
func _buttons() -> Array:
	var list := []
	var cx := map_size.x * 0.5
	var off := _menu_offset()
	var bw := minf(map_size.x - 80.0, 600.0)
	match state:
		State.MAIN:
			if has_game():
				list.append(_btn("resume", Rect2(cx - bw * 0.5, off + 370.0, bw, 100.0), "Fortfahren", 38,
					["laufende Partie"]))
				list.append(_btn("go_setup", Rect2(cx - bw * 0.5, off + 480.0, bw, 90.0), "Neues Spiel", 32))
				list.append(_btn("go_workshop", Rect2(cx - bw * 0.5, off + 580.0, bw, 80.0), "Werkstatt", 30))
				list.append(_btn("go_multi", Rect2(cx - bw * 0.5, off + 670.0, bw, 80.0), "Mehrspieler (WLAN)", 28))
				list.append(_btn("go_editor", Rect2(cx - bw * 0.5, off + 760.0, bw, 80.0), "Level-Editor", 28))
			else:
				list.append(_btn("go_setup", Rect2(cx - bw * 0.5, off + 380.0, bw, 110.0), "Spielen", 42))
				list.append(_btn("go_workshop", Rect2(cx - bw * 0.5, off + 500.0, bw, 90.0), "Werkstatt", 32))
				list.append(_btn("go_multi", Rect2(cx - bw * 0.5, off + 600.0, bw, 90.0), "Mehrspieler (WLAN)", 30))
				list.append(_btn("go_editor", Rect2(cx - bw * 0.5, off + 700.0, bw, 90.0), "Level-Editor", 30))
			var hw := (bw - 10.0) * 0.5
			list.append(_btn("toggle_music", Rect2(cx - bw * 0.5, off + 910.0, hw, 70.0),
				"Musik: " + ("An" if music_on else "Aus"), 24))
			list.append(_btn("toggle_sfx", Rect2(cx - bw * 0.5 + hw + 10.0, off + 910.0, hw, 70.0),
				"Sound: " + ("An" if sfx_on else "Aus"), 24))
			if dev_mode:
				var w := (bw - 20.0) / 3.0
				list.append(_btn("dev_coins", Rect2(cx - bw * 0.5, off + 1070.0, w, 70.0), "+1000", 22, ["Münzen"]))
				list.append(_btn("dev_unlock", Rect2(cx - bw * 0.5 + w + 10.0, off + 1070.0, w, 70.0), "Alles", 22, ["freischalten"]))
				list.append(_btn("dev_reset", Rect2(cx - bw * 0.5 + 2.0 * (w + 10.0), off + 1070.0, w, 70.0), "Fortschritt", 22, ["zurücksetzen"]))
			if dev_mode:
				list.append(_btn("dev_toggle", Rect2(cx - bw * 0.5, off + 1160.0, bw, 60.0),
					"Developer Mode: An (ausschalten)", 22))
		State.SETUP:
			list.append(_btn("back", Rect2(20.0, off + 16.0, 150.0, 56.0), "Zurück", 26))
			for i in LEVELS.size():
				list.append(_btn("d%d" % i, Rect2(cx - bw * 0.5, off + 198.0 + i * 70.0, bw, 62.0),
					LEVELS[i]["label"], 26, ["Gegner: " + LEVELS[i]["name"]]))
			list.append_array(_level_type_buttons(cx, bw, off + 618.0))
			var row_y := off + 750.0
			list.append_array(_count_buttons(cx, bw, row_y))
			var tw := (bw - 20.0) / 3.0
			for i in TYPE_IDS.size():
				var tid: String = TYPE_IDS[i]
				var t: Dictionary = TYPES[tid]
				var is_open := tid in unlocked
				var lines := ["Kraft ×" + _fmt(t["power"]), "Tempo ×" + _fmt(t["speed"])] if is_open \
					else ["gesperrt", "(Werkstatt)"]
				var b := _btn("type_" + tid, Rect2(cx - bw * 0.5 + i * (tw + 10.0), off + 862.0, tw, 100.0),
					t["label"], 26, lines, is_open)
				b["shape"] = t["shape"]
				list.append(b)
			list.append(_btn("enemy_toggle", Rect2(cx - bw * 0.5, off + 972.0, bw, 66.0),
				"Gegner levelt mit: " + ("An" if enemy_levels_up else "Aus"), 24,
				["Gegner bekommt deine Verstärkungen, Münzen ×1,5"]))
			list.append(_btn("start", Rect2(cx - bw * 0.5, off + 1048.0, bw, 100.0), "Spiel starten", 34))
		State.EDITOR:
			var sel_ok := ed_sel >= 0 and ed_sel < ed_circles.size()
			list.append(_btn("ed_back", Rect2(20.0, 8.0, 150.0, 56.0), "Zurück", 26))
			var tw4 := (map_size.x - 50.0) / 4.0
			var tops := [["ed_test", "Test"], ["ed_save", "Speichern"], ["ed_new", "Neu"], ["ed_load", "Laden ▶"]]
			for k in tops.size():
				list.append(_btn(tops[k][0], Rect2(10.0 + k * (tw4 + 10.0), 72.0, tw4, 56.0), tops[k][1], 22))
			var py := map_size.y - ED_BOTTOM + 8.0
			var w3 := (map_size.x - 40.0) / 3.0
			var o_txt := "Neutral"
			var k_txt := "Normal"
			if sel_ok:
				o_txt = ["Neutral", "Du", "Gegner"][int(ed_circles[ed_sel]["owner"])]
				k_txt = ["Normal", "Gold ×2", "Ausgebrannt", "Hügel"][int(ed_circles[ed_sel]["kind"])]
			list.append(_btn("ed_owner", Rect2(10.0, py, w3, 62.0), "Besitzer: " + o_txt, 20, [], sel_ok))
			list.append(_btn("ed_kind", Rect2(20.0 + w3, py, w3, 62.0), "Art: " + k_txt, 20, [], sel_ok))
			list.append(_btn("ed_del", Rect2(30.0 + 2.0 * w3, py, w3, 62.0), "Planet löschen", 20, [], sel_ok))
			var w5 := (map_size.x - 60.0) / 5.0
			var steps := [["ed_m5", "-5"], ["ed_m1", "-1"], ["", ""], ["ed_p1", "+1"], ["ed_p5", "+5"]]
			for k in steps.size():
				if steps[k][0] != "":
					list.append(_btn(steps[k][0], Rect2(10.0 + k * (w5 + 10.0), py + 68.0, w5, 62.0), steps[k][1], 26, [], sel_ok))
			list.append(_btn("ed_dellevel", Rect2(10.0, py + 136.0, map_size.x - 20.0, 58.0),
				"Gespeichertes Level löschen", 20, [], ed_slot >= 0))
		State.WORKSHOP:
			list.append(_btn("back", Rect2(20.0, off + 16.0, 150.0, 56.0), "Zurück", 26))
			for row in _workshop_rows():
				var r: Rect2 = row["rect"]
				list.append(_btn(row["id"], Rect2(r.position.x + r.size.x - 210.0, r.position.y + 20.0, 190.0, 70.0),
					row["btn"], 22, [], row["enabled"]))
		State.MULTI:
			list.append(_btn("mp_cancel", Rect2(20.0, off + 16.0, 150.0, 56.0), "Zurück", 26))
			if mp_status == "":
				list.append(_btn("mp_host", Rect2(cx - bw * 0.5, off + 190.0, bw, 100.0), "Spiel erstellen", 34))
				var ips: Array = mp_found.keys()
				for i in mini(ips.size(), 4):
					list.append(_btn("join_" + str(ips[i]), Rect2(cx - bw * 0.5, off + 370.0 + i * 80.0, bw, 70.0),
						"Beitreten: " + str(ips[i]), 26))
				list.append(_btn("mp_connect", Rect2(cx - bw * 0.5, off + 825.0, bw, 90.0), "Verbinden", 30))
			elif mp_status == "hosting":
				list.append_array(_count_buttons(cx, bw, off + 520.0))
				list.append_array(_level_type_buttons(cx, bw, off + 650.0))
		State.PLAYING:
			if game_over:
				var gw := 400.0
				if mp_role != "client":
					list.append(_btn("again", Rect2(cx - gw * 0.5, map_size.y * 0.5 + 110.0, gw, 90.0), "Nochmal"))
				list.append(_btn("tomenu", Rect2(cx - gw * 0.5, map_size.y * 0.5 + 220.0, gw, 90.0), "Menü"))
			else:
				if shop_pause:
					var mine: bool = shop_votes[1]
					list.append(_btn("shop_resume", Rect2(map_size.x - 190.0, 16.0, 170.0, 56.0),
						"Warte …" if mine else "Weiter", 26, [], not mine))
					if shop_planet >= 0:
						for row in _shop_rows():
							var r: Rect2 = row["rect"]
							list.append(_btn("ub_" + row["kind"], Rect2(r.position.x + r.size.x - 180.0, r.position.y + 14.0, 164.0, 52.0),
								row["btn"], 22, [], row["enabled"]))
				elif paused:
					var pw := 400.0
					var py := map_size.y * 0.5 - 130.0
					list.append(_btn("resume", Rect2(cx - pw * 0.5, py, pw, 100.0), "Fortfahren", 38))
					list.append(_btn("menu", Rect2(cx - pw * 0.5, py + 120.0, pw, 90.0), "Menü"))
					if dev_mode:
						list.append(_btn("dev", Rect2(cx - pw * 0.5, py + 230.0, pw, 80.0), "Developer", 28))
						if dev_open:
							list.append_array(_dev_buttons())
				else:
					list.append(_btn("pause", Rect2(map_size.x - 170.0, 16.0, 150.0, 56.0), "Verlassen" if mp_role != "" else "Pause", 26))
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
	if id.begins_with("lt_"):
		return id.substr(3) == level_type
	if id.begins_with("type_"):
		return id.substr(5) == selected_type
	match id:
		"dev": return dev_open
		"dev_ai": return dev_ai_frozen
		"dev_info": return dev_info
		"dev_toggle": return dev_mode
		"enemy_toggle": return enemy_levels_up
		"toggle_music": return music_on
		"toggle_sfx": return sfx_on
		"dev_tool_owner": return dev_tool == "owner"
		"dev_tool_plus": return dev_tool == "plus"
		"dev_tool_minus": return dev_tool == "minus"
		"dev_tool_off": return dev_tool == ""
	return false


func _activate(id: String) -> void:
	_play_sfx("click")
	match id:
		"shop_resume":
			_shop_vote_self()
		"toggle_music":
			music_on = not music_on
			_save_settings()
		"toggle_sfx":
			sfx_on = not sfx_on
			_save_settings()
		"go_setup":
			state = State.SETUP
		"go_workshop":
			state = State.WORKSHOP
		"go_editor":
			state = State.EDITOR
			if ed_circles.is_empty() and ed_slot < 0:
				_ed_new()
		"ed_back":
			state = State.MAIN
			_update_size()
		"ed_test":
			_ed_test()
		"ed_save":
			_ed_save()
		"ed_new":
			_ed_new()
		"ed_load":
			_ed_load_next()
		"ed_owner":
			if ed_sel >= 0:
				ed_circles[ed_sel]["owner"] = (int(ed_circles[ed_sel]["owner"]) + 1) % 3
		"ed_kind":
			if ed_sel >= 0:
				var nk := (int(ed_circles[ed_sel]["kind"]) + 1) % 4
				if nk == KIND_HILL:
					for c in ed_circles:
						if int(c["kind"]) == KIND_HILL:
							c["kind"] = KIND_NORMAL
				ed_circles[ed_sel]["kind"] = nk
		"ed_del":
			if ed_sel >= 0:
				ed_circles.remove_at(ed_sel)
				ed_sel = -1
		"ed_m5":
			_ed_change_value(-5.0)
		"ed_m1":
			_ed_change_value(-1.0)
		"ed_p1":
			_ed_change_value(1.0)
		"ed_p5":
			_ed_change_value(5.0)
		"ed_dellevel":
			_ed_delete_level()
		"cl_prev":
			if custom_levels.size() > 0:
				selected_custom = (selected_custom - 1 + custom_levels.size()) % custom_levels.size()
				_save_settings()
		"cl_next":
			if custom_levels.size() > 0:
				selected_custom = (selected_custom + 1) % custom_levels.size()
				_save_settings()
		"go_multi":
			state = State.MULTI
			_mp_close()
			_mp_listen()
		"mp_host":
			_mp_host()
		"mp_connect":
			_mp_join(ip_edit.text.strip_edges())
		"mp_cancel":
			_mp_close()
			state = State.MAIN
		"back":
			state = State.MAIN
		"start":
			if level_type == "custom" and custom_levels.is_empty():
				toast = "Erst im Level-Editor ein Level bauen"
				toast_time = 3.0
				return
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
			if mp_role == "host":
				if multiplayer.get_peers().is_empty():
					mp_status = "hosting"
					state = State.MULTI
				else:
					_mp_start_round()
			else:
				start_game()
		"pause":
			if mp_role != "":
				_mp_leave()
				return
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
			if ed_testing:
				_ed_end_test()
				return
			if mp_role != "":
				_mp_leave()
				return
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
			if id.begins_with("lt_"):
				level_type = id.substr(3)
				_save_settings()
			elif id.begins_with("ub_"):
				_shop_buy_request(id.substr(3))
			elif id.begins_with("join_"):
				_mp_join(id.substr(5))
			elif id.begins_with("buy_"):
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
	elif event is InputEventMouseMotion:
		if state == State.EDITOR:
			_ed_motion(event.position)
		elif drag_active:
			drag_pos = event.position
			queue_redraw()


# Titel im Hauptmenü (Tippfläche für den Developer-Geheimcode)
func _title_rect() -> Rect2:
	var off := _menu_offset()
	return Rect2(map_size.x * 0.5 - 200.0, off + 70.0, 400.0, 130.0)


# 5 Tipper hintereinander (je höchstens 1,5 s Pause) schalten den Developer Mode um
func _title_tap() -> void:
	var now := Time.get_ticks_msec()
	if now - title_tap_time > 1500:
		title_taps = 0
	title_tap_time = now
	title_taps += 1
	if title_taps >= 5:
		title_taps = 0
		dev_mode = not dev_mode
		_reset_dev()
		_save_settings()
		toast = "Developer Mode " + ("aktiviert" if dev_mode else "deaktiviert")
		toast_time = 2.0
		Input.vibrate_handheld(80)


func _on_press(pos: Vector2) -> void:
	press_button = _button_at(pos)
	if press_button != "":
		title_taps = 0
		queue_redraw()
		return
	if state == State.MULTI:
		if ip_edit != null:
			ip_edit.release_focus()
		return
	if state == State.EDITOR:
		if name_edit != null:
			name_edit.release_focus()
		_ed_press(pos)
		return
	if state == State.MAIN:
		if _title_rect().has_point(pos):
			_title_tap()
		else:
			title_taps = 0
		queue_redraw()
		return
	if state != State.PLAYING or game_over:
		return
	if shop_pause:
		if shop_planet >= 0 and _shop_panel_rect().has_point(pos):
			return
		var hit := _circle_at(pos)
		if hit >= 0 and circles[hit]["owner"] == 1:
			_shop_open(hit)
		else:
			shop_planet = -1
		queue_redraw()
		return
	if paused and dev_mode and dev_open and _panel_rect().has_point(pos):
		return  # Berührungen auf dem Panel gehen nicht ins Spielfeld durch
	if dev_mode and dev_tool != "" and mp_role == "":
		_apply_dev_tool(_circle_at(pos))
		return
	if paused:
		return
	drag_active = true
	drag_pos = pos
	press_pos = pos
	hold_target = -1
	hold_time = 0.0
	press_index = _circle_at(pos)
	press_time = 0.0
	press_moved = false
	mass_active = false
	chain.clear()
	chain_cand = -1
	chain_time = 0.0
	if press_index >= 0 and circles[press_index]["owner"] == 1:
		selected = press_index
		chain.append(press_index)
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
	if state == State.EDITOR:
		ed_drag = -1
		return
	if state != State.PLAYING or game_over:
		mass_active = false
		return

	if mass_active:
		_mass_release(pos)
		return

	var target := _circle_at(pos, RELEASE_SNAP)
	if press_index >= 0 and circles[press_index]["owner"] == 1:
		if target >= 0 and target != press_index:
			# Auf dem Ziel gehalten? Dann zählt der angezeigte Prozentwert, sonst 50 %.
			var percent := 50
			if target == hold_target:
				percent = _hold_percent()
			# Alle Planeten der Kette schicken ihren Anteil gemeinsam zum Ziel
			for src in _chain_sources(target):
				_player_send(src, target, percent)
		elif target == press_index and chain.size() <= 1 and not shop_pause:
			_shop_open(press_index)  # Antippen eines eigenen Planeten: Upgrades
	else:
		selected = -1
	press_index = -1
	chain.clear()
	chain_cand = -1
	hold_target = -1
	hold_time = 0.0
	queue_redraw()


# ---- Massenangriff ----

# Position des roten Abbrechen-X: die Ecke, die am weitesten vom Ziel entfernt ist
func _mass_cancel_pos() -> Vector2:
	if mass_target < 0 or mass_target >= circles.size():
		return Vector2(90.0, 200.0)
	var tp: Vector2 = circles[mass_target]["pos"]
	var corners := [Vector2(90.0, 190.0), Vector2(map_size.x - 90.0, 190.0),
		Vector2(90.0, map_size.y - 110.0), Vector2(map_size.x - 90.0, map_size.y - 110.0)]
	var best: Vector2 = corners[0]
	for c in corners:
		if c.distance_to(tp) > best.distance_to(tp):
			best = c
	return best


func _mass_percent() -> int:
	return 50 + roundi(clampf(mass_time / HOLD_RAMP, 0.0, 1.0) * 10.0) * 5


func _mass_sources(target: int) -> Array:
	var out := []
	for i in circles.size():
		if i != target and circles[i]["owner"] == 1 and floorf(circles[i]["value"]) >= 2.0:
			out.append(i)
	return out


func _mass_total(target: int, percent: int) -> float:
	var t := 0.0
	for i in _mass_sources(target):
		t += _amount_for_percent(i, percent)
	return t


# Läuft jeden Frame: erkennt langes ruhiges Halten auf einem Planeten und startet den Zähler
func _mass_update(delta: float) -> void:
	if mass_active:
		mass_time += delta
		return
	if not drag_active or press_index < 0 or chain.size() > 1:
		return
	if drag_pos.distance_to(press_pos) > TAP_TOLERANCE * 1.5:
		press_moved = true
	if press_moved:
		return
	press_time += delta
	if press_time >= MASS_DELAY:
		mass_active = true
		mass_target = press_index
		mass_time = 0.0
		selected = -1
		chain.clear()
		Input.vibrate_handheld(25)


# Loslassen: auf dem Ziel = Angriff mit dem Zählerstand, sonst (z. B. auf dem roten X) abbrechen
func _mass_release(pos: Vector2) -> void:
	var target := mass_target
	var percent := _mass_percent()
	var on_target := target >= 0 and _circle_at(pos, RELEASE_SNAP) == target
	var cancelled := pos.distance_to(_mass_cancel_pos()) <= MASS_CANCEL_RADIUS or not on_target
	mass_active = false
	mass_target = -1
	mass_time = 0.0
	press_index = -1
	chain.clear()
	hold_target = -1
	hold_time = 0.0
	selected = -1
	if not cancelled:
		for i in _mass_sources(target):
			_player_send(i, target, percent)
	queue_redraw()


# Sammelangriff: Wer beim Wischen kurz (CHAIN_DWELL) auf einem weiteren eigenen Planeten verweilt,
# nimmt ihn in die Kette auf. Zügiges Darüberwischen zählt nicht.
func _chain_update(delta: float) -> void:
	if not drag_active or chain.is_empty():
		chain_cand = -1
		chain_time = 0.0
		return
	var idx := _circle_at(drag_pos)
	if idx < 0 or circles[idx]["owner"] != 1 or (idx in chain):
		chain_cand = -1
		chain_time = 0.0
		return
	if idx != chain_cand:
		chain_cand = idx
		chain_time = 0.0
		return
	chain_time += delta
	if chain_time >= CHAIN_DWELL:
		chain.append(idx)
		chain_cand = -1
		chain_time = 0.0
		Input.vibrate_handheld(20)


# Quellen eines Wischers: alle Planeten der Kette, außer dem Ziel (wenn es selbst in der Kette liegt)
func _chain_sources(target: int) -> Array:
	var out := chain.duplicate()
	out.erase(target)
	return out


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
	_mass_update(delta)
	if mass_active:
		return
	_chain_update(delta)
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
		"boost": BOOST_MULT[int(circles[src]["boost"])],
		"target": dst,
		"src": src,
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
	var dfn: float = dst["value"] * _power(dst["owner"]) * _shield(dst)
	_spawn_fx(dst, owner, atk > dfn)
	_battle_sound(owner, dst["owner"], atk > dfn)
	if atk > dfn and (owner == 1 or dst["owner"] == 1):
		Input.vibrate_handheld(60)  # Kreis erobert (oder verloren)
	if mp_role == "host" and mp_peer != null and mp_status == "playing":
		rpc_fx.rpc(int(army["target"]), owner, atk > dfn)
	if atk > dfn:
		dst["owner"] = owner
		dst["value"] = (atk - dfn) / _power(owner)
		dst["shield"] = 0  # Upgrades gehen bei der Eroberung verloren
		dst["gun"] = 0
		dst["boost"] = 0
		dst["gun_t"] = 0.0
	else:
		dst["value"] = (dfn - atk) / (_power(dst["owner"]) * _shield(dst))


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


func _spawn_shot(from: Vector2, to: Vector2, color: Color) -> void:
	if DisplayServer.get_name() == "headless" or fx.size() > 60:
		return
	fx.append({"kind": "shot", "from": from, "to": to, "color": color, "age": 0.0, "dur": 0.18})


func _update_fx(delta: float) -> void:
	for e in fx.duplicate():
		e["age"] += delta
		if e["age"] >= e["dur"]:
			fx.erase(e)


func _draw_fx() -> void:
	for e in fx:
		var t: float = e["age"] / e["dur"]
		var a := 1.0 - t
		if e.get("kind", "") == "shot":
			draw_line(e["from"], e["to"], Color(1.0, 0.7, 0.2, a), 4.0)
			draw_line(e["from"], e["to"], Color(1, 1, 0.9, a), 1.5)
			draw_circle(e["to"], 7.0 * a + 2.0, Color(1.0, 0.8, 0.3, a))
			continue
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
	if toast_time > 0.0:
		toast_time -= delta
	if state == State.PLAYING and game_over and not reward_paid:
		_pay_reward()
	_mp_process(delta)
	_update_music()
	if mass_active and (game_over or paused or shop_pause or state != State.PLAYING):
		mass_active = false
	if game_over and shop_pause:
		shop_pause = false
		shop_planet = -1
	if state == State.PLAYING and game_over and not over_sound:
		over_sound = true
		_play_sfx("win" if winner == 1 else "lose")
	var running := state == State.PLAYING and not game_over and not paused and not shop_pause and mp_role != "client"
	if running:
		_update_hold(delta)
		_tick(delta * SPEEDS[dev_speed_index])
	if state == State.PLAYING and not paused:
		_update_fx(delta)
	queue_redraw()


# Wachstum eines Planeten pro Sekunde (Besitzer, Planetenart und Levelart eingerechnet)
func _rate(c: Dictionary) -> float:
	var o: int = c["owner"]
	if o == 0:
		return 0.0
	var f := RUSH_GROWTH if level_type == "rush" else 1.0
	return BASE_GROWTH * _growth(o) * float(KIND_MULT[int(c.get("kind", 0))]) * f


# König des Hügels: Wer den Hügel durchgehend hält, gewinnt nach HILL_GOAL Sekunden
func _hill_tick(delta: float) -> void:
	if level_type != "hill" and level_type != "custom":
		return
	var idx := -1
	for i in circles.size():
		if int(circles[i].get("kind", 0)) == KIND_HILL:
			idx = i
			break
	if idx < 0:
		return
	var o: int = circles[idx]["owner"]
	if o != hill_owner:
		hill_owner = o
		hill_time = 0.0
	if o != 0:
		hill_time += delta
		if hill_time >= HILL_GOAL and mp_role != "client" and not game_over:
			game_over = true
			winner = o
			drag_active = false
			selected = -1


# Ein Simulationsschritt (auch für Testläufe ohne Anzeige nutzbar)
func _tick(delta: float) -> void:
	for c in circles:
		c["value"] += _rate(c) * delta
	_hill_tick(delta)

	for army in armies.duplicate():
		var dist: float = maxf(army["from"].distance_to(army["to"]), 1.0)
		army["progress"] += ARMY_SPEED * _speed(army["owner"]) * float(army.get("boost", 1.0)) * delta / dist
		if army["progress"] >= 1.0:
			armies.erase(army)
			_resolve(army)

	_guns(delta)

	if mp_role == "" and not dev_ai_frozen:
		ai_timer -= delta
		if ai_timer <= 0.0:
			ai_timer = float(level["interval"]) * (RUSH_AI_SLOWDOWN if level_type == "rush" else 1.0)
			_ai_think()

	_check_winner()


# ---------- Planeten-Upgrades ----------

func _shield(c: Dictionary) -> float:
	return 1.0 if c["owner"] == 0 else SHIELD_MULT[int(c["shield"])]


# Kauf: kostet Armee auf dem Planeten, mindestens 1 bleibt übrig
func _shop_buy(owner: int, idx: int, kind: String) -> bool:
	if idx < 0 or idx >= circles.size() or not (kind in UP_KINDS):
		return false
	var c: Dictionary = circles[idx]
	if c["owner"] != owner or int(c[kind]) >= UP_MAX:
		return false
	var cost := _up_cost(c, kind)
	if c["value"] - float(cost) < 1.0:
		return false
	c["value"] -= float(cost)
	c[kind] = int(c[kind]) + 1
	return true


func _shop_buy_request(kind: String) -> void:
	if shop_planet < 0:
		return
	if mp_role == "client":
		rpc_buy.rpc_id(1, shop_planet, kind)
		_play_sfx("send")
	elif _shop_buy(1, shop_planet, kind):
		_play_sfx("conquer")


func _shop_sync() -> void:
	if mp_role == "host" and mp_peer != null and mp_status == "playing":
		rpc_shop_state.rpc(shop_pause, shop_votes[1], shop_votes[2])


# Eigenen Planeten für Upgrades öffnen; das Spiel pausiert für alle
func _shop_open(idx: int) -> void:
	shop_planet = idx
	selected = -1
	drag_active = false
	shop_votes[1] = false
	if mp_role == "client":
		shop_pause = true
		rpc_shop_open.rpc_id(1)
	else:
		shop_pause = true
		shop_votes[2] = mp_role == "" or shop_votes[2]
		_shop_sync()


# "Weiter" gedrückt: erst wenn alle bereit sind, läuft das Spiel weiter
func _shop_vote_self() -> void:
	shop_votes[1] = true
	shop_planet = -1
	if mp_role == "client":
		rpc_shop_vote.rpc_id(1)
	else:
		_shop_check_resume()
		_shop_sync()


func _shop_check_resume() -> void:
	if shop_votes[1] and shop_votes[2]:
		shop_pause = false
		shop_planet = -1
		shop_votes = {1: false, 2: mp_role == ""}


# Abwehrgeschütze: schießen alle 0,9 s auf die nächste feindliche Armee in Reichweite
func _guns(delta: float) -> void:
	for ci in circles.size():
		var c: Dictionary = circles[ci]
		var lvl := int(c["gun"])
		if lvl <= 0 or c["owner"] == 0:
			continue
		c["gun_t"] = maxf(float(c["gun_t"]) - delta, 0.0)
		if c["gun_t"] > 0.0:
			continue
		var reach: float = c["radius"] + GUN_RANGE[lvl]
		var best: Dictionary = {}
		var best_d := INF
		var best_pos := Vector2.ZERO
		for a in armies:
			if a["owner"] == c["owner"]:
				continue
			var ap: Vector2 = a["from"].lerp(a["to"], a["progress"])
			var d := ap.distance_to(c["pos"])
			if d <= reach and d < best_d:
				best_d = d
				best = a
				best_pos = ap
		if best.is_empty():
			continue
		c["gun_t"] = GUN_INTERVAL
		best["amount"] -= GUN_DAMAGE[lvl]
		_spawn_shot(c["pos"], best_pos, COLORS[c["owner"]])
		if mp_role == "host" and mp_peer != null and mp_status == "playing":
			rpc_shot.rpc(ci, best_pos.x / map_size.x, best_pos.y / map_size.y)
		if best["amount"] <= 0.0:
			armies.erase(best)


# KI kauft (je nach Stufe) auf ihren Planeten Upgrades, ein Kauf pro Entscheidung
func _ai_buy(own: Array) -> void:
	var chance: float = level["buy"]
	if chance <= 0.0:
		return
	for i in own:
		if rng.randf() > chance:
			continue
		var c: Dictionary = circles[i]
		for kind in UP_KINDS:
			if int(c[kind]) < UP_MAX and c["value"] - float(_up_cost(c, kind)) >= AI_KEEP:
				if _shop_buy(2, i, kind):
					return


# ---------- Level-Editor ----------

func _load_levels() -> void:
	custom_levels.clear()
	if not FileAccess.file_exists(LEVELS_PATH):
		return
	var f := FileAccess.open(LEVELS_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if data is Array:
		for lv in data:
			if lv is Dictionary and lv.has("name") and lv.has("circles") and lv["circles"] is Array:
				custom_levels.append(lv)


func _save_levels() -> void:
	var f := FileAccess.open(LEVELS_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(custom_levels))


func _current_custom() -> Dictionary:
	if ed_testing:
		return ed_test_level
	if selected_custom >= 0 and selected_custom < custom_levels.size():
		return custom_levels[selected_custom]
	return {}


func _custom_label() -> String:
	if custom_levels.is_empty():
		return "Noch keins (Editor)"
	selected_custom = clampi(selected_custom, 0, custom_levels.size() - 1)
	return "%s (%d/%d)" % [custom_levels[selected_custom]["name"], selected_custom + 1, custom_levels.size()]


func _ed_toast(msg: String) -> void:
	toast = msg
	toast_time = 3.0


func _ed_new() -> void:
	ed_circles.clear()
	ed_sel = -1
	ed_slot = -1
	if name_edit != null:
		name_edit.text = "Level %d" % (custom_levels.size() + 1)


func _ed_hit_radius(c: Dictionary) -> float:
	return maxf(float(c["radius"]) + 8.0, 40.0)


func _ed_planet_at(pos: Vector2) -> int:
	var best := -1
	var best_d := INF
	for i in ed_circles.size():
		var d: float = pos.distance_to(ed_circles[i]["pos"])
		if d <= _ed_hit_radius(ed_circles[i]) and d < best_d:
			best = i
			best_d = d
	return best


# Passt ein Planet mit diesem Radius an diese Stelle (Rand, Leisten, Abstand zu den anderen)?
func _ed_fits(pos: Vector2, radius: float, ignore: int) -> bool:
	if pos.x < radius + 8.0 or pos.x > map_size.x - radius - 8.0:
		return false
	if pos.y < ED_TOP + radius or pos.y > map_size.y - ED_BOTTOM - radius:
		return false
	for i in ed_circles.size():
		if i == ignore:
			continue
		if pos.distance_to(ed_circles[i]["pos"]) < radius + float(ed_circles[i]["radius"]) + ED_GAP:
			return false
	return true


func _ed_press(pos: Vector2) -> void:
	var hit := _ed_planet_at(pos)
	if hit >= 0:
		ed_sel = hit
		ed_drag = hit
		return
	ed_drag = -1
	var in_area := pos.y >= ED_TOP and pos.y <= map_size.y - ED_BOTTOM
	if not in_area:
		return
	if ed_circles.size() >= ED_MAX_PLANETS:
		_ed_toast("Höchstens %d Planeten" % ED_MAX_PLANETS)
		return
	var value := 10.0
	var radius := _radius_for(value)
	if not _ed_fits(pos, radius, -1):
		_ed_toast("Kein Platz für einen Planeten")
		return
	ed_circles.append({"pos": pos, "value": value, "owner": 0, "kind": KIND_NORMAL, "radius": radius})
	ed_sel = ed_circles.size() - 1
	queue_redraw()


func _ed_motion(pos: Vector2) -> void:
	if ed_drag < 0 or ed_drag >= ed_circles.size():
		return
	var r: float = ed_circles[ed_drag]["radius"]
	var p := Vector2(clampf(pos.x, r + 8.0, map_size.x - r - 8.0),
		clampf(pos.y, ED_TOP + r, map_size.y - ED_BOTTOM - r))
	if _ed_fits(p, r, ed_drag):
		ed_circles[ed_drag]["pos"] = p
	queue_redraw()


func _ed_change_value(delta: float) -> void:
	if ed_sel < 0 or ed_sel >= ed_circles.size():
		return
	var c: Dictionary = ed_circles[ed_sel]
	var v := clampf(float(c["value"]) + delta, 1.0, 40.0)
	var r := _radius_for(v)
	if delta > 0.0 and not _ed_fits(c["pos"], r, ed_sel):
		_ed_toast("Kein Platz zum Vergrößern")
		return
	c["value"] = v
	c["radius"] = r


# Editor-Karte -> speicherbares Level (Koordinaten 0..1)
func _ed_to_level() -> Dictionary:
	var arr := []
	for c in ed_circles:
		arr.append([snappedf(c["pos"].x / map_size.x, 0.0001), snappedf(c["pos"].y / map_size.y, 0.0001),
			float(c["value"]), int(c["owner"]), int(c["kind"])])
	var lname := name_edit.text.strip_edges() if name_edit != null else ""
	if lname == "":
		lname = "Level %d" % (custom_levels.size() + 1)
	return {"name": lname, "circles": arr}


func _ed_load_level(lv: Dictionary) -> void:
	ed_circles.clear()
	for a in lv["circles"]:
		var v := float(a[2])
		ed_circles.append({"pos": Vector2(float(a[0]) * map_size.x, float(a[1]) * map_size.y),
			"value": v, "owner": int(a[3]), "kind": int(a[4]), "radius": _radius_for(v)})
	ed_sel = -1
	if name_edit != null:
		name_edit.text = str(lv["name"])


# Gültig, wenn beide Seiten mindestens einen Planeten haben
func _ed_valid() -> bool:
	var mine := 0
	var theirs := 0
	for c in ed_circles:
		if c["owner"] == 1:
			mine += 1
		elif c["owner"] == 2:
			theirs += 1
	if mine == 0 or theirs == 0:
		_ed_toast("Du und der Gegner brauchen je mindestens einen Planeten")
		return false
	return true


func _ed_save() -> void:
	if not _ed_valid():
		return
	var lv := _ed_to_level()
	if ed_slot >= 0 and ed_slot < custom_levels.size():
		custom_levels[ed_slot] = lv
	else:
		if custom_levels.size() >= ED_MAX_LEVELS:
			_ed_toast("Höchstens %d Level – erst eins löschen" % ED_MAX_LEVELS)
			return
		custom_levels.append(lv)
		ed_slot = custom_levels.size() - 1
	selected_custom = ed_slot
	_save_levels()
	_save_settings()
	_ed_toast("Gespeichert: " + str(lv["name"]))


func _ed_load_next() -> void:
	if custom_levels.is_empty():
		_ed_toast("Noch keine gespeicherten Level")
		return
	ed_slot = (ed_slot + 1) % custom_levels.size()
	_ed_load_level(custom_levels[ed_slot])
	_ed_toast("Geladen: " + str(custom_levels[ed_slot]["name"]))


func _ed_delete_level() -> void:
	if ed_slot < 0 or ed_slot >= custom_levels.size():
		return
	var lname := str(custom_levels[ed_slot]["name"])
	custom_levels.remove_at(ed_slot)
	selected_custom = clampi(selected_custom, 0, maxi(custom_levels.size() - 1, 0))
	_save_levels()
	_save_settings()
	_ed_new()
	_ed_toast("Gelöscht: " + lname)


# Probespiel direkt aus dem Editor (ohne Münzen); Menü führt zurück in den Editor
func _ed_test() -> void:
	if not _ed_valid():
		return
	ed_test_level = _ed_to_level()
	ed_testing = true
	ed_prev_type = level_type
	level_type = "custom"
	start_game()


func _ed_end_test() -> void:
	ed_testing = false
	level_type = ed_prev_type
	circles.clear()
	armies.clear()
	game_over = false
	drag_active = false
	selected = -1
	paused = false
	fx.clear()
	state = State.EDITOR


func _draw_editor(font: Font) -> void:
	# Spielfläche markieren
	draw_rect(Rect2(6.0, ED_TOP, map_size.x - 12.0, map_size.y - ED_BOTTOM - ED_TOP), Color(1, 1, 1, 0.03), true)
	draw_rect(Rect2(6.0, ED_TOP, map_size.x - 12.0, map_size.y - ED_BOTTOM - ED_TOP), Color(1, 1, 1, 0.15), false, 2.0)
	if ed_circles.is_empty():
		_text(font, map_size.y * 0.45, "Tippe auf die Karte,", 28, Color(1, 1, 1, 0.6))
		_text(font, map_size.y * 0.45 + 38.0, "um einen Planeten zu setzen", 28, Color(1, 1, 1, 0.6))
	for i in ed_circles.size():
		var c: Dictionary = ed_circles[i]
		draw_circle(c["pos"], c["radius"], COLORS[c["owner"]])
		_draw_kind(font, c)
		if i == ed_sel:
			draw_arc(c["pos"], c["radius"] + 8.0, 0.0, TAU, 48, Color.WHITE, 3.0)
		draw_string(font, c["pos"] + Vector2(-c["radius"], 10.0), str(int(c["value"])),
			HORIZONTAL_ALIGNMENT_CENTER, c["radius"] * 2.0, 28, Color.WHITE)
	# Werkzeugfeld
	draw_rect(Rect2(0.0, map_size.y - ED_BOTTOM, map_size.x, ED_BOTTOM), Color(0, 0, 0, 0.55), true)
	if ed_sel >= 0 and ed_sel < ed_circles.size():
		var w5 := (map_size.x - 60.0) / 5.0
		var py := map_size.y - ED_BOTTOM + 8.0 + 68.0
		draw_string(font, Vector2(10.0 + 2.0 * (w5 + 10.0), py + 40.0), "Armee %d" % int(ed_circles[ed_sel]["value"]),
			HORIZONTAL_ALIGNMENT_CENTER, w5, 22, GOLD)
	if toast_time > 0.0:
		_text(font, ED_TOP - 8.0, toast, 20, GOLD)
	_draw_buttons(font)


# ---------- Audio ----------

func _setup_audio() -> void:
	audio_enabled = DisplayServer.get_name() != "headless"
	if not audio_enabled:
		return
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = MUSIC_VOLUME_DB
	add_child(music_player)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)


func _audio(file: String) -> AudioStream:
	if audio_cache.has(file):
		return audio_cache[file]
	var path := "res://audio/" + file
	var st: AudioStream = null
	if ResourceLoader.exists(path):
		st = load(path)
		if st is AudioStreamOggVorbis:
			st.loop = true
	audio_cache[file] = st
	return st


func _play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	if not audio_enabled or not sfx_on:
		return
	var now := Time.get_ticks_msec()
	if now - int(sfx_last.get(sfx_name, -1000)) < 70:
		return  # nicht dasselbe Geräusch mehrfach übereinander
	sfx_last[sfx_name] = now
	var st := _audio("sfx_%s.wav" % sfx_name)
	if st == null:
		return
	for p in sfx_players:
		if not p.playing:
			p.stream = st
			p.volume_db = volume_db
			p.play()
			return


func _battle_sound(attacker: int, defender: int, conquered: bool) -> void:
	_play_sfx("hit", 0.0 if (attacker == 1 or defender == 1) else -8.0)
	if conquered:
		if attacker == 1:
			_play_sfx("conquer")
		elif defender == 1:
			_play_sfx("lost")


# Musik je nach Bildschirm: Menü-Stück in den Menüs, Spiel-Stück in der Partie, im Pausenmenü leiser
func _update_music() -> void:
	if not audio_enabled or music_player == null:
		return
	var want := ""
	if music_on:
		if state == State.PLAYING:
			want = "" if game_over else "game"
		else:
			want = "menu"
	if want != music_track:
		music_track = want
		if want == "":
			music_player.stop()
		else:
			var st := _audio("music_%s.ogg" % want)
			if st != null:
				music_player.stream = st
				music_player.play()
	music_player.volume_db = MUSIC_VOLUME_DB - (9.0 if (state == State.PLAYING and paused) else 0.0)


# ---------- Mehrspieler (WLAN) ----------

func _swap(o: int) -> int:
	return 3 - o if o > 0 else 0


func _local_ips() -> Array:
	var out := []
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254."):
			continue
		out.append(a)
	return out


func _mp_listen() -> void:
	if mp_udp_recv != null:
		return
	mp_found.clear()
	mp_udp_recv = PacketPeerUDP.new()
	if mp_udp_recv.bind(DISCOVERY_PORT) != OK:
		mp_udp_recv = null


# Alles beenden: Verbindung, Broadcast, Suche
func _mp_close() -> void:
	if mp_peer != null:
		mp_peer.close()
	mp_peer = null
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	if mp_udp_send != null:
		mp_udp_send.close()
		mp_udp_send = null
	if mp_udp_recv != null:
		mp_udp_recv.close()
		mp_udp_recv = null
	mp_role = ""
	mp_status = ""
	mp_end_sent = false


# Spiel (laufend oder beendet) verlassen und zurück ins Hauptmenü
func _mp_leave() -> void:
	_mp_close()
	circles.clear()
	armies.clear()
	game_over = false
	drag_active = false
	selected = -1
	state = State.MAIN
	_update_size()


func _mp_host() -> void:
	_mp_close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_server(NET_PORT, 1) != OK:
		toast = "Spiel konnte nicht erstellt werden"
		toast_time = 3.0
		return
	mp_peer = peer
	multiplayer.multiplayer_peer = peer
	mp_role = "host"
	mp_status = "hosting"
	mp_udp_send = PacketPeerUDP.new()
	mp_udp_send.set_broadcast_enabled(true)
	mp_udp_send.set_dest_address("255.255.255.255", DISCOVERY_PORT)
	mp_bcast_timer = 0.0


func _mp_join(ip: String) -> void:
	if ip == "":
		toast = "Bitte IP-Adresse eingeben"
		toast_time = 3.0
		return
	_mp_close()
	var peer := ENetMultiplayerPeer.new()
	if peer.create_client(ip, NET_PORT) != OK:
		toast = "Verbindung nicht möglich"
		toast_time = 3.0
		return
	last_ip = ip
	_save_settings()
	mp_peer = peer
	multiplayer.multiplayer_peer = peer
	mp_role = "client"
	mp_status = "connecting"


func _on_peer_connected(_id: int) -> void:
	if mp_role == "host" and mp_status == "hosting":
		_mp_start_round()


func _on_peer_disconnected(_id: int) -> void:
	if mp_role != "host":
		return
	if state == State.PLAYING and not game_over:
		game_over = true
		winner = 1
		mp_end_sent = true
		drag_active = false
		selected = -1
		toast = "Gegner hat das Spiel verlassen"
		toast_time = 6.0
	elif state != State.PLAYING:
		mp_status = "hosting"


func _on_connected() -> void:
	mp_status = "waiting"


func _on_connection_failed() -> void:
	_mp_close()
	toast = "Keine Verbindung zum Host"
	toast_time = 4.0


func _on_server_disconnected() -> void:
	_mp_leave()
	toast = "Verbindung zum Host verloren"
	toast_time = 4.0


# Host: neue Runde starten und dem Client die Karte schicken
func _mp_start_round() -> void:
	if level_type == "custom" and custom_levels.is_empty():
		level_type = "classic"
	dev_speed_index = 1
	dev_ai_frozen = false
	dev_tool = ""
	dev_open = false
	start_game()
	reward_paid = true
	mp_status = "playing"
	mp_end_sent = false
	mp_snap_timer = 0.0
	rpc_begin.rpc(_pack_circles())


func _pack_circles() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for c in circles:
		var o: int = c["owner"]
		out.append_array(PackedFloat32Array([
			c["pos"].x / map_size.x, c["pos"].y / map_size.y, c["value"], float(o),
			_rate(c), c["radius"],
			float(c["shield"]), float(c["gun"]), float(c["boost"]), float(c["kind"])]))
	return out


func _pack_armies() -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for a in armies:
		var dist: float = maxf(a["from"].distance_to(a["to"]), 1.0)
		out.append_array(PackedFloat32Array([
			float(a["src"]), float(a["target"]), float(a["owner"]), a["amount"], a["progress"],
			ARMY_SPEED * _speed(a["owner"]) * float(a.get("boost", 1.0)) / dist]))
	return out


# Client: Kreise aus den Host-Daten übernehmen (gespiegelt, Seiten getauscht)
func _apply_circles(c: PackedFloat32Array, full: bool) -> void:
	var n := c.size() / 10
	if full:
		circles.clear()
		for i in n:
			circles.append({"pos": Vector2.ZERO, "value": 0.0, "owner": 0, "radius": 0.0, "rate": 0.0,
				"shield": 0, "gun": 0, "boost": 0, "gun_t": 0.0, "kind": 0})
	if circles.size() != n:
		return
	for i in n:
		var d: Dictionary = circles[i]
		d["pos"] = Vector2(c[i * 10] * map_size.x, (1.0 - c[i * 10 + 1]) * map_size.y)
		d["value"] = c[i * 10 + 2]
		d["owner"] = _swap(int(c[i * 10 + 3]))
		d["rate"] = c[i * 10 + 4]
		d["radius"] = c[i * 10 + 5]
		d["shield"] = int(c[i * 10 + 6])
		d["gun"] = int(c[i * 10 + 7])
		d["boost"] = int(c[i * 10 + 8])
		d["kind"] = int(c[i * 10 + 9])


func _apply_armies(a: PackedFloat32Array) -> void:
	armies.clear()
	for i in a.size() / 6:
		var src := int(a[i * 6])
		var dst := int(a[i * 6 + 1])
		if src >= circles.size() or dst >= circles.size():
			continue
		armies.append({"from": circles[src]["pos"], "to": circles[dst]["pos"],
			"owner": _swap(int(a[i * 6 + 2])), "amount": a[i * 6 + 3], "target": dst, "src": src,
			"progress": a[i * 6 + 4], "rate": a[i * 6 + 5]})


# Client: zwischen zwei Zustandsmeldungen weiterrechnen, damit alles flüssig läuft
func _client_tick(delta: float) -> void:
	for c in circles:
		if c["owner"] != 0:
			c["value"] += float(c.get("rate", 0.0)) * delta
	for a in armies:
		a["progress"] = minf(a["progress"] + float(a.get("rate", 0.0)) * delta, 1.0)
	_hill_tick(delta)


func _has_kind(kind: int) -> bool:
	for c in circles:
		if int(c.get("kind", 0)) == kind:
			return true
	return false


func _player_send(src: int, dst: int, percent: int) -> void:
	if mp_role == "client":
		rpc_command.rpc_id(1, src, dst, percent)
		_play_sfx("send")
	elif _send_amount(1, src, dst, _amount_for_percent(src, percent)):
		_play_sfx("send")


@rpc("authority", "reliable")
func rpc_begin(c: PackedFloat32Array) -> void:
	if mp_role != "client":
		return
	map_size = get_viewport_rect().size if is_inside_tree() else DESIGN_SIZE
	_apply_circles(c, true)
	level_type = "hill" if _has_kind(KIND_HILL) else "classic"
	armies.clear()
	fx.clear()
	selected = -1
	press_index = -1
	drag_active = false
	hold_target = -1
	hold_time = 0.0
	game_over = false
	winner = 0
	reward = 0
	reward_paid = true
	paused = false
	over_sound = false
	shop_pause = false
	shop_planet = -1
	shop_votes = {1: false, 2: false}
	hill_owner = 0
	hill_time = 0.0
	level = LEVELS[difficulty]
	_compute_stats()
	mp_status = "playing"
	state = State.PLAYING
	queue_redraw()


@rpc("authority", "unreliable_ordered")
func rpc_snapshot(c: PackedFloat32Array, a: PackedFloat32Array) -> void:
	if mp_role != "client" or state != State.PLAYING or game_over:
		return
	_apply_circles(c, false)
	_apply_armies(a)


@rpc("authority", "reliable")
func rpc_end(host_winner: int) -> void:
	if mp_role != "client":
		return
	game_over = true
	winner = _swap(host_winner)
	drag_active = false
	selected = -1


@rpc("authority", "unreliable")
func rpc_fx(idx: int, attacker: int, conquered: bool) -> void:
	if mp_role != "client" or idx < 0 or idx >= circles.size():
		return
	var local_attacker := _swap(attacker)
	_spawn_fx(circles[idx], local_attacker, conquered)
	_battle_sound(local_attacker, circles[idx]["owner"], conquered)
	if conquered and (local_attacker == 1 or circles[idx]["owner"] == 1):
		Input.vibrate_handheld(60)


@rpc("authority", "reliable")
func rpc_shop_state(active: bool, vote_host: bool, vote_client: bool) -> void:
	if mp_role != "client" or game_over:
		return
	shop_pause = active
	shop_votes = {1: vote_client, 2: vote_host}
	if not active:
		shop_planet = -1


@rpc("authority", "unreliable")
func rpc_shot(idx: int, nx: float, ny: float) -> void:
	if mp_role != "client" or idx < 0 or idx >= circles.size():
		return
	_spawn_shot(circles[idx]["pos"], Vector2(nx * map_size.x, (1.0 - ny) * map_size.y), COLORS[circles[idx]["owner"]])


@rpc("any_peer", "reliable")
func rpc_shop_open() -> void:
	if mp_role != "host" or game_over or mp_status != "playing":
		return
	shop_pause = true
	shop_votes[2] = false
	_shop_sync()


@rpc("any_peer", "reliable")
func rpc_shop_vote() -> void:
	if mp_role != "host" or game_over or mp_status != "playing" or not shop_pause:
		return
	shop_votes[2] = true
	_shop_check_resume()
	_shop_sync()


@rpc("any_peer", "reliable")
func rpc_buy(idx: int, kind: String) -> void:
	if mp_role != "host" or game_over or mp_status != "playing" or not shop_pause:
		return
	_shop_buy(2, idx, kind)


@rpc("any_peer", "reliable")
func rpc_command(src: int, dst: int, percent: int) -> void:
	if mp_role != "host" or game_over or mp_status != "playing" or shop_pause:
		return
	if src < 0 or src >= circles.size() or dst < 0 or dst >= circles.size():
		return
	_send_amount(2, src, dst, _amount_for_percent(src, clampi(percent, 50, 100)))


func _mp_process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	# Host: im Lobby-Zustand alle Sekunde "hier bin ich" senden
	if mp_role == "host" and mp_status == "hosting" and mp_udp_send != null:
		mp_bcast_timer -= delta
		if mp_bcast_timer <= 0.0:
			mp_bcast_timer = 1.0
			mp_udp_send.put_packet("CircleWar1".to_utf8_buffer())
	# Suchender: Hosts im WLAN einsammeln
	if mp_udp_recv != null:
		while mp_udp_recv.get_available_packet_count() > 0:
			var text := mp_udp_recv.get_packet().get_string_from_utf8()
			var ip := mp_udp_recv.get_packet_ip()
			if text == "CircleWar1" and ip != "":
				mp_found[ip] = now
		for ip in mp_found.keys():
			if now - int(mp_found[ip]) > 4000:
				mp_found.erase(ip)
	# Eingabefeld für die IP nur in der Suche zeigen
	if ip_edit != null:
		var show_edit := state == State.MULTI and mp_status == ""
		ip_edit.visible = show_edit
		if show_edit:
			var off := _menu_offset()
			var bw := minf(map_size.x - 80.0, 600.0)
			ip_edit.position = Vector2(map_size.x * 0.5 - bw * 0.5, off + 740.0)
			ip_edit.size = Vector2(bw, 70.0)
	if name_edit != null:
		name_edit.visible = state == State.EDITOR
		if state == State.EDITOR:
			name_edit.position = Vector2(180.0, 8.0)
			name_edit.size = Vector2(map_size.x - 190.0, 56.0)
	# Host: Zustand an den Client schicken, Spielende melden
	if mp_role == "host" and mp_status == "playing" and state == State.PLAYING:
		mp_snap_timer -= delta
		if (mp_snap_timer <= 0.0 or game_over) and not mp_end_sent:
			mp_snap_timer = 1.0 / SNAPSHOT_RATE
			rpc_snapshot.rpc(_pack_circles(), _pack_armies())
		if game_over and not mp_end_sent:
			mp_end_sent = true
			rpc_end.rpc(winner)
	# Client: weiterrechnen
	if mp_role == "client" and mp_status == "playing" and state == State.PLAYING and not game_over:
		_update_hold(delta)
		if not shop_pause:
			_client_tick(delta)


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
	var attacked := false
	for i in attacks:
		if not _ai_attack(own, others):
			break
		attacked = true
	if not attacked:
		_ai_buy(own)  # kein Angriff möglich: Armee in Upgrades stecken


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
			if circles[dst]["kind"] == KIND_HILL:
				score *= 2.5
			elif circles[dst]["kind"] == KIND_GOLD:
				score *= 1.5
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
		v += _rate(circles[dst]) * dist / (ARMY_SPEED * _speed(owner) * BOOST_MULT[int(circles[src]["boost"])])
	var eff := v * _power(dst_owner) * _shield(circles[dst])
	if count_inflight:
		for a in armies:
			if a["target"] == dst and a["owner"] == owner:
				eff -= a["amount"] * atk
	var loss := 0.0
	if dst_owner != owner and dst_owner != 0:
		loss = GUN_DAMAGE[int(circles[dst]["gun"])] * 2.5  # Abwehrgeschütz schießt unterwegs
	return maxf(eff, 0.0) / atk + loss


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
		State.MULTI:
			_draw_multi(font)
		State.EDITOR:
			_draw_editor(font)


func _draw_buttons(font: Font) -> void:
	for b in _buttons():
		var id: String = b["id"]
		_draw_button(font, b, _is_active(id), id == press_button, id == "start" or id == "resume" or (id == "go_setup" and not has_game()))


func _draw_coins(font: Font, off: float) -> void:
	draw_string(font, Vector2(0.0, off + 52.0), "Münzen: %d" % coins,
		HORIZONTAL_ALIGNMENT_RIGHT, map_size.x - 20.0, 28, GOLD)


func _draw_main(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 140.0, "Circle-Wars", 64, Color.WHITE)
	_text(font, off + 190.0, "Erobere alle Kreise", 26, Color(1, 1, 1, 0.7))
	_text(font, off + 330.0, "Münzen: %d" % coins, 40, GOLD)
	_draw_buttons(font)
	if toast_time > 0.0:
		_text(font, off + 250.0, toast, 26, Color(GOLD, minf(1.0, toast_time)))
	_text(font, off + 1256.0, "Danke an B4Players und N4Players!", 22, Color(GOLD, 0.85))
	if dev_mode:
		_text(font, off + 1058.0, "Developer", 18, Color(1, 1, 1, 0.5))


func _draw_setup(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 130.0, "Spielen", 48, Color.WHITE)
	_draw_coins(font, off)
	_text(font, off + 186.0, "Schwierigkeit", 22, Color(1, 1, 1, 0.7))
	_draw_buttons(font)
	_text(font, off + 570.0, level_info(), 19, Color(1, 1, 1, 0.85))
	_text(font, off + 606.0, "Levelart", 22, Color(1, 1, 1, 0.7))
	_text(font, off + 710.0, LEVEL_TYPES[level_type]["desc"], 18, Color(GOLD, 0.9))
	_text(font, off + 738.0, "Anzahl Kreise" if level_type != "custom" else "Eigenes Level", 22, Color(1, 1, 1, 0.7))
	var count_text := str(circle_count) if level_type != "rush" else "%d (Rush)" % RUSH_CIRCLES
	if level_type == "custom":
		count_text = _custom_label()
	_text(font, off + 750.0 + 48.0, count_text, 40 if level_type != "custom" else 26, Color.WHITE)
	if toast_time > 0.0:
		_text(font, off + 1180.0, toast, 22, GOLD)
	_text(font, off + 850.0, "Armeetyp", 22, Color(1, 1, 1, 0.7))


func _draw_multi(font: Font) -> void:
	var off := _menu_offset()
	_text(font, off + 130.0, "Mehrspieler (WLAN)", 44, Color.WHITE)
	if toast_time > 0.0:
		_text(font, off + 170.0, toast, 24, GOLD)
	match mp_status:
		"":
			_text(font, off + 342.0, "Gefundene Spiele" if not mp_found.is_empty() else "Suche Spiele im WLAN …",
				22, Color(1, 1, 1, 0.7))
			_text(font, off + 720.0, "Oder IP-Adresse des Hosts eingeben", 22, Color(1, 1, 1, 0.7))
			_text(font, off + 950.0, "Beide Handys müssen im selben WLAN sein.", 20, Color(1, 1, 1, 0.55))
			_text(font, off + 985.0, "Kein WLAN? Ein Handy schaltet seinen mobilen Hotspot ein,", 20, Color(1, 1, 1, 0.55))
			_text(font, off + 1010.0, "das andere verbindet sich damit. Dann ganz normal spielen.", 20, Color(1, 1, 1, 0.55))
		"hosting":
			_text(font, off + 280.0, "Warte auf Mitspieler …", 36, Color.WHITE)
			var ips := _local_ips()
			_text(font, off + 340.0, "Deine IP: " + (", ".join(ips) if not ips.is_empty() else "unbekannt"),
				24, GOLD)
			_text(font, off + 380.0, "Der Mitspieler findet dich automatisch oder gibt die IP ein.",
				20, Color(1, 1, 1, 0.65))
			_text(font, off + 410.0, "Ohne WLAN: mobilen Hotspot einschalten, der andere verbindet sich damit.",
				18, Color(1, 1, 1, 0.55))
			_text(font, off + 500.0, "Anzahl Kreise", 22, Color(1, 1, 1, 0.7))
			if level_type == "custom":
				_text(font, off + 520.0 + 48.0, _custom_label(), 26, Color.WHITE)
			else:
				_text(font, off + 520.0 + 48.0, str(circle_count) if level_type != "rush" else "%d (Rush)" % RUSH_CIRCLES,
					40, Color.WHITE)
			_text(font, off + 638.0, "Levelart", 22, Color(1, 1, 1, 0.7))
			_text(font, off + 742.0, LEVEL_TYPES[level_type]["desc"], 18, Color(GOLD, 0.9))
			_text(font, off + 800.0, "Beide spielen mit Standard-Armeen, ohne Verstärkungen.",
				20, Color(1, 1, 1, 0.6))
		"connecting":
			_text(font, off + 400.0, "Verbinde …", 36, Color.WHITE)
		_:
			_text(font, off + 400.0, "Verbunden – warte auf den Start", 30, Color.WHITE)
	_draw_buttons(font)


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
		_draw_badges(c)
		_draw_kind(font, c)
		if shop_pause and i == shop_planet:
			draw_arc(c["pos"], c["radius"] + 12.0, 0.0, TAU, 48, GOLD, 4.0)
		var label := "%.1f" % c["value"] if (dev_mode and dev_info) else str(int(c["value"]))
		var label_size := 24 if (dev_mode and dev_info) else 28
		draw_string(font, c["pos"] + Vector2(-c["radius"], label_size * 0.35), label,
			HORIZONTAL_ALIGNMENT_CENTER, c["radius"] * 2.0, label_size, Color.WHITE)
		if dev_mode and dev_info:
			draw_arc(c["pos"], _hit_radius(c), 0.0, TAU, 48, Color(1, 1, 0, 0.35), 1.5)

	for a in armies:
		_draw_army(font, a)
	_draw_fx()

	if mass_active and mass_target >= 0 and mass_target < circles.size():
		_draw_mass(font)

	if drag_active and selected >= 0:
		var end := drag_pos
		var hover := _circle_at(drag_pos, RELEASE_SNAP)
		# Kette: Planeten, über die gewischt wurde, werden hervorgehoben und verbunden
		for ci in chain:
			if ci != selected:
				draw_arc(circles[ci]["pos"], circles[ci]["radius"] + 10.0, 0.0, TAU, 48, GOLD, 3.0)
		if chain_cand >= 0:
			var cc: Dictionary = circles[chain_cand]
			draw_arc(cc["pos"], cc["radius"] + 10.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(chain_time / CHAIN_DWELL, 0.0, 1.0),
				48, GOLD, 3.0)
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
			var total := 0.0
			for src in _chain_sources(hover):
				total += _amount_for_percent(src, pct)
			draw_string(font, hc["pos"] + Vector2(-60.0, label_y),
				"-> %d" % int(total),
				HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color.WHITE)
		# Linie durch alle Planeten der Kette bis zum Finger bzw. Ziel
		var pts := PackedVector2Array()
		for ci in chain:
			if ci != hover or ci == selected:
				pts.append(circles[ci]["pos"])
		pts.append(end)
		if pts.size() >= 2:
			draw_polyline(pts, Color(1, 1, 1, 0.5), 3.0)

	var player_count := _indices_with_owner(1).size()
	var enemy_count := _indices_with_owner(2).size()
	draw_string(font, Vector2(20, 40),
		"Du: %d   %s: %d" % [player_count, "Gegner" if mp_role != "" else level["name"], enemy_count],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(font, Vector2(20, 76),
		"Wischen = %d %%, Ziel halten = mehr, kurz auf eigenen = sammeln" % int(SEND_FRACTION * 100),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 1, 1, 0.8))

	if shop_pause and not game_over:
		_draw_shop(font)

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
		if mp_role != "":
			_text(font, map_size.y * 0.5 + 30.0, "Mehrspieler", 26, Color(1, 1, 1, 0.8))
			if mp_role == "client":
				_text(font, map_size.y * 0.5 + 78.0, "Der Host startet die nächste Runde", 22, Color(1, 1, 1, 0.7))
			if toast_time > 0.0:
				_text(font, map_size.y * 0.5 + 340.0, toast, 24, GOLD)
		else:
			_text(font, map_size.y * 0.5 + 30.0, "%s (%s)" % [level["label"], level["name"]], 26, Color(1, 1, 1, 0.8))
		if reward > 0:
			_text(font, map_size.y * 0.5 + 78.0, "+%d Münzen" % reward, 30, GOLD)
		for b in _buttons():
			_draw_button(font, b, false, b["id"] == press_button, b["id"] == "again")


# Developer-Anzeigen: Werkzeug, Pause und (optional) Diagnosewerte
# Massenangriff: Linien von allen Quellen zum Ziel, Zähler am Ziel, rotes X zum Abbrechen
func _draw_mass(font: Font) -> void:
	var tc: Dictionary = circles[mass_target]
	var tp: Vector2 = tc["pos"]
	var pct := _mass_percent()
	var xp := _mass_cancel_pos()
	var over_x := drag_pos.distance_to(xp) <= MASS_CANCEL_RADIUS
	var live := not over_x and _circle_at(drag_pos, RELEASE_SNAP) == mass_target
	var fade := 1.0 if live else 0.35
	for i in _mass_sources(mass_target):
		draw_line(circles[i]["pos"], tp, Color(GOLD, 0.3 * fade), 3.0)
		draw_arc(circles[i]["pos"], circles[i]["radius"] + 8.0, 0.0, TAU, 40, Color(GOLD, 0.8 * fade), 3.0)
	var arc_r: float = tc["radius"] + 24.0
	var frac := float(pct - 50) / 50.0
	draw_arc(tp, arc_r, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 8.0)
	draw_arc(tp, arc_r, -PI * 0.5, -PI * 0.5 + TAU * maxf(frac, 0.02), 64, Color(GOLD, fade), 8.0)
	var label_y: float = -tc["radius"] - 26.0
	draw_rect(Rect2(tp + Vector2(-60.0, label_y - 68.0), Vector2(120.0, 94.0)), Color(BG_COLOR, 0.88), true)
	draw_string(font, tp + Vector2(-60.0, label_y - 28.0), "%d %%" % pct,
		HORIZONTAL_ALIGNMENT_CENTER, 120, 34, Color(GOLD, fade))
	draw_string(font, tp + Vector2(-60.0, label_y + 6.0), "-> %d" % int(_mass_total(mass_target, pct)),
		HORIZONTAL_ALIGNMENT_CENTER, 120, 24, Color(1, 1, 1, fade))
	# rotes X
	var r := 46.0 if not over_x else 56.0
	draw_circle(xp, r, Color(0.85, 0.15, 0.18, 0.92))
	draw_arc(xp, r, 0.0, TAU, 40, Color.WHITE, 3.0)
	var k := r * 0.42
	draw_line(xp + Vector2(-k, -k), xp + Vector2(k, k), Color.WHITE, 6.0)
	draw_line(xp + Vector2(-k, k), xp + Vector2(k, -k), Color.WHITE, 6.0)
	draw_string(font, xp + Vector2(-80.0, r + 26.0), "Abbrechen" if over_x else "Hierher wischen",
		HORIZONTAL_ALIGNMENT_CENTER, 160, 20, Color.WHITE)


# Planetenart: Gold (×2), ausgebrannt (×0), Hügel mit Haltezeit
func _draw_kind(font: Font, c: Dictionary) -> void:
	var kind := int(c.get("kind", 0))
	if kind == KIND_NORMAL:
		return
	var pos: Vector2 = c["pos"]
	var r: float = c["radius"]
	match kind:
		KIND_GOLD:
			draw_arc(pos, r + 3.0, 0.0, TAU, 48, GOLD, 3.0)
			draw_string(font, pos + Vector2(-30.0, r + 24.0), "×2", HORIZONTAL_ALIGNMENT_CENTER, 60, 20, GOLD)
		KIND_DEAD:
			draw_circle(pos, r, Color(0, 0, 0, 0.4))
			draw_line(pos + Vector2(-r * 0.5, -r * 0.5), pos + Vector2(r * 0.5, r * 0.5), Color(1, 1, 1, 0.25), 3.0)
			draw_line(pos + Vector2(-r * 0.5, r * 0.5), pos + Vector2(r * 0.5, -r * 0.5), Color(1, 1, 1, 0.25), 3.0)
			draw_string(font, pos + Vector2(-30.0, r + 24.0), "×0", HORIZONTAL_ALIGNMENT_CENTER, 60, 20, Color(1, 1, 1, 0.5))
		KIND_HILL:
			var col: Color = COLORS[c["owner"]] if c["owner"] != 0 else GOLD
			draw_arc(pos, r + 6.0, 0.0, TAU, 64, Color(1, 1, 1, 0.2), 6.0)
			if hill_owner != 0 and hill_time > 0.0:
				draw_arc(pos, r + 6.0, -PI * 0.5, -PI * 0.5 + TAU * clampf(hill_time / HILL_GOAL, 0.0, 1.0), 64, col.lightened(0.3), 6.0)
			_draw_shape("star", pos + Vector2(0.0, -r - 22.0), Vector2.RIGHT, 9.0, GOLD)
			var txt := "Hügel" if hill_owner == 0 else "%d s" % int(ceilf(HILL_GOAL - hill_time))
			draw_string(font, pos + Vector2(-40.0, r + 28.0), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 22, GOLD)


# Upgrades am Planeten: Schildringe (blau), Geschützpunkte oben (orange), Beschleunigerpunkte unten (grün)
func _draw_badges(c: Dictionary) -> void:
	var r: float = c["radius"]
	var pos: Vector2 = c["pos"]
	for k in int(c["shield"]):
		draw_arc(pos, r + 5.0 + k * 4.0, 0.0, TAU, 48, Color(0.45, 0.85, 1.0, 0.85), 2.5)
	var g := int(c["gun"])
	for k in g:
		var ang := -PI * 0.5 + (k - (g - 1) * 0.5) * 0.45
		draw_circle(pos + Vector2.RIGHT.rotated(ang) * (r + 18.0), 5.0, Color(1.0, 0.6, 0.15))
	var b := int(c["boost"])
	for k in b:
		var ang2 := PI * 0.5 + (k - (b - 1) * 0.5) * 0.45
		draw_circle(pos + Vector2.RIGHT.rotated(ang2) * (r + 18.0), 5.0, Color(0.4, 0.95, 0.45))


func _draw_shop(font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, map_size), Color(0, 0, 0, 0.35), true)
	var mine: bool = shop_votes[1]
	var other: bool = shop_votes[2]
	var note := "PAUSE – eigenen Planeten antippen für Upgrades"
	if mine and not other:
		note = "PAUSE – warte auf den Gegner …"
	elif other and not mine and mp_role != "":
		note = "PAUSE – der Gegner ist bereit"
	_text(font, map_size.y * 0.5, note, 22, Color(1, 1, 1, 0.9))
	if shop_planet < 0:
		return
	var pr := _shop_panel_rect()
	draw_rect(pr, Color("#1b2029"), true)
	draw_rect(pr, Color(1, 1, 1, 0.2), false, 2.0)
	var c: Dictionary = circles[shop_planet]
	draw_string(font, pr.position + Vector2(16, 38), "Upgrades – Armee: %d" % int(c["value"]),
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, GOLD)
	for row in _shop_rows():
		var r: Rect2 = row["rect"]
		draw_rect(r, Color("#232a36"), true)
		draw_string(font, r.position + Vector2(12, 30), row["title"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190.0, 22, Color.WHITE)
		draw_string(font, r.position + Vector2(12, 60), row["desc"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 190.0, 15, Color(1, 1, 1, 0.65))


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
