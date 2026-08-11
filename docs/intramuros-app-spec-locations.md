# Intramuros App — Locations Dataset Spec (for Kiro AI)

## Context
This is a **standalone addendum** covering location data completeness. The current app's location list is incomplete. This document provides the full authoritative list across four categories and specifies what data/features every location must have, matching what's already been established for existing locations elsewhere in this project's specs (`intramuros-app-spec.md` and `intramuros-app-spec-updates.md` — read those first for full context on how locations are used across Search, Plans, and Navigation).

**Research task for Kiro:** Use web search (Google) to verify and categorize each location below — confirm real-world coordinates, current status/accessibility, a short factual description, and which category it best fits if not obvious. This is a **one-time data-population research task**, not a live runtime API integration — the base spec already established that the live app uses static, manually-curated data (photos, reviews) rather than a live Google Places API call. Use search here only to populate that static dataset accurately.

---

## Assumed defaults (flagging these — override if not what you intended)
Since these weren't explicitly confirmed, I'm proceeding with the following reasonable defaults. Tell Kiro (or me) if any of these should change:

1. **Naming for sites with a current/adaptive-use name in parentheses** (e.g., "Aduana (Intendencia)," "Baluarte Plano Luneta de Santa Isabel (Philippine Eatsperience)"): display the **historical name as primary**, with the current-use name shown as a **subtitle/secondary label** (e.g., on the location card and detail page).
2. **Schools:** get the **full feature set** — same as every other location (appears in Search, Plans, Navigate, has reviews, pin popup with photo) — but their **budget/cost defaults to "Free"** rather than a random paid figure, since they're active campuses without a tourist entrance fee. Users can still leave reviews (e.g., about visiting the campus/heritage tour), and schools still appear in relevant curated routes if applicable.
3. **Duplicate handling:** Kiro should **cross-check this list against locations that already exist in the app first**, and only add what's genuinely missing — not blindly overwrite or duplicate entries that already exist under a slightly different name. If a name below is ambiguous against an existing entry, flag it rather than guessing.

---

## Feature checklist — applies to every location below (no exceptions)
Every single location listed in this document must have the following, matching the standard already established for existing locations in this app. Kiro should treat this as a per-location checklist to complete, not just a data dump:

- [ ] **Verified real-world coordinates** (via web search — not estimated)
- [ ] **Category tag** — one of: Fortifications, Landmarks (includes Museums, per the grouping below), Parks, Schools — this must match the app's existing filter categories used on the Navigation page and Plans page filter chips
- [ ] **Short factual description** (researched, not fabricated) — used on the location detail page
- [ ] **One manually-sourced photo** — reused consistently across the location's pin popup, detail page, and reviews section (per base spec Section 2.6/5)
- [ ] **Budget/cost value** — a sample-realistic entrance fee or incidental-spend estimate (per base spec addendum Section 3.5), except Schools which default to "Free" per the assumed default above. Sites with genuinely no cost and no realistic incidental spend can also show "Free."
- [ ] **3–6 seeded reviews**, distinct in phrasing/rating/reviewer name from every other location's set — no reused template (per base spec Section 2.7)
- [ ] **"Leave a review" capability** wired to this location, from both the location's own page and the Settings > Reviews section (per addendum Section 7)
- [ ] **Searchable** — appears in the Navigation page's search results (scoped to in-app data only, per base spec Section 2.5)
- [ ] **Appears on the map** with a pin, using the pin popup format (photo + name) from base spec Section 2.6
- [ ] **Included in relevant Curated Routes** where its category/theme fits (per addendum Section 3.4) — e.g., Fortifications sites should be eligible for a "Military Defense Walk"-style route, Landmarks/Museums for heritage-themed routes, etc.
- [ ] **Eligible for inclusion in user-built itineraries** (Plans page "Add" flow) and the nearest-neighbor route sequencing logic

---

## Full location list

### Fortifications (12)
1. Baluarillo de San Juan
2. Baluarte Plano Luneta de Santa Isabel *(current use: Philippine Eatsperience)*
3. Baluartillo de San Eugenio
4. Baluartillo de San Jose
5. Reducto de San Pedro
6. Puerta Real & Revellin Real de Bagumbayan
7. Baluarte de San Andres
8. Revellin de Recoletos
9. Baluarte de Dilao
10. Puerta del Parian & Revellin del Parian
11. Baluarte de San Gabriel
12. Puerta Isabel II

### Landmarks (includes Museums) (17)
1. Fort Santiago
2. Palacio del Gobernador
3. Ayuntamiento de Manila
4. Manila Cathedral
5. Centro de Turismo Intramuros
6. Museo de Intramuros
7. Foro de Intramuros
8. San Agustin Church and Museum
9. Casa Manila Museum
10. Bahay Tsinoy
11. Fr. George Willman Museum
12. NCCA Gallery
13. Bagumbayan Light and Sound Museum
14. Baluarte de San Diego
15. Distileria Limtuaco Museum
16. Chamber of Commerce
17. Aduana *(current use: Intendencia)*

**Note:** museums are grouped under the "Landmarks" filter category, not a separate "Museums" filter — this matches the app's existing 4-category filter set (Fortifications, Landmarks, Schools, Parks) already confirmed in the base spec. Do not add a 5th filter category for museums.

### Parks (8)
1. Plaza Roma
2. Plazuela de Santa Isabel
3. Plaza de Santo Tomas
4. Plaza España
5. Plaza Mexico
6. Plaza Moriones
7. Plaza de Armas
8. Galleria de los Presidentes

### Schools (5)
1. Pamantasan ng Lungsod ng Maynila
2. Manila High School
3. Mapua University
4. Lyceum of the Philippines University
5. Colegio de San Juan de Letran

---

## Cross-page consistency requirement
Once populated, every location above must behave identically to existing locations across **every page that touches location data**, specifically:
- **Plans page** — appears in category chip filters, budget filter, eligible for Curated Routes and custom itineraries (per addendum Section 3)
- **Navigation page** — appears as a map pin with photo popup, included in the persistent category filter bar, included in search results (per base spec Section 2 and addendum Section 1–2)
- **Search bars** — anywhere the app searches in-app locations (Navigation page search, and any search entry point on Plans), all locations above must be indexed and returned like existing entries
- **Location Details page** — full detail page with photo, description, budget, reviews, and Navigate button (per base spec Section 2.2's shared navigation flow)

Kiro should treat this as: populate the data once, then verify it flows correctly through each of these surfaces — not as four separate implementation efforts.
