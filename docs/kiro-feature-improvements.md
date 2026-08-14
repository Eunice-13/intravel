# Feature Improvement Spec — App Update Batch

## Context
This spec covers a batch of UX and functional fixes/improvements to the existing Intramuros travel/navigation app. Each section is self-contained and can be implemented as a separate task, but they share app data (locations, itineraries, accessibility tags) so keep data models consistent across all of them.

---

## 1. Chatbot — Move from Keyword Matching to Full Question Understanding

### Problem
The current chatbot only responds to specific hardcoded keywords. If a user phrases a question differently, or asks something the keyword list didn't anticipate, it fails to answer even when the app already has the relevant data.

### Requirements
1. WHEN a user submits any natural-language question THE SYSTEM SHALL attempt to answer it using the app's existing data (locations, categories, itineraries, budgets, accessibility tags, hours, etc.) instead of matching against a fixed keyword list.
2. WHEN a user's question references a location, category, budget range, or itinerary type THE SYSTEM SHALL extract that intent regardless of exact phrasing (e.g. "cheap food near Fort Santiago," "where can I bring my grandma," "places under 500 pesos" should all resolve correctly).
3. WHEN a user asks a question that combines multiple filters (e.g. location + budget + accessibility) THE SYSTEM SHALL apply all filters together and return matching results from app data.
4. IF the question cannot be answered from app data (out-of-scope, e.g. general trivia unrelated to the app) THEN THE SYSTEM SHALL respond that it can only help with information available in the app, rather than guessing or hallucinating.
5. WHERE the underlying data changes (new locations, updated prices, updated hours) THE SYSTEM SHALL reflect the update immediately without requiring new keyword rules to be hardcoded.

### Technical Notes
- Replace keyword/if-else matching with an intent + entity extraction approach (e.g. small NLU model or LLM-based query understanding) that maps free-text questions to structured queries against the app's location/itinerary database.
- Define a structured schema the chatbot can query: `{category, budget_min, budget_max, accessibility_tags, area, hours}` so any parsed intent can be turned into a filter against real data.
- Keep responses grounded strictly in app data — no answers should be fabricated outside of what exists in the database.

### Acceptance Criteria
- [ ] Chatbot answers rephrased/synonym versions of previously-supported questions correctly.
- [ ] Chatbot correctly filters by budget range when asked (e.g. "₱200–₱500").
- [ ] Chatbot correctly filters by combined criteria (budget + location + category).
- [ ] Chatbot gracefully declines out-of-scope questions instead of guessing.

---

## 2. Settings — Remove Standalone "Satellite Map" Toggle

### Problem
Settings has a separate Satellite Map option, but satellite view is already toggleable directly from the navigation/map screen, making the Settings entry redundant.

### Requirements
1. WHEN a user opens Settings THE SYSTEM SHALL NOT display a "Satellite Map" toggle.
2. THE SYSTEM SHALL leave the satellite view toggle inside the navigation/map screen completely unchanged (same position, same behavior).
3. WHERE satellite preference was previously stored via the Settings toggle THE SYSTEM SHALL migrate/preserve that stored preference so the in-map toggle still reflects the user's last choice (no behavior regression, just relocation of the control).

### Acceptance Criteria
- [ ] Satellite option no longer appears in Settings.
- [ ] In-map satellite toggle still works exactly as before.
- [ ] No duplicate or broken state between the removed Settings entry and the in-map toggle.

---

## 3. Move "Transport and Access" from Settings to Home Page

### Problem
"Transport and Access" currently lives in Settings and in a "starting gate" step, but it's a frequently-needed feature that should be more accessible from the main Home screen.

### Requirements
1. WHEN a user opens Settings THE SYSTEM SHALL NOT display the "Transport and Access" option.
2. WHEN a user is prompted at the starting gate/onboarding flow THE SYSTEM SHALL NOT show "Transport and Access" there either — it is fully removed from both locations.
3. WHEN a user opens the Home page THE SYSTEM SHALL display a "Transport and Access" section positioned directly below the "Travel Your Way" banner.
4. THE SYSTEM SHALL render "Transport and Access" options as a two-column grid layout on the Home page.
5. WHEN a user taps a transport/access option on the Home page THE SYSTEM SHALL trigger the same functionality that previously existed in Settings/starting gate (no feature loss — pure relocation).

### Acceptance Criteria
- [ ] "Transport and Access" no longer appears in Settings.
- [ ] "Transport and Access" no longer appears in the starting gate flow.
- [ ] "Transport and Access" appears on Home, directly beneath the "Travel Your Way" banner, in a 2-column layout.
- [ ] All original functionality/options still work identically from the new location.

---

## 4. Map Movement — Free Panning/Zooming + Re-center Button

### Problem
The map currently locks/snaps back to the user's current position whenever they try to drag or zoom, preventing free exploration of the map.

### Requirements
1. WHEN a user drags the map THE SYSTEM SHALL allow the map to pan freely without snapping back to the current location.
2. WHEN a user pinch-zooms or double-taps to zoom THE SYSTEM SHALL allow free zoom in/out without forcing the camera back to the current position.
3. WHEN the map is not centered on the user's current location THE SYSTEM SHALL display a re-center button fixed to the side of the screen (e.g. bottom-right, above other floating controls).
4. WHEN a user taps the re-center button THE SYSTEM SHALL smoothly animate the camera back to the user's current location/pin at the default zoom level.
5. WHILE the user is actively navigating turn-by-turn THE SYSTEM SHALL still allow the user to pan away to inspect the map, and the re-center button SHALL bring them back into "follow" mode.
6. WHEN the map re-enters follow mode (either automatically or via the re-center button) THE SYSTEM SHALL resume automatic camera tracking until the user manually pans again.

