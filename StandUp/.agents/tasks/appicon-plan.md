# Implementation Plan: Add Application Icon (AppIcon) to StandUp

## Goal

Make the StandUp logo appear as the **application icon** (Finder, Spotlight "application" search, the About window / app switcher when visible). The **existing menu bar icon must remain completely unchanged** — it is an SF Symbol driven by `MenuBarLabelView` and the `MenuBarExtra` label in `StandUpApp.swift`, and is entirely independent of the app icon.

## Key findings from exploration (read before implementing)

- **No asset catalog exists.** Confirmed by searching the repo (`find ... -name "*.xcassets"` returns nothing) and by reading `project.pbxproj`: there is no `Assets.xcassets` file reference and no `ASSETCATALOG_COMPILER_APPICON_NAME` build setting.
- **The project format is Xcode 16+ synchronized folders (`objectVersion = 77`).** The `StandUp` source folder is declared as a `PBXFileSystemSynchronizedRootGroup` (object `A1000020`), referenced by the `StandUp` target (`A1000005`) via its `fileSystemSynchronizedGroups` list. **Consequence:** any file placed on disk under `StandUp/StandUp/` is automatically included in the target's build — no `PBXFileReference`, no `PBXBuildFile`, and no `PBXResourcesBuildPhase` entry are needed or wanted.
- **DEVIATION from the task brief (deliberate, with reason):** The task asked to add a `PBXFileReference`, a Resources-build-phase entry, and new 24-char object IDs for `Assets.xcassets`. That procedure is for the **legacy** pbxproj format. In this synchronized-folder project, adding those entries would make the catalog a member of the target **twice** (once implicitly via the synchronized group, once explicitly), which Xcode flags as a duplicate/"multiple commands produce" build error. The correct wiring here is: drop the catalog on disk inside the synchronized folder, and add only the `ASSETCATALOG_COMPILER_APPICON_NAME` build setting. The `.pbxproj` object-ID edits in the brief are therefore intentionally **not** performed; the only `.pbxproj` change is to the two `buildSettings` dictionaries (see item 4).
- The `StandUp` target already has `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor` in both Debug (`A1000018`) and Release (`A1000019`). This currently references a non-existent `AccentColor` asset, which is harmless. We will add the AppIcon setting next to it; we do **not** need to add an AccentColor asset.
- **Source image:** `/Users/matanrephaelganon/Documents/timer/docs/images/screenshot.png`, confirmed **1254×1254** square PNG. All required icon sizes (max 1024×1024) are downscales — we never upscale.
- **Tooling present:** `sips` at `/usr/bin/sips`; Xcode 27.0 (`xcodebuild` works); active developer dir `/Applications/Xcode.app/Contents/Developer`. Deployment target macOS 15.0.
- **Menu bar code to leave untouched:** `StandUp/StandUp/Views/MenuBarLabelView.swift` (SF Symbols + countdown text), `StandUp/StandUp/Views/MenuBarContentView.swift`, and the `MenuBarExtra { ... } label: { MenuBarLabelView(...) }` block in `StandUp/StandUp/StandUpApp.swift`. None of these reference an app icon; setting the AppIcon does not affect them.

## macOS AppIcon size requirements (what the appiconset must contain)

Standard macOS icon set — 10 entries, 5 sizes at @1x and @2x. Pixel dimensions = point size × scale:

| idiom | size (pt) | scale | pixels | filename |
|-------|-----------|-------|--------|----------|
| mac | 16x16   | 1x | 16   | icon_16.png     |
| mac | 16x16   | 2x | 32   | icon_16@2x.png  |
| mac | 32x32   | 1x | 32   | icon_32.png     |
| mac | 32x32   | 2x | 64   | icon_32@2x.png  |
| mac | 128x128 | 1x | 128  | icon_128.png    |
| mac | 128x128 | 2x | 256  | icon_128@2x.png |
| mac | 256x256 | 1x | 256  | icon_256.png    |
| mac | 256x256 | 2x | 512  | icon_256@2x.png |
| mac | 512x512 | 1x | 512  | icon_512.png    |
| mac | 512x512 | 2x | 1024 | icon_512@2x.png |

All ten are downscales from the 1254×1254 source (largest needed is 1024). Note 32 and 256 pixels each appear twice (as the @2x of one size and @1x of the next) — generate the PNG once per unique pixel dimension and reuse, or generate per filename; either is fine as long as all ten files exist.

---

# Implementation Plan

