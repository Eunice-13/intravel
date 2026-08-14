# Intramuros App — In-App Assistant Chatbot Spec (for Kiro AI)

## Context
This is a **standalone addendum** specifying a new feature: an in-app AI assistant chatbot. It should be read alongside the existing specs (`intramuros-app-spec.md`, `intramuros-app-spec-updates.md`, `intramuros-app-spec-locations.md`) since the chatbot's job is to help users with everything those documents describe — it is not a separate product, it's a conversational interface layered on top of the app's existing features and data.

**Design constraint (same as all prior specs):** the chat window/bubble UI must match the existing design system — colors, typography, spacing, corner radii, etc. No new visual language.

---

## 1. Placement & entry point
- The assistant is accessible via a **toggleable side icon**, visible on every page of the app — not a fixed floating bubble that's always sitting on-screen. The user can show/hide it themselves (e.g., a small tab or handle on the side of the screen that expands into the chat button when tapped, and can be collapsed/hidden again when not needed).
- Tapping the icon (when shown) opens the chat window (overlay/sheet — match the app's existing modal/sheet pattern if one exists) without navigating away from whatever page the user was on. Closing the chat returns them to exactly where they were; the side icon's shown/hidden state should also persist as the user navigates between pages, so it doesn't reset to visible (or hidden) every time they switch tabs.

---

## 2. Scope — what the assistant knows and can talk about
The assistant's knowledge is scoped **strictly to the app and Intramuros itself**. In practice, that means it should be able to answer questions about:
- Any location in the app's dataset (`intramuros-app-spec-locations.md`) — description, category, budget/cost, hours if known, reviews summary, how to get there
- The four entry gates (Section 1 of the base spec) — what they are, where they are, how to select/change a starting gate
- How app features work — e.g., "how do I add a stop to my itinerary," "what does the budget filter do," "how do I turn on accessibility mode"
- Itinerary/Plans page content — a user's own saved itineraries, Curated Routes, budget filtering
- Practical Intramuros visitor info that's reasonably in-scope for a walking-tour app (e.g., "is Intramuros walkable," "what should I wear") — general enough that it doesn't require inventing specific unverified facts

### Out-of-scope handling
- If asked something clearly unrelated to the app or Intramuros (e.g., general trivia, unrelated cities, personal advice, current events), the assistant should **politely decline and redirect** — e.g., "I can only help with things related to Intramuros and this app — try asking about a location, your itinerary, or how a feature works." It should not attempt to answer as a general-purpose assistant.
- **Confirmed:** the assistant stays **strictly scoped to Intramuros** — it should decline broader Manila/Metro Manila travel questions (e.g., "how do I get to Intramuros from the airport" is out of scope too), not just fully unrelated topics. If a question isn't about Intramuros itself, the app's features, or the user's own itinerary/saved data, it's out of scope.

---

## 3. Data grounding
- The assistant should draw its answers from the **app's own curated dataset** (locations, gates, itinerary features, budget data) established in the other three specs — not from live open-ended web search or general model knowledge that could contradict what's actually in the app (e.g., it shouldn't quote a different entrance fee than what the Plans page shows for the same location).
- This keeps answers consistent with what the user sees elsewhere in the app. If the assistant needs to reference a fact not covered by the app's dataset, it should say it doesn't have that specific detail rather than guessing.

---

## 4. Action capabilities
The assistant can **perform actions on the user's behalf**, not just answer questions. Confirmed capabilities include (at minimum):
- Adding a location to the user's itinerary (e.g., "add Fort Santiago to my itinerary")
- Starting navigation to a location (e.g., "navigate me to Plaza Roma") — this should trigger the same navigation flow described in the base spec (view-mode choice, etc.), not a shortcut that skips it
- Applying a filter (e.g., "show me only fortifications," "filter by budget under ₱200")
- Changing a setting the user references conversationally (e.g., "turn on accessibility mode," "change my starting gate to Puerta Real")

### Confirmation before acting
- **Confirmed:** the assistant must **confirm with the user first** in the chat before executing **any** state-changing action — this includes adding to itinerary, changing settings, changing starting gate, *and* starting navigation (e.g., "Start navigation to Fort Santiago? Yes/No"). No action should fire directly off a single ambiguous or implied request without an explicit yes from the user first.
- This avoids the assistant misreading an ambiguous request and silently modifying the user's itinerary, settings, or navigation state.

---

## 5. Language handling
- The assistant should **auto-detect the language the user is typing in** and respond in kind — English, Filipino, or Taglish (mixed). No manual language toggle needed; this should happen per-message based on what the user actually typed.

---

## 6. Conversation behavior
- **Context awareness:** the assistant should be aware of what page/location the user is currently viewing, so a vague follow-up like "tell me more about this place" or "how much does it cost" resolves correctly without the user having to restate the location name.
- **Multi-turn memory within a session:** the assistant should remember earlier turns in the same chat session (e.g., if the user says "add that to my itinerary" right after asking about a specific location, it should know which location "that" refers to).
- **Confirmed:** chat history **persists across app restarts** — it should be saved (per user/device) rather than reset each session, so a user can close the app and later reopen the chat with prior conversation still visible.

---

## 7. Tone & persona
- **Confirmed:** friendly, casual, locally-knowledgeable tour-guide voice — like a helpful local showing someone around, not formal, corporate, or robotic. Matches the app's overall warm/approachable design tone.

---

All items in this document reflect confirmed decisions. Kiro AI can implement this directly without further clarification.
