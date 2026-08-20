# Packaging & releases

This project builds and publishes release assets on three separate pipelines:

- GitHub Actions for Linux (`.github/workflows/linux-release.yml`)
- GitHub Actions for Windows (`.github/workflows/windows-release.yml`)
- Codemagic for macOS (`codemagic.yaml`)

Packaging inputs for the Linux and Windows release pipelines live in this
directory (`packaging/linux`, `packaging/windows`).

Each pipeline pins its own Flutter SDK version. Because they're three
independent files, it's easy for them to drift apart if one is bumped and the
others are forgotten — `scripts/update_flutter_version.dart` exists to
prevent that.

## Release checklist

1. Update `pubspec.yaml`'s version if needed.
2. Update `CHANGELOG.md`.
3. Sync the Flutter version pinned in every release workflow:

   ```bash
   dart run scripts/update_flutter_version.dart
   ```

   Run with no arguments to pin every workflow to whatever Flutter version
   is currently installed and on `PATH` — i.e. the version you're about to
   build the release with. Pass an explicit version instead
   (`dart run scripts/update_flutter_version.dart 3.48.0`) if you want to pin
   to something other than your local install.
4. Commit and push the release changes (including any workflow file updates
   from step 3), e.g.:

   ```bash
   git commit -am "v1.0.0"
   git push
   ```

5. Create and push an annotated tag like:

   ```bash
   git tag -a v1.0.0 -m "v1.0.0"
   git push origin v1.0.0
   ```

Pushing a `vX.Y.Z` tag triggers all three release pipelines automatically.

## Keeping the Flutter version in sync

`scripts/update_flutter_version.dart` is the single source of truth for
keeping Linux, Windows, and macOS release builds on the same Flutter SDK
version. It supports three modes:

```bash
# Pin every workflow to your currently installed Flutter version.
dart run scripts/update_flutter_version.dart

# Pin every workflow to an exact version.
dart run scripts/update_flutter_version.dart 3.48.0

# Verify the workflows already agree on one version, without changing anything.
# Useful as a pre-release sanity check; exits non-zero if they're out of sync.
dart run scripts/update_flutter_version.dart --check
```

Run it (with no arguments) as part of every release, right before tagging —
that's step 3 of the checklist above. Never hand-edit the Flutter version in
`codemagic.yaml` or the two GitHub Actions workflow files directly; always go
through the script so all three stay in lockstep.

## Current release targets

- Linux bundle as `.tar.gz`
- Linux AppImage package
- Windows installer `.exe`
- macOS DMG package

These release pipelines build the existing Flutter desktop outputs and upload
them to the GitHub release for the pushed tag.

## Workflow behavior

- Linux and Windows GitHub Actions trigger on tags matching `vX.Y.Z`
- The macOS Codemagic workflow triggers on tags matching `vX.Y.Z`
- The macOS Codemagic workflow also supports manual runs by setting `RELEASE_TAG_PARAM`
- All release automation uploads assets to the matching GitHub release

## Produced asset names

- `resolve-media-converter-<version>-linux-x86_64.tar.gz`
- `resolve-media-converter-<version>-linux-x86_64.AppImage`
- `Resolve-Media-Converter-v<version>-windows-x64.exe`
- `resolve-media-converter-<version>-macos.dmg`

## Notes

- These are release bundles, not signed installers
- Linux builds a tarball bundle and an AppImage, but not Flatpak
- Windows builds an Inno Setup installer executable
- macOS builds a DMG package in Codemagic, but it is not yet signed or notarized
- Codemagic expects a secret group named `resolve_media_converter_github_token` with `GITHUB_TOKEN` set for release publishing
