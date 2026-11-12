# video-editing-tool

A native Mac app for editing screen recordings, in the spirit of Screen Studio: polished zooms, a styled frame and (later) a smooth styled cursor, exported quickly as MP4 or GIF. It's an original app. Don't copy Screen Studio's name, branding, art or UI.

**Who does what:** Mari is a product designer and the owner. Claude builds the app: it writes, builds, runs and checks the code. Mari tries each milestone and judges look and feel. Mari doesn't read or write code, so explain technical things in plain language.

## Keep this file current (every session)

This file is the shared memory for every Claude session on this project. Any agent working here must:

1. **Read this file, [PLAN.md](PLAN.md) and [FEATURES.md](FEATURES.md) before starting work.**
2. **Update this file before ending a session** in which anything changed. Add:
   - a line to the **Session log**
   - an entry to the **Decision log** for each decision Mari made, with the reason
   - any change to **Current status** and **Open questions**
3. **Also update it in the middle of long sessions,** after each milestone or major decision, so nothing is lost if a session ends early.
4. Keep entries short and in plain language. Newest first. Use absolute dates (YYYY-MM-DD).
5. Put the feature list in FEATURES.md and the build order in PLAN.md. This file records context, decisions and history, and links to those two.

## Current status

- **Phase:** M3 (timeline) reworked to Mari's 2026-11-12 design and pushed, **waiting for Mari to try it.** M2 (frame and style) is also still waiting for feedback on the default look. M1 was approved on 2026-11-10. Next: M4 (crop and zoom).
- Git repo on branch `main`, remote `origin` = https://github.com/marihirano/video-editing-tool.git. Pushed to GitHub on 2026-11-10 (Mari approved). The `gh` tool isn't installed; use plain `git`.
- **Build the app:** `scripts/build-app.sh` → `build/Video Editing Tool.app` (release build, ad-hoc signed). **Run checks:** `swift run CoreChecks` (project save/reopen, shader compile, layout, a real 1080p hardware export of a generated test video). XCTest and Swift Testing don't run without Xcode, so checks are a plain program.
- **Screenshots:** the terminal has no screen-recording permission and computer use was off. `VET_SNAPSHOT=/path.png` makes the app save its window, log whether the preview drew video frames (`/path.png.txt`), and quit; launch with `open -n --env VET_SNAPSHOT=… -a "build/Video Editing Tool.app" video.mov`. The Metal preview itself is blank in that picture.
- **Code map:** `Sources/EditorCore/` = `Settings.swift` (every tunable value), `Project/` (model, save/load, TimeMap), `Render/` (shaders as source text, FrameLayout steps crop → zoom → cursor → frame, FrameRenderer, MetalContext). `Views/InspectorView.swift` = the right-hand style panel; `EditorModel.updateStyle` changes the style and sets `hasUnsavedChanges`, `Playback/`, `Export/`. `Sources/VideoEditingTool/` = SwiftUI app, `EditorModel`, menus, `Views/`. `Resources/Info.plist` declares the `.vetproj` package type.
- **Style (M2):** `project.json` → `style` holds kind (wallpaper/gradient/solid/image), colours, wallpaper index, padding, corner radius and shadow. All defaults, ranges, gradients and wallpapers are in `Settings.swift`. Wallpapers are four-colour blends drawn by the shader (original, no image files). A custom background image is stored as an absolute path, so moving the picture breaks it (falls back to a blank background). Padding is % of canvas height; corners, blur and distance are pixels on a 1080-tall canvas and scale with output size. `CoreChecks` writes example frames if `VET_CHECK_FRAME_DIR=<folder>` is set.
- **Timeline (M3):** `project.json` → `timeline.clips` = the pieces of the recording in the video, in order, each `{start, end, rate}` in source seconds (empty = whole recording). Split/delete/speed are in `Project/TimelineEdits.swift`; files from the first M3 build (`trim`/`cuts`/`speedSegments`) are read and turned into clips. `TimeMap` places clips on the finished video's clock and is used by both export and `PlaybackController` (jumps over deleted parts, sets `player.rate`). The timeline shows the finished video (deleted clips close up). Gray line = `playback.playheadTime`; blue line = `EditorModel.hoverTime ?? editTime`; hovering calls `playback.skim` so the preview shows that moment, click pins the blue line and moves the playhead. Scissors button = a cut tool (`CutMode.swift`: scissors pointer via an event monitor; every timeline click cuts until the scissors button is clicked again or Esc). Clicking a clip selects it and the side panel shows `ClipInspector` (speed, delete, "‹ Style" back). Top bar = SwiftUI `.toolbar` in `ContentView` (undo/redo, side-panel toggle, Export). Every edit goes through `EditorModel.edit` → `UndoHistory` (one slider drag = one step). Unsaved changes asked on open, quit and window close (`WindowCloseGuard`). `VET_SNAPSHOT_SPLIT=1` makes the debug snapshot cut once with the scissors tool and select clip 2; it also writes `…-top.png` with the top bar.
- **Known M1 limits:** rotated videos (phone footage) aren't turned upright; colour is passed through as-is (no Display P3 → BT.709 conversion); unsaved-changes prompt added in M3.
- Xcode is **not installed** (only the command-line tools, Swift 6.3.2). That's fine for the MVP. Mari installs Xcode before phase 2.
- Mari's Mac: macOS 26.6, Apple silicon (arm64).

