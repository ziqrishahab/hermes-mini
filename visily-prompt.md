# Hermes Mobile — Dark Theme Design System

Flutter AI agent chat app. Dark theme, flat design, NO gradients/shadows. Use subtle borders instead.

## Colors
- Scaffold bg: #212121 | Cards: #171717 | Hover: #2F2F2F | Active: #424242
- Accent (navy): #003F7A | Hover: #0055A4 | Link: #006ACD
- Text primary: #ECECEC | Secondary: #B4B4B4 | Muted: #8E8E8E
- Borders: subtle rgba(255,255,255,0.06), visible rgba(255,255,255,0.1), focus #003F7A
- Success: #22C55E | Error: #EF4444 | Warning: #F59E0B | Highlight: #F5C518
- User chat bubble: bg #003F7A, text #FFFFFF
- Agent chat bubble: bg #2F2F2F, text #ECECEC
- Code block: bg #1A1A1A, 12px monospace JetBrains Mono

## Typography
- Body: 14px Inter, line-height 1.65
- Timestamp: 11px, secondary color
- Code: 12px JetBrains Mono

## Border Radius
- 6px small (buttons), 10px medium (cards/inputs), 14px large (chat bubbles)
- Chat asymmetric: user bottom-right=4px, agent bottom-left=4px (speech bubble tail)

## Spacing
- Chat bubble: 10px v, 16px h | Input: 10px v, 14px h | Button: 10px v, 24px h
- Card: 12px | Screen: 40px | Message gap: 12px | Nav gap: 6px

## Screens

**Chat Screen:**
- Top bar: "Hermes" + bolt icon
- User bubbles right-aligned, navy bg #003F7A, bottom-right tail (4px radius)
- Agent bubbles left-aligned, dark gray bg #2F2F2F, bottom-left tail, can contain markdown (headings, code blocks #1A1A1A, links #006ACD, lists, blockquotes)
- Timestamps below messages, 11px, color #B4B4B4
- Bottom input bar: rounded text field + navy send button
- Model selector chip above input

**Bottom Nav (4 tabs, 64px height):**
- Capabilities (sparkles), Chat (bubble), Schedules (clock), Settings (gear)
- Active: #003F7A, inactive: #666666, no labels, icons only
- Full-width, subtle top border, indicator dot above active tab

**Settings Screen:**
- Section headers: secondary text #B4B4B4
- Rows: primary text label + secondary value or toggle
- Cards bg #171717 with subtle borders
- Toggles in navy #003F7A when active

**Capabilities Screen:**
- Grid of feature cards, bg #171717 with subtle borders
- Each: icon + title (primary) + description (secondary)
- Empty state: bolt icon, "Connection failed", retry button navy

Design: developer tool aesthetic, clean, professional, flat. Not consumer social app.