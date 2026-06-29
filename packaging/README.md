# Release builds

This project uses split release automation:

- GitHub Actions for Linux and Windows
- Codemagic for macOS

## Current release targets

- Linux bundle as `.tar.gz`
- Linux AppImage package
- Windows installer `.exe`
- macOS DMG package

These release pipelines build the existing Flutter desktop outputs and upload them to the GitHub release for a tag.

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

- Linux and Windows GitHub Actions trigger on tags matching `vX.Y.Z`
- The macOS Codemagic workflow triggers on tags matching `vX.Y.Z`
- The macOS Codemagic workflow also supports manual runs by setting `RELEASE_TAG_PARAM`
- All release automation builds with Flutter `3.44.4`
- All release automation uploads assets to the matching GitHub release

## Produced asset names

- `resolve-file-converter-<version>-linux-x86_64.tar.gz`
- `resolve-file-converter-<version>-linux-x86_64.AppImage`
- `resolve-file-converter-<tag>-windows-x64.exe`
- `resolve-file-converter-<version>-macos.dmg`

## Notes

- These are release bundles, not signed installers
- Linux now also builds an AppImage package, but not Flatpak
- Windows now builds an Inno Setup installer executable
- macOS now builds a DMG package in Codemagic, but it is not yet signed or notarized
- Codemagic expects a secret group named `resolve_file_converter_github_token` with `GITHUB_TOKEN` set for release publishing
