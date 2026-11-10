# Features: decisions and build effort

Mari sorted all 78 Screen Studio features (version 4.1, November 2026) on the [Feature triage](https://claude.ai/artifact/ALXf7BAygL8xHEsJv6Gyy7) page (source: `feature-triage.html`). The page is the source of truth. This file is a copy of it, last synced on 2026-11-10.

| Now | Future | Maybe | Never |
|---|---|---|---|
| 27 | 19 | 7 | 25 |

**What v1 is:** a native Mac app, written in Swift. It edits screen recordings and makes them look polished with zooms, a styled frame and (in phase 2) a smooth styled cursor. It exports MP4 and GIF quickly. There's no sound or camera in v1. Claude builds it, and Mari reviews how it looks and feels.

---

## Now, in two phases (locked 2026-11-10)

### MVP: edit imported recordings (13)

Drop in a video you already have, from macOS's built-in recorder or anything else, and make it look good. No screen recording permission is needed.

**Import**
- Import an existing video and edit it

**Timeline editing**
- Trim the start and end
- Cut out sections from the middle
- Speed up sections
- Crop the recording to the part that matters
- Undo and redo

**Zoom**
- Add, move and edit zooms by hand on the timeline
- Smooth, spring-like zoom animation

**Frame and style**
- Background: wallpapers, gradients, solid colors, custom images
- Padding, rounded corners and a drop shadow

**Export**
- MP4 at 720p, 1080p or 4K, up to 60 fps
- GIF, up to 1080p
- Hardware-accelerated encoding on Apple silicon

### Phase 2: record in the app (14)

The app records the screen itself, so it knows exactly where the cursor was and when you clicked. That unlocks the signature look. Install Xcode before this phase starts.

**Recording**
- Record the full display, one window or a custom area
- Track the cursor and clicks as data, separate from the video
- Countdown before recording starts
- Global shortcut to start and stop
- Pause and resume within one take
- Hide desktop icons while recording

**Zoom**
- Zoom in automatically on clicks and typing

**Cursor**
- Smoothed cursor paths
- Change cursor size after recording
- High-resolution cursor that stays sharp when large
- Change cursor style after recording
- Motion blur on fast movement
- Click effects (circle or ripple)
- Hide the cursor when it's idle

**Built in from day one:** the project file has an empty slot for cursor data. The MVP never shows or uses it. Phase 2 fills it for recordings made in the app, and the cursor and auto-zoom controls appear only then. Imported videos never get them.

## Future (19)

- Recording: webcam, microphone and system sound
- Editing: speed up typing automatically, edit by transcript, remove filler words
- Zoom: smart framing around the webcam, loupe zoom
- Cursor: show keyboard shortcuts on screen
- Style: inset controls
- Camera: webcam bubble, layouts, animated layout transitions
- Audio: volume for each track
- Privacy: blur sensitive information, spotlight
- Sharing: shareable links, private links
- Roadmap: MCP server, annotations

## Maybe (7)

- Autosave with crash recovery
- Command menu (⌘K)
- Return the cursor to its start position, for looping videos
- Export 16:9, 1:1 and 9:16 from one recording
- Upscaling for sharp close-ups
- Copy the export to the clipboard
- Process on the Mac, with cloud features opt-in

## Never (25)

- Recording: speaker notes, one-click window resize, iPhone and iPad over USB
- Style: Unsplash backgrounds, reel mode, device frames, style presets
- Camera: background cutout, hide on silence, face tracking, color grading
- Audio: voice cleanup, podcast mode, click sounds, background music, AI voiceover
- Captions: transcription, caption styles, caption placement, .srt export
- Export: ProRes
- Sharing: viewer comments, view counts, shared projects, shared presets

---

## Build effort for Now

Native Mac app: Swift and SwiftUI for the interface, AVFoundation to read and encode video, Metal to render, ScreenCaptureKit to capture (phase 2).

Claude writes, builds and checks the code. Mari tries each milestone and gives feedback on look and feel. Progress is measured in milestones Mari can open and try, not weeks. The detailed milestones are in [PLAN.md](PLAN.md).

The work comes in 7 building blocks. The sizes show their share of the total.

| Building block | Phase | Size |
|---|---|---|
| **App foundation:** app shell, project file format (with the empty cursor slot), settings | MVP | M |
| **Renderer:** one Metal pipeline that draws a frame: crop → zoom → frame and background, with room for the cursor. Preview and export both use it | MVP | L |
| **Timeline editor:** trim, cut, speed, zoom track, undo and redo | MVP | L |
| **Zoom, manual:** zoom segments and spring easing | MVP | M |
| **Export and import:** MP4 through the hardware encoder, GIF with a good color palette, progress, importing a video | MVP | M |
| **Capture:** area and window picker, countdown, shortcut, pause and resume, hide desktop icons, cursor and click log | Phase 2 | M–L |
| **Cursor and auto-zoom:** smoothing, size, style, sharp cursor images, motion blur, clicks, idle hide, auto-zoom rules | Phase 2 | L |

The MVP is about 55–60% of the total work, because the renderer, timeline and export are the biggest blocks.

### Hardest parts (the risks)

1. **Making auto-zoom feel good.** Writing the code is quick. Deciding when to zoom, how far, how long to hold and when to pull out takes rounds of trying it on real recordings. This is what makes Screen Studio feel like Screen Studio.
2. **Smooth preview while editing.** Drawing all the effects live at 4K, 60 fps without stutter. That's why the renderer is one Metal pipeline from the start.
3. **The timeline UI.** Dragging, snapping, speed sections and zoom segments on one track is the most UI-heavy part of the app.
4. **Coordinates.** Cursor positions are recorded in screen points across Retina and non-Retina displays, then must line up after cropping, zooming and speed changes. It's easy to get subtly wrong.

### Things to know about these picks

- **Imported videos won't get cursor effects or auto-zoom.** They have no cursor data. That's why the MVP has none of these features, and why phase 2 records in the app.
- **No sound in v1.** Recording audio is Future. That keeps v1 much simpler, with no audio and video sync and no audio while speeding up. The timeline should still be built with room for audio tracks, so adding them later doesn't mean a rewrite.
- **Edit by transcript and remove filler words are Future, but transcription is Never.** Both features need a transcript of the audio, though not on-screen captions. If they move to Now, transcription comes with them, without caption styling.
- **Autosave is Maybe, but consider it for Now.** Writing the recording in small pieces as it goes costs little when building capture in phase 2, and it means a crash doesn't lose the take.
- **Multiple aspect ratios is Maybe.** If the renderer takes the output size as a setting from day one (it should), adding 9:16 and 1:1 later is cheap.
