---
name: kiddo-ui-ux
description: Improve or review KiddoTasks iOS and web interfaces, including accessibility, responsive layouts, forms, parent dashboards, Kids Station, navigation, and shared design-system work. Use whenever a task changes UI or user experience in this repository, even when the user does not ask for a design review explicitly.
---

# KiddoTasks UI and UX

Use this skill for changes to the SwiftUI iOS app and the Next.js web app. Treat this as a family product used by parents managing routines and children using a shared device. Make the next action clear, keep the experience reassuring, and make the same family state understandable across platforms.

## Before editing

1. Inspect the target screen, shared components, design tokens, and the current diff. Build on existing in-progress work; do not revert unrelated changes.
2. Trace the user journey and relevant state transitions before changing presentation. Preserve task recurrence, separate completion records, approval and rejection history, points, and cross-device sync behavior.
3. Prefer the existing CALM ADVENTURE visual language: blue primary actions, warm reward accents, slate text, pale neutral backgrounds, rounded cards, and restrained motion. Use the existing tokens and shared controls instead of introducing a competing visual system.
4. Choose changes that solve a visible usability issue. Avoid decorative complexity, unnecessary new dependencies, and broad redesigns that make familiar workflows harder to scan.

## Platform conventions

### iOS

- Use `KiddotasksDesignTokens` for colors, type, spacing, radii, and touch targets. Prefer Dynamic Type text styles and layouts that can grow vertically.
- Give every icon-only action an explicit VoiceOver label. Mark decorative imagery hidden from accessibility when appropriate.
- Keep interactive targets at least 44 points; use the larger shared target for child-facing actions when the layout allows.
- Respect Reduce Motion, safe areas, keyboard focus, and system navigation conventions. Avoid fixed heights that clip larger text.
- Make selected state and state changes available to VoiceOver, not just by color.

### Web

- Use existing CSS variables, shared components, semantic elements, and Tailwind conventions. Keep light/night theme behavior and narrow-screen layouts intact.
- Associate labels, descriptions, and validation errors with form controls. Provide visible keyboard focus, meaningful accessible names, and live announcements for async feedback.
- Use links for navigation and buttons for actions. Keep touch targets comfortable, prevent horizontal overflow, and support zoom and reduced motion.
- Cover loading, empty, error, saving, and success states whenever a change affects an async workflow.

## Review before handoff

- Check the smallest relevant mobile width and a wider layout; inspect Dynamic Type and VoiceOver implications for native changes.
- Check keyboard-only use, focus visibility, contrast, long names, empty lists, and error/loading states for the affected flow.
- Prefer a focused diff and explain which user problem it addresses. Do not change product rules or data lifecycles as a side effect of visual work.
- Do not claim visual or runtime validation unless it was actually performed. Do not run tests unless the user asks for them.
