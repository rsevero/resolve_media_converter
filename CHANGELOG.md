# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

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

### Changed

- Replaced the default Flutter counter app with a Resolve-focused desktop shell.
- Updated dependencies to support file picking, path handling, and shared preferences.
- Switched Linux file and directory picking to `file_selector`.
- Improved the run/results copy, surfaced media type in result rows, and refreshed the README with current app behavior and requirements.
- Tightened the Convert action so it only enables when source selection, trim validation, and tool validation are all ready.
- Replaced the ineffective runner-specific startup sizing attempt with a Flutter-managed desktop window configuration.

### Fixed

- Removed the accidentally committed nested duplicate Flutter project from the repository.
