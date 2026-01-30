# Club Blackout Design Language (v1.0)

This document defines the visual language for the Club Blackout host companion app. 
All future UI components should adhere to these principles to maintain a consistent "Midnight Neon" aesthetic.

## 1. Core Principles
- **Dark Dominance**: Always use absolute black (`#000000`) for the primary background.
- **Neon Accents**: UI elements are defined by thin, high-intensity neon borders and subtle glows.
- **Glassmorphism**: Cards and overlays should have a semi-transparent black surface to feel like tinted glass.
- **High-Contrast Typography**: Headings use the `NeonGlow` font with letter-spacing and glow effects.

## 2. Color Palette
- **Background**: `#000000` (Pure Black)
- **Primary / Actions**: `#00D1FF` (Neon Blue)
- **Secondary / Warning**: `#FFFF2E63` (Neon Red)
- **Success**: `#00FF9A` (Neon Green)
- **Selection / Highlight**: `#FF4FD8` (Neon Pink)

## 3. UI Patterns

### Neon Frames
Used for cards, list tiles, and dialogs.
- **Border**: 1.0 - 2.5px width.
- **Opacity**: 80-95% (near opaque to ensure text readability).
- **Glow**: Subtle outer shadow matching the border color.

### Typography
- **Headings**: `NeonGlow` font, Uppercase, 1.5 - 4.0 letter spacing.
- **Body**: Standard Sans-serif, white or off-white.
- **Labels**: Bold, uppercase, letter-spaced.

### Transitions
- **Fades**: Short durations (200-300ms).
- **Glows**: Pulse effects for active/active steps.

## 4. Implementation Reference (Flutter)
- `ClubBlackoutTheme.neonFrame()`: Helper for `BoxDecoration`.
- `ClubBlackoutTheme.textGlow()`: List of shadows for glowing text.
- `NeonPageScaffold`: Standard page wrapper with background and watermark.
