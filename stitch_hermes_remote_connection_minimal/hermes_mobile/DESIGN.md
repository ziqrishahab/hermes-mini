---
name: Hermes Mobile
colors:
  surface: '#131313'
  surface-dim: '#131313'
  surface-bright: '#393939'
  surface-container-lowest: '#0e0e0e'
  surface-container-low: '#1c1b1b'
  surface-container: '#201f1f'
  surface-container-high: '#2a2a2a'
  surface-container-highest: '#353534'
  on-surface: '#e5e2e1'
  on-surface-variant: '#cac4cf'
  inverse-surface: '#e5e2e1'
  inverse-on-surface: '#313030'
  outline: '#948f99'
  outline-variant: '#49454e'
  surface-tint: '#cebff1'
  primary: '#e2d5ff'
  on-primary: '#352a52'
  primary-container: '#c7b8ea'
  on-primary-container: '#534772'
  inverse-primary: '#645883'
  secondary: '#c8c6c5'
  on-secondary: '#313030'
  secondary-container: '#474746'
  on-secondary-container: '#b7b5b4'
  tertiary: '#eadd95'
  on-tertiary: '#373100'
  tertiary-container: '#cdc17c'
  on-tertiary-container: '#574f15'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e9ddff'
  primary-fixed-dim: '#cebff1'
  on-primary-fixed: '#1f143c'
  on-primary-fixed-variant: '#4c406a'
  secondary-fixed: '#e5e2e1'
  secondary-fixed-dim: '#c8c6c5'
  on-secondary-fixed: '#1c1b1b'
  on-secondary-fixed-variant: '#474746'
  tertiary-fixed: '#f1e49b'
  tertiary-fixed-dim: '#d4c882'
  on-tertiary-fixed: '#201c00'
  on-tertiary-fixed-variant: '#4f470e'
  background: '#131313'
  on-background: '#e5e2e1'
  surface-variant: '#353534'
typography:
  headline-lg:
    fontFamily: Hanken Grotesk
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.02em
  headline-md:
    fontFamily: Hanken Grotesk
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  body-md:
    fontFamily: Inter
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  label-sm:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.05em
  headline-lg-mobile:
    fontFamily: Hanken Grotesk
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  unit: 4px
  margin-main: 20px
  gutter-card: 16px
  stack-sm: 8px
  stack-md: 16px
  stack-lg: 24px
---

## Brand & Style
The design system establishes a high-performance, technical aesthetic for the mobile agent experience. It combines a **Minimalist** ethos with **Corporate Modern** reliability. The primary emotional response is one of secure, focused efficiency. 

The visual identity is defined by a "Deep Space" theme: high-contrast typography against a monochromatic charcoal backdrop, punctuated by a single, soft lavender accent that signifies intelligence and connectivity. This system prioritizes legibility and rapid task completion, moving the complex desktop dashboard into a streamlined, mobile-first interface.

## Colors
The palette is rooted in a pure dark mode experience. 
- **Primary Lavender (#C7B8EA):** Used exclusively for primary actions, active states, and critical brand moments (like the lightning bolt icon).
- **Neutral Background (#121212):** The foundation for all screens to reduce eye strain and maximize OLED efficiency.
- **Surface Card (#242424):** A slightly lighter charcoal used to define interactive containers and separate content sections.
- **Typography:** High-contrast white for headings to ensure immediate hierarchy, with muted greys for secondary labels and placeholder text.

## Typography
The system uses a pairing of **Hanken Grotesk** for headlines to provide a sharp, contemporary tech feel, and **Inter** for body and functional labels to ensure maximum utility and readability.

Key principles:
- **Tight Leading:** Headlines use tight line-height for a compact, modern look.
- **Visual Hierarchy:** Large, white headlines contrast sharply against the charcoal background.
- **Data Density:** Label styles use slightly increased letter spacing and uppercase styling to denote metadata or secondary form headers clearly.

## Layout & Spacing
This design system follows a **Fixed Mobile Grid** with standard 20px side margins. 

- **Stacking:** Elements are stacked vertically using a 4px base unit. 
- **Content Blocks:** Information is grouped into cards. Internal padding within cards is a consistent 16px.
- **Bottom Navigation:** A persistent 64px height bottom bar houses the primary navigation, anchored to the bottom of the screen with a subtle blur or solid charcoal fill.
- **Safe Areas:** Strictly adhere to device-specific safe areas for top status bars and bottom home indicators.

## Elevation & Depth
Depth is expressed through **Tonal Layering** rather than heavy shadows, maintaining the minimalist aesthetic.

- **Level 0 (Background):** Pure #121212 for the main canvas.
- **Level 1 (Cards/Containers):** #242424 with no shadow. Differentiation is achieved through value change.
- **Level 2 (Modals/Overlays):** #2D2D2D with a soft, 15% opacity black shadow (0px 8px 24px) to suggest physical lift during interaction.
- **Interactive States:** Buttons use a subtle glow effect (10px blur) using the Lavender primary color when active to simulate a digital "lit" state.

## Shapes
The shape language is defined by oversized, friendly radiuses that soften the "technical" feel of the dark theme.

- **Cards:** Use a 20px radius to create a distinct, nested feel.
- **Buttons:** Primary buttons use a slightly smaller 12px or 16px radius to feel more "clickable" and distinct from container shapes.
- **Toggle Switches:** Selection pills (e.g., Remote vs SSH) use a fully rounded (pill-shaped) geometry to indicate their switch-like behavior.

## Components
- **Primary Button:** Solid Lavender (#C7B8EA) background with dark charcoal text (#121212). Full-width on mobile for high reachability.
- **Input Fields:** Surface-on-surface design. Use #242424 background with a subtle #333333 border. Icons should be placed on the left, using Lavender only when the field is focused.
- **Bottom Navigation:** 4-5 icons max. Active icon uses Lavender; inactive icons use muted grey (#666666). No text labels unless necessary for clarity.
- **Segmented Control (Toggle):** A contained track (#1A1A1A) with a sliding Lavender pill to indicate the selected state.
- **Status Chips:** Small, low-profile indicators with a subtle Lavender border and 10px text for system status (e.g., "CONNECTED").
- **Lists:** Clean rows with 1px #333333 dividers, featuring 16px horizontal padding.