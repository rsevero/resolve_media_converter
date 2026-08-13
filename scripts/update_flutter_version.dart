#!/usr/bin/env dart
// Keeps the pinned Flutter SDK version in sync across every release
// pipeline (GitHub Actions for Linux/Windows, Codemagic for macOS).
//
// Run this every time a release is cut, so the three workflow files always
// track whatever Flutter version was actually used to build the release
// instead of drifting out of sync with each other over time.
//
// Usage:
//   dart run scripts/update_flutter_version.dart               # pin to the currently installed `flutter` version
//   dart run scripts/update_flutter_version.dart <version>      # pin an exact version, e.g. 3.48.0
//   dart run scripts/update_flutter_version.dart --check         # verify all files already agree

import 'dart:convert';
import 'dart:io';

void main(List<String> arguments) {
  if (arguments.length > 1 || arguments.contains('--help') || arguments.contains('-h')) {
    _printUsage();
    exit(arguments.length > 1 ? 64 : 0);
  }

  final repoRoot = _findRepoRoot();

  if (arguments.isEmpty) {
    exit(_apply(repoRoot, _detectInstalledFlutterVersion()) ? 0 : 1);
  }

  if (arguments.first == '--check') {
    exit(_check(repoRoot) ? 0 : 1);
  }

  final version = arguments.first;
  if (!RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    stderr.writeln('error: "$version" is not a valid Flutter version (expected X.Y.Z).');
    exit(64);
  }

  exit(_apply(repoRoot, version) ? 0 : 1);
}

void _printUsage() {
  stdout.writeln('''
Usage:
  dart run scripts/update_flutter_version.dart
  dart run scripts/update_flutter_version.dart <version>
  dart run scripts/update_flutter_version.dart --check

  (no arguments)  Pin every release workflow to the Flutter version currently
                  installed and on PATH (via `flutter --version`).
  <version>       Pin every release workflow to this exact Flutter version (X.Y.Z).
  --check         Verify the workflows already agree on one version; makes no changes.
                  Exits non-zero if they are missing or out of sync.
''');
}

String _detectInstalledFlutterVersion() {
  final ProcessResult result;
  try {
    result = Process.runSync('flutter', ['--version', '--machine']);
  } on ProcessException catch (error) {
    stderr.writeln('error: could not run `flutter --version` (${error.message}).');
    stderr.writeln('Pass an explicit version instead, e.g.: dart run scripts/update_flutter_version.dart 3.48.0');
    exit(1);
  }

  if (result.exitCode != 0) {
    stderr.writeln('error: `flutter --version --machine` exited with ${result.exitCode}:');
    stderr.writeln(result.stderr);
    exit(1);
  }

  final Map<String, dynamic> info;
  try {
    info = jsonDecode(result.stdout as String) as Map<String, dynamic>;
  } on FormatException catch (error) {
    stderr.writeln('error: could not parse `flutter --version --machine` output: $error');
    exit(1);
  }

  final version = info['frameworkVersion'] as String?;
  if (version == null || !RegExp(r'^\d+\.\d+\.\d+$').hasMatch(version)) {
    stderr.writeln('error: unexpected frameworkVersion in `flutter --version --machine` output: $version');
    exit(1);
  }

  stdout.writeln('Detected installed Flutter version: $version');
  return version;
}

class _Target {
  const _Target({required this.path, required this.pattern});

  /// Path relative to the repo root.
  final String path;

  /// Must have exactly two capture groups: the text before the version
  /// (kept as-is) and the version number itself.
  final RegExp pattern;
}

final _targets = [
  _Target(
    path: '.github/workflows/linux-release.yml',
    pattern: RegExp(r'(flutter-version:\s*)(\d+\.\d+\.\d+)'),
  ),
  _Target(
    path: '.github/workflows/windows-release.yml',
    pattern: RegExp(r'(flutter-version:\s*)(\d+\.\d+\.\d+)'),
  ),
  _Target(
    path: 'codemagic.yaml',
    pattern: RegExp(r'(^\s*flutter:\s*)(\d+\.\d+\.\d+)', multiLine: true),
  ),
];

Directory _findRepoRoot() {
  var dir = File(Platform.script.toFilePath()).parent;
  while (true) {
    if (File('${dir.path}/pubspec.yaml').existsSync()) {
      return dir;
    }
    final parent = dir.parent;
    if (parent.path == dir.path) {
      return Directory.current;
    }
    dir = parent;
  }
}

bool _apply(Directory repoRoot, String version) {
  var ok = true;
  var changedAny = false;

  for (final target in _targets) {
    final file = File('${repoRoot.path}/${target.path}');
    if (!file.existsSync()) {
      stderr.writeln('error: ${target.path} not found.');
      ok = false;
      continue;
    }

    final original = file.readAsStringSync();
    if (!target.pattern.hasMatch(original)) {
      stderr.writeln('error: could not find a Flutter version pin in ${target.path}.');
      ok = false;
      continue;
    }

    final updated = original.replaceAllMapped(
      target.pattern,
      (match) => '${match.group(1)}$version',
    );

    if (updated == original) {
      stdout.writeln('${target.path}: already pinned to $version');
      continue;
    }

    file.writeAsStringSync(updated);
    changedAny = true;
    stdout.writeln('${target.path}: updated to $version');
  }

  if (ok && !changedAny) {
    stdout.writeln('All release workflows were already pinned to $version.');
  }

  return ok;
}

bool _check(Directory repoRoot) {
  final versions = <String, String>{};
  var ok = true;

  for (final target in _targets) {
    final file = File('${repoRoot.path}/${target.path}');
    if (!file.existsSync()) {
      stderr.writeln('error: ${target.path} not found.');
      ok = false;
      continue;
    }

    final match = target.pattern.firstMatch(file.readAsStringSync());
    if (match == null) {
      stderr.writeln('error: could not find a Flutter version pin in ${target.path}.');
      ok = false;
      continue;
    }

    versions[target.path] = match.group(2)!;
  }

  final distinctVersions = versions.values.toSet();
  if (distinctVersions.length > 1) {
    ok = false;
    stderr.writeln('error: release workflows are pinned to different Flutter versions:');
    versions.forEach((path, version) => stderr.writeln('  $path: $version'));
  } else if (distinctVersions.length == 1) {
    stdout.writeln('All release workflows are pinned to ${distinctVersions.single}.');
  }

  return ok;
}
