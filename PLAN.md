# PromptFlow Implementation Handoff

## 1. Product Summary
PromptFlow is a native iPhone app for capturing, organizing, and reusing AI prompts with the fewest possible taps. The MVP is explicitly mobile-first and should feel optimized for the iOS share sheet rather than for desktop-style browsing.

Core user flow:
1. User selects text or a URL in another app and invokes the iOS share sheet.
2. PromptFlow captures the content into a shared local store.
3. The app auto-assigns likely AI tool and task-type tags.
4. The user opens the app or widget, taps a prompt, and copies it immediately.

Primary promise:
- Faster capture than Notes or Reminders.
- Better prompt-specific organization than generic note apps.
- No sign-up and no custom backend.

## 2. Scope and Non-Goals
### In scope for MVP
- Share Sheet capture from any app for text and URLs.
- Auto-tagging by AI tool and task type.
- One-screen prompt detail with copy action.
- iCloud sync via the user private database.
- Home screen widget.
- Basic folders and tags.

### Explicit non-goals for MVP
- Web app, desktop app, or Android client.
- Collaborative sharing or multi-user libraries.
- Marketplace, template feed, or social discovery.
- Heavy document ingestion, OCR, or PDF workflows.
- Remote LLM categorization service.

## 3. Repo Reality and Project Bootstrap
The current repository contains planning artifacts only. The downstream agent should treat this as a greenfield native iOS implementation.

Recommended bootstrap:
- Create a new Xcode project named `PromptFlow`.
- Use Swift and SwiftUI.
- Target iPhone only.
- Prefer a modern deployment target such as `iOS 18.0` unless a lower version is explicitly required.
- Add three targets in one Xcode project:
  - Main app target: `PromptFlow`
  - Share extension target: `PromptFlowShareExtension`
  - Widget extension target: `PromptFlowWidget`
- Add one App Group, for example `group.com.yourorg.promptflow`.
- Enable iCloud with CloudKit for the main app target.

Do not introduce a server, web frontend, or unnecessary package sprawl.

## 4. Architecture Overview
### Chosen stack
- UI: SwiftUI
- Persistence: Core Data
- Sync: `NSPersistentCloudKitContainer`
- Extensions: Share Extension, WidgetKit
- Local intelligence: deterministic rules plus `NaturalLanguage`
- System integrations: `UIPasteboard`, deep links, optional `Core Spotlight`

### Why Core Data instead of SwiftData
Use Core Data for MVP because the combination of App Group storage, CloudKit mirroring, share extension access, and widget access is more mature and predictable. SwiftData is attractive, but the downstream agent should optimize for delivery reliability.

### High-level runtime design
- The share extension writes lightweight intake data into the shared App Group-backed store.
- The main app reads the same store, enriches prompts, and renders the library UI.
- CloudKit mirrors the local database into the user private iCloud database.
- The widget reads from the shared store and deep-links into the main app.
- All core behaviors remain functional offline.

## 5. iOS Sandbox and Platform Constraints
The downstream agent must respect these constraints:
- The share extension is memory- and time-limited. Keep it thin.
- The widget should be treated as read-only UI with deep links, not as a place for complex mutation logic.
- Shared persistence must live in the App Group container if multiple targets need access.
- CloudKit sync may be delayed or unavailable; local writes must still succeed.
- Do not depend on clipboard writes directly from the widget unless verified on the chosen iOS target.

Implementation rule: heavy parsing, expensive classification, or sync repair should happen in the main app, not inside the share extension.

## 6. Suggested Project Structure
Use a single Xcode project with shared groups. A practical file/module layout is:

```text
PromptFlow/
  PromptFlow.xcodeproj
  PromptFlowApp/
    App/
      PromptFlowApp.swift
      AppContainer.swift
      AppRouter.swift
    Features/
      Library/
        LibraryView.swift
        PromptRowView.swift
        LibraryFilterBar.swift
      PromptDetail/
        PromptDetailView.swift
        CopyButton.swift
      Organize/
        FolderListView.swift
        TagManagementView.swift
      Settings/
        SettingsView.swift
        SyncStatusView.swift
    Resources/
      Assets.xcassets
      Info.plist
  Shared/
    Persistence/
      PersistenceController.swift
      CoreDataModel.xcdatamodeld
      PromptRepository.swift
    Models/
      PromptRecord+Extensions.swift
      FolderRecord+Extensions.swift
      TagRecord+Extensions.swift
      PromptTaxonomy.swift
    Services/
      CaptureNormalizer.swift
      CategorizationService.swift
      SourceInferenceService.swift
      DeepLinkHandler.swift
    Utilities/
      AppGroupPaths.swift
      Logger.swift
  PromptFlowShareExtension/
    Share/
      ShareViewController.swift
      ShareItemExtractor.swift
      ShareSaveService.swift
    Resources/
      Info.plist
  PromptFlowWidget/
    Widget/
      PromptFlowWidget.swift
      PromptWidgetProvider.swift
      PromptWidgetEntryView.swift
      WidgetDeepLinks.swift
  PromptFlowTests/
    PersistenceControllerTests.swift
    PromptRepositoryTests.swift
    CategorizationServiceTests.swift
    CaptureNormalizerTests.swift
  PromptFlowUITests/
    LibraryFlowUITests.swift
    PromptDetailCopyUITests.swift
```

