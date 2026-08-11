# Intramuros App — Development Spec for Kiro AI

## Context
This document specifies improvements to an existing Intramuros walking-tour app. The current visual design is approved and must be preserved — all changes below are about **functionality**, not restyling. Treat this as a feature/requirements spec: implement each section as described, and flag any ambiguity before deviating from it.

**Design constraint (applies to every section below):** Reuse existing components, color tokens, spacing, and typography. No new design language should be introduced. Any new screen or state (empty states, loading states, modals, filter chips, etc.) must visually match the current design system.

---

## 1. Entry Flow — Gate Selection

**Requirement:** Before the user can access the app's homepage, prompt them to select which Intramuros gate they are currently near/entering from. This selection determines their starting point for navigation and orientation.

### 1.1 Gates to include
**Historical gates:**
- Puerta de Santa Lucia
- Puerta Real

**Modern road openings:**
- Victoria Street opening (near Manila City Hall)
- Aduana / Magallanes vehicular gap

### 1.2 Requirements
- Gate selection is **skippable but strongly encouraged**: the screen should present a clear "Skip" option, but should visually/textually nudge the user to select their gate first (e.g., a short line explaining that selecting a gate improves navigation accuracy). The homepage remains reachable either way.
- Each gate option must display a real reference photo of that gate. **Sourcing method:** manually search the internet (Google Images/Google Maps listings, tourism sites, etc.) for a clear, representative photo of each gate and add it as static content in the app — no live API pull needed for these images.
- Layout should be a simple selection screen (grid or list of cards) consistent with the existing design system — card image, gate name, short label (historical vs. modern opening).
- Selected gate should be stored (e.g., in app/user state) and used to set the user's initial position/orientation on the navigation map.

---

## 2. Navigation Page

### 2.1 General functionality
- All UI elements on the navigation page must be fully functional — no dead buttons, static mockups, or placeholder states.
- The interaction pattern should be modeled closely on **Google Maps' walking navigation experience**, including:
  - Turn-by-turn directions during active navigation
  - Live route line/path rendering
  - Distance and ETA display
  - Re-centering / "return to route" behavior if the user pans away

### 2.2 Tap behavior — distinguishing "tap a pin" vs. "Navigate Now"
Two distinct interactions must be supported on the navigation page:

**A. Direct tap on the navigation page (not the "Navigate Now" button)**
- Reveals a **filter bar** with the following categories:
  - Fortifications
  - Landmarks
  - Schools
  - Parks
- Selecting a filter shows only the pinned locations belonging to that category on the map.
- Filters are **multi-select** — the user can activate more than one category at once, and the map should show the union of all active categories' pins. Each active filter must clearly indicate its selected state (matching existing design system for toggles/chips).

**B. "Navigate Now" button**
- Initiates turn-by-turn walking navigation to the selected destination, styled like Google Maps' active navigation mode (see 2.1).

### 2.3 Search
- Add a functional search bar on the navigation page, behaving like Google Maps search-as-you-type (results filter/narrow as the user types, tapping a result centers/pins it on the map).
- **Scope constraint:** search results must be limited exclusively to locations already listed within the Intramuros app's dataset — do not pull in general Google Maps results.

### 2.4 Reviews
- Every location listed in the app must have a reviews section.
- Reviews do not need to be pulled live from Google Maps. Generate a small set of plausible, varied reviews per location (e.g., 3–6 each) and add them as static content — same manual-content approach as the photos above.
- Each location's set of reviews must be **distinct from every other location's** — vary the reviewer names, star ratings, phrasing, and what's mentioned (e.g., don't reuse the same comment about "great historical site" across multiple locations word-for-word). Reviews should read like they're about that specific place, not a generic template.
- Review display should match existing design system components (rating, reviewer name/snippet, etc. — confirm exact fields against current UI if a review component already exists elsewhere in the app).

---

## Notes on Content Sourcing
Both photos (Section 1.2 / 2.4) and reviews (Section 2.4) are now static, manually-added content rather than live API pulls — no Google Places API integration is required for this version of the app. This keeps the build simple and free of API costs/rate limits, at the cost of the images/reviews not staying current automatically. If live, always-up-to-date Google data becomes a priority later, that would require revisiting this decision and integrating the Places API instead.

---

## 3. Itinerary Page

### 3.1 Current state
The itinerary page is currently broken/not rendering correctly. Reference the working implementation from the **`Eunice-branch`** on the project's GitHub repo and restore/rebuild the itinerary page to match that baseline functionality before layering in the new features below.

### 3.2 Budget filter
- Add a budget input field.
- When a budget value is entered, the itinerary/location list should filter to show only locations whose associated cost falls within that budget range.
- Define "within range" clearly (e.g., ≤ entered amount, or a min–max range field — confirm which makes more sense given the existing cost data structure).
- **Cost data does not yet exist per location.** Kiro should research realistic entrance fees / cost ranges for each listed Intramuros location (e.g., museum entrance fees, park access, guided tour costs — many sites are free, which should be reflected as ₱0 or "Free" rather than left blank) and add this as a new field in each location's details, to power the budget filter above.

### 3.3 Custom itinerary creation
- Add an **"Add" button** that lets users build their own itinerary by selecting locations from the app's listings.
- Once the user finishes building their itinerary, it should be saved and appear in an **Itinerary Hub**, located in **Settings**.

### 3.4 Itinerary Hub — route sequencing
For each saved itinerary in the Itinerary Hub, the app should automatically suggest an optimal visiting order:
- Determine the user's current location.
- Identify the **nearest** itinerary location to the user's current position — this becomes stop #1.
- From that point, continue sequencing the **next-nearest unvisited location**, and so on, until all locations in the itinerary are ordered — ending with the farthest/last remaining stop.
- This produces a full structured route (nearest-neighbor-style path) covering every location in the user's itinerary, not just a single point-to-point direction.
- Note for implementation: this is a nearest-neighbor routing approach, which is a reasonable approximation but not guaranteed shortest-overall-path (true shortest path across many stops is a traveling-salesman-style problem). Nearest-neighbor is acceptable here unless higher route optimization is explicitly required later.

### 3.5 Editing
- Saved itineraries in the Itinerary Hub must be editable:
  - Add/remove locations
  - Manually reorder stops (in addition to the auto-suggested order)
  - Edit or delete the itinerary entirely
- All buttons (edit, delete, reorder, save changes) must be fully functional, not placeholders.

All requirements above are now fully specified — no open stakeholder questions remain. Kiro AI can proceed directly against this document.
