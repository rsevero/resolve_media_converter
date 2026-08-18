# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## v1.0.4 - not yet released

### Added

### Changed

- Migrated Material widget imports from the bundled `package:flutter/material.dart` to the standalone `material_ui` package ahead of the Fall stable release, which deprecates the SDK-bundled Material/Cupertino libraries.

### Fixed

## v1.0.3 - released on 2026-08-13

### Added

- Per-file progress bar showing live conversion percentage, encode speed, and a real-time ETA for the file currently being converted.
- Rotation option (90°/180°/270°) for video sources, applied by re-encoding the frame with an ffmpeg `transpose` filter rather than just tagging metadata, so orientation is correct regardless of how the destination player or NLE handles rotation tags. The requested rotation is combined with the source's own rotation metadata (e.g. a file tagged +90° with a -90° rotation requested converts to 0° net rotation) instead of being applied on top of it. A fifth, mutually exclusive "Strip metadata" choice ignores the source's rotation metadata entirely and keeps the raw stored orientation.
- `scripts/update_flutter_version.dart` and an expanded `packaging/README.md` release checklist, to keep the Flutter SDK version pinned in the Linux/Windows GitHub Actions workflows and the Codemagic macOS workflow from drifting out of sync with each other.

### Fixed

- Updated the Windows GitHub release workflow to use the renamed `resolve_media_converter` installer script, executable, and packaging path references so Windows release builds continue to work after the app rename.
- Updated the Codemagic macOS DMG packaging spec and verifier to look for `Resolve Media Converter.app` instead of the old `resolve_media_converter.app` bundle name after the app rename.
- Restored the SVG pixbuf loader in the Linux AppImage so GTK file-selection dialogs work on Fedora 44 and systems whose host loader paths differ from the bundled cache.
- Synced the Linux and Windows GitHub Actions workflows to Flutter 3.47.0, matching the version already used by the Codemagic macOS workflow.

## v1.0.2 - released on 2026-07-01

### Changed

- Renamed the app from `Resolve File Converter` to `Resolve Media Converter` across user-facing copy and internal package metadata, bundle IDs, executable names, asset filenames, installer scripts, and release artifact references.
- Moved the optional tool-path override controls below the conversion run section and collapsed them behind a lower-prominence disclosure by default.
- Expanded the trim controls to full width with side-by-side time inputs on wider windows, and reduced the default window height to better fit the shorter layout.
- Switched the GitHub Actions Linux release workflow to run on `ubuntu-22.04` and aligned the AppImage package sources with Ubuntu Jammy.
- Renamed the macOS release artifact from `*-macos-universal.dmg` to `*-macos.dmg` so the published filename matches the actual build output.

### Fixed

- Replaced the Linux release workflow's cached apt-package action with a direct `apt-get` install step so GitHub Actions dependency setup is less likely to stall before the AppImage build begins.
- Corrected the Linux AppImage `AppDir` layout so the packaged launcher starts the bundled Flutter executable with its adjacent `lib/` and `data/` directories in the expected location.
- Updated the Linux AppImage recipe entrypoint metadata so `appimage-builder` resolves the packaged executable from `usr/bin/resolve_media_converter` instead of the old AppDir root path.
- Trimmed unnecessary `librsvg2` packages from the Linux AppImage recipe because the bundled app assets use PNG icons and do not require SVG runtime support.
- Added a Linux release workflow validation step that checks the generated `.AppImage` with `--appimage-version` before uploading it, preventing broken artifacts from being published.
- Made the Codemagic macOS release upload step tolerate GitHub release creation races so tagged Linux, Windows, and macOS builds can all publish to the same release reliably.
- Made the Codemagic macOS dependency-preparation step skip CocoaPods cleanly when `macos/Podfile` is not present, so manual builds can continue to the actual Flutter build.
- Removed the invalid `appdmg` background setting that made Codemagic macOS DMG packaging fail by treating `builtin-arrow` as a missing file path.
- Fixed DMG verification on Codemagic by parsing mounted volume paths with spaces correctly and by falling back to the first app bundle found in the mounted image.
- Switched the Codemagic GitHub release publishing step to non-interactive token-based `gh` usage so CI does not fall back to browser/device login prompts.

## v1.0.1 - released on 2026-06-29

### Changed

