# Folio — Design Document

This document is the source of truth for Folio. Every product, design, and engineering decision should be traceable back to something written here. If you find yourself making a choice that contradicts this document, stop and either change the choice or change the document. Don't drift.

---

## 1. What Folio is

Folio is a daily scrapbook app for iOS. Each morning, the user receives a blank page. They can place written notes, voice memos, photo cutouts, location stickers, and decorative stamps on the page, arranging them spatially like physical objects. At local midnight, the page closes permanently. Tomorrow is a fresh page.

Folio is not a journal, not a notes app, not a memory keeper. It is a structured daily ritual for capturing today's moments before today ends.

---

## 2. Why Folio exists

Most journaling and capture apps fail the same way: they accumulate. Half-finished entries, photos you meant to caption, voice memos you forgot to listen back to, days you missed — the journal grows into debt, and eventually opening the app reminds you of what you owe it. People stop opening it.

Folio inverts this. The page closes whether you fill it or not. There is no backlog because there is no possibility of backlog. The product cannot make you feel guilty because it does not let you owe it anything.

In place of accumulation, Folio offers **presence**. You cannot save thoughts for tomorrow; you cannot edit yesterday. The only page that exists is today's, and only until midnight. This constraint produces, by design, the disposition the product wants to encourage in its users.

---

## 3. Core constraints (do not violate)

These are the non-negotiable rules. Every feature, every screen, every animation must be checked against them.

### 3.1 The midnight rule

- At local midnight, the current page closes.
- Once closed, a page cannot be edited, added to, or modified in any way.
- The next page begins at 00:00 local time.
- Time zone changes are handled by the user's current local time at the moment the rule is evaluated. If the user crosses a time zone, their page may close earlier or later than expected. This is acceptable. Folio does not anchor to a fixed time zone.
- There is no grace period beyond what is naturally afforded by the user finishing an in-progress interaction (e.g. a voice memo being recorded at 23:59:55 finishes recording and is added to the page). No new elements can be initiated after midnight.

**Clarification (2026-05-17).** In-progress interactions at midnight complete naturally — this applies to text edits as well as voice memos. Concretely:

- The page closes the moment the user stops touching it: focus drops, recording ends, drag releases.
- New elements cannot be initiated after midnight. Tap-to-create on the canvas is silently ignored. Drag-to-move on existing elements is suppressed.
- Tapping a non-focused element to start editing it is also blocked after midnight — it's a new edit, even if not a new element.
- The currently-focused element continues to accept input until the user commits (taps outside). The TextField is not disabled mid-keystroke.
- No notification, no banner, no modal asks the user what to do. Silence is the feature: the page transitions when the user finishes, not when the clock demands it.
- If the user stays focused indefinitely past midnight, the page stays open indefinitely. This is self-imposed; Folio does not beg for engagement.

The §3.2 prohibition on notifications-that-pressure applies here: a "continue editing or move on?" prompt at midnight would itself be such a notification, and would also make the page closing a *user choice* — which would let backlog re-enter the product through the back door (§2). Quiet completion preserves both: the user finishes naturally, and the page closes irrevocably the moment they let go.

### 3.2 No accumulation

- The journal of past pages exists, but the app's default state is today's page.
- Past pages are not surfaced unless the user explicitly seeks them out.
- There are no badges, streaks, "you've journaled X days in a row" mechanics.
- Missed days are blank pages in the journal. They are not flagged, surfaced, or apologised for.
- There are no notifications that pressure the user to engage. A single optional gentle reminder per day is the maximum.

### 3.3 No accounts, no walls

- Folio does not require a login, account creation, or email.
- The app works fully on first launch, with no onboarding screens beyond what is strictly necessary.
- iCloud sync, if enabled, uses the user's existing iCloud account silently.
- No analytics, no telemetry, no third-party SDKs that phone home.

### 3.4 The page is spatial

- Elements are placed, layered, rotated, resized — not listed.
- The page is the metaphor. Lists, feeds, and timelines are not.
- Every interaction should reinforce the physical-object feeling: things have weight, things layer, things can be picked up and put down.

### 3.5 Beauty is a feature, not a finish

- Visual polish, gesture feel, animation curves, and haptic feedback are not optional final-stage work. They are part of the product's value from the first prototype onwards.
- A version of Folio with crude animations is a different, worse product — not an early version of the same product.

---

## 4. The page

### 4.1 Page structure

