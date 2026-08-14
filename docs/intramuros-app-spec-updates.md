# Intramuros App — New Updates Spec (for Kiro AI)

## Context
This is a **standalone addendum** covering only the latest round of requested changes. It assumes the base app and the earlier full spec (`intramuros-app-spec.md`) are already in place — read that file first for context on pages, components, and prior decisions (gate selection, nav page filters, itinerary structure, etc.) before implementing anything here, since several items below extend those existing features.

**Design constraint (same as base spec):** Reuse existing components, color tokens, spacing, and typography. No new design language. Match the existing design system for any new UI state.

---

## 1. Navigation View Options

**Requirement:** Navigation supports two view modes:

1. **Bird's-eye view** — the current browse-mode map, with a route line drawn from the current/gate position to the destination. No turn-by-turn card needed — this is intentionally the simpler view.
2. **Turn-by-turn view** — step-by-step directions with:
   - A live heading indicator (shows which direction the user is facing)
   - Distance to the next turn
   - Current street name
   - Styled to match Google Maps' walking-navigation experience

### View-mode switching UI
- **Confirmed:** this is not a one-time upfront choice (no bottom sheet or dialog shown once at the start). Instead, provide a **persistent, tappable toggle icon** positioned on the side of the navigation screen, which the user can tap **at any time during navigation** to switch between Bird's-eye and Turn-by-turn view. The icon should clearly indicate current mode and/or what tapping it switches to.

### Panel behavior (turn-by-turn view)
- The live directions panel at the bottom must be **collapsible/draggable**, matching standard `DraggableScrollableSheet`-style behavior (drag anywhere on the panel to resize/dismiss it, revealing the full map underneath) — this is the confirmed behavior, matching Google Maps' feel.

### Consistency requirement
This exact flow — persistent view-mode toggle + collapsible-panel turn-by-turn — must be **identical across all three entry points**:
1. "Navigate Now" on the **Home page** — note: this button is already gated behind the user first picking a location on the Home page (i.e., there's no separate "no destination" case to design for — by the time Navigate Now is tappable/relevant, a location has already been selected, same as Location Details' Navigate button).
2. "Navigate" on a **Location Details** page
3. "Navigate" within an **Itinerary** (see Section 6 below — itinerary navigation additionally adds a transport-mode choice *before* this flow)

Do not build three separate implementations — this should be one shared navigation flow/component invoked from three places.

---

## 2. Back Button & Starting Location

### 2.1 Back button
- Add a back button to **every page** in the app, except:
  - The initial onboarding/gate-selection screen (nothing to go back to)
  - Home (root of the bottom nav)
- Standard platform back behavior: returns to the previous screen in the navigation stack. Consistent placement/styling across all pages.

### 2.2 Starting location — fixed gate position until arrival
- When the user has selected a starting gate (e.g., "Aduana") — from the first-launch gate-selection flow or from the "Starting Gate" setting — **use that gate's fixed coordinates as the starting position for route calculations**, not the user's live GPS location.
- This matters specifically because a user may open the app while physically far from Intramuros (e.g., elsewhere in Metro Manila) — routes should still calculate as if starting from the selected gate, not from wherever the user actually is yet.

### 2.3 Live tracking activation
- **Live GPS tracking activates once the user is detected within ~50 meters of their selected starting gate** (confirmed threshold — typical GPS accuracy range). Before that point, the app should not reposition the user's marker based on real-time GPS.
- Once the ~50m threshold is crossed, switch to real-time GPS tracking for the rest of the session within Intramuros (this is what powers live turn-by-turn in Section 1). **Confirmed:** once live GPS activates, it stays active for the remainder of that navigation session even if the user later moves more than 50m away from the gate again — it does not revert back to the fixed gate-position mode.
- If the user skipped gate selection entirely, fall back to standard real-time GPS behavior from app start (no fixed starting point to wait on).

---

## 3. Plans Page (Itinerary Page)

Reference: uploaded screenshot "4.0 - ITINERARY PAGE GROUP SIZE" shows the intended layout — "Travel Your Way" header with a filter icon top-right, group-size selector row (Solo/Couple/Group/Large), category chips (All Sites/Fortification/Landmarks/etc.), a "Curated Routes" list, and a budget input pinned above the bottom nav showing an "Est. total."