- Show the newest completed conversion result at the top of the run history instead of appending it to the bottom.
- Select DNxHR HQ / yuv422p for 8-bit sources and DNxHR HQX / yuv422p10le for 10-bit sources, detected automatically via ffprobe.
- Show each file's conversion time directly in the main results list, in addition to the detailed log dialog.
- Include the selected trim range in output filenames for trimmed conversions so exported clips are easier to identify.

### Fixed

- Pass `-ss` (start time) both before and after `-i` on ffmpeg so seeking is fast, frame-accurate, and `-to` is treated as an end timestamp rather than a duration.
- Reset the trim start and end fields after each conversion run so the next conversion starts from a full-range state.

## v1.0.0 - released on 2026-06-27

### Added

- Initial Flutter desktop project structure for the Resolve media converter.
- Product planning documents in `resolve_media_converter_plan.md` and `resolve_media_converter_implementation_steps.md`.
- Desktop app shell for the Resolve media converter workflow.
- Core domain models for conversion requests, probe results, resolved jobs, tool settings, and conversion results.
- Tool path persistence for separate `ffmpeg` and `ffprobe` manual overrides.
- Tool detection and validation services for `ffmpeg` and `ffprobe`.
- Widget test coverage for the new app shell.
- Source selection, output placement, and trim validation controls for the conversion workflow.
- Browse actions for manually selecting `ffmpeg` and `ffprobe` executables.
- Top-level source scanning, media probing, output path generation, ffmpeg command building, and sequential conversion execution services.
- Conversion progress and per-file results UI for the initial runnable pipeline.
- Service-level test coverage for source resolution, probe classification, output path generation, and ffmpeg argument building.
- Additional widget coverage for source/output workflow controls.
- Edge-case tests for trim parsing, tool-path precedence, output collision handling, and conversion button readiness.
- Cross-platform desktop window sizing through Flutter using `window_manager`.
- Persistence for the last directory used in file, folder, and executable picker flows.
- Persistent per-file conversion logs with stored `ffmpeg` output and an in-app viewer from the results list.
- GitHub Actions release workflows for Linux and Windows desktop bundles.
- Codemagic release workflow for macOS desktop bundles.

### Changed

- Replaced the default Flutter counter app with a Resolve-focused desktop shell.
- Updated dependencies to support file picking, path handling, and shared preferences.
- Switched Linux file and directory picking to `file_selector`.
- Improved the run/results copy, surfaced media type in result rows, and refreshed the README with current app behavior and requirements.
- Tightened the Convert action so it only enables when source selection, trim validation, and tool validation are all ready.
- Replaced the ineffective runner-specific startup sizing attempt with a Flutter-managed desktop window configuration.
- Reused the last-picked directory as the initial location for future source and tool picker dialogs.
- Clear the current source selection after a conversion run while keeping the remembered picker directory for future browsing.
- Clear all persisted conversion log files automatically when the app starts.
- Run startup log cleanup in the background so app launch does not wait for it.
- Skip conversion for files that are already in accepted Resolve-friendly formats such as CFR H.264 MP4, ProRes, DNxHR, BRAW/CinemaDNG, and 48 kHz / 24-bit WAV/BWF.
- Switch the default converted video container from `MOV` to `MXF`.
- macOS release automation now builds a DMG package in Codemagic similar to the Mapiah flow.
- Linux release workflow now also builds an AppImage package similar to the Mapiah release flow.
- Windows release workflow now builds an installable `.exe` package similar to the Mapiah release flow.
- Wired the shared `resolve_media_converter-icon.png` asset into Windows, macOS, and Linux packaging icons.

### Fixed

- Removed the accidentally committed nested duplicate Flutter project from the repository.
- Bundled `libpcre3` for Linux AppImage builds so the packaged `gdk-pixbuf-query-loaders` step can generate the pixbuf loader cache on GitHub Actions.
- Narrowed the Linux AppImage loader-cache environment so `gdk-pixbuf-query-loaders` can use bundled `libpcre` without loading an incompatible bundled `glibc` on newer GitHub runners.
- Switched the Linux AppImage runtime bundle from Ubuntu Focal to Ubuntu Noble so the packaged GLib stack matches the `ubuntu-24.04` build environment and avoids `g_once_init_enter_pointer` launch failures on newer distros such as Fedora 44.