- Each page has a fixed size — large enough to accommodate substantial composition, small enough that "filling the page" feels achievable. Working assumption: roughly two device-screen heights tall, one device-screen wide. Scrollable vertically.
- The page has a subtle paper texture. Cream-white, slightly off-pure-white, with the kind of imperfection that makes it feel material rather than digital. No grid lines, no rulers, no margins drawn.
- The date is displayed in elegant typography at the top of the page, small and unobtrusive. It is the only fixed element.
- No prompts. No "what did you do today?" placeholder text. The blank page invites without instructing.

### 4.2 Page lifecycle

- **05:00 - 23:59 (active state):** The user can add, arrange, edit, and remove elements freely. Elements are auto-saved continuously.
- **00:00 (transition):** A brief, dignified animation closes the page. The user sees the page settle, the date adjust, and a new blank page take its place. If the user has the app open at midnight, they witness this transition. If not, they simply find a fresh page next time they open the app.
- **After close (read-only):** The closed page lives in the journal. It can be viewed but not modified.

### 4.3 The first launch

- The user opens Folio for the first time. They see today's blank page, with the date at the top.
- A small, gentle hint appears — something like "tap anywhere to begin" — that disappears the moment the user does anything.
- That is the onboarding. There are no tutorial screens, no feature tours, no "swipe through to learn how Folio works." The product reveals itself through use.

---

## 5. Element types

Folio supports five types of element. Each has its own visual treatment, but all share a common design language: the Polaroid-style white border and slight shadow, suggesting a physical object placed on the page.

### 5.1 Text

- Typed directly on the page, not in a separate text editor.
- The user taps an empty area to start writing.
- Text can be resized (small to large) via pinch gesture.
- A small set of fonts is available — initially three, chosen for character: a clean sans-serif, an elegant serif, and a handwritten-style script. Fonts are selected from a compact picker, not buried in a settings menu.
- Text is not contained in a visible "box" — it sits directly on the paper, like ink.
- Optional: a "torn paper" treatment for text that gives it more visual weight when desired, with a thick white border similar to other element types.

### 5.2 Voice memo

- Tap-and-hold a button to record. Release to stop.
- Recording produces a sticker: a Polaroid-bordered rectangle containing a rendered waveform.
- The waveform is generated from the actual audio data — abstract, vertical lines whose heights map to amplitude.
- Tap the sticker to play; tap again to pause. Playback is local; no streaming.
- Maximum recording length: 60 seconds. Voice memos are *moments*, not interviews.

### 5.3 Photo (with subject cutout)

- The user can either select a photo from their library or capture one in-app.
- After selection, Folio uses the Vision framework's foreground instance mask request to automatically isolate the subject. The user sees the result and can accept, retry, or use the full photo.
- The isolated subject is rendered with a thick white border, like a hand-cut sticker. A subtle drop shadow gives it depth.
- The user can rotate and resize the photo sticker on the page.

### 5.4 Location

- Tap a button to capture the current location.
- Folio resolves the location to a short, human-readable name (e.g. "Granary Wharf, Leeds" rather than "53.7929°N, 1.5536°W").
- The location appears as a sticker — same Polaroid border treatment — containing the place name and a small location-pin glyph.
- The user can override the auto-resolved name with a typed alternative. This matters because "the cafe on the corner" is sometimes more honest than the official place name.

### 5.5 Stamp

- A library of pre-designed decorative stamps: shapes, symbols, small illustrations, mood markers.
- The user can also design their own stamps in a separate tool (released as a v1.1 feature, not v1).
- Stamps are placed by tap-and-drag from a tray.
- Stamps can be tinted within a constrained palette (curated colours that look good on cream paper).

---

## 6. Interaction model

### 6.1 Adding elements

- Elements are added by tapping toolbar buttons at the bottom of the screen, which then enter a placement mode where the user taps the page to place the element.
- The toolbar is minimal: text, voice, photo, location, stamp. Five icons, no labels in the default state, labels visible on long-press.
- When no element is being placed or edited, the toolbar is visually quiet — present but not demanding attention.

### 6.2 Manipulating elements

- **Move:** Single-finger drag.
- **Resize:** Pinch gesture on a selected element.
- **Rotate:** Two-finger rotation gesture on a selected element.
- **Layer:** Long-press brings up a small "bring forward / send back" option. This should be needed rarely — most layering should be intuitive from order of placement.
- **Lift to reveal:** Some elements can be visually "taped" to the page. Pulling at a corner reveals what's underneath. This is a v1.1 feature; v1 ships without it but the data model must support it.
- **Delete:** Swipe an element off the edge of the page, or drag to a small trash icon that appears during manipulation.

