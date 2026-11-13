# Build plan

The feature decisions are in [FEATURES.md](FEATURES.md). This file is the order of work.

**How we work:** Claude builds each milestone, then runs it and checks it with screenshots. Mari opens the app, tries it, and says what looks or feels off. A milestone is done when Mari is happy with it.

## Technical decisions

- **Native Mac app in Swift.** SwiftUI for the interface, AVFoundation for video, Metal for rendering.
- **Built without Xcode for the MVP,** using Swift Package Manager from the command line. A small script packages the build into a `.app` you can double-click. Xcode is needed from phase 2, for screen recording permission and app signing.
- **Metal shaders are compiled when the app starts.** Without Xcode there's no shader compiler on this Mac. The app compiles them at launch instead, with no visible difference.
- **Runs on macOS 14 (Sonoma) and later,** on Apple silicon.
- **One renderer for preview and export,** so what you see while editing is exactly what you get.
- **The output size is a setting from day one,** so other aspect ratios (Maybe) stay cheap to add later.
- **Project file:** a folder package holding `project.json` (the edits: cuts, speed, zooms, style, export settings) and a reference to the source video. It has an empty `cursor` slot for phase 2.
- **No sound in v1.** Imported videos play and export silently. The timeline model has room for audio tracks later.

## MVP: edit imported recordings

Each milestone ends with something Mari can open and try.

### M1: Open, play, export
The whole pipeline, end to end, as plainly as possible.
- App window with a preview area and play and pause controls
- Import a video by drag and drop, or with File › Open
- Play it in the preview through the Metal renderer
- Export it as MP4 (1080p) through the hardware encoder, with a progress bar
- Save and reopen a project

**Try it:** drop in a screen recording, play it, export it, then open the MP4.

### M2: Frame and style
- Backgrounds: built-in wallpapers, gradients, solid colors, your own image
- Padding, rounded corners and a drop shadow
- An inspector panel on the side with these controls, updating the preview live

**Try it:** this is the first "looks like Screen Studio" moment. Expect feedback rounds on the default look.

### M3: Timeline
- Timeline under the preview: a clip track and an (empty) zoom track, a gray playhead and a blue hover/edit line that the preview follows (no thumbnails, per Mari's 2026-11-12 design)
- Split clips with the scissors tool (click scissors, then click the timeline); click a clip to set its speed or delete it in the side panel (trimming = split + delete the end clip)
- Speed up clips (2×, 4×, 8×, or custom)
- Undo and redo for every edit

**Try it:** edit a real recording down to its good parts.

### M4: Crop and zoom
- Crop with handles on the preview
- Zoom segments on a track in the timeline: add, move, resize, delete
- Choose where each zoom points and how far it goes
- Spring-like easing in and out, with a few presets plus fine-tuning

**Try it:** the most "feel" work in the MVP. Expect several rounds on easing and timing.

### M5: Export options and polish
- MP4 at 720p, 1080p or 4K; 30 or 60 fps
- GIF up to 1080p, with a good color palette and a file size estimate
- Check that preview and export stay smooth with long or 4K recordings
- App icon, menus, keyboard shortcuts, empty states

**Try it:** use it for a real video you'd post.

## Phase 2: record in the app

Before starting: install Xcode (free, from the App Store).

- **P1. Capture:** record a display, window or area; countdown; global shortcut; pause and resume; hide desktop icons; save the cursor and click log into the project's cursor slot
- **P2. Cursor:** draw the cursor from the log: smoothing, size, style, sharp cursor images, motion blur, click effects, idle hide
- **P3. Auto-zoom:** create zoom segments from clicks and typing, then let Mari edit them on the zoom track from M4
- **P4. Tuning:** rounds on real recordings until auto-zoom and the cursor feel right

## Next step

The MVP (M1–M5) is done and signed off (2026-11-12). Next: install Xcode, then P1 (capture).