## Files and links

| What | Where |
|---|---|
| Feature decisions (Now / Future / Maybe / Never) and effort | [FEATURES.md](FEATURES.md) |
| Build plan and milestones | [PLAN.md](PLAN.md) |
| Feature triage page (the source of truth for decisions) | https://claude.ai/artifact/ALXf7BAygL8xHEsJv6Gyy7, source [feature-triage.html](feature-triage.html) |
| Project Drive entry | project `video-editing-tool` in `~/design-project-drive` |

**Reading the triage page's decisions:** use the `ArtifactData` tool, `action: "list"`, collection `decisions`, on the artifact URL above. Each doc id is a feature id (like `zm-auto`) with `{status: "now" | "future" | "maybe" | "never"}`. The list of features with their ids is the `GROUPS` array in `feature-triage.html`. After Mari changes choices, sync FEATURES.md from the page.

**Updating the triage page:** edit `feature-triage.html`, then republish to the same URL. Its database rules: everyone with access can read, and only editors and above can write.

## Project Drive filing

This project is registered in Project Drive as `video-editing-tool` (see the global `~/.claude/CLAUDE.md`). File every new artifact the same session it's created, by running from this folder:

```bash
node ~/design-project-drive/sweep.mjs add --type <type> --url <url> --label "<short name>"
```

- **Already filed:** the local folder; the triage page (as `deployment`, label "feature triage"); the GitHub repo.
- **To file when created:** Figma files, any deployments.
- Mari tags this project's links in her daily reflections with `#video-editing-tool`.

## The plan in brief

- **MVP: edit imported recordings (13 features).** Import, trim, cut, speed, crop, undo and redo, manual zoom with spring easing, background, padding, corners and shadow, MP4, GIF, hardware encoding. Milestones M1–M5 are in PLAN.md.
- **Phase 2: record in the app (14 features).** Screen capture with a cursor and click log, countdown, shortcut, pause, hide desktop icons, auto-zoom, 7 cursor features. Milestones P1–P4.
- **Everything else** is Future, Maybe or Never, as marked on the triage page.

## Technical decisions

