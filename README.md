# resolve_file_converter

Flutter desktop app for converting `ffmpeg`-readable audio and video files into formats that are easier to edit in DaVinci Resolve.

## Current behavior

- Audio sources convert to `48 kHz / 24-bit PCM WAV`
- Video sources convert to `MXF` with `DNxHR HQ` video and `48 kHz PCM` audio
- Input can be a single file or one directory
- Directory mode scans only the selected folder's top level
- Output can stay in the same folder with a `-for_resolve` suffix or go into a `for_resolve` subdirectory
- Optional start and end trim fields can limit the conversion range
- Files already in accepted Resolve-friendly formats are skipped instead of being reconverted
- Each converted or skipped file gets its own persistent log file, including captured `ffmpeg` output when `ffmpeg` runs

## Requirements

- `ffmpeg` must be installed on the machine
- `ffprobe` must be installed on the machine
- The app can auto-detect both tools, but the user can also configure each path manually

## Linux note

- Linux file and directory picking uses `file_selector`
- If native picker integration still fails on your session, the app falls back to manual path entry

## Development

Run the usual Flutter checks:

```bash
flutter analyze
flutter test
```

## Releases

- GitHub Actions release workflows are available for Linux, Windows, and macOS desktop builds
- Tag releases with `vX.Y.Z` to trigger automated release bundles
- macOS releases are packaged as DMG files
- See `packaging/README.md` for the release flow and asset naming

## Manual verification checklist

- Test one audio file conversion
- Test one video file conversion
- Test one mixed folder with unsupported files present
- Test both output placement modes
- Test start only, end only, both, and blank trim inputs
- Test auto-detected tool paths and manual overrides for `ffmpeg` and `ffprobe`
- Test accepted-format skipping for H.264 MP4 (CFR), ProRes, DNxHR, BRAW/CinemaDNG, and 48 kHz / 24-bit WAV/BWF
- Open a completed item log from the results list and confirm the stored command/output details
