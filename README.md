# CircleWar

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
