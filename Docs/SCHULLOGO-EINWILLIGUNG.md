# Einwilligung zur Nutzung des Schullogos als App-Symbol

*Vorlage. Eine Seite, vom Schulleiter oder der Schulleiterin unterschrieben,
bevor ein echtes Schullogo in die App kommt. Ein eigenes Design in den
Schulfarben (wie „Eli“) braucht das nicht — ein Wappen, Logo oder Schriftzug
der Schule immer.*

---

**Schule:** ______________________________________ (Schulnummer: ________)

**Vertreten durch:** ______________________________ (Schulleitung)

**App:** Schulportal-App für iOS (inoffiziell), Entwickler: ______________________

## 1. Gegenstand

Die Schule gestattet dem Entwickler, das beigefügte Logo/Wappen der Schule
(„Logo“) als **wählbares App-Symbol** in der oben genannten iOS-App zu
verwenden. Das Symbol ist ausschließlich für Nutzerinnen und Nutzer sichtbar,
die die Schule in der App ausgewählt haben.

## 2. Umfang

- Nutzung nur als App-Symbol (Homescreen) und in der Symbol-Auswahl der App.
- Keine Nutzung in Werbung, im App-Store-Eintrag oder außerhalb der App ohne
  gesonderte Zustimmung.
- Das Logo darf technisch angepasst werden (Zuschnitt, Hintergrundfarbe,
  Auflösung), nicht aber inhaltlich verändert.
- Das Symbol wird für Schülerinnen, Schüler und Eltern der Schule
  **kostenlos** angeboten. Es ist kein Verkaufsgegenstand.

## 3. Kein Anschein der Offiziellität

Die App ist ein privates, inoffizielles Angebot und **kein Produkt der Schule,
des Hessischen Kultusministeriums oder des Schulportals Hessen**. Die App
weist darauf hin. Die Schule übernimmt keine Verantwortung für die App.

## 4. Dauer und Widerruf

Die Einwilligung gilt unbefristet und kann jederzeit ohne Angabe von Gründen
per E-Mail widerrufen werden. Der Entwickler entfernt das Logo dann mit dem
nächsten App-Update, spätestens innerhalb von 30 Tagen.

## 5. Rechte

Die Schule versichert, über die nötigen Rechte am Logo zu verfügen. Es
werden keine weiteren Rechte übertragen; das Logo bleibt Eigentum der Schule
bzw. des Schulträgers.

---

Ort, Datum: ____________________

Unterschrift Schulleitung: ____________________   Stempel:

Unterschrift Entwickler: ____________________

*Anlage: Logo als Bilddatei (mind. 1024 × 1024 px, PNG oder SVG).*

---

## Ablauf intern (nicht Teil der Vorlage)

1. Anfrage kommt von Schule, Förderverein oder SV → diese Vorlage schicken.
2. Unterschrieben zurück → als PDF unter `Docs/consent/<Schulnummer>.pdf`
   ablegen (nicht ins öffentliche Repo, nur lokal/verschlüsselt).
3. Icon bauen (1024 px, opak), `AppIcon<Schule>.appiconset` anlegen,
   Namen in `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` (`project.yml`
   und `project.pbxproj`) ergänzen.
4. `iconName` im Eintrag der Schule in `Resources/schools.json` setzen.
5. Release. Das Symbol erscheint unter „App-Symbol › Meine Schule“ für alle,
   die diese Schule gewählt haben.