Do not spend time extracting Swift Packages unless the codebase actually becomes hard to manage.

## 7. Data Model Notes
### Prompt entity
Recommended fields:
- `id: UUID`
- `createdAt: Date`
- `updatedAt: Date`
- `title: String`
- `body: String`
- `sourceType: String` such as text or url
- `sourceAppBundleID: String?`
- `sourceURLString: String?`
- `suggestedToolTag: String?`
- `suggestedTaskTag: String?`
- `folderID` relationship
- `tags` relationship
- `isPinned: Bool`
- `isFavorite: Bool`
- `copyCount: Int32`
- `lastCopiedAt: Date?`
- `classificationConfidence: Double`
- `captureMethod: String` such as share_extension

### Folder entity
- `id: UUID`
- `name: String`
- `sortOrder: Int32`
- relationship to prompts

### Tag entity
- `id: UUID`
- `name: String`
- `kind: String` where kind is tool, task, or custom
- relationship to prompts

### Taxonomy recommendation
Keep MVP taxonomy small and explicit.

Tool tags:
- ChatGPT
- Claude
- Midjourney
- Coding AI
- Generic AI

Task tags:
- Writing
- Coding
- Image generation
- Summarization
- Research
- Brainstorming

### CloudKit-safe modeling guidance
- Use UUIDs as stable identifiers.
- Avoid uniqueness constraints for MVP.
- Avoid storing large binary payloads in the main entities.
- Give scalar fields explicit defaults where possible.
- Plan for lightweight migration only in MVP.

## 8. Capture Pipeline
### Supported input types for MVP
- Plain text
- URLs

### Share extension behavior
1. Accept input from `NSExtensionItem` attachments.
2. Extract text directly when available.
3. If a URL is shared, store the URL string and best-effort title or host metadata.
4. Normalize whitespace and trim boilerplate.
5. Save a new prompt record into the shared App Group store.
6. Return control to the host app quickly.

### Normalization rules
Implement `CaptureNormalizer` with deterministic cleanup:
- Trim leading and trailing whitespace.
- Collapse repeated blank lines.
- Normalize smart quotes only if it improves copy reliability.
- Derive a short title from the first meaningful line.
- Mark capture source as text or url.

Do not do heavy content fetching in the share extension.

## 9. Smart Categorization Strategy
Smart categorization must work offline.

### MVP algorithm
Implement `CategorizationService` with this order:
1. Source-app hints.
   - If the share source or URL obviously points to a known AI tool, assign that first.
2. High-confidence keywords.
   - Examples: `midjourney`, `prompt`, `system prompt`, `refactor`, `summarize`, `tweet thread`, `logo`, `image`, `bug`.
3. Lightweight `NaturalLanguage` tokenization and scoring.
4. Fallback to `Generic AI` plus the best matching task tag.

### Product rule
Classification should be helpful, not magical. Persist a confidence value and always let the user edit tags manually.

### Important implementation detail
Do not block capture on classification quality. If needed, save immediately and classify on first app foreground after the write completes.

## 10. Main App UX
### Navigation recommendation
Keep navigation simple:
- Primary screen: Library
- Secondary management surfaces: Folders, Tags, Settings
- Detail screen: Prompt detail with copy action

### Library screen requirements
- Show recent prompts by default.
- Support filter chips or segmented controls for folder and tag filters.
- Include obvious empty states for first run.
- Make each row readable on iPhone without truncating all context.

### Prompt detail requirements
This is the most important screen.

It should show on one screen without forcing drill-down:
- Title
- Prompt body
- Suggested tool tag
- Suggested task tag
- Folder assignment
- Custom tags
- Copy button
- Pin or favorite action

