# InTravel

**Hackathon Project**: Developed as a competitive hackathon entry featuring precision navigation, dynamic route planning, and accessible travel tools for historic cultural heritage sites.

The InTravel dashboard is bundled as a Flutter app and opens in an Android WebView. It works offline, including maps, location photos, navigation, planner, settings, saved places, and the Apple-style dark mode.

**InTravel: Intramuros High-Precision Navigation Engine**

InTravel is a responsive, single-page progressive web application designed to guide travelers through the historic walled city of Intramuros in Manila, Philippines. Built with modern web standards, it delivers a smooth native-like mobile experience with dynamic route planning, site history, interactive mapping, and accessible travel options.

## Features

**Native Mobile-First UI Shell**: Optimized for responsive touch screens with fixed status metrics, dynamic viewport scaling, and an Apple-style dark mode.

**Full Offline Capability**: Embedded local storage and assets enable full offline access to interactive maps, location photos, turn-by-turn navigation, custom itinerary planners, settings, and saved places without requiring an active internet connection.

**Dynamic Entity Registry**: Real-time search and categorization for historic landmarks, fortifications, public parks, and educational hubs.

**Live GPS Navigation Mode**: Simulated route vectoring with turn-by-turn guidance, distance estimation, and local transport options (Tranvia, Kalesa, E-Trike).

**Curated Itinerary Engine**: Custom travel planning based on group dynamics (Solo, Couples, Groups) and budget constraints.

**IntraBadi Chatbot**: An AI-powered virtual guide providing real-time assistance, answering questions about Intramuros' rich history, and offering personalized travel recommendations.

**Accessibility Support Overlay**: Dedicated accessibility mode highlighting low-cobblestone routes, audio narration cues, and wheelchair-friendly pathways.

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
2. Open `android/app/src/main/AndroidManifest.xml` and replace the placeholder value in the `com.google.android.geo.API_KEY` meta-data tag with your real key:
   ```xml
   <meta-data
       android:name="com.google.android.geo.API_KEY"
       android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE" />
   ```
3. **Never commit your real key to a public repo.** For a shared team repo, either:
   - keep the placeholder committed and have each teammate paste in their own key locally before running (don't commit the change), or
   - restrict the key in Google Cloud Console to your app's SHA-1 fingerprint + package name (`com.example.intravel`) so a leaked key has limited blast radius.
4. Rebuild the app (`flutter run`) after changing the manifest — a hot reload alone won't pick up native config changes.

If the key is left as the placeholder or is otherwise invalid, `osm_poi_map_screen.dart`'s map area shows a "Map unavailable — check the Google Maps API key" fallback with the POI list still browsable underneath, rather than crashing.

### Setting up the OpenRouteService API key

Each teammate should sign up for their own free key rather than sharing one — it takes under a minute and keeps everyone's usage/quota separate.

1. Sign up for a free API key at [openrouteservice.org/dev/#/signup](https://openrouteservice.org/dev/#/signup), then copy the key from your ORS dashboard.
2. **Never paste the key into a source file or commit it** — it's passed in at build/run time only, via `--dart-define`.

**Running from the command line:**

```sh
flutter run --dart-define=ORS_API_KEY=your_key_here
```

Or for a release build:

```sh
flutter build apk --dart-define=ORS_API_KEY=your_key_here
```

**Running from Android Studio (so you don't retype the flag every run):**

1. Run → Edit Configurations…
2. Select your Flutter run configuration (usually named `main.dart`).
3. In "Additional run args", add:
   ```
   --dart-define=ORS_API_KEY=your_key_here
   ```
4. Apply, then just press **Run** as normal — the key is picked up automatically from now on for that configuration, and it's stored in your local IDE settings, not in a committed file.

If no key is provided, the routing call fails gracefully with an inline "routing not configured" message instead of crashing — the POI map and pins still work normally, only the walking-route lookup is affected.
