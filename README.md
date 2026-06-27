# resolve_file_converter

Flutter desktop app for converting `ffmpeg`-readable audio and video files into formats that are easier to edit in DaVinci Resolve.

## Current behavior

- Audio sources convert to `48 kHz / 24-bit PCM WAV`
- Video sources convert to `MOV` with `DNxHR HQ` video and `48 kHz PCM` audio
- Input can be a single file or one directory
- Directory mode scans only the selected folder's top level
- Output can stay in the same folder with a `-for_resolve` suffix or go into a `for_resolve` subdirectory
- Optional start and end trim fields can limit the conversion range

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

## Manual verification checklist

- Test one audio file conversion
- Test one video file conversion
- Test one mixed folder with unsupported files present
- Test both output placement modes
- Test start only, end only, both, and blank trim inputs
- Test auto-detected tool paths and manual overrides for `ffmpeg` and `ffprobe`
