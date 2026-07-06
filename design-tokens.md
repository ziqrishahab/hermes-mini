# Hermes Desktop → Mobile Design Tokens

Extracted from [hermes-desktop](https://github.com/fathah/hermes-desktop) (`main.css` + `base.css`).
Every token is annotated with its exact desktop usage + mobile adaptation guidance.

---

## 1. Background Hierarchy (Dark Theme)

Hermes Desktop uses a 6-layer background system for depth perception — darkest at the bottom,
lightest for interactive elements.

### `--bg-primary: #212121`
**Role:** App shell, main content area, input backgrounds.  
**Desktop locations:** `.app`, `body`, `.input` fields, `.screen` containers.  
**Visual:** Dark charcoal — the "canvas" everything sits on. Not pure black, has a subtle warmth.  
**Mobile mapping:** `scaffoldBackgroundColor` in Flutter. Saat ini `#0E0E0E` (terlalu gelap), harus diganti ke `#212121`.

### `--bg-secondary: #171717`
**Role:** Sidebar, cards, secondary panels.  
**Desktop locations:** `.sidebar` (full sidebar panel), `.welcome-remote-card`, `.install-log`, code block containers.  
**Visual:** Near-black — creates a subtle indentation effect against primary bg.  
**Mobile mapping:** Card backgrounds (`cardTheme.color`), bottom nav bar background. Saat ini `#242424` (terlalu terang vs bg-primary).

### `--bg-tertiary: #2f2f2f`
**Role:** Hover/pressed feedback, raised surfaces yang bukan primary interactive.  
**Desktop locations:** `.btn-ghost:hover`, `.sidebar-collapse-toggle:hover`, `.install-progress-bar` track.  
**Visual:** Mid-gray — enough contrast to signal "this is interactive" without overwhelming.  
**Mobile mapping:** `hoverColor` on list tiles, progress bar tracks, subtle surface highlights.

### `--bg-elevated: #303030`
**Role:** Dropdown menus, tooltips, popover surfaces.  
**Desktop locations:** `.btn-secondary` default background, floating panels.  
**Visual:** Slightly lighter than tertiary — for elements that need to "float" above content.  
**Mobile mapping:** Dialog backgrounds, bottom sheet backgrounds.

### `--bg-hover: #3a3a3a`
**Role:** Row-level hover, list item hover.  
**Desktop locations:** `.btn-secondary:hover`, `.sidebar-nav-item:hover`.  
**Visual:** Lighter mid-gray — instant visual feedback on mouseover.  
**Mobile mapping:** `highlightColor` or `splashColor` on `InkWell`/`GestureDetector` wrappers.

### `--bg-active: #424242`
**Role:** Pressed/selected state, active navigation item.  
**Desktop locations:** `.sidebar-nav-item.active`, scrollbar thumb (default).  
**Visual:** Lightest gray — "this is the current thing."  
**Mobile mapping:** Selected bottom nav item indicator, active chip background.

---

## 2. Accent System

Hermes Desktop uses a single navy-blue accent family. No gradients — flat, solid colors.

### `--accent: #003f7a`
**Role:** Primary action color — buttons, focus rings, selected states.  
**Desktop:** `.btn-primary` background, `.input:focus` border, progress bar fill, loading spinner border-top.  
**Visual:** Deep navy — professional, high contrast against dark bg, tidak mencolok seperti bright blue.  
**Mobile mapping:** `primaryColor`, `FilledButton` background, `InputDecoration.focusedBorder`, `CircularProgressIndicator` color.  
**⚠️ Mismatch besar:** Mobile saat ini pakai `#C7B8EA` (lavender pastel) — ini warna yang beda total. Desktop ga pernah pakai lavender.

### `--accent-hover: #0055a4`
**Role:** Button hover brightness bump.  
**Desktop:** `.btn-primary:hover`.  
**Visual:** ~30% lebih terang dari accent — subtle lift, bukan warna baru.  
**Mobile mapping:** `FilledButton` hover/pressed state.

### `--accent-subtle: rgba(0, 63, 122, 0.15)`
**Role:** Very subtle accent background — badges, tags, selected item bg.  
**Desktop:** Used contextually for low-emphasis accent areas.  
**Mobile mapping:** `Chip` selected background, `NavigationBar` indicator color.

### `--accent-text: #006acd`
**Role:** Link color, inline actionable text.  
**Desktop:** Inline links inside chat bubbles (`.chat-bubble-agent a`).  
**Visual:** Brighter than accent — needs to be distinguishable as a link from surrounding body text.  
**Mobile mapping:** `TextStyle(color: ...)` for tappable inline spans.

---

## 3. Text Hierarchy

3-tier text system: primary (readable), secondary (less important), muted (hints/disabled).

### `--text-primary: #ececec`
**Role:** Main body text, headings, chat messages.  
**Desktop:** `body`, `.welcome-title`, `.chat-bubble-agent` text.  
**Visual:** Off-white — slightly warmer than pure `#FFFFFF` untuk mengurangi eye strain di dark mode.  
**Mobile mapping:** `onSurface`, `textTheme.bodyLarge.color`.

### `--text-secondary: #b4b4b4`
**Role:** Labels, descriptions, timestamps, nav labels.  
**Desktop:** `.remote-notice-title`, `.chat-bubble-time`, sidebar item labels.  
**Visual:** Medium gray — jelas terbaca tapi jelas BUKAN konten utama.  
**Mobile mapping:** `textTheme.bodyMedium.color` untuk teks pendukung, subtitle.

### `--text-muted: #8e8e8e`
**Role:** Placeholders, hints, disabled text, empty states.  
**Desktop:** `::placeholder`, `.remote-notice-desc`, `.sidebar-collapse-toggle` icon.  
**Visual:** Low-contrast gray — barely-there, "ini opsional."  
**Mobile mapping:** `InputDecoration.hintStyle`, disabled widget text.

---

## 4. Border System

2-tier border untuk membedakan subtle separation vs visible boundaries.

### `--border: rgba(255, 255, 255, 0.06)`
**Role:** Subtle dividers, card edges yang tidak dominan.  
**Desktop:** Separator lines, `.welcome-divider`, `.install-log` border, `.sidebar` right edge.  
**Visual:** Hampir tidak kelihatan — untuk memisahkan section tanpa visual noise.  
**Mobile mapping:** `Divider`, `Card` elevation shadow replacement (flat design), subtle section separators.

### `--border-bright: rgba(255, 255, 255, 0.1)`
**Role:** Visible input borders, button outlines, interactive element boundaries.  
**Desktop:** `.input`, `.btn-secondary` border, chat input container.  
**Visual:** Low-contrast tapi jelas terlihat — "ini bisa diisi/diklik."  
**Mobile mapping:** `InputDecoration.enabledBorder`, `OutlinedButton` border.

### `--border-focus: #003f7a`
**Role:** Focus ring — tells user "you're here."  
**Desktop:** `.input:focus` border → accent color.  
**Visual:** Navy — sama dengan accent, konsisten.  
**Mobile mapping:** `InputDecoration.focusedBorder`.

---

## 5. Semantic Colors (Feedback)

### `--success: #22c55e`
**Role:** Green — operation succeeded, connected status, health check OK.  
**Desktop:** Status indicators, success toasts.  
**Mobile mapping:** `Colors.green`, status badges, connection indicator.

### `--error: #ef4444`
**Role:** Red — connection failed, operation error.  
**Desktop:** `.btn-danger`, `.install-error-banner` border, error toasts.  
**Mobile mapping:** `Colors.red`, `SnackBar` error, error state widgets.

### `--warning: #f59e0b`
**Role:** Amber — warnings, "perhatian" state.  
**Desktop:** Warning banners.  
**Mobile mapping:** `Colors.amber`, warning badges.

### `--primary-yellow: #f5c518`
**Role:** Highlight yellow — bukan warning, lebih ke "emphasis/star/highlight."  
**Desktop:** Starred items, special emphasis.  
**Visual:** Warm gold — beda dari warning amber.  
**Mobile mapping:** Feature highlights, "new" badges.

---

## 6. Chat Bubbles

The chat experience is the core of Hermes. Desktop uses asymmetric radius to give
bubbles a "tail" feel (speech bubble effect) — user has tail on bottom-right, agent on bottom-left.

### User Bubble
| Property | Value | Notes |
|---|---|---|
| Background | `#003f7a` (accent) | User = primary brand color |
| Text | `#ffffff` | White on dark navy |
| Padding | 10px 16px | Comfortable reading |
| Border radius | 14px / 14px / 14px / 4px | Top-left, top-right, bottom-left = 14px; bottom-right = 4px (tail) |
| Font size | 14px | Same as body |
| Line height | 1.65 | Legible multi-line |

### Agent Bubble
| Property | Value | Notes |
|---|---|---|
| Background | `#2f2f2f` (bg-tertiary) | Agent = neutral surface |
| Text | `#ececec` (text-primary) | Normal body text |
| Padding | 10px 16px | Same as user |
| Border radius | 14px / 14px / 4px / 14px | Bottom-left = 4px (tail on agent side) |
| Font size | 14px | Same as user |
| Line height | 1.65 | Same as user |
| White space | `normal` (not pre-wrap) | Markdown HTML — structure via elements, not literal whitespace |

### Error Bubble
| Property | Value |
|---|---|
| Border | 1px solid `error` at 35% opacity |
| Background | `error-bg` (`rgba(239,68,68,0.1)`) |

### Chat Actions
- **Copy button:** Position absolute, top-6px right-8px, hidden by default (`opacity: 0`)
- **Reveal:** On bubble hover → `opacity: 1` with 0.15s transition
- **Mobile note:** No hover on mobile — pertimbangkan long-press atau always-visible small icon

### Timestamp
- Font: 11px, `text-secondary` color
- Position: bottom of message row, inside padding
- Visibility: hidden by default, shown on message row hover
- **Mobile note:** Bisa always-visible dengan opacity rendah, atau muncul pas tap message

### Code Blocks (inside agent bubble)
- Background: `#1a1a1a` (darker than agent bubble untuk kontras)
- Font: monospace (`JetBrains Mono` / `Fira Code`), 12px
- Border radius: mengikuti parent bubble
- Muted scrollbar: `#424242` thumb

---

## 7. Typography

### Font Stack Priority
1. **Cairo** (Arabic glyphs only, via `unicode-range: U+0600-06FF...`)
2. **Manrope** — Primary Latin font, geometric sans-serif
3. **System fallback:** -apple-system, BlinkMacSystemFont, Segoe UI, Roboto

### Font Weights Loaded
| Weight | Files |
|---|---|
| 400 (Regular) | Manrope-Regular, Cairo-Regular |
| 500 (Medium) | Manrope-Medium, Cairo-Medium |
| 600 (SemiBold) | Manrope-SemiBold, Cairo-SemiBold |
| 700 (Bold) | Manrope-Bold, Cairo-Bold |

### Monospace
Stack: `SF Mono → Fira Code → JetBrains Mono → Menlo → Consolas`

### Mobile Font Mapping
Desktop ga pakai Inter atau Hanken Grotesk — jadi ada gap. Saran:
- **Teks utama:** Tetap `Inter` (tersedia di Google Fonts, mirip Manrope secara proportion)
- **Monospace:** `JetBrains Mono` (available di Google Fonts, ada di desktop stack)
- **Opsional:** Tambah `Manrope` via `google_fonts` kalau mau match 1:1

---

## 8. Component Spacing Reference

| Component | Horizontal | Vertical | Total | Context |
|---|---|---|---|---|
| Chat bubble | 16px | 10px | — | Message padding inside bubble |
| Input field | 14px | 10px | — | `.input` class |
| Primary button | 24px | 10px | — | `.btn` default |
| Small button | 14px | 6px | — | `.btn-sm` |
| Ghost button | 10px | 6px | — | `.btn-ghost` — compact |
| Card content | — | 12px | — | `.install-log` padding |
| Screen page | 40px | 40px | — | `.screen` class |
| Sidebar brand | 20px left, 14px right | 20px | — | Logo + collapse toggle area |
| Nav item gap | — | — | 6px | Gap antar nav items |
| Chat message gap | — | — | 12px | Vertical spacing antar bubble |
| Drag region | full width | 28px | — | Title bar (mobile: not needed) |

---

## 9. Border Radius — Full Breakdown

| Token | Value | Used On |
|---|---|---|
| `--radius-sm: 6px` | Small corners | Buttons (`.btn`), small inputs, chips |
| `--radius-md: 10px` | Medium corners | Cards, input fields, sidebar nav items, code blocks |
| `--radius-lg: 14px` | Large corners | Chat bubbles, modals, welcome logo container |
| `--radius-xl: 20px` | Extra large | Large feature cards, welcome screen elements |

### Asymmetric Radius (Chat Bubbles)
```
User:  tl=14px  tr=14px  bl=14px  br=4px  (tail kanan bawah)
Agent: tl=14px  tr=14px  bl=4px   br=14px (tail kiri bawah)
```
Ini bikin efek "speech bubble" halus tanpa gambar tail explicit.

### Mobile Radius Adjustments
Desktop pakai radius lebih conservatif (6-14px). Mobile saat ini pakai 12-20px (terlalu rounded).
Saran: turunkan card radius dari 20px → 10px, button dari 14px → 6px.

---

## 10. Sidebar → Bottom Nav Mapping

Desktop sidebar adalah 250px collapsible panel. Mobile harus adapt ke bottom navigation.

| Desktop Sidebar | Mobile Bottom Nav |
|---|---|
| `.sidebar-nav-item` — icon + label vertical | Tab dengan icon + label kecil |
| `.sidebar-nav-item.active` — `bg-active` highlight | Selected tab — accent color |
| `.sidebar-new-chat` — icon button | Belum ada — bisa jadi FAB tengah |
| `.sidebar-chat-scroll` — scrollable session list | Swipeable recent chats (future) |
| `.sidebar-brand` — logo + name | Tidak perlu di bottom nav |
| `.sidebar-collapse-toggle` — collapse/expand | Tidak relevan di mobile |
| 250px lebar (collapsed: 64px) | Full width bar, height 64px |

---

## 11. Transition & Animation

| Token | Value | Usage |
|---|---|---|
| `--transition` | `150ms ease` | Default transition duration — buttons, inputs, hover states |
| Background theme switch | `0.2s ease` | Dark ↔ light transition (lebih lambat supaya smooth) |
| Chat actions reveal | `0.15s ease` | Copy button fade in |
| Progress bar fill | `0.5s ease` | Install progress width transition |
| Tab switch | `200ms` | `AnimatedSwitcher` fade transition di main body |

---

## 12. Light Theme — Key Differences

Light theme menggunakan struktur token yang sama persis, yang beda warnanya:

| Token | Dark | Light | Notes |
|---|---|---|---|
| bg-primary | `#212121` | `#ffffff` | Full white canvas |
| bg-secondary | `#171717` | `#f8f8f8` | Very light gray |
| text-primary | `#ececec` | `#111111` | Near-black, bukan pure black |
| agent-bubble | `#2f2f2f` | `#f0f0f0` | Light gray, tetep distinct dari bg |
| agent-bubble-text | `#ececec` | `#111111` | Dark text on light bubble |
| border | `rgba(255,255,255,0.06)` | `#e5e5e5` | Solid light gray instead of white-alpha |
| code-bg | `#1a1a1a` | `#f5f5f5` | Inverted — light bg for code |
| scrollbar-thumb | `#424242` | `#d4d4d4` | Light gray |
| user-bubble | `#003f7a` (same) | `#003f7a` (same) | Accent unchanged in both modes |

---

## 13. Mobile Implementation Priority

| # | Task | Token(s) | Impact |
|---|---|---|---|
| 1 | Ganti accent dari lavender ke navy | `accent`, `accent-hover`, `border-focus` | Brand consistency |
| 2 | Perbaiki background hierarchy | `bg-primary`, `bg-secondary`, `bg-tertiary` | Visual depth |
| 3 | Fix border radius | `radius-sm`, `radius-md`, `radius-lg` | Less rounded, match desktop |
| 4 | Implement chat bubble style | `user-bubble`, `agent-bubble` + asymmetric radius | Core experience |
| 5 | Update text colors | `text-primary`, `text-secondary`, `text-muted` | Readability |
| 6 | Add semantic colors | `success`, `error`, `warning` | Status feedback |
| 7 | Add code block styling | `code-bg`, monospace font | Code readability |
