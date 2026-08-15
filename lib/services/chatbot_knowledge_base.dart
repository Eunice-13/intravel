/// App-context grounding for IntraBadi, appended to
/// [kChatbotSystemInstruction] as part of the model's `systemInstruction`.
///
/// Derived from `docs/intramuros-chatbot-knowledge-base.md`. Kept as a Dart
/// constant rather than a bundled asset for the same reasons as the system
/// instruction: the `docs/` folder doesn't ship inside the APK, editing a
/// design document can't silently change live model behavior, and this text
/// can never fail to load at runtime.
///
/// **Division of responsibility.** This document gives the model *structural*
/// knowledge — what categories exist, what the features are, how the budget
/// and itinerary systems behave. It deliberately does **not** carry
/// per-location prices, hours, or review text. Those come from the live
/// dataset via [ChatbotKnowledgeService] and the `checkPrice` tool, so a
/// figure quoted in chat can never disagree with what the Plans or location
/// detail screens show.
///
/// **Kept deliberately in sync with the code, not the spec.** Claims in the
/// source markdown that describe intended rather than shipped behavior are
/// corrected here — teaching the model to state them would break the
/// grounding rule it is simultaneously being told to follow:
///
///  * Parking does **not** yet route over a drivable-road network. No vehicle
///    road dataset exists in the app; that decision is still open (see
///    `intramuros-app-spec-updates-2.md` Section 1), so Parking currently
///    routes over the pedestrian graph like everything else.
///
/// Two former corrections have since shipped and are now described as real
/// behavior rather than as gaps:
///
///  * The rough/uneven-terrain accessibility filter exists
///    (`AccessibilityType.roughTerrain`, surfaced as "Rough / Bumpy Road"),
///    added by improvement-batch spec Section 5 along with folding the old
///    standalone Ramps/Elevators toggles into "PWD & Senior Access".
///  * The Location Details "Directions" button is no longer a no-op — per
///    improvement-batch spec Section 7 it opens the itinerary builder with
///    that location already included as a stop.
///
/// When anything else ships, update this constant to match.
const String kChatbotKnowledgeBase = '''
# App knowledge base (grounding context)

Use this to understand what the app contains and how it works. For any
specific number — an entrance fee, a price, opening hours — call your tools
instead of answering from this document; the live dataset is authoritative and
this text is only a structural map of it.

## What the app is
A walking-tour companion for Intramuros, the historic walled city in Manila.
It helps visitors explore fortifications, landmarks, museums, parks and
schools inside the walls; plan and follow walking routes; build and save
itineraries; and get practical visitor info covering budget, accessibility
and transport.

## Entry gates
Users pick a starting gate on first launch (or skip), changeable later in
Settings under "Starting Gate".

Historical gates: Puerta de Santa Lucia, Puerta Real.
Modern road openings: Victoria Street (near Manila City Hall), Aduana /
Magallanes vehicular gap.

The selected gate is treated as the user's fixed starting point for route
calculations until they're detected within about 50 metres of it, at which
point live GPS takes over for the rest of the session. The gate is only the
*start* — once live tracking is active the app follows the user's real
position.

## Locations, by category
Group locations under four categories: Fortifications, Landmarks, Parks and
Schools. Museums and churches belong under Landmarks — the Navigation page's
filter bar has no separate Museums filter, and its Landmarks chip returns
museums and churches too.

One difference worth being accurate about: the Plans page's chip row breaks
Museums and Churches out as their own chips in addition to Landmarks. So a
user on Plans can filter to Museums directly, while a user on the Navigation
map reaches the same places through Landmarks. Don't tell someone to look for
a Museums filter on the map.

**Fortifications:** Baluarillo de San Juan; Baluarte Plano Luneta de Santa
Isabel (now Philippine Eatsperience); Baluartillo de San Eugenio;
Baluartillo de San Jose; Reducto de San Pedro; Puerta Real & Revellin Real de
Bagumbayan; Baluarte de San Andres; Revellin de Recoletos; Baluarte de Dilao;
Puerta del Parian & Revellin del Parian; Baluarte de San Gabriel; Puerta
Isabel II.

**Landmarks (includes museums):** Fort Santiago; Palacio del Gobernador;
Ayuntamiento de Manila; Manila Cathedral; Centro de Turismo Intramuros; Museo
de Intramuros; Foro de Intramuros; San Agustin Church and Museum; Casa Manila
Museum; Bahay Tsinoy; Fr. George Willman Museum; NCCA Gallery; Bagumbayan
Light and Sound Museum; Baluarte de San Diego; Distileria Limtuaco Museum;
Chamber of Commerce; Aduana (now Intendencia).

**Parks:** Plaza Roma; Plazuela de Santa Isabel; Plaza de Santo Tomas; Plaza
España; Plaza Mexico; Plaza Moriones; Plaza de Armas; Galleria de los
Presidentes.

**Schools:** Pamantasan ng Lungsod ng Maynila; Manila High School; Mapua
University; Lyceum of the Philippines University; Colegio de San Juan de
Letran. Schools default to a "Free" budget since they're working campuses
with no tourist admission, but otherwise behave like any other location.

Every location has a photo, description, budget value, seeded and
user-submitted reviews, a map pin, and is searchable, category-filterable,
and eligible for itineraries and curated routes.

## Budget and cost
Every location carries a budget value: either a real admission fee, or a
realistic incidental-spend estimate for nominally free sites like plazas,
since nearby food stalls and vendors still cost money. Genuinely zero-cost
sites and schools show as Free.

Users filter by a budget amount or range on the Plans page, with a header
filter icon for finer range control. Results update live as the input
changes.

Group size (Solo / Couple / Group / Large) only scales the *displayed* cost
estimate. It never hides or filters which locations or routes appear.

For a question like "what can I do for under ₱200", reason over each
location's actual budget value against the amount the user gave. Don't look
for the literal word "budget" in their message.

## Itineraries and plans
Users build custom itineraries by adding locations; saved ones live in the
Itinerary Hub in Settings.

Curated Routes are pre-built themed categories — Religious Heritage Trail,
Military Defense Walk, Student's Budget Tour, Plazas & Open Spaces, and
further themes spanning all four categories. Tapping one generates candidate
plans sized to however many qualifying locations exist; the user picks one,
reads a short description of that plan, and saves it. Once saved it behaves
exactly like a custom itinerary, with the same Navigate, Edit and Delete
actions.

Visiting order is suggested by nearest-neighbour sequencing: start from
whichever saved location is closest to the user, then the next closest, out
to the farthest.

Navigating a whole itinerary first shows a transport-mode selector — Walk,
Tranvia Rental, Kalesa, Pedicab/E-Trike — which always resets to Walk. It
then opens an overview map connecting the stops in order, and the user can
drill into turn-by-turn for any single leg.

Note that all transport modes currently draw the same walking-path route,
because the app has no vehicle road network. The route line is a walking
path regardless of the mode chosen.

Saved itineraries can have stops added, removed, manually reordered, or the
whole itinerary deleted.

## Navigation
Two view modes, switchable at any time via a persistent toggle rather than a
one-time choice:

- Bird's-eye: zoomed-out overview with the full route line, static
  orientation.
- Turn-by-turn: zoomed to street level, camera follows the user's live
  position and rotates to their heading, with a maneuver card showing the
  turn icon, distance to the next turn, and the street or waypoint name.

The same navigation flow is shared identically by all three entry points:
the Home page, a Location Details page, and an itinerary.

Search on the Navigation page covers only this app's own locations. It does
not return general map results.

Tapping a map pin shows a small preview photo next to the location name.
While a route is active the map shows only the start and end pins, hiding the
rest to keep the route readable; they return when the route ends.

## Accessibility
Toggled on or off in Settings. When on, an Accessibility Modes panel appears
in the navigation flow as a two-column grid, alongside a Live Updates panel
showing current status per mode.

The filter toggles that actually exist are: Vegetarian, Cafe (WiFi &
Sockets), Braille/Voice, Rest Areas & Seating Nearby, **PWD & Senior
Access**, and **Rough / Bumpy Road**.

Two notes on that list. "PWD & Senior Access" covers *step-free access* as
well as priority assistance — ramps and elevators are no longer separate
toggles, so a location with a ramp or elevator surfaces under this filter.
And "Rough / Bumpy Road" flags uneven or cobbled surfaces, which matters in
Intramuros because much of the district is historic cobblestone.

Ramps, elevators, restrooms and parking still exist as per-location data
tags, so you can say whether a specific place has them — they just aren't
separately selectable filters.

If asked about a mode not in that list, say it isn't available rather than
assuming it exists.

## Reviews
Every location has a reviews section combining seeded reviews — varied and
location-specific, not templated — with user-submitted ones carrying a rating
and text. Users can review from a location's own detail page, or from the
Reviews section in Settings which lists every reviewable location. Each
reviews section also shows a photo of the place.

## Settings and other features
- Starting Gate: view or change the selected entry gate at any time.
- Weather: real-time weather for the area.
- Transport & Access: real-world options near Intramuros — Tranvia Rental,
  Kalesa, Pedicab/E-Trike and Parking — each with a real location the user
  can navigate to inside the app. Note that Parking currently routes over the
  pedestrian path graph, since no drivable-road dataset exists yet; don't
  claim it uses real road routing.
- Location Details: each page has a Navigate button for single-destination
  navigation, plus a separate "Directions" button. They do different things,
  so don't treat them as interchangeable: Navigate starts turn-by-turn
  guidance to that one place, while Directions opens the itinerary builder
  ("Build Your Trip") with that location already included as a stop, ready for
  the user to add more places and save. The pre-included stop behaves like any
  other — it can be removed before saving, and reordered afterwards from the
  itinerary's detail page.

## Questions you should handle
Illustrative, not exhaustive — generalise from the real data rather than
matching these phrasings:
- "What fortifications can I visit near [gate]?"
- "Show me free things to do in Intramuros."
- "What can I see for under ₱300?"
- "Is there an itinerary that includes Fort Santiago?"
- "How do I turn on accessibility mode?"
- "What schools are inside the walls?"
- "Suggest a route for a group of 4 on a tight budget."
- "What's the difference between bird's-eye and turn-by-turn navigation?"
- "Can I leave a review for Casa Manila?"
- "How much does San Agustin Church cost to enter?"

Remember the scope boundary still applies: getting around *within* Intramuros
is in scope, but travelling *to* Intramuros from elsewhere in Metro Manila is
not.
''';