### Copy behavior
- Use `UIPasteboard.general.string` from the main app.
- Increment `copyCount`.
- Update `lastCopiedAt`.
- Optionally show a lightweight confirmation state.

## 11. Folder and Tag Management
Keep this lightweight.

Minimum functionality:
- Create folder
- Rename folder
- Create custom tag
- Assign folder and tags from prompt detail
- Filter library by folder and tag

Do not build a complex editing suite. Speed matters more than taxonomy depth.

## 12. Widget Plan
### MVP widget behavior
Provide one widget family that surfaces recent or pinned prompts.

Recommended widget data:
- prompt title
- short preview
- tag badge or folder label if space permits

### Interaction model
- Tapping a widget item should deep-link to the exact prompt detail screen.
- If no prompts exist, show a friendly empty state leading users to share content into the app.

Do not assume widget clipboard writes are reliable enough for MVP without target-version verification.

## 13. iCloud Sync Plan
### Persistence setup
- Configure `NSPersistentCloudKitContainer` in `PersistenceController`.
- Store SQLite files in the App Group container.
- Mirror into the user private CloudKit database.

### UX requirements
- App must remain usable if iCloud is signed out.
- Show sync status or a concise explanatory message in Settings.
- Do not block local writes on sync availability.

### Testing requirements
Validate at least these states:
- fresh install with iCloud available
- iCloud disabled
- offline mode
- same account on second device or simulator pair if available

## 14. Testing Strategy
### Unit tests
Add tests for:
- prompt normalization
- categorization heuristics
- repository CRUD
- copy metadata updates

### UI tests
Add UI tests for:
- launch with seeded prompt data
- library loads and opens detail
- copy action is available and does not crash
- folder or tag filtering changes visible results

### Manual QA checklist
- Share text from Safari or Notes into PromptFlow
- Share a URL into PromptFlow
- Open new prompt in app and copy it
- Edit tags and folder
- Pin a prompt and verify widget visibility
- Disable network and confirm local behavior still works
- Re-enable network and verify app remains stable

## 15. Implementation Phases
### Phase 1: Foundation
- Scaffold Xcode project and targets.
- Configure entitlements and App Group.
- Implement Core Data stack and repository.

### Phase 2: Capture and core read path
- Build share extension.
- Build library list and prompt detail.
- Implement copy flow.

### Phase 3: Organization and intelligence
- Add folders and tags.
- Add local categorization service.
- Add manual editing path for bad suggestions.

### Phase 4: Widget and sync hardening
- Build recent or pinned widget.
- Enable CloudKit mirroring.
- Add sync state handling and settings surface.

### Phase 5: Test and polish
- Add unit and UI tests.
- Run simulator QA.
- Fix entitlement, empty-state, and offline edge cases.

## 16. Acceptance Criteria
The MVP is complete when all of the following are true:
- Sharing text from another app creates a prompt in PromptFlow.
- Sharing a URL creates a prompt with useful stored metadata.
- New prompts get AI tool and task-type suggestions offline.
- The user can open a prompt and copy it from a single detail screen.
- The user can organize prompts using folders and tags.
- The widget surfaces recent or pinned prompts and deep-links into the app.
- The app works locally with no account beyond optional iCloud.
- iCloud sync mirrors data through the private database when available.
- Unit and UI tests cover the core flows and pass on simulator.

## 17. Risks and Mitigations
### Share extension instability
Mitigation: keep extension work minimal and offload heavier enrichment to the app.

### CloudKit schema surprises
Mitigation: start with a conservative model and test iCloud-enabled and iCloud-disabled states early.

### Weak classification quality
Mitigation: keep taxonomy narrow, use transparent heuristics, persist confidence, and support easy edits.

### Widget interaction limits
Mitigation: ship a deep-link widget first instead of overpromising direct actions.

## 18. Execution Guidance for the Downstream Agent
- Work on a dedicated git branch from the start.
- Build and run the app on iPhone simulator after each phase.
- Do not introduce a server or cross-platform framework to solve local iOS problems.
- Prefer small, verifiable commits aligned to the phase breakdown above.
- If a platform limitation blocks a feature, preserve the core capture-to-copy workflow first and document the tradeoff instead of adding architectural complexity.

## 19. Definition of Done
A user on iPhone can share a prompt into PromptFlow, see it categorized and organized locally, open it quickly, copy it in one tap, and keep it synced over iCloud without creating an account.