- [ ] 1. Create the asset catalog root and its `Contents.json`.
      Create directory `StandUp/StandUp/Assets.xcassets/` and a top-level `Contents.json` containing only the author metadata: `{ "info": { "author": "xcode", "version": 1 } }`. This marks the folder as an asset catalog so Xcode's `actool` compiles it.
      Files: `StandUp/StandUp/Assets.xcassets/Contents.json` (create)
      Verify: `test -f StandUp/StandUp/Assets.xcassets/Contents.json && python3 -c "import json;json.load(open('StandUp/StandUp/Assets.xcassets/Contents.json'))"` — exits 0 (valid JSON present).

- [ ] 2. Generate the ten PNG icon files from the source image with `sips`.
      Create directory `StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/`. From the source `/Users/matanrephaelganon/Documents/timer/docs/images/screenshot.png` (1254×1254), produce the files listed in the size table using `sips -z <px> <px> <source> --out <dest>` for each unique pixel size (16, 32, 64, 128, 256, 512, 1024), then place/copy them under the ten required filenames (icon_16.png, icon_16@2x.png, icon_32.png, icon_32@2x.png, icon_128.png, icon_128@2x.png, icon_256.png, icon_256@2x.png, icon_512.png, icon_512@2x.png). `sips -z` only downscales here; never pass a dimension larger than the source. Example for one: `sips -z 16 16 /Users/matanrephaelganon/Documents/timer/docs/images/screenshot.png --out StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/icon_16.png`.
      Files: the 10 PNGs under `StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/` (create)
      Verify: `ls StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/*.png | wc -l` prints `10`; spot-check dimensions, e.g. `sips -g pixelWidth StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/icon_512@2x.png` reports `pixelWidth: 1024` and `icon_16.png` reports `16`.

- [ ] 3. Create the `AppIcon.appiconset/Contents.json` that maps the ten files.
      Write a `Contents.json` with an `images` array of ten entries, each with `idiom: "mac"`, the correct `size` string ("16x16", "32x32", "128x128", "256x256", "512x512"), `scale` ("1x"/"2x"), and `filename` matching exactly the files from item 2, plus the top-level `info` block (`author: xcode`, `version: 1`). Filenames must match item 2 byte-for-byte or the build warns/fails on missing images.
      Files: `StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/Contents.json` (create)
      Verify: `python3 -c "import json;d=json.load(open('StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/Contents.json'));assert len(d['images'])==10"` exits 0; and confirm every `filename` in that JSON exists on disk (e.g. a short shell loop checking `test -f` for each) — all present.

- [ ] 4. Add `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` to the StandUp app target's Debug and Release build settings.
      In `StandUp/StandUp.xcodeproj/project.pbxproj`, edit the two `buildSettings` dictionaries for the **StandUp app** target only — Debug config object `A1000018` and Release config object `A1000019` (these are the two that already contain `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;`, `INFOPLIST_FILE = StandUp/Info.plist;`, and `PRODUCT_BUNDLE_IDENTIFIER = com.standup.app;`). Add the line `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;` to each. Do **not** touch the StandUpTests configs (`A100001A`/`A100001B`), the project-level configs (`A1000016`/`A1000017`), or add any `PBXFileReference`/`PBXBuildFile`/Resources-phase entries (see the DEVIATION note above — the synchronized folder handles catalog membership automatically).
      Files: `StandUp/StandUp.xcodeproj/project.pbxproj` (modify — exactly two added lines, one per config)
      Verify: `grep -c "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;" StandUp/StandUp.xcodeproj/project.pbxproj` prints `2`. (This grep is a sanity check on the edit, not the feature verification — item 6 is the real verification.)

- [ ] 5. Confirm no menu bar code was altered.
      Do not modify `StandUp/StandUp/Views/MenuBarLabelView.swift`, `StandUp/StandUp/Views/MenuBarContentView.swift`, or the `MenuBarExtra`/`label:` block in `StandUp/StandUp/StandUpApp.swift`. This is a guard item, not an edit.
      Files: none (verification only)
      Verify: `git status --porcelain` shows the only changed/added paths are under `StandUp/StandUp/Assets.xcassets/` and `StandUp/StandUp.xcodeproj/project.pbxproj` (plus this plan file under `.agents/`); the three menu bar files are absent from the diff. Optionally `git diff -- StandUp/StandUp/Views/MenuBarLabelView.swift StandUp/StandUp/Views/MenuBarContentView.swift StandUp/StandUp/StandUpApp.swift` is empty.

