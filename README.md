# CircleWar

Echtzeit-Strategie mit Kreisen für das Handy (Godot 4.3). Zwei Kontrahenten kämpfen um die Kreise auf der Karte. Die Zahl im Kreis ist die Armee.

## Spielregeln

- Zufällig verteilte Kreise (Startwert 5 bis 20, Größe hängt vom Wert ab), die Startkreise haben 15
- Besetzte Kreise bekommen laufend Armee dazu
- Angriff nur, wenn die entsandte Armee größer ist als die Armee auf dem Ziel

## Menü

- **Schwierigkeit** (entspricht dem Gegner): Sehr leicht (Kiesel), Leicht (Wächter), Mittel (Sturm), Schwer (Stratege), Unspielbar (Kollektiv)
- **Anzahl Kreise:** 4 bis 30
- Die Auswahl wird gespeichert

## Steuerung

- **Wischen:** von einem eigenen Kreis auf ein Ziel ziehen, um Armee zu entsenden
- **Tippen auf einen eigenen Kreis:** Anteil der entsendeten Armee umschalten (25, 50, 75, 100 %)
- **Menü-Knopf** oben rechts bricht die Partie ab; nach dem Ende gibt es „Nochmal“ und „Menü“

## Gegner einstellen

Die Stufen stehen als `LEVELS` oben in `scripts/game.gd` (Reaktionszeit, Wachstum, Vorsicht, Angriffe pro Entscheidung).

Zum Messen der Stärke gibt es einen Bot, der ohne Anzeige gegen jede Stufe spielt:

    godot --headless --path . -s tools/sim.gd -- games=40 circles=12 bot=2.5,1.3

`bot=<Reaktionszeit in s>,<Sicherheitsfaktor>` beschreibt den Bot-Spieler (größer = langsamer und vorsichtiger).

## Öffnen und bauen

1. Godot 4.3 installieren, `project.godot` importieren, mit F5 starten.
2. Die APK baut GitHub Actions bei jedem Push auf `main` (Reiter „Actions“, Artefakt `echtzeit-strategie-apk`).
