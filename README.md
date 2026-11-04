# Circle-Wars

Echtzeit-Strategie mit Kreisen für das Handy (Godot 4.3). Zwei Kontrahenten kämpfen um die Kreise auf der Karte. Die Zahl im Kreis ist die Armee.

## Spielregeln

- Zufällig verteilte Kreise (Startwert 5 bis 20, Größe hängt vom Wert ab), die Startkreise haben 15
- Besetzte Kreise bekommen laufend Armee dazu
- Man kann jederzeit Armee senden. Ist sie kleiner als die Armee auf dem Ziel, wird sie bei der Ankunft davon abgezogen; ist sie größer, wird der Kreis erobert
- Armeen unterwegs erscheinen als kleine Dreiecke mit ihrer Stärke, im Kreis steht die Zahl

## Menü

- **Schwierigkeit** (entspricht dem Gegner): Sehr leicht (Kiesel), Leicht (Wächter), Mittel (Sturm), Schwer (Stratege), Unspielbar (Kollektiv)
- **Anzahl Kreise:** 4 bis 30
- Die Auswahl wird gespeichert

## Steuerung

- **Wischen:** von einem eigenen Kreis auf ein Ziel ziehen und loslassen sendet **50 %** der vorhandenen Armee (abgerundet, mindestens 1).
- **Halten:** Bleibt der Finger beim Zielen länger auf dem Ziel, erscheint ein Bogen mit einer Anzeige, die von 50 % auf 100 % steigt (5-%-Schritte). Beim Loslassen wird dieser Anteil gesendet. Bei 100 % wird alles bis auf 1 gesendet. Wechselt der Finger auf einen anderen Kreis, beginnt die Anzeige neu.
- **Menü-Knopf** oben rechts bricht die Partie ab; nach dem Ende gibt es „Nochmal“ und „Menü“

## Developer Mode

Im Menü unten mit „Developer Mode“ einschalten (wird gespeichert). Im Spiel erscheint oben der Knopf **DEV**, der ein Panel öffnet:

- **Pause / Weiter**, **Tempo** (x0.5, x1, x2, x4)
- **KI: an/aus** friert die Entscheidungen des Gegners ein
- **Infos:** FPS, Armeen unterwegs, KI-Takt, genaue Armeewerte mit Nachkommastellen und die Trefferflächen der Kreise
- **Neue Karte**, **Gegner +** (Stufe live wechseln), **Sieg** und **Niederlage** erzwingen (zum Testen des Endbildschirms)
- **Werkzeuge** (danach Kreis antippen): Besitzer wechseln, +10 oder -10 Armee

## Gegner einstellen

Die Stufen stehen als `LEVELS` oben in `scripts/game.gd` (Reaktionszeit, Wachstum, Vorsicht, Angriffe pro Entscheidung).

Zum Messen der Stärke gibt es einen Bot, der ohne Anzeige gegen jede Stufe spielt:

    godot --headless --path . -s tools/sim.gd -- games=40 circles=12 bot=2.5,1.3

`bot=<Reaktionszeit in s>,<Sicherheitsfaktor>` beschreibt den Bot-Spieler (größer = langsamer und vorsichtiger).

## Öffnen und bauen

1. Godot 4.3 installieren, `project.godot` importieren, mit F5 starten.
2. Die APK baut GitHub Actions bei jedem Push auf `main` (Reiter „Actions“, Artefakt `echtzeit-strategie-apk`).

## Fortschritt (Werkstatt)

- Hauptmenü: **Spielen** (Schwierigkeit, Kreise, Armeetyp, "Gegner levelt mit") und **Werkstatt**; Münzen oben.
- Verstärkungen **Kraft / Tempo / Wachstum**: je 10 Stufen, +5 % pro Stufe, Preise 100, 150, 200, 300, 400, 550, 700, 900, 1100, 1400.
- Armeetypen: Standard (Dreieck), **Tank** (Quadrat, Kraft ×1,3, Tempo ×0,7) und **Schnell** (Stern, Kraft ×0,8, Tempo ×1,4), je 500 Münzen.
- Kraft wirkt nur im Kampf (Angriff und Verteidigung): beide Armeen × Kraft, die Differenz entscheidet.
- "Gegner levelt mit": Gegner bekommt deine Verstärkungen, Münzen ×1,5.
- Münzen pro Sieg: 20 / 40 / 70 / 110 / 160 (bei 12 Kreisen, skaliert mit der Kreisanzahl), Niederlage 25 %.
- Speicherstand in `user://settings.cfg`. Developer Mode (Hauptmenü): +1000 Münzen, alles freischalten, Fortschritt zurücksetzen.
- Tests: `godot --headless --path . -s tools/tests.gd`; Simulation mit `type=tank|star upg=0..10 enemy=1`.

## Pause und Menü

- **Pause** (oben rechts): friert die Partie ein. Im Pause-Menü: Fortfahren, Menü und (Developer Mode) das Developer-Panel.
- **Menü** aus dem Pause-Menü lässt die Partie bestehen; im Hauptmenü gibt es dann **Fortfahren**.
- Kämpfe zeigen Blitze, Funken und eine Druckwelle um den Kreis (größer bei Eroberung).

## Mehrspieler (WLAN)

- Hauptmenü → **Mehrspieler (WLAN)**. Einer erstellt ein Spiel, der andere findet es automatisch (UDP-Broadcast, Port 24601) oder gibt die IP ein (Spielport 24600).
- Der Host rechnet das Spiel, der Client bekommt den Zustand ca. 15× pro Sekunde und schickt seine Wisch-Befehle; die Karte ist für den Client gespiegelt, sodass er immer unten spielt.
- Beide spielen mit Standard-Armeen (keine Verstärkungen, keine Münzen). Der Host startet Revanche mit "Nochmal".
- Test auf einem Rechner: `tools/net_test.gd` (Host und Client als zwei Prozesse).

## Musik und Sound

- Alles selbst erzeugt (keine fremden Dateien): `python3 tools/make_audio.py` schreibt die Dateien nach `audio/` (benötigt numpy, scipy, ffmpeg).
- Menü-Musik und Spiel-Musik als Schleife; Effekte für Klick, Senden, Kampf, Eroberung, Verlust, Sieg und Niederlage.
- Im Hauptmenü lassen sich **Musik** und **Sound** getrennt aus- und einschalten (wird gespeichert).

## Planeten-Upgrades

- Eigenen Planeten antippen: Das Spiel pausiert (auch im Mehrspieler, für beide), und du kannst mit der **Armee auf dem Planeten** bezahlen. Mindestens 1 Armee bleibt übrig.
- **Schutzschild** (6/10/15): Verteidigung ×1,2 / ×1,4 / ×1,6. **Abwehrgeschütz** (8/12/18): schießt alle 0,9 s auf die nächste feindliche Armee in Reichweite (2/3/4 Schaden). **Beschleunigungsfeld** (5/8/12): von hier entsandte Armeen +25/50/75 % schneller.
- Upgrades gehen bei Eroberung des Planeten verloren. Anzeige am Planeten: blaue Ringe (Schild), orange Punkte oben (Geschütz), grüne Punkte unten (Beschleuniger).
- Weiter geht es erst, wenn alle Spieler "Weiter" gedrückt haben (Einzelspiel: nur du).
- Die KI kauft je nach Schwierigkeit (Mittel selten, Unspielbar häufig), wenn sie gerade keinen Angriff starten kann.
- Simulation: `botbuy=<0..1>` lässt den Bot ebenfalls kaufen.
