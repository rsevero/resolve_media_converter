# Flutter Desktop Resolve Media Converter Plan

## Summary

Build a Flutter desktop app that converts `ffmpeg`-readable media into Resolve-friendly outputs:

- Audio input -> `WAV` with `48 kHz / 24-bit PCM`
- Video input -> `MOV` with `DNxHR HQ` video and `48 kHz PCM` audio

The app accepts a single file or a directory, scans only the selected folder's top level, supports two output-location modes, allows optional `start` and `end` trim values, and uses external `ffmpeg`/`ffprobe` executables with automatic detection plus separate manual overrides for each.

## Key Changes

- Replace the starter app with a desktop-focused main screen containing:
  - Source selector for `single file` or `directory`
  - Output selector:
    - same folder with `-for_resolve` suffix
    - `for_resolve` subdirectory
  - Optional `start time` and `end time`
  - Tools section showing detected `ffmpeg` and `ffprobe` paths, validation state, and manual override controls for each executable independently
  - Convert action, progress UI, and per-file result list
- Add media probing and conversion services that:
  - try default system locations and `PATH` first
  - keep manual settings for `ffmpeg` and `ffprobe` as two separate optional overrides
  - allow manual overrides even when auto-detection succeeds
  - validate both effective paths before conversion starts
  - use `ffprobe` for media classification and `ffmpeg` for execution
  - process jobs sequentially and capture logs for user-readable diagnostics
- Directory mode scans only the selected folder itself:
  - no recursion into subfolders
  - ignore directories inside the selected folder
  - skip unreadable or unsupported files with explicit status messages
- Use these default output profiles:
  - Audio: `.wav`, `pcm_s24le`, `48000 Hz`
  - Video: `.mov`, `dnxhr_hq`, PCM audio at `48000 Hz`
- Apply output naming rules:
  - same-folder mode:
    - `name-for_resolve.wav`
    - `name-for_resolve.mov`
  - subdirectory mode:
    - `parent/for_resolve/name.wav`
    - `parent/for_resolve/name.mov`
  - resolve collisions by appending `-1`, `-2`, etc.
- Validate trim input:
  - allow `start`, `end`, both, or neither
  - accept `SS`, `MM:SS`, `HH:MM:SS(.ms)`
  - reject negative values
  - reject `end <= start`

## Interfaces

- `ConversionRequest`
  - source path
  - source type (`file` or `directory`)
  - output mode
  - optional start time
  - optional end time
  - effective `ffmpeg` path
  - effective `ffprobe` path
- `ToolPathsSettings`
  - optional manual `ffmpeg` path
  - optional manual `ffprobe` path
  - detected `ffmpeg` path
  - detected `ffprobe` path
- `MediaProbeResult`
  - source path
  - media kind (`audio` or `video`)
  - probe status / error
- `ResolvedJob`
  - source path
  - destination path
  - target kind
  - ffmpeg arguments
- `ConversionResult`
  - source
  - destination
  - status
  - error message
  - elapsed time

## Test Plan

- Unit tests for tool path resolution:
  - detected paths used when no overrides exist
  - manual `ffmpeg` override replaces detected path
  - manual `ffprobe` override replaces detected path
  - one override set while the other still uses detected path
  - invalid manual path rejected for either tool
  - missing executable surfaces a clear validation error
- Unit tests for top-level directory scanning:
  - files in selected folder included
  - nested subdirectory contents excluded
  - unsupported entries skipped cleanly
- Unit tests for output path generation for `.wav` and `.mov`
- Unit tests for trim parsing and invalid ranges
- Unit tests for command generation:
  - audio input without trim
  - audio input with start/end
  - video input without trim
  - video input with start/end
- Widget tests for:
  - source mode switching
  - output mode switching
  - independent `ffmpeg` and `ffprobe` path editing
  - validation errors blocking conversion
  - mixed conversion results rendering
- Manual verification with:
  - detected tools only
  - custom `ffmpeg` only
  - custom `ffprobe` only
  - both custom paths
  - one audio file
  - one video file
  - one mixed top-level folder

## Assumptions

- Default video target is `DNxHR HQ` in `MOV`.
- Default audio target is `24-bit PCM WAV` at `48 kHz`.
- The app never bundles `ffmpeg` or `ffprobe`.
- The user can always override detected tool paths through two separate settings, even when auto-detection succeeds.
- Directory processing is top-level only and sequential in v1 for predictability and simpler UX.