### 3.1 Budget filter (icon-triggered, not a permanent header display)
- The icon in the upper-right of the Plans page header (currently shown as a sliders/filter icon in the reference screenshot) opens a **more detailed budget range filter** (e.g., min–max range, possibly combined with other filter controls) — this is an additional/alternate entry point for finer control. This replaces the earlier idea of a permanent "total budget" display sitting where the logo is; the logo stays where it is, and the icon simply opens this detailed filter on tap.
- The **bottom budget bar** (the "Type your total budget..." input pinned above the bottom nav, with "Est. total" shown alongside) is **always visible** and serves as the quick, primary way to enter a budget — the user shouldn't need to open the header filter just to filter by budget. Both controls should read from and write to the same underlying budget filter state, so entering a value in one is reflected in the other (e.g., using the detailed range filter updates what's shown/implied by the bottom bar, and vice versa).

### 3.2 Group size selector
- Add a **group size selector** row: Solo / Couple / Group / Large (single-select, matching the reference screenshot's pill styling — selected state filled dark green).
- **Confirmed behavior:** group size does **not** filter which sites/routes appear. It only **adjusts the displayed cost estimate** (e.g., per-person pricing scales into a total that reflects the selected group size). All sites/routes remain visible regardless of group size selection.

### 3.3 Category chips
- Below the group-size row, add category filter chips: "All Sites," "Fortification," "Landmarks" (extend with any other categories already established elsewhere in the app, e.g., Schools/Parks from the Navigation page filter set in the base spec, if this page should mirror that same category list — confirm if unsure, otherwise default to matching Section 2.4 of the base spec's category list).

### 3.4 Curated Routes
- Add a **"Curated Routes"** section: a list of pre-built themed itinerary categories (matching the reference screenshot's examples — e.g., "Religious Heritage Trail," "Military Defense Walk," "Student's Budget Tour," "Plazas & Open Spaces"). Each entry shows an icon, name, "All group sizes" label, an estimated price range, and an estimated duration (e.g., "~4 hrs").
- **Tapping a curated route** generates a set of **system-made plan options** that qualify for that route's theme and estimated duration — e.g., tapping "Religious Heritage Trail" generates candidate itineraries built from sites tagged as religious/heritage sites, sequenced to roughly fit the ~4 hr estimate.
  - **Number of options generated:** left to Kiro's judgment based on how many qualifying sites exist for that category (i.e., don't force a fixed count like always-3 — generate as many sensible distinct options as the available site pool supports, within reason).
  - Each generated plan option should be selectable — the user reviews the option(s), picks one, and saves it.
- **Saving a curated-route plan:** once selected and saved, it's added to the **Itinerary Hub** in Settings, exactly like a manually-built custom itinerary (see base spec Section 5.4–5.7).
- **Feature parity with custom itineraries:** every curated-route-based itinerary, once saved, must have the **same functional buttons as a user-built itinerary** — Navigate (base spec Section 5.6, including transport-mode selector and view-mode choice), Edit, Reorder, Delete. A curated route is just a different *creation path* into the same itinerary object — it is not a separate, more limited type of itinerary.

### 3.5 Budget data — including free sites
- Add sample/randomized budget values to **every site**, including ones with no formal entrance fee (e.g., open plazas, public landmarks). For these, the estimated budget should reflect realistic incidental costs nearby (food stalls, souvenir vendors, parking, etc.) rather than showing "Free" — since the user pointed out these sites still carry a practical spending range even without an entrance ticket. Sites with a genuine, verifiable zero cost with no realistic incidental spend can still show "Free," but default to a small estimated range for typical tourist-facing spots (food/tourist areas) rather than defaulting to Free just because there's no formal entrance fee.
- These remain placeholder-realistic sample figures for now, consistent with the base spec's note on sample data (real-world sourcing can follow later).

### 3.6 Budget filter logic
- Filtering must work sensibly: entering/adjusting a budget value/range filters the visible sites, routes, and curated route price ranges to those within the selected range.
- Results should **update dynamically** as the budget input changes — no separate "apply" button required, unless the app already has an established apply-button pattern for other filters (match existing pattern if so).

---

## 4. Settings Page

### 4.1 Weather
- Replace placeholder weather data with **accurate, real-time weather data**, pulled from Google Weather or an equivalent reliable weather API/source.

### 4.2 Accessibility Support
- Replace current behavior (tapping "Accessibility Support" currently just opens the Navigation page) with a **simple on/off toggle**, styled to match the existing Dark Mode toggle.
- **When ON:** accessibility options appear within the Navigate flow (the flow described in Section 1 above), in the same "Live Updates" / "Accessibility Modes" panel style shown in the reference screenshot ("2.1 - LOCATION NAVIGATION PAGE").
- **When OFF:** those options are hidden from the Navigate flow entirely.
- **Layout change:** the "Accessibility Modes" button list should switch from a single column (as currently shown) to a **two-column grid**, keeping each button's existing icon + label styling — just reflowed into a 2-across grid instead of a vertical stack.
- **Confirmed full list of 6 accessibility modes** (3 existing + 3 newly confirmed):
  1. Vegetarian (existing)
  2. Braille / Voice (existing)
  3. Ramps & Elevators (existing)
  4. Rest Areas & Seating Nearby (new)
  5. PWD & Senior Priority Assistance (new)
  6. Audio-Described Directions (new)
- The "Live Updates" panel above (showing live status like "67m — open now," "Voiceover mode active," etc.) should also gain corresponding entries for the 3 new modes, following the same live-status pattern already used for the existing 3.

### 4.3 Transport & Access section
- For each transport option listed (Tranvia Rental, Kalesa, Pedicab/E-Trike, Parking, etc.), tapping it should navigate to that service's **actual real-world location**, using accurate coordinates verified via web search (not estimated/approximated) — **confirmed:** Kiro should web-search for verifiable public real-world locations (e.g., known kalesa stations, public parking lots near Intramuros) rather than needing specific vendor names supplied.
- **Confirmed:** tapping an item opens the app's **own in-app navigation flow** (Section 1's shared Navigate component) toward that real-world location — not an external Maps app handoff. Even though these are third-party services outside the app's own location dataset, they should still route through the same in-app navigation experience as everything else.
- Add a **minimize/collapse control** for this panel — **confirmed:** a simple chevron that collapses the whole section, matching the same pattern used for the accessibility panel.

---

## 5. Location Pins on Navigation Page

- Improve the popup shown when a pin is tapped: include a **small preview photo** of the location next to its name, instead of plain text only.
- Reuse the same location photo asset referenced elsewhere in the app (detail pages, reviews — see Section 7) rather than sourcing a separate image just for the pin popup, so there's one consistent image per location across the app.

---

## 6. Itinerary Navigation — Transport Mode Selector

- When a user taps **"Navigate"** within an itinerary, first show a **transport mode selector** before the view-mode choice from Section 1.
- **Confirmed mode list — matches Settings > Transport & Access exactly:**
  - Walk
  - Tranvia Rental
  - Kalesa
  - Pedicab / E-Trike
- Visual style: a row of mode icons the user taps to select, similar to Google Maps' mode-selector pattern (car/transit/walk/bike icons).
- **Routing limitation — confirmed handling:** since routing is straight-line/walking-path based (no real road network for vehicles), Tranvia/Kalesa/Pedicab will reuse the **same route line/path logic as Walk** for now. This is not hidden from the user — show a **small UI note** near the route/panel explaining that the shown path is a walking path used for all modes (e.g., a small caption like "Route shown is a walking path"). Don't give each mode a distinct line color/style, since that would visually imply route differences that don't actually exist yet.
- **Default state:** **confirmed** — the selector always **resets to Walk** by default each time it's opened, rather than remembering the last-used mode per itinerary.
- After mode selection, proceed into the standard navigate flow (Section 1: persistent view-mode toggle, bird's-eye ↔ turn-by-turn).

---

## 7. Reviews

### 7.1 Leaving a review
- Users can leave a review for a specific location from **two places**, both leading to the same underlying review data:
  1. **The location's own detail page** — a "Leave a Review" action directly on that place.
  2. **A dedicated Reviews section in Settings** — listing all reviewable locations, letting the user pick one and leave a review from there.
- A review submitted from either entry point should appear identically on that location's review list (single shared data source — not two separate review systems).

### 7.2 Review content
- At minimum, a review includes a star rating and text.
- New user-submitted reviews append to that location's existing review list (which may already include seeded/generated reviews from the base spec) — don't replace or separate them into a different section.

### 7.3 Location photos in reviews
- Each location's review section should display a **photo of the place**, sourced the same way as other location photos in this app (manually searched/curated static image, not a live API pull) — see Section 5's note on reusing one consistent image per location.

---

All requirements in this document reflect confirmed decisions and can be implemented directly by Kiro AI without further clarification.