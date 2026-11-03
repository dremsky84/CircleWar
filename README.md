# Echtzeit Strategie (Prototyp)

Echtzeit-Strategie mit Kreisen. Zwei Kontrahenten kämpfen um die Kreise auf der Karte. Die Zahl im Kreis ist die Armee.

## Stand

Kernspiel als Prototyp:
- Zufällig verteilte Kreise (Startwert 5 bis 20), Startkreise mit 15
- Besetzte Kreise wachsen laufend
- Angriff nur, wenn die entsandte Armee größer ist als die Armee auf dem Ziel
- Gegner mit fünf Strategien: Kiesel, Wächter, Sturm, Stratege, Kollektiv
- Steuerung per Tippen und Wischen

Noch offen: Startmenü (Kreisanzahl 4 bis 30, Gegnerwahl), Armeetypen und Progression, Gegner-Feinschliff, APK-Build über GitHub.

## Steuerung

- **Wischen:** von einem eigenen Kreis auf ein Ziel ziehen, um Armee zu entsenden.
- **Tippen auf eigenen Kreis:** Anteil der entsendeten Armee umschalten (25, 50, 75, 100 %).
- **Nach Spielende:** Tippen startet eine neue Partie.

## Öffnen

1. Godot 4.3 (Standard-Version) installieren.
2. Im Godot-Projektmanager „Importieren“ und die Datei `project.godot` wählen.
3. Mit F5 starten.

Die Partie startet mit 12 Kreisen gegen den Gegner „Sturm“. Diese Werte stehen oben in `scripts/game.gd` (`circle_count`, `opponent_name`).