### Acceptance Criteria
- [ ] Dragging the map no longer snaps back automatically.
- [ ] Zooming in/out is unrestricted and doesn't reset.
- [ ] A visible re-center button appears on the side of the screen once the user has panned away.
- [ ] Tapping re-center smoothly returns to current location and resumes follow mode.

---

## 5. Accessibility Options — Consolidate & Replace

### Problem
Current accessibility filter list has redundant/overly granular options and is missing a useful "terrain condition" filter.

### Requirements
1. THE SYSTEM SHALL remove "Ramps" and "Elevators" as standalone accessibility filter options.
2. THE SYSTEM SHALL fold the functional intent of "Ramps" and "Elevators" (i.e., step-free/wheelchair-navigable access) into the existing "PWD and Senior" accessibility option, so filtering by "PWD and Senior" already surfaces locations with ramp/elevator access.
3. THE SYSTEM SHALL remove the "Audio-described" option.
4. THE SYSTEM SHALL replace "Audio-described" with a new option that indicates whether the route/location has a rough or bumpy road surface (e.g. "Smooth Path" vs "Rough/Bumpy Road" indicator), so users can avoid or anticipate uneven terrain.
5. WHEN a user filters by "PWD and Senior" THE SYSTEM SHALL only surface locations that are step-free/ramp-or-elevator accessible.
6. WHEN a user filters by the new terrain option THE SYSTEM SHALL only surface locations/routes matching the selected terrain condition.

### Acceptance Criteria
- [ ] "Ramps" and "Elevators" no longer appear as separate options.
- [ ] "PWD and Senior" filter results include only locations that were previously tagged Ramp/Elevator-accessible.
- [ ] "Audio-described" option is gone.
- [ ] New "Rough/Bumpy Road" (terrain) option is present and functional.

---

## 6. Location Data — Fill In Sensible Placeholder Locations

### Problem
Most category location lists are placeholders/incomplete. The "Cafe" category is already correct and should not be touched.

### Requirements
1. THE SYSTEM SHALL leave the "Cafe" category's existing data completely untouched.
2. FOR all other categories THE SYSTEM SHALL populate locations with realistic, sensible entries appropriate to that category.
3. THE SYSTEM SHALL ensure all generated/placeholder locations fall within the actual Intramuros district boundaries.
4. THE SYSTEM SHALL NOT place any location in water (e.g. Manila Bay, the moat) or outside the Intramuros wall boundary.
5. WHERE real-world reference is useful THE SYSTEM SHALL use real Intramuros landmarks/establishments as a basis; WHERE no clean real-world match exists THE SYSTEM MAY use a plausible generic name/coordinate within Intramuros, as long as it stays believable and within bounds.

### Acceptance Criteria
- [ ] Cafe category data is unchanged.
- [ ] All other categories have complete, plausible entries.
- [ ] No entries fall outside Intramuros or in water.
- [ ] Coordinates spot-checked against an Intramuros map boundary.

---

## 7. Location Details — Fix Non-Functional Directions Button

### Problem
The "Directions" button inside a location's detail view currently does nothing.

### Requirements
1. WHEN a user taps "Directions" on a location detail screen THE SYSTEM SHALL NOT attempt (or fail at) inline turn-by-turn launch as before.
2. WHEN a user taps this button THE SYSTEM SHALL instead redirect the user to the Itinerary Options screen.
3. WHEN the user lands on Itinerary Options via this button THE SYSTEM SHALL automatically pre-include the originating location as a stop in the itinerary being built/selected.
4. WHEN the user proceeds from Itinerary Options THE SYSTEM SHALL treat this pre-included location the same as any manually-added itinerary stop (editable, removable, reorderable).

### Acceptance Criteria
- [ ] Directions button no longer no-ops.
- [ ] Tapping it opens Itinerary Options.
- [ ] The originating location appears already added to the itinerary.
- [ ] User can still edit/remove/reorder that stop normally.

---

## 8. Navigation View — Floating Location Info Above Live Updates

### Problem
During turn-by-turn/bird's-eye navigation, the space below the location name/ETA/distance is empty and wastes screen space.

### Requirements
1. WHEN a user is in turn-by-turn or bird's-eye navigation view THE SYSTEM SHALL render the location name, ETA, and distance in a smaller, compact format (reduced from current size).
2. THE SYSTEM SHALL position this compact info block as a floating element directly above the "Live Updates" panel.
3. WHEN the user taps the "up" (expand) button on Live Updates THE SYSTEM SHALL animate the compact location/ETA/distance block upward in tandem, so it stays floating just above the expanded Live Updates panel rather than being covered or left behind.
4. WHEN the user collapses Live Updates (taps "down") THE SYSTEM SHALL animate the floating block back down to its default resting position above the collapsed panel.
5. THE SYSTEM SHALL keep the floating block legible at its reduced size (name, ETA, distance all remain readable) at all supported screen sizes.

### Acceptance Criteria
- [ ] Location name/ETA/distance block is now smaller and floats directly above Live Updates.
- [ ] Expanding Live Updates pushes the block up smoothly, no overlap/clipping.
- [ ] Collapsing Live Updates returns the block to its default position.
- [ ] No more empty/dead space below the location info block.

---

## Implementation Priority (Suggested)
1. Settings cleanup (#2, #3) — low risk, quick win, unblocks Home page work.
2. Home page transport/access relocation (#3).
3. Accessibility filter consolidation (#5) — data model change, do before location data fill-in.
4. Location data fill-in (#6).
5. Directions button fix (#7) — depends on itinerary screen accepting pre-filled stops.
6. Map panning + re-center button (#4).
7. Navigation floating info block (#8).
8. Chatbot NLU upgrade (#1) — largest scope, tackle once data model from #5/#6 is stable since chatbot will query against it.
