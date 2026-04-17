# Prompt Atelier Release Checklist

Project and scheme:
- Project: `PromptAtelier.xcodeproj`
- Primary scheme: `PromptAtelier`
- Deployment target: `iOS 18.0`

Simulator QA:
- Launch the app with seeded browse data and verify the library opens, filter chips respond, and prompt detail loads.
- Launch with seeded copy data and verify `Copy` updates the clipboard and increments the copied count immediately.
- Check the empty library state with no prompts and confirm the message is concise and visible in dark mode.
- Open Settings and confirm local-only, offline, and signed-out sync messages remain readable and accurate.
- Verify the launch screen, app icon, and widget entry point still use the Prompt Atelier branding.

Accessibility checks:
- VoiceOver focus lands on the filter chips, prompt rows, copy button, and settings sync card with readable labels.
- Dark mode contrast stays legible for body text, metadata, empty-state text, and accent badges.
- Core controls used in tests expose stable accessibility identifiers for regression coverage.

Entitlements:
- Main app keeps App Group: `group.com.codex.promptatelier`
- Main app keeps iCloud/CloudKit container: `iCloud.com.codex.promptatelier`
- Share extension and widget keep the shared App Group entitlement
- Automatic signing remains enabled; no code-signing settings were disabled

Privacy strings:
- No runtime permission prompts are used in the current build, so no `NS*UsageDescription` keys are required today.
- If camera, microphone, photos, contacts, or tracking are added later, add the matching usage descriptions before release.

Empty-state behavior:
- Default library empty state: `Share text or links into Prompt Atelier.`
- Filtered library empty state: `Try another filter.`
- Widget empty state should still guide the user back to the library/share flow.