- Native Mac app in **Swift**: SwiftUI for the interface, **AVFoundation** for video, **Metal** for rendering, **ScreenCaptureKit** for capture (phase 2).
- **MVP builds without Xcode:** Swift Package Manager, plus a script that packages the build into a `.app`. Metal shaders are compiled from source when the app starts (there's no Metal compiler without Xcode).
- Runs on **macOS 14 and later**, on Apple silicon.
- **One renderer for preview and export.** The order of operations is crop → zoom → cursor (phase 2) → frame and background.
- **The output size is a setting from day one,** so other aspect ratios stay cheap to add.
- **Project file:** a folder package with `project.json` (the edits) plus a reference to the source video. It has an empty `cursor` slot that the MVP never shows or uses.
- **No audio in v1,** but the timeline model leaves room for audio tracks.
- **Imported videos never get cursor effects or auto-zoom,** because they have no cursor data. Those features appear only for recordings made in the app.

## Decision log

Newest first. Each entry: date, decision, reason.

- **2026-11-12** — **Scissors is a tool, clip speed lives in the side panel (Mari):** clicking the scissors turns the pointer into scissors; the next click on the timeline cuts there. No pop-up menu on clips: clicking a clip shows its speed (1×/2×/4×/8×/custom) and Delete in the side panel, with "‹ Style" to go back to the background settings. *Why:* Mari's feedback. Mari then asked for the scissors to stay on until clicked again (Esc also turns it off). **Claude's calls, for review:** the scissors button turns blue while the tool is out; selecting a clip re-opens a hidden side panel.
- **2026-11-12** — **M3 timeline redesign (Mari's mockup):** undo/redo, a side-panel collapse button and a blue Export MP4 button in the top bar, title centred. Under the preview: play, time, scissors. Two tracks: orange clips labelled "length speed" (e.g. "30s 1×") on top, an empty zoom track below for M4. Gray line = playhead; blue line = where you hover (preview shows that frame) and where you clicked; the scissors split at the blue line and clicking a clip opened a menu (both changed later the same day, see above). *Why:* Mari's design. **Claude's calls within it, for review:** clicking also moves the playhead; deleted clips close up (undo brings them back); no thumbnails or trim handles (trim = split + delete); Delete key removes the selected clip, ⌘B splits.
- **2026-11-10** — **M3 timeline choices (Claude's, superseded on 2026-11-12):** the timeline always shows the whole recording, with trimmed ends dimmed, cut parts striped red and sped-up parts marked by an orange band, so removed parts can be seen and restored. Click moves the playhead; drag across selects a part; Cut (Delete key), Speed (2×, 4×, 8×, custom 1.1–32×) and Restore act on the selection. Yellow handles trim the ends, and "Start here" / "End here" ( [ and ] keys) trim to the playhead. The old position slider is gone (the timeline replaces it); the time readout shows the finished video's length. Undo covers style changes too; one slider drag = one undo step. Prompt says Save / Cancel / Don't Save. *Why:* familiar editing pattern; all values in `Settings.swift`.

- **2026-11-10** — **M2 default look (Claude's, for Mari to review):** "Aurora" wallpaper (dark navy to mint, violet and blue), padding 8% of the height, corner radius 14 px, shadow 45% opacity, blur 40, 16 px lower. Four wallpapers (Aurora, Dusk, Meadow, Ember), six gradients, a colour picker and "your own image". Style changes mark the project changed with a simple flag; no unsaved-changes prompt or undo until M3. The old black-bars look is gone: a non-16:9 video now sits on the background. M1 projects open with the new default look. Fps, resolution and other aspect ratios were not added (M5 and Maybe). *Why:* sensible starting point to react to; all values in `Settings.swift`.

- **2026-11-10** — **M1 build choices (Claude's, for Mari to veto):** project packages use the `.vetproj` extension; export defaults to 1080p **60 fps** H.264 at ~16 Mbit/s with the hardware encoder; the window is always dark; the preview always matches the output shape (16:9) with black bars around other shapes; the project stores the source as a bookmark plus relative and absolute paths, so moving files usually still works. *Why:* sensible defaults for screen recordings; all are in `Settings.swift` and easy to change.

- **2026-11-10** — **How to work efficiently:** one fresh session per milestone; small, focused files; compiler checks before screenshots; batched feedback; all tuning values in one settings file. Models: Opus for M1, M3, M4 and phase 2; Sonnet for M2, M5 and feedback rounds; Haiku or Sonnet for docs and filing. *Why:* Mari wants to keep token usage low.

- **2026-11-10** — **This CLAUDE.md records every session,** and agents update it periodically. *Why:* Mari wants every future agent to have the full context.
- **2026-11-10** — **The phase plan is locked.** The MVP edits imported recordings; phase 2 adds recording in the app. *Why:* Mari's proposal. The biggest blocks (renderer, timeline, export) get built first and can be tested with any video, with no permissions. The trade-off Mari accepted is that auto-zoom and the cursor effects only arrive in phase 2.
- **2026-11-10** — **Claude builds the app;** progress is measured in milestones Mari can try, not weeks. *Why:* Mari's call.
- **2026-11-10** — **Native Mac app, not a web app or Electron.** *Why:* phase 2 needs the cursor position and clicks in other apps, which browsers can't see. Hardware encoding and smooth 4K preview also need native access. Mari asked and agreed after the explanation.
- **2026-11-10** — **Feature triage finished:** 27 Now, 19 Future, 7 Maybe, 25 Never, out of 78 Screen Studio features. *Why:* Mari's picks on the triage page.
- **2026-11-10** — **The triage page has four choices: Now, Future, Maybe, Never.** *Why:* Mari asked for a three-way choice, then added Maybe.
- **2026-11-10** — **The project name is `video-editing-tool`,** the same as the folder. *Why:* Mari's pick. Use it for the repo, Figma file and deployment.

## Session log

Newest first. One or two lines per session.

- **2026-11-12** — Scissors became a cut tool with a scissors pointer; clip speed and delete moved from a pop-up menu to the side panel (with "‹ Style" back). All checks pass; app builds.

- **2026-11-12** — Applied Mari's M3 feedback: clip-based timeline (split / delete / speed per clip), hover preview with gray and blue lines, empty zoom track, top bar with undo/redo, side-panel toggle and Export. Checks updated (clips, old-file conversion, edited export length and frames). All checks pass; app builds.

- **2026-11-10** — Built M3: TimeMap with trim, cuts and speed (shared by preview and export), timeline with thumbnails, playhead, selection and trim handles, Cut/Speed/Restore toolbar, undo and redo for every edit, unsaved-changes prompt on open/quit/close. Checks added (TimeMap, edit tidying, round-trip, undo grouping, edited export length and frames). All checks pass; app builds and plays.

- **2026-11-10** — Built M2: style model (tolerant of old files), shader background (wallpaper, gradient, colour, image), rounded corners and shadow, padding in the layout, inspector panel with live preview, checks for save/reopen, M1 files and a styled export (looked at exported frames). All checks pass; app builds and plays.

- **2026-11-10** — Built M1: git set up, Swift package (EditorCore library + app + CoreChecks), Metal renderer shared by preview and export, silent playback, hardware MP4 export with progress and cancel, save/reopen `.vetproj` projects with the empty cursor slot, `scripts/build-app.sh`. All checks pass; app verified opening a video from Finder and playing. Pushed after Mari approved.

- **2026-11-10** — Project start. Registered in Project Drive. Researched Screen Studio's features (version 4.1) and built the triage page. Explained features Mari asked about (crop, loupe zoom, inset, hardware encoding). Mari sorted all 78. Estimated effort, then split Now into MVP and phase 2. Explained Swift and native vs web. Wrote FEATURES.md, PLAN.md and this file.

## Open questions

- **Autosave** is Maybe. Claude recommends building it into capture in phase 2, because it's cheap there.
- **Edit by transcript and filler-word removal** are Future, but transcription is Never. They need a transcript, so revisit transcription if those move up.
- **Hint for imported videos:** whether to tell people to record in the app to unlock auto-zoom. To decide in phase 2.
- **App name and icon:** not decided. `video-editing-tool` is the project name for now.
