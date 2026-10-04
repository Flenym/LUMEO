# Lumeo Design System — Liquid Glass rules (breeze note)

> OLED-first. Default theme: OLED Black `#000000` + Orange `#FF6B00`.
> Rule #1: user must understand any screen in 1–2 seconds.
> Tokens: `Design/theme.json` — colors, statusColors, spacing (xs 4 → xxl 32), radius (sm 8 → pill 999), typography, motion (≤300ms easeOut, respect Reduce Motion).

## Dose of Liquid Glass (доза)

Glass is a spice, not a meal: **max 1 translucent layer visible at any pixel**.
Allowed carriers (pick ONE per screen): tab bar, OR floating create-session button, OR primary CTA highlight, OR one sheet, OR one small pressed card, OR Live Activity/widget background where the system requires it.
Default everything else to solid OLED surfaces (`#000000` / `#131316` / `#1C1C1F`).

Example — Home (correct): solid black list + solid friend cells + ONE glass tab bar.
Example — Session banner (correct): solid banner card, glass ONLY on the floating Join pill.
Example — Chat (correct): solid bubbles + solid background; glass allowed ONLY on the pinned banner XOR the composer, never both.

## Where Liquid Glass IS allowed

- Tab bar (system `UITabBar` / SwiftUI `.toolbarBackground(.visible)` + glass material).
- Floating create-session button (single, central).
- Primary CTA buttons (Play / Accept) — subtle glass highlight, not full transparency.
- Sheets (session create, profile preview) — standard system sheet material.
- Small interactive cards (friend card pressed state, session banner).
- Live Activity / widget backgrounds where system requires translucency.

## Where Liquid Glass is FORBIDDEN

- Full-screen backgrounds (must be pure `#000000` OLED, no blur stack).
- Chat message bubbles en masse (max one glass layer: pinned banner OR composer, never both + bubbles).
- Long lists (friends list, chat history, workshop grid) — solid cells, no per-row glass.
- Stacking glass-on-glass (sheet over glass tab over glass card) — max 1 glass layer visible.
- Text-heavy screens (settings, legal, guidelines).

## The 1–2 second rule

- One screen = one question. Home answers: "who is free?".
- Max 1 primary action per screen section.
- No more than 2 accent-colored elements above the fold.
- Animations: ≤ 300ms, `easeOut`, respect Reduce Motion.
- No infinite shimmer/particles on lists; effects only on profile showcase / rewards.

## Anti "стеклянная каша" checklist

- [ ] No more than 1 translucent layer at any pixel.
- [ ] No custom blur radius — only system materials (`.ultraThin`, `.thin`, `.regular`).
- [ ] Contrast of body text on any background ≥ 4.5:1.
- [ ] Glass never carries critical info alone (status color dot is always solid, not glass).
- [ ] Screenshots in light/ambient light still readable.

## Status colors (always solid)

- 🟢 `#34C759` — free. 🟡 `#FFCC00` — later. 🔴 `#FF3B30` — busy.
- Online dot: green solid / gray `#8E8E93` offline. Never glass, never gradient.

## Spacing / radius / motion usage

- Gaps: `xs/sm` inside cards, `md/lg` between sections, `xl/xxl` screen edges on large screens.
- Radius: `sm` chips/badges, `md` cards, `lg` sheets, `xl` hero/profile, `pill` CTAs/avatars.
- Motion: `fast 150ms` pressed states, `base 250ms` transitions, never over `maxDurationMs 300ms`; `reduceMotion: respect-system` always.
