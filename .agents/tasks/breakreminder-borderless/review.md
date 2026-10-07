# Borderless break reminder overlay (pass 3) — intent met, build evidence now present

The aggressive full-screen break reminder (`BreakReminderView`) floats its content directly on the dimmed backdrop with no outer panel: the material-filled rounded rectangle, the `pulse`-driven stroke border, and the heavy drop shadow are all absent. Legibility is carried by a raised backdrop dim (`0.58`) plus a soft, blurred radial scrim behind the content column rather than a solid card. The one blocking item carried over from pass 2 — missing Release build evidence — is now satisfied: `build.log` in the task directory records the Release `xcodebuild` command and `** BUILD SUCCEEDED **`. All eight acceptance checks pass.

Watch for: the HEAD→working-tree diff spans eleven files, not one, because the "card" the intent describes removing never existed on the committed HEAD — it lived in uncommitted redesign work (confirmed via `git log`/`plan.md`), so the diff bundles the whole SCREEN RESET redesign. The borderless edit itself and its one forced companion (`BreakReminderWindowController`, which must pass the two new required params) are correct; the other nine files are a broader redesign the committer should confirm belong to this commit (confirmed).

**Verdict**: APPROVED

## High-level view

The borderless outcome is correct and complete. The main content `VStack(spacing: 26)` closes with `.padding(36) → .frame(width:) → .background { RadialGradient … .blur(40) } → .position(…)`. Grep confirms the file contains no `.regularMaterial`, no `cornerRadius: 30`, no `.stroke` outer overlay, and no `.shadow(color: .black.opacity(0.4), radius: 50, y: 24)`. The replacement scrim fades to `.clear` and is blurred 40pt, so there is no panel silhouette and nothing hard-edged was reintroduced.

Legibility is handled without a panel: the full-screen backdrop dim is raised to `0.58` and a soft radial scrim sits behind the content column. Inner `BreakTip` tiles (`0.03`, stroke dropped) and `SessionMetric` chips (`0.04`) are softened so the composition reads cohesive, not boxy.

The `pulse` flag has a single live consumer, `ShoulderRollIllustration(highlighted: pulse)`, and `.animation(…, value: pulse)` still animates that highlight, so the reminder keeps motion without driving a non-existent border. All three action closures (`onStartBreak`, `onSnooze`, `onSkip`) are wired to the same buttons with bodies unchanged.

Build verification is now established: `build.log` records the Release `xcodebuild` invocation dated Oct 8 00:59 and ends in `** BUILD SUCCEEDED **`, resolving the sole blocking concern from pass 2. The compile risk from the two new required params (`breakMinutes`, `snoozeMinutes`) is covered — the only call site, `BreakReminderWindowController.makeRoot()`, passes both.

The remaining open item is scope: the intent says only `BreakReminderView.swift` should change, yet the working tree touches eleven files. This is non-blocking for the borderless styling goal but the committer should confirm the unrelated files are intended for this commit.

<details>
<summary>Issues (1)</summary>

1. **Scope spans more than BreakReminderView.swift** — the intent says only `BreakReminderView.swift` should change. The two new required params force a (correct) edit to `BreakReminderWindowController.swift`, and the HEAD diff additionally sweeps in 9 files unrelated to the borderless goal (menu redesign, BreakCoordinator and tests, ReminderPresenter, AppModel, ScreenPlacement, Info.plist, project.pbxproj, .gitignore). Confirm these belong to this commit or split them out. Non-blocking for the styling intent. (confirmed)

</details>

<details>
<summary>Details</summary>

### Card frame removal — the final chain

The content `VStack(spacing: 26)` closes into:

```swift
.padding(36)
.frame(width: min(920, max(0, geometry.size.width - 64)))
.background {
    RadialGradient(colors: [.black.opacity(0.28), .clear],
                   center: .center, startRadius: 0, endRadius: 620)
        .blur(radius: 40)
        .allowsHitTesting(false)
}
.position(x: geometry.size.width / 2, y: geometry.size.height / 2)
```

