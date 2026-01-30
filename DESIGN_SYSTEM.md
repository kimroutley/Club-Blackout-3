# Club Blackout UI Design System (WIP)

This repo is converging on a small, explicit design system so every screen looks consistent and stays easy to maintain.

## Goals

- Consistent spacing, radii, typography, and glow treatments across all screens
- Prefer **theme tokens + reusable components** over per-screen one-off styles
- Keep behavior the same; only reduce duplication and improve cohesion

## Source of Truth

- **Tokens + helpers:** `lib/ui/styles.dart` (`ClubBlackoutTheme`)
- **Reusable shells/components (existing):** `lib/ui/widgets/*` (e.g. NeonGlassCard, Bulletin shell, GlowButton)

## Rules of Thumb

### 1) Use tokens (don’t invent new numbers)

Prefer:
- `ClubBlackoutTheme.pagePadding`, `sheetPadding`, `cardPadding`
- `ClubBlackoutTheme.rowPadding`, `controlPadding`, `fieldPadding`, `fieldPaddingLoose`
- `ClubBlackoutTheme.inset16`, `inset24`, `dialogInsetPadding`
- `ClubBlackoutTheme.borderRadiusSmAll`, `borderRadiusMdAll`, `borderRadiusControl`

If you need a *new* spacing/radius, add a token to `ClubBlackoutTheme` and reuse it.

### 2) Use style helpers

- Text glows: `ClubBlackoutTheme.glowTextStyle(...)` and `neonGlowTextStyle(...)`
- Frames/containers: `ClubBlackoutTheme.neonFrame(...)`, `bulletinItemDecoration(...)`

### 3) Standard screen structure

Most screens should follow:

1. `Scaffold` with consistent padding (`pagePadding`)
2. A small number of section containers (prefer NeonGlassCard / bulletin item patterns)
3. Standardized vertical rhythm (prefer `ClubBlackoutTheme.gap8/gap12/gap16/gap24`)

### 4) Prefer components over copy/paste

If you see repeated patterns ("section header + card + list", "glowing button row", "dialog content shell"), create/extend a widget in `lib/ui/widgets/` and use it across screens.

## Current status

- Glow text patterns are centralized.
- Common paddings/radii are being centralized (row paddings, control/field paddings, common radii).

## Next candidates (nice wins)

- Consolidate “section header” widgets (title + icon + glow + spacing)
- Consolidate common list-row decorations (selected/unselected variants)
- Consolidate dialog shells (inset padding + shape + blur + header)
