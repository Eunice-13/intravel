# InTravel

**Hackathon Project**: Developed as a competitive hackathon entry featuring precision navigation, dynamic route planning, and accessible travel tools for historic cultural heritage sites.

The InTravel dashboard is bundled as a Flutter app and opens in an Android WebView. It works offline, including maps, location photos, navigation, planner, settings, saved places, and the Apple-style dark mode.

🧭 InTravel: Intramuros High-Precision Navigation Engine
InTravel is a responsive, single-page progressive web application designed to guide travelers through the historic walled city of Intramuros in Manila, Philippines. Built with modern web standards, it delivers a smooth native-like mobile experience with dynamic route planning, site history, interactive mapping, and accessible travel options.

## Features

📱 Native Mobile-First UI Shell: Optimized for responsive touch screens with fixed status metrics, dynamic viewport scaling, and an Apple-style dark mode.

📶 Full Offline Capability: Embedded local storage and assets enable full offline access to interactive maps, location photos, turn-by-turn navigation, custom itinerary planners, settings, and saved places without requiring an active internet connection.

🔎 Dynamic Entity Registry: Real-time search and categorization for historic landmarks, fortifications, public parks, and educational hubs.

🧭 Live GPS Navigation Mode: Simulated route vectoring with turn-by-turn guidance, distance estimation, and local transport options (Tranvia, Kalesa, E-Trike).

🎯 Curated Itinerary Engine: Custom travel planning based on group dynamics (Solo, Couples, Groups) and budget constraints.

🤖 IntraBadi Chatbot: An AI-powered virtual guide providing real-time assistance, answering questions about Intramuros' rich history, and offering personalized travel recommendations.

♿ Accessibility Support Overlay: Dedicated accessibility mode highlighting low-cobblestone routes, audio narration cues, and wheelchair-friendly pathways.

## Setup

This project uses three API keys, loaded through two mechanisms — **none of them are ever committed to git.** Get real key values from your team lead, or generate your own (see the per-key sections below).

1. **Copy the two example files and fill in real keys:**

   ```sh
   cp android/local.properties.example android/local.properties
   cp env.json.example env.json
   ```

   (On Windows PowerShell: `Copy-Item android/local.properties.example android/local.properties` and `Copy-Item env.json.example env.json`.)