- [ ] 6. Build the app and confirm the icon compiles into the bundle; menu bar behavior unchanged.
      Clean-build the StandUp target with the project's real toolchain. The build must compile the asset catalog (actool) and embed the icon in the product.
      Files: none (verification only)
      Verify: run `xcodebuild -project StandUp/StandUp.xcodeproj -scheme StandUp -configuration Debug build CODE_SIGNING_ALLOWED=NO` (from repo root `/Users/matanrephaelganon/Documents/timer`) — ends with `** BUILD SUCCEEDED **`. Then locate the built app in DerivedData (e.g. `xcodebuild -project StandUp/StandUp.xcodeproj -scheme StandUp -showBuildSettings | grep -m1 BUILT_PRODUCTS_DIR`) and confirm the compiled icon is present: `ls "$BUILT_PRODUCTS_DIR/StandUp.app/Contents/Resources/" | grep -i -E 'AppIcon|\.icns'` lists an `AppIcon.icns` (and the Info.plist inside the bundle gains `CFBundleIconName = AppIcon` / `CFBundleIconFile`). The menu bar remains an SF Symbol because no menu bar code changed (item 5) — nothing further to run for that.

## Notes / assumptions

- If `xcodebuild` cannot run in the implementer's environment (e.g. headless CI without the full Xcode), the build verification in item 6 is the authoritative check and must be run wherever Xcode is available; items 1–4 are still verifiable by the file/JSON checks above. On this machine Xcode 27.0 is installed and `xcodebuild` works, so item 6 should run locally.
- `CODE_SIGNING_ALLOWED=NO` is used in item 6 to keep the build self-contained (the brief explicitly allows unsigned development builds). Signing is not required to validate the app icon.
- The source image is a screenshot/logo named `screenshot.png`; it is used as-is per the task. No cropping/padding is applied — it is already square. If the implementer finds the icon needs rounded-rect masking, that is a visual refinement outside this task's scope and should not block completion.

---

# Verification evidence (iteration 1 — implemented)

All six plan items implemented. The project is confirmed to be an Xcode 16+ synchronized-folder
project (`objectVersion = 77`, `StandUp` is a `PBXFileSystemSynchronizedRootGroup` object `A1000020`
referenced by target `A1000005`), so the catalog is wired by dropping it on disk inside
`StandUp/StandUp/` plus the single build-setting change. No `PBXFileReference`/`PBXBuildFile`/
Resources-phase edits were made (per the DEVIATION note above).

What was created/changed:
- `StandUp/StandUp/Assets.xcassets/Contents.json` (catalog root author metadata).
- `StandUp/StandUp/Assets.xcassets/AppIcon.appiconset/` — 10 PNGs + `Contents.json`.
  Generated with `sips -z <px> <px> screenshot.png --out <dest>` (downscales only; source 1254×1254).
  Confirmed dimensions: icon_16=16, icon_16@2x=32, icon_32=32, icon_32@2x=64, icon_128=128,
  icon_128@2x=256, icon_256=256, icon_256@2x=512, icon_512=512, icon_512@2x=1024.
- `StandUp/StandUp.xcodeproj/project.pbxproj` — added `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;`
  to the StandUp app target Debug (`A1000018`) and Release (`A1000019`) build settings only.
  `grep -c "ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;"` → `2`.

Build command run (from `/Users/matanrephaelganon/Documents/timer/StandUp`):
`xcodebuild -project StandUp.xcodeproj -scheme StandUp -configuration Release build CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO`
Result: `** BUILD SUCCEEDED **` (exit 0).

Compiled-icon evidence (built app at
`~/Library/Developer/Xcode/DerivedData/StandUp-czsxzyqcmnrzibedgpigjjxpuvsf/Build/Products/Release/StandUp.app`):
- `Contents/Resources/` contains `AppIcon.icns` (110661 bytes) and `Assets.car`.
- `Contents/Info.plist`: `CFBundleIconName = AppIcon` and `CFBundleIconFile = AppIcon`.

Menu bar unchanged (guard item 5):
`git diff --name-only -- MenuBarLabelView.swift MenuBarContentView.swift StandUpApp.swift` → empty.

Changed files from this task (`git status --porcelain`):
- `M  StandUp/StandUp.xcodeproj/project.pbxproj` (2 lines added)
- `?? StandUp/StandUp/Assets.xcassets/` (new catalog)
(Also present in the working tree but NOT from this task: `M README.md`, `?? docs/images/`,
`?? StandUp/.agents/` — pre-existing uncommitted changes from earlier workflow steps.)

Per constraints: no commit made, no worktree created — changes left in the working tree.
