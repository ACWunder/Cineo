# Cineo

Schlanker iOS Film- & Serien-Tracker (SwiftUI + Firebase + TMDB).
Bibliothek pro User, 5-Sterne-Bewertung, Empfehlungen, Staffel-Übersicht.

## Setup

> Nur Punkt **1** musst du selbst machen (Firebase SDK über Xcode SPM hinzufügen).
> Der TMDB-Token, die Firebase-Config-Plist und die Sign-in-with-Apple Capability sind bereits eingetragen.

### 1) Firebase SDK über Swift Package Manager hinzufügen

In Xcode:

1. `File → Add Package Dependencies …`
2. URL eingeben: `https://github.com/firebase/firebase-ios-sdk`
3. *Dependency Rule:* `Up to Next Major Version` (oder neuste stabile).
4. *Add to Target: Cineo* — folgende Produkte auswählen:
   - **FirebaseAuth**
   - **FirebaseFirestore**
   - (FirebaseCore wird automatisch mitgezogen)
5. `Add Package` klicken und warten, bis das SPM-Resolving fertig ist.

Beim ersten Build dauert das ein paar Minuten — Firebase ist groß.

### 2) Capabilities prüfen (sind bereits gesetzt, aber zur Sicherheit)

In Xcode: Target *Cineo* → *Signing & Capabilities*. Es sollte aktiv sein:

- ✅ **Sign in with Apple**
- ✅ **App Sandbox** mit *Outgoing Connections (Client)* (für Mac/Catalyst)

Die Entitlements-Datei liegt unter `Cineo/Cineo.entitlements`.

### 3) Konfig-Dateien (sind bereits in Place)

| Datei                                   | Status         | Was sie tut                                              |
|-----------------------------------------|----------------|----------------------------------------------------------|
| `Config/Info.plist`                     | ✅ committed   | App-Info-Dictionary; liest `$(TMDB_BEARER_TOKEN)`.       |
| `Config/Secrets.xcconfig`               | ⛔ .gitignore  | Enthält deinen TMDB v4 Read Access Token.                |
| `Config/Secrets.example.xcconfig`       | ✅ committed   | Vorlage für andere Teammitglieder.                       |
| `Cineo/Cineo.entitlements`              | ✅ committed   | Sign in with Apple + Sandbox-Network-Client.             |
| `Cineo/GoogleService-Info.plist`        | ⛔ .gitignore  | Firebase-Config für `com.arthurwunder.Cineo`.            |

Wenn jemand neu klont:
```bash
cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
# danach TMDB_BEARER_TOKEN eintragen
# dazu separat: GoogleService-Info.plist aus der Firebase-Console laden
# und unter Cineo/GoogleService-Info.plist ablegen
```

### 4) Build

```
⌘B   in Xcode
```
Oder via CLI:
```bash
xcodebuild -project Cineo.xcodeproj -scheme Cineo -destination 'platform=iOS Simulator,name=iPhone 15' build
```

## Architektur

| Bereich       | Pfad                                  | Zweck                                          |
|---------------|---------------------------------------|------------------------------------------------|
| App-Einstieg  | `Cineo/CineoApp.swift`                | Firebase boot, Environment-Injection.          |
| Root          | `Cineo/ContentView.swift`             | Auth-Gate → Tab-Navigation.                    |
| Theme         | `Cineo/Theme/Theme.swift`             | Farben, Spacing, Typografie, Radien.           |
| Models        | `Cineo/Models/*`                      | `LibraryItem`, `DismissedItem`, TMDB-Structs.  |
| Networking    | `Cineo/Networking/TMDBClient.swift`   | Async TMDB-Client (Actor) + Genre-Cache.       |
| Services      | `Cineo/Services/*`                    | Firebase Bootstrap, Auth, Firestore-Repos.     |
| Components    | `Cineo/Components/*`                  | StarRating, Poster, EmptyState, Buttons.       |
| Features      | `Cineo/Features/{Auth,Search,Library,Discover,Seasons}` | Vier Tabs + ViewModels.                       |

Tabs:
1. **Empfehlungen** — Karten-Stack mit Aggregations-Score aus bewerteten Titeln (Fallback: Trending der Woche).
2. **Bibliothek** — Grid mit Sortier-/Filter-Optionen, Detail-Sheet, Sterne änderbar.
3. **Suche** — `/search/multi`, Live-Suche, Add-Sheet (gesehen+Rating oder Watchlist).
4. **Staffeln** — Filter auf eigene Serien mit `next_episode_to_air`.

## Firestore-Struktur

```
users/{uid}/library/{tmdbId}     → LibraryItem fields
users/{uid}/dismissed/{tmdbId}   → { tmdbId, mediaType }
```

Du brauchst Firestore-Regeln. Minimal sicher für Single-User-Zugriff:

```rules
rules_version = '2';
service cloud.firestore {
  match /databases/{db}/documents {
    match /users/{uid}/{document=**} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
```

## Empfehlungs-Logik

```
ratedTitles = library where rating != nil
for title in ratedTitles:
    weight = Double(title.rating)
    recs = TMDB.recommendations(title) + TMDB.similar(title)
    for rec in recs:
        skip if rec in library or in dismissed
        score = weight * (rec.voteAverage / 10.0)
        candidates[rec.id] += score
result = candidates.sorted desc
```

Doppelt-empfohlene Titel akkumulieren automatisch mehr Score.

## Scope-Grenzen

Bewusst nicht enthalten: Cast/Crew, Trailer, soziale Features, Streaming-Anbieter, Trakt-Integration, Push-Notifications.

## Lizenz

Privat / unveröffentlicht.