2. Edit `android/local.properties` and set `flutter.sdk` (path to your local Flutter SDK) and `MAPS_API_KEY` (see [Google Maps setup](#setting-up-the-google-maps-api-key-android) below).
3. Edit `env.json` and set `ORS_API_KEY` and `GEMINI_API_KEY` (see [OpenRouteService setup](#setting-up-the-openrouteservice-api-key) below).
4. Run:

   ```sh
   flutter clean && flutter run
   ```

   **The Maps key requires a full rebuild, not a hot reload.** It's read natively (`android/local.properties` → `android/app/build.gradle.kts` → a Gradle `manifestPlaceholders` entry → `AndroidManifest.xml`), so it's baked in at native/Gradle build time — a hot reload or hot restart won't pick up a key you just added or changed, only a fresh `flutter run` (ideally after `flutter clean`) will.

Both `android/local.properties` and `env.json` are gitignored (`android/.gitignore`'s `/local.properties` line and the root `.gitignore`'s `env.json` line, respectively) — only the `.example` templates above are committed.

### Why two mechanisms?

- **`MAPS_API_KEY`** (Google Maps) is Android-native only — there's no Dart-side or JSON path for it. It's read from `android/local.properties` by `android/app/build.gradle.kts` at Gradle build time and injected into `AndroidManifest.xml` via the `${mapsApiKey}` manifest placeholder.
- **`ORS_API_KEY`** and **`GEMINI_API_KEY`** are Dart-side. Each is resolved at runtime in this order:
  1. A compile-time `--dart-define` value, if one was supplied when running/building (this is what `.vscode/launch.json`'s `--dart-define-from-file=env.json` sets up automatically for the two VS Code launch configs).
  2. Otherwise, the same-named entry read from the bundled `env.json` asset at runtime (see `lib/services/routing_service.dart` and `lib/services/gemini_api_key_loader.dart`) — this is what makes the key load automatically for *any* launch method (Android Studio's Run button, a plain `flutter run`, hot restart), not just ones that pass the `--dart-define` flag explicitly.

  Both paths read the same `env.json` file, so filling it in once covers every way of running the app.

## Run in Android Studio

1. Open this `intravel-hackathon` folder in Android Studio.
2. Wait for the Gradle and Flutter sync to finish.
3. Choose an emulator or connected Android phone.
4. Press **Run**.

The dashboard source is in `assets/intravel/index.html`; its local images are in `assets/intravel/assets/`. The Flutter entry screen is `lib/main.dart`.

## Google Maps Integration

The app's map screens — `lib/screens/navigation_screen.dart` (live GPS turn-by-turn guidance), `lib/screens/itinerary_navigation_overview_screen.dart` (itinerary route overview), and `lib/screens/osm_poi_map_screen.dart` (standalone POI explorer + walking-route lookup) — all use `google_maps_flutter` (Android only in this build) as the base map layer. Each requires a Google Maps API key wired via native Android config — see setup below. If the key is missing/invalid or the map otherwise fails to load, `osm_poi_map_screen.dart` automatically falls back to a non-map POI list (same photos/names/categories, still tappable) instead of crashing or showing a blank screen.

### Explore POIs Map & Walking Routes

The **Explore POIs** screen (`lib/screens/osm_poi_map_screen.dart`, reachable from the "Explore POIs" button on the Navigation tab) is a standalone map for browsing points of interest and looking up walking routes between them:

- **POI pins**: loaded once, offline, from the bundled `assets/data/pois.json` (schools, churches, attractions, historic sites). Tapping a pin shows a photo + name + category bottom sheet. Regenerate this file with `dart run tool/fetch_pois.dart` (queries the Overpass API — a build-time tool only, never called at runtime).
- **Walking routes**: real, street-following directions between any two POIs, powered by the [OpenRouteService](https://openrouteservice.org/) Directions API (`foot-walking` profile) via `lib/services/routing_service.dart`.

### Setting up the Google Maps API key (Android)

1. In the [Google Cloud Console](https://console.cloud.google.com/), create/select a project, enable the **Maps SDK for Android**, attach a billing account (required by Google even for free-tier usage), and generate an API key.
2. Put that key in `android/local.properties` (copied from `android/local.properties.example` — see [Setup](#setup) above) as `MAPS_API_KEY=your_key_here`. **Never** put a real key directly in `AndroidManifest.xml` or any other committed file — the manifest only references it indirectly via `${mapsApiKey}`, filled in from `local.properties` at build time.
3. To limit a leaked key's blast radius, restrict it in Google Cloud Console to your app's SHA-1 fingerprint + package name (`com.example.intravel`).
4. Rebuild the app (`flutter clean && flutter run`) after adding/changing the key — a hot reload alone won't pick up native config changes.

If the key is missing or invalid, `osm_poi_map_screen.dart`'s map area shows a "Map unavailable — check the Google Maps API key" fallback with the POI list still browsable underneath, rather than crashing.

### Setting up the OpenRouteService API key

Each teammate should sign up for their own free key rather than sharing one — it takes under a minute and keeps everyone's usage/quota separate.

1. Sign up for a free API key at [openrouteservice.org/dev/#/signup](https://openrouteservice.org/dev/#/signup), then copy the key from your ORS dashboard.
2. Put it in `env.json` (copied from `env.json.example` — see [Setup](#setup) above) as the `ORS_API_KEY` value. **Never** paste the key into a source file or commit it — `env.json` is gitignored specifically so this is safe.

Alternatively, without touching `env.json`, you can pass it directly at build/run time:

```sh
flutter run --dart-define=ORS_API_KEY=your_key_here
```

Or for a release build:

```sh
flutter build apk --dart-define=ORS_API_KEY=your_key_here
```

The compile-time `--dart-define` value always takes priority over `env.json` when both are present (see [Why two mechanisms?](#why-two-mechanisms) above).

If no key is provided through either path, the routing call fails gracefully with an inline "routing not configured" message instead of crashing — the POI map and pins still work normally, only the walking-route lookup is affected.
