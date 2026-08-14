# Intramuros App — Updates Spec 3: Cafe & Workspace Features (for Kiro AI)

## Context
This is a **standalone addendum**, to be read alongside the existing specs: `intramuros-app-spec.md`, `intramuros-app-spec-updates.md`, `intramuros-app-spec-locations.md`, and `intramuros-app-spec-updates-2.md`. Where anything here conflicts with those files, **this document takes precedence** — it reflects the newest decisions.

**Design constraint (same as all prior specs):** reuse existing components, color tokens, spacing, and typography. No new design language.

---

## 1. Navigation View Options — Cafe Filter

**Requirement:** Users need a way to filter the navigation map to specifically show cafes, with a focus on workspace amenities (Sockets and WiFi).

### 1.1 Placement in the UI
- Add a new **"Cafe (WiFi & Sockets)"** toggle to the navigation area.
- This new feature must be integrated into the existing Accessibility/Filters panel.
- The previous document established this panel as a two-column grid. 
- Place the new Cafe icon **directly under the "Vegetarian" icon** (which is item #1 in the existing list).

### 1.2 Visual Style
- The icon and button must be styled **identically** to the "Vegetarian" option. 
- Use the same icon + label styling, keeping the dimensions and tap states consistent with the rest of the 2-across grid.

### 1.3 Live Updates Panel Integration
- When the Cafe filter is toggled ON, the "Live Updates" panel above the grid must reflect this status (e.g., showing "Cafe mode active" or highlighting nearby cafes), matching the live-status pattern already established for the existing accessibility modes.

## 2. Location Pins & Amenities Data

### 2.1 Map Pin Updates
- When the Cafe filter is active, the map should highlight locations categorized as cafes.
- When a user taps a cafe's location pin on the Navigation Page, the popup must display the availability of workspace amenities.

### 2.2 Amenity Indicators
- Inside the pin popup (which now includes a small preview photo), add two small, clear boolean indicators (icons or text chips):
  - **WiFi:** (Available / Not Available)
  - **Sockets:** (Available / Not Available)
- These indicators should only appear for Cafe locations, keeping the UI clean for standard historical sites and landmarks.

---

All requirements in this document reflect confirmed decisions and can be implemented directly by Kiro AI without further clarification.