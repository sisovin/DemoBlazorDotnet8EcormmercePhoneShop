---
name: Frontend UI Review Checklist
description: "Use when creating, reviewing, refactoring, or debugging frontend UI components and pages. Covers accessibility, color contrast, focus states, responsive behavior, interaction feedback, and consistency checks."
applyTo: "**/*.{html,css,scss,sass,less,js,jsx,ts,tsx,vue,svelte,astro}"
---

# Frontend UI Review Checklist

Use this checklist before finalizing frontend changes.

## Accessibility

- Ensure text contrast meets WCAG AA minimum: 4.5:1 for normal text and 3:1 for large text.
- Verify every interactive control has a visible focus indicator (`:focus` or `:focus-visible`).
- Ensure keyboard-only navigation can reach and activate all interactive elements.
- Keep input labels visible and associated with fields.

## Interaction Quality

- Ensure clickable targets are at least 44x44 px on touch devices.
- Include distinct hover, active, disabled, and focus states for controls.
- Provide loading and error feedback for async actions.
- Keep animation purposeful and short (about 150-300 ms).

## Layout And Responsiveness

- Validate at common widths: 375, 768, 1024, and 1440 px.
- Prevent horizontal scroll on mobile unless intentionally required.
- Preserve visual hierarchy with consistent spacing and typography scale.

## Component Consistency

- Use shared tokens or variables for color, spacing, and typography.
- Keep icon style and stroke weight consistent across the same view.
- Avoid mixing unrelated visual styles in one interface.

## Pre-PR Verification

- Run lint and tests relevant to UI changes.
- Manually test keyboard navigation and focus visibility.
- Manually inspect contrast for changed text/background combinations.
