# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## v1.0.0

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
- GitHub Actions release workflows for Linux, Windows, and macOS desktop bundles.

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
- macOS release workflow now builds a DMG package similar to the Mapiah Codemagic flow.
- Linux release workflow now also builds an AppImage package similar to the Mapiah release flow.
- Windows release workflow now builds an installable `.exe` package similar to the Mapiah release flow.
- Wired the shared `resolve_file_converter-icon.png` asset into Windows, macOS, and Linux packaging icons.

### Fixed

- Removed the accidentally committed nested duplicate Flutter project from the repository.
- Bundled `libpcre3` for Linux AppImage builds so the packaged `gdk-pixbuf-query-loaders` step can generate the pixbuf loader cache on GitHub Actions.
- Narrowed the Linux AppImage loader-cache environment so `gdk-pixbuf-query-loaders` can use bundled `libpcre` without loading an incompatible bundled `glibc` on newer GitHub runners.
