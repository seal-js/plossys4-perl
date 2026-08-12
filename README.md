# plossys4-perl

Dieses Repository enthaelt eine Sammlung von Perl-Skripten und Hilfsmodulen fuer typische Aufgaben im PLOSSYS-4-Umfeld.
Der Schwerpunkt liegt auf Dateiverarbeitung, Buildjob-Erzeugung, Kodierungsthemen und wiederverwendbaren Bibliotheken.

## Ziel und Funktionalitaet

Die Inhalte lassen sich in drei Hauptbereiche einteilen:

- Operative Skripte: Kleine, direkt ausfuehrbare Tools fuer alltaegliche Aufgaben (z. B. Verzeichnisse lesen, Strings bearbeiten, ZIPs entpacken, Header-Dateien erzeugen).
- Bibliotheken: Wiederverwendbare Module fuer Logging, Konfiguration, Dateispeicherung und die Integration externer Tools.
- Beispiele und Tests: Testskripte fuer einzelne Module und technische Randfaelle.

Wichtige Beispiele:

- [lib/sealperl/powershell.pm](lib/sealperl/powershell.pm): Fuehrt PowerShell-Skripte robust aus, sammelt STDOUT/STDERR und liefert den Exit-Code.
- [lib/FileStorable.pm](lib/FileStorable.pm): Persistiert Perl-Datenstrukturen ueber Storable.
- [dir/lib/FindFiles.pm](dir/lib/FindFiles.pm): Traversiert Verzeichnisbaeume und filtert Treffer nach Dateityp.

## Repository-Aufbau

- [lib](lib): Allgemeine Perl-Module fuer mehrere Skripte.
- [lib/sealperl](lib/sealperl): PLOSSYS-nahe Basisfunktionen (Konstanten, Logging, PowerShell-Aufrufe).
- [PLOSSYS_buildjobs](PLOSSYS_buildjobs): Skripte und Beispieldaten zur Erzeugung und Aufteilung von Buildjobs und Headern.
- [dir](dir): Dateisystem-Utilities (Verzeichnisse lesen, Dateien finden, Unicode-Verzeichnisse anlegen).
- [array](array): Kleine Hilfsskripte fuer Array-Vergleiche und Auswertungen.
- [string](string): String-bezogene Helfer (z. B. Trimmen).
- [output](output): Konvertierungs- und Analyse-Skripte fuer Dateinamen/Header sowie Modultests.
- [web](web): HTTP/HTTPS- und LWP-Testskripte.
- [zip](zip): ZIP-bezogene Hilfsskripte.
- [maingate](maingate): Vorlagen/Glue-Code fuer Maingate-nahe Verarbeitung.
- [testfiles](testfiles): Testdaten fuer verschiedene Skripte.

## Typische Nutzung

Die meisten Skripte sind als Einzeltools gedacht und koennen direkt mit Perl gestartet werden:

```powershell
perl .\output\test_powershell_module.pl
perl .\PLOSSYS_buildjobs\create_printers.pl
```

Fuer Modul-Tests mit lokalen Bibliotheken wird in der Regel das Repo-eigene [lib](lib) Verzeichnis eingebunden (z. B. ueber FindBin oder -I).

## Hinweise

- Viele Skripte sind bewusst klein gehalten und als Bausteine fuer groessere Prozessketten gedacht.
- Teile des Repositories enthalten historische oder umgebungsabhaengige Beispiele, die lokal angepasste Pfade/Variablen erwarten.