### 6.3 Haptics

- Haptic feedback accompanies every meaningful interaction: placing an element (soft tap), starting/stopping a recording (slightly firmer), closing the page at midnight (a gentle, dignified pulse). Use `UIImpactFeedbackGenerator` with calibrated intensities. Haptics are not optional.

---

## 7. The journal

**Naming note (2026-05-17).** Originally specified as "archive" throughout this document; renamed to "journal" to better match how users naturally describe what Folio holds ("I keep a journal in Folio"). The §8.1 visual treatment — cooler tones, deliberately quieter — is unchanged, so the warmer name doesn't dilute §7's design intent: a place you visit on purpose, not a place that calls to you.

### 7.1 Access

- The journal is accessed via a single subtle gesture — a downward swipe from the top of the active page, or a small icon near the date.
- The journal view is visually distinct from the active page: cooler tone, less inviting, deliberately quieter. It is a place you visit on purpose, not a place that calls to you.

### 7.2 Browsing

- Past pages are displayed as a grid of thumbnails by default, scrollable backwards through time.
- Tapping a thumbnail opens the full page in read-only view.
- A "random page" option exists for serendipitous revisiting, but is not the default.

### 7.3 What the journal does not do

- The journal does not offer search.
- The journal does not offer tags or categorisation.
- The journal does not generate "memories" or "throwbacks" or "On this day."
- The journal does not export to other formats. (May reconsider in v2.)

The reason for each of these absences: search and categorisation imply the journal is a knowledge base. It is not. It is a quiet record. Browsing is the only intended interaction, and serendipity is preferable to retrieval.

---

## 8. Visual language

### 8.1 Palette

- **Paper:** Cream off-white, slightly warm. Subtle paper texture.
- **Ink (text default):** Deep near-black, never pure #000. Slightly warm to match paper.
- **Sticker borders:** Pure white with a soft, low-spread drop shadow.
- **Accents:** A small, curated palette of muted, slightly desaturated colours — a dusty rose, a deep sage, a soft ochre, a muted slate. No bright primaries. No neon. No gradients.
- **Journal view:** A slightly darker cream than the active page — same warm family, just dimmer. Revised 2026-05-17 from the originally-specified cooler tones; the warmer-darker version keeps the journal feeling like the same paper world in lower light, rather than a clinically different room.

### 8.2 Typography

- The system uses one display face for the date header (elegant, slightly editorial).
- The user's available fonts for text elements are a curated set of three (initially) — each chosen to feel distinct in character without overlapping in mood.
- Avoid SF Pro for body content. The system font is the right choice for chrome, not for the user's expressive content.

### 8.3 Motion

- Animations are slow enough to be felt, fast enough not to be noticed. Default: 250-400ms with appropriate easing curves.
- Spring physics are appropriate for object manipulation (placing, lifting, settling).
- No bouncy, playful animations. Folio is calm, not cute.

---

## 9. Technical approach

### 9.1 Stack

