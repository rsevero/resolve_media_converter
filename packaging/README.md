# Release builds

This project now includes GitHub Actions release workflows similar in spirit to the ones used in `~/devel/mapiah`, adapted to this app's current packaging state.

## Current release targets

- Linux bundle as `.tar.gz`
- Windows bundle as `.zip`
- macOS DMG package

These workflows build the existing Flutter desktop outputs and upload them to the GitHub release for a tag.

## Triggering a release

1. Update `pubspec.yaml` version if needed.
2. Update `CHANGELOG.md`.
3. Commit and push the release changes.
4. Create and push an annotated tag like:

```bash
git tag -a v1.0.0 -m "v1.0.0"
git push origin v1.0.0
```

## Workflow behavior

- Trigger on tags matching `vX.Y.Z`
- Also support manual `workflow_dispatch` runs with a `test_tag`
- Build with Flutter `3.44.4`
- Upload assets to the matching GitHub release

## Produced asset names

- `resolve-file-converter-<version>-linux-x86_64.tar.gz`
- `resolve-file-converter-<version>-windows-x64.zip`
- `resolve-file-converter-<version>-macos-universal.dmg`

## Notes

- These are release bundles, not signed installers
- Linux does not yet build AppImage or Flatpak
- Windows does not yet build an installer executable
- macOS now builds a DMG package, but it is not yet signed or notarized
