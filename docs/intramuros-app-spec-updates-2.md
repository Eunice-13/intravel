# Intramuros App — Updates Spec 2 (for Kiro AI)

## Context
This is a **standalone addendum**, to be read alongside the existing specs: `intramuros-app-spec.md`, `intramuros-app-spec-updates.md`, and `intramuros-app-spec-locations.md`. Where anything here conflicts with those files, **this document takes precedence** — it reflects the newest decisions.

**Design constraint (same as all prior specs):** reuse existing components, color tokens, spacing, and typography. No new design language.

---

## 1. Parking navigation — use real vehicle roads, not the walking-path graph

- Navigation to the **Parking** item (Settings/Home > Transport & Access — see Section 2 below for its new location) must **not** use the app's existing walking-path graph (`walking_paths.json`). That graph is pedestrian-only and includes walkways/shortcuts a car cannot physically fit through.
- Parking (and any future vehicle-bound destination) needs routing over **actual drivable roads**.
- **Open technical decision — flag before implementing:** the app currently has no vehicle road dataset. This needs one of:
  - (a) A real driving-directions routing source (e.g., a directions API with a driving mode) — this would be a new live dependency, similar in nature to the reverse-geocoding fork discussed for street names, and should be weighed the same way (new dependency/possible billing vs. accuracy).
  - (b) A hand-authored vehicle-road graph, built the same way `walking_paths.json` was — a separate dataset mapping actual car-accessible roads around Intramuros, used only for vehicle-bound destinations like Parking.
  - Recommend Kiro flag which approach it's leaning toward before building, since this is a new data source either way, not a small tweak to the existing routing logic.

---

## 2. Transport & Access — move to Home page as its own section

- **Remove** "Transport & Access" from the Settings page (superseding `intramuros-app-spec-updates.md` Section 4.3's placement — the content/behavior described there, minus coordinates/in-app-nav/collapse behavior which stay as previously confirmed, still applies, just relocated).
- **Add it to the Home page instead, as its own distinct section** — not merged into or displayed alongside the regular location listings/cards. It should read as a clearly separate module on Home (e.g., its own header/card group), listing the same transport options (Tranvia Rental, Kalesa, Pedicab/E-Trike, Parking) with the same behavior already confirmed: tapping an item opens in-app navigation to its real-world location, using the coordinates already confirmed (Plaza Roma for Tranvia, near Fort Santiago/Plaza Moriones for Kalesa, Aduana/Magallanes for Parking, Plaza Roma labeled "General pickup area" for Pedicab/E-Trike), with a collapse/chevron control.

---

## 3. Location Details page — replace the broken "Directions" button

- The current **"Directions" button on the Location Details page is non-functional** and should be **replaced**, not fixed as-is.
- **New button:** instead of a Directions action, this button should take the user to a view showing the **itinerary options that include this specific location** — i.e., a list of curated routes/itinerary categories this location qualifies for (per Section 4 below), letting the user browse and pick one to view/save, the same way tapping a Curated Route from the Plans page works (per `intramuros-app-spec-updates.md` Section 3.4).
- Effectively: this location's detail page now offers a shortcut into "see itinerary options featuring this place" rather than a broken point-to-point directions action. Direct single-destination navigation to this location is still available via the page's separate "Navigate" button (unaffected by this change).

---

## 4. Curated Routes — more options per category

- Expand the Curated Routes list (currently: Religious Heritage Trail, Military Defense Walk, Student's Budget Tour, Plazas & Open Spaces) to include **more themed route options that make sense per category**, covering Fortifications, Landmarks (incl. Museums), Parks, and Schools more thoroughly rather than one route loosely touching each category.
- Exact new route names/themes are left to Kiro's judgment, grounded in the actual location dataset from `intramuros-app-spec-locations.md` — e.g., additional heritage, museum-focused, family-friendly, or short-on-time route themes, as long as each new route is backed by enough qualifying locations to actually populate it (per the existing "generate options based on how many qualifying sites exist" rule already confirmed).
- Each new curated route follows all previously confirmed behavior: tappable, generates system-made plan option(s) sized to the available site pool, selectable, saveable to the Itinerary Hub, with full Navigate/Edit/Delete parity once saved (per `intramuros-app-spec-updates.md` Section 3.4).

---

## 5. Curated Route option details — short description before saving

- When a user taps into a specific generated plan option under a Curated Route (i.e., after selecting a route theme and being shown one or more candidate itinerary options), add a **short description/details blurb about that specific plan**, positioned **above the "Save to Itinerary Hub" button**.
- This description should briefly summarize what the plan includes — e.g., a one- or two-sentence overview naming the general character of the route and its stop count/duration (in the spirit of the existing "~4 hrs" / "All group sizes" labels already shown on the Curated Routes list) — so the user has context on what they're about to save before committing.

---

All items above reflect confirmed direction except the flagged technical fork in Section 1, which needs Kiro's input before implementation (new dependency vs. hand-authored road graph).
