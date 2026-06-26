# Resolve Media Converter Implementation Steps

## Goal

Implement the Flutter desktop app in small, verifiable steps so we can ship a working v1 that:

- Converts audio files to `48 kHz / 24-bit PCM WAV`
- Converts video files to `DNxHR HQ MOV` with `48 kHz PCM` audio
- Accepts a single file or a top-level directory
- Lets the user choose output placement
- Lets the user set optional start and end trim values
- Uses detected or manually configured `ffmpeg` and `ffprobe` paths

## Step 1: Prepare the project structure

- Replace the default counter app with a minimal desktop shell app.
- Create folders for:
  - `lib/app`
  - `lib/features/conversion`
  - `lib/features/settings`
  - `lib/services`
  - `lib/models`
  - `lib/widgets`
- Add the packages needed for v1:
  - file/directory picking
  - local settings persistence
  - path manipulation
- State management will be done with MobX.

## Step 2: Define the core models

- Create `ConversionRequest`.
- Create `ToolPathsSettings`.
- Create `MediaProbeResult`.
- Create `ResolvedJob`.
- Create `ConversionResult`.
- Add enums or sealed types for:
  - source type
  - media kind
  - output mode
  - conversion status
- Keep these models UI-agnostic so they can be unit tested without widgets.

## Step 3: Add app settings support

- Persist two separate optional settings:
  - manual `ffmpeg` path
  - manual `ffprobe` path
- Add methods to load and save these settings at startup and on user change.
- Define the effective-path rule:
  - use manual path if set
  - otherwise use detected path
- Keep detection results separate from saved overrides.

## Step 4: Implement tool path detection and validation

- Create a service that tries to find `ffmpeg` and `ffprobe` on the default system path.
- Return detection status independently for both tools.
- Add validation that confirms:
  - the path exists
  - it points to an executable
  - the executable responds successfully
- Surface clear errors for:
  - tool missing
  - invalid manual path
  - missing one tool while the other exists

## Step 5: Build the settings UI for tool paths

- Add a tools/settings section to the main screen.
- Show detected `ffmpeg` path and detected `ffprobe` path separately.
- Provide separate manual override inputs for each tool.
- Add browse buttons for each tool path.
- Show validation state next to each effective path.
- Allow manual overrides even when detection succeeds.
- Add a reset action to clear a manual override and fall back to detection.

## Step 6: Build source selection UI

- Add a source mode toggle:
  - single file
  - directory
- Add a picker button that changes behavior based on source mode.
- Show the selected path clearly in the UI.
- For directory mode, make it explicit that only the selected folder’s top level will be processed.

## Step 7: Build output mode UI

- Add two output placement options:
  - same folder with `-for_resolve` suffix
  - `for_resolve` subdirectory
- Show a short preview example for the selected mode so the user understands the resulting path pattern.

## Step 8: Build trim input UI and validation

- Add optional `start time` and `end time` text inputs.
- Accept these formats:
  - `SS`
  - `MM:SS`
  - `HH:MM:SS`
  - `HH:MM:SS.mmm`
- Validate on edit and on convert.
- Block conversion when:
  - a value is malformed
  - a value is negative
  - `end <= start`
- Allow conversion when both fields are empty.

## Step 9: Implement directory scanning

- Create a scanner that:
  - accepts a single file directly
  - lists files in the selected directory’s top level only
  - skips subdirectories
  - skips unreadable entries
- Return a candidate file list for probing.
- If no valid files are found, show a user-friendly empty-state error.

## Step 10: Implement media probing with `ffprobe`

- Probe every candidate file with the effective `ffprobe` path.
- Classify files as:
  - audio
  - video
  - unsupported
- Capture enough metadata to drive command generation.
- Skip unsupported files while recording a result row that explains why they were skipped.

## Step 11: Implement output path generation

- Generate destination names using the selected output mode.
- Apply these defaults:
  - audio output -> `.wav`
  - video output -> `.mov`
- Use:
  - `name-for_resolve.ext` for same-folder mode
  - `parent/for_resolve/name.ext` for subdir mode
- Create the `for_resolve` directory when needed.
- Prevent accidental overwrite by appending `-1`, `-2`, and so on.

## Step 12: Implement ffmpeg command generation

- Build commands from the probed media type plus trim settings.
- For audio input:
  - output `pcm_s24le`
  - output sample rate `48000`
  - output container `.wav`
- For video input:
  - output `dnxhr_hq`
  - output container `.mov`
  - output audio as PCM `48000`
- Apply trim rules:
  - start only
  - end only
  - both start and end
  - neither
- Keep command construction isolated in a service so it is easy to unit test.

## Step 13: Implement conversion execution

- Run jobs sequentially in v1.
- Use the effective `ffmpeg` path for execution.
- Capture stdout/stderr for each job.
- Mark each job as:
  - success
  - failed
  - skipped
- Continue processing remaining files after a single-file failure.

## Step 14: Build progress and results UI

- Add a progress section showing:
  - total jobs
  - current file
  - completed count
- Add a results list/table showing:
  - source file
  - output file
  - media type
  - final status
  - error message when applicable
- Disable the convert button while jobs are running.
- Add a way to clear results before a new run.

## Step 15: Wire the full conversion flow

- On convert:
  - validate tool paths
  - validate trim inputs
  - resolve source files
  - probe media
  - build jobs
  - execute conversions
  - publish results to the UI
- Ensure unsupported files and failed jobs do not crash the app.

## Step 16: Add unit tests for core logic

- Test tool path resolution and override precedence.
- Test trim parsing and invalid ranges.
- Test directory scanning top-level-only behavior.
- Test media classification from probe output.
- Test output path generation and collision handling.
- Test ffmpeg command generation for:
  - audio without trim
  - audio with trim
  - video without trim
  - video with trim

## Step 17: Add widget tests for the main flow

- Test source mode switching.
- Test output mode switching.
- Test independent editing of `ffmpeg` and `ffprobe` manual paths.
- Test validation errors blocking conversion.
- Test rendering of mixed conversion results.

## Step 18: Manual desktop verification

- Verify with a single audio file.
- Verify with a single video file.
- Verify with a mixed folder containing:
  - supported audio
  - supported video
  - unsupported files
  - nested subfolders that must be ignored
- Verify both output modes.
- Verify:
  - detected tools only
  - custom `ffmpeg` only
  - custom `ffprobe` only
  - both custom paths
- Verify start only, end only, both, and neither.

## Step 19: Polish for v1

- Improve copy and error messages.
- Add a short README section explaining:
  - what formats are produced
  - that `ffmpeg` and `ffprobe` must already be installed
  - how manual path overrides work
  - that directory mode is top-level only
- Check layout on desktop window sizes likely to be used in editing workflows.

## Suggested Implementation Order

1. Steps 1 to 4
2. Steps 6 to 8
3. Steps 9 to 13
4. Steps 14 to 15
5. Steps 16 to 18
6. Step 19

## Definition of Done

The v1 implementation is complete when:

- The app runs as a Flutter desktop app.
- The user can select one file or one directory.
- Directory mode scans only the selected folder’s top level.
- The user can choose output placement.
- The user can optionally set start and end trim values.
- The user can rely on detected tool paths or manually set `ffmpeg` and `ffprobe` separately.
- Audio sources convert to Resolve-friendly `.wav` output.
- Video sources convert to Resolve-friendly `.mov` output.
- Unsupported files are skipped cleanly.
- Failures are reported per file without aborting the whole batch.
- Core logic is covered by unit tests and the main flow is covered by widget tests.