- **Language:** Swift
- **UI:** SwiftUI, targeting iOS 18.0 minimum. (Originally 17.0, the floor for `VNGenerateForegroundInstanceMaskRequest`; bumped 2026-05-17 to use `.navigationTransition(.zoom(...))` and the iOS 18 transition APIs for §7's journal navigation.)
- **Persistence:** SwiftData primarily; fall back to Core Data only if SwiftData hits known blockers
- **Sync:** iCloud via CloudKit (handled transparently through SwiftData where possible)
- **Audio:** AVFoundation for recording, AVAudioEngine for waveform generation
- **Vision:** Vision framework for photo subject masking
- **Location:** CoreLocation, requesting only `whenInUse` permission, never `always`

### 9.2 Data model (initial sketch)

```
Page
  - id: UUID
  - date: Date (the calendar date this page represents)
  - createdAt: Date
  - closedAt: Date? (nil while active, set at midnight)
  - elements: [Element]

Element (abstract)
  - id: UUID
  - position: CGPoint
  - rotation: Double
  - scale: Double
  - zIndex: Int
  - createdAt: Date

TextElement: Element
  - text: String
  - fontName: String
  - fontSize: Double
  - colour: Color

VoiceMemoElement: Element
  - audioFileURL: URL
  - durationSeconds: Double
  - waveformSamples: [Double]

PhotoElement: Element
  - imageFileURL: URL
  - maskedImageFileURL: URL? (the subject-isolated version)
  - usesMaskedVersion: Bool

LocationElement: Element
  - latitude: Double
  - longitude: Double
  - displayName: String (auto-resolved or user-overridden)

StampElement: Element
  - stampType: String
  - tintColour: Color
```

### 9.3 What lives where

- **On-device:** Everything by default. Photos, audio files, page metadata.
- **iCloud (if enabled):** Page metadata syncs; large media (photos, audio) syncs via CloudKit assets. The user can disable sync; the app works fully offline.
- **No external services:** No analytics, no crash reporting via third parties (use Apple's built-in MetricKit), no feature flags, no remote config.

### 9.4 Performance constraints

- The page must remain responsive even when it contains 30+ elements. Test against this early.
- Voice memo recording and playback must not block UI.
- The midnight transition must be smooth even if the page has substantial content.

---

## 10. Monetisation

- **One-time purchase** at launch. Indicative price: £4.99-£9.99, to be tested.
- No subscriptions in v1. May introduce a Pro tier in v1.1+ for premium features (custom stamps, additional fonts, advanced journal features), but the core product remains a one-time purchase forever.
- No in-app advertising, ever.
- No "lite version" with restricted features. Folio is sold whole.

---

## 11. What Folio is not

This section is here because clarity about what something is *not* is often more useful than clarity about what it is.

- Folio is not a journaling app in the productivity sense. There are no prompts, no structures, no "five things you're grateful for today."
- Folio is not a social product. There is no sharing, no feeds, no followers, no comments. Pages are private and personal.
- Folio is not a knowledge management tool. There is no search, no tagging, no linking between pages.
- Folio is not a habit tracker. It does not measure consistency, completion, or improvement.
- Folio is not a memory keeper in the FaceBook/Apple Memories sense. It does not surface old content algorithmically. The user finds their past only by going looking.
- Folio is not an AI product. There is no LLM integration, no automatic captioning, no suggested content, no smart organisation.

If a feature being considered fits one of the categories above, it does not belong in Folio.

---

## 12. Release plan

### v1 (initial App Store release)

- Active page with full element creation: text, voice, photo (with optional subject masking), location, stamps from a curated library
- Full manipulation: place, move, rotate, resize, layer, delete
- Midnight rollover with proper transition
- Journal view (grid of thumbnails, read-only full-page view, random page option)
- iCloud sync (opt-in during first journal view)
- Five fonts (three for user content, two for system use)
- Curated stamp library (~30 stamps)
- One-time purchase

### v1.1 (post-launch, based on early user feedback)

- Tape-and-lift interaction for elements
- Custom stamp creation tool
- Additional fonts as a Pro upgrade
- Year-end retrospective view (a single curated montage of the year's pages)

### v2 (consideration only)

- Export options (PDF, image) — only if there's strong demand and it can be done without compromising the closed-page principle
- Multi-device handoff (start a page on iPhone, finish on iPad)
- Apple Pencil support for direct drawing/annotation on iPad

Anything not listed above is out of scope. New features are added through the design document first, then built.

---

## 13. How decisions get made

When facing a design or engineering choice:

1. Does the principle in section 3 dictate the answer? If yes, follow it.
2. If section 3 doesn't apply, does another section of this document apply? If yes, follow it.
3. If no section applies, the choice is "out of design document" — meaning we need to either update this document with new guidance or decide consciously which precedent we're setting.
4. Never decide silently. If a choice is being made that this document doesn't cover, surface it explicitly.

The reason for this rigour: small unsurfaced decisions compound. A hundred small "we'll figure it out later" moments produce a product that doesn't know what it is. This document exists to prevent that.

---

## 14. Document maintenance

This document is a living artefact. It should be updated when:

- A real-world constraint forces a change (e.g. a SwiftUI limitation we hadn't accounted for).
- User feedback reveals a flaw in the original thinking.
- A new feature is being considered and we need to articulate why it does or doesn't fit.

Updates should be explicit, dated, and reasoned. The history of this document is part of the design.

The document does *not* get updated for:

- Convenience.
- "It would be easier if we just..."
- Investor or stakeholder requests that don't have a user case behind them.
- Trends or fashions in app design.

If a change to this document feels uncomfortable, that's usually a sign it deserves more thought, not less.