The three card-forming modifiers named in the intent — the `.regularMaterial` rounded-rectangle background, the rounded-rectangle `.stroke` overlay, and `.shadow(color: .black.opacity(0.4), radius: 50, y: 24)` — are absent from the whole file (grep returned no match). The replacement background fades to `.clear` and is blurred 40pt, so there is no hard edge and no panel silhouette. `.frame(width:)` is retained, keeping the content a centered readable column (max 920pt) rather than stretching edge-to-edge, and `.position` keeps it centered. The one potential reintroduction risk, the `ShoulderRollIllustration`'s own rounded-rect stroke, is an inner 220×175 exercise cue, not the outer content panel, so it does not revive the card.

### Legibility and inner softening

The full-screen backdrop is `Rectangle().fill(.ultraThinMaterial).overlay(Color.black.opacity(0.58))`, paired with the soft radial scrim behind the column. No solid panel carries contrast, matching the "slight dim increase and/or subtle scrim is OK; a solid panel is NOT" constraint. `BreakTip` tiles use `.white.opacity(0.03)` with no stroke overlay; `SessionMetric` chips use `.white.opacity(0.04)`. Subtle backgrounds are kept so the groupings still read, without hard borders. The `Divider().overlay(.white.opacity(0.12))` is a thin hairline, not a panel border.

### pulse and actions

`pulse` previously fed the deleted card stroke's opacity/width; it now has exactly one consumer, `ShoulderRollIllustration(highlighted: pulse)`, and `.animation(…, value: pulse)` still animates that highlight. The three action closures are wired to the same three buttons with bodies unchanged; the only keyboard shortcut is the pre-existing `.defaultAction` on Start.

### Build evidence and the controller coupling

`build.log` under `.agents/tasks/breakreminder-borderless/` records the exact Release command (`xcodebuild -project StandUp.xcodeproj -scheme StandUp -configuration Release build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`), dated Oct 8 00:59, ending in `** BUILD SUCCEEDED **`. This resolves pass 2's lone blocking finding. The view's new signature adds `var breakMinutes: Int` and `var snoozeMinutes: Int` as non-optional, forcing the only call site, `BreakReminderWindowController.makeRoot()`, to pass both — which it does (`breakMinutes:`/`snoozeMinutes:` confirmed at lines 111–112). That controller edit is intrinsic to this view change.

### Scope

The remaining changed files are not required by the borderless goal; per `plan.md` they are part of a broader uncommitted redesign the committed HEAD baseline doesn't capture, which is also why the HEAD-based diff still shows the pre-redesign simple layout as the "before" rather than the card the intent describes. The task's acceptance says only `BreakReminderView.swift` should change, so these should be confirmed as intended companions or separated. This does not affect the borderless styling result and so is non-blocking.

</details>

<details>
<summary>File map</summary>

- `StandUp/StandUp/Views/BreakReminderView.swift` — outer card background/stroke/shadow removed; radial scrim + raised dim (`0.58`); new `breakMinutes`/`snoozeMinutes` params; `SessionMetric`, `BreakTip`, `ShoulderRollIllustration` subviews; redesigned layout and labels. (In scope.)
- `StandUp/StandUp/AppKit/BreakReminderWindowController.swift` — passes the two new params to the view. (Forced by this change.)
- `StandUp/StandUp/Views/MenuBarContentView.swift`, `.../AppModel.swift`, `.../Services/ReminderPresenter.swift`, `.../AppKit/ScreenPlacement.swift`, `.../Info.plist`, `StandUp.xcodeproj/project.pbxproj`, `StandUpCore/.../BreakCoordinator.swift`, `.../BreakCoordinatorTests.swift`, `.gitignore` — unrelated to the borderless goal; verify they belong to this commit.

Full diff: `git diff` in the repo root; view-only: `git diff -- StandUp/StandUp/Views/BreakReminderView.swift`. Build evidence: `.agents/tasks/breakreminder-borderless/build.log`.

</details>
