import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import '../../../models/conversion_enums.dart';
import '../../../models/conversion_result.dart';
import '../../../models/tool_detection_result.dart';
import '../../../services/app_settings_service.dart';
import '../../../services/tool_detection_service.dart';
import '../application/conversion_run_controller.dart';
import '../application/conversion_setup_controller.dart';
import '../../settings/application/tool_paths_controller.dart';

class ConversionShellPage extends StatefulWidget {
  const ConversionShellPage({super.key});

  @override
  State<ConversionShellPage> createState() => _ConversionShellPageState();
}

class _ConversionShellPageState extends State<ConversionShellPage> {
  late final AppSettingsService _appSettingsService;
  late final ToolPathsController _toolPathsController;
  late final ConversionSetupController _conversionSetupController;
  late final ConversionRunController _conversionRunController;
  late final TextEditingController _ffmpegTextController;
  late final TextEditingController _ffprobeTextController;
  late final TextEditingController _startTimeTextController;
  late final TextEditingController _endTimeTextController;
  String? _lastUsedDirectory;

  @override
  void initState() {
    super.initState();
    _appSettingsService = AppSettingsService();
    _ffmpegTextController = TextEditingController();
    _ffprobeTextController = TextEditingController();
    _startTimeTextController = TextEditingController();
    _endTimeTextController = TextEditingController();
    _toolPathsController = ToolPathsController(
      settingsService: _appSettingsService,
      toolDetectionService: const ToolDetectionService(),
    )..addListener(_syncTextControllers);
    _conversionSetupController = ConversionSetupController()
      ..addListener(_syncTextControllers);
    _conversionRunController = ConversionRunController();

    _toolPathsController.load();
    _loadLastUsedDirectory();
  }

  @override
  void dispose() {
    _toolPathsController
      ..removeListener(_syncTextControllers)
      ..dispose();
    _conversionSetupController
      ..removeListener(_syncTextControllers)
      ..dispose();
    _conversionRunController.dispose();
    _ffmpegTextController.dispose();
    _ffprobeTextController.dispose();
    _startTimeTextController.dispose();
    _endTimeTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _toolPathsController,
            _conversionSetupController,
            _conversionRunController,
          ]),
          builder: (context, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _HeaderBanner(isLoading: _toolPathsController.isLoading),
                      const SizedBox(height: 24),
                      Wrap(
                        spacing: 24,
                        runSpacing: 24,
                        children: [
                          SizedBox(
                            width: 520,
                            child: _SourceSelectionCard(
                              controller: _conversionSetupController,
                              onPickSource: _pickSourcePath,
                            ),
                          ),
                          SizedBox(
                            width: 520,
                            child: _OutputModeCard(
                              controller: _conversionSetupController,
                            ),
                          ),
                          SizedBox(
                            width: 1064,
                            child: _TrimCard(
                              controller: _conversionSetupController,
                              startTimeTextController: _startTimeTextController,
                              endTimeTextController: _endTimeTextController,
                            ),
                          ),
                          SizedBox(
                            width: 1064,
                            child: _ExecutionCard(
                              title: 'Conversion run',
                              controller: _conversionRunController,
                              onRunConversion: _runConversion,
                              canRun: !_toolPathsController.isLoading &&
                                  !_conversionRunController.isRunning &&
                                  _conversionSetupController.hasSourceSelection &&
                                  _conversionSetupController.hasValidTrimRange &&
                                  _toolPathsController.ffmpegValidation.isValid &&
                                  _toolPathsController.ffprobeValidation.isValid,
                            ),
                          ),
                          SizedBox(
                            width: 1064,
                            child: _ToolPathsCard(
                              controller: _toolPathsController,
                              ffmpegTextController: _ffmpegTextController,
                              ffprobeTextController: _ffprobeTextController,
                              onPickFfmpegPath: _pickFfmpegPath,
                              onPickFfprobePath: _pickFfprobePath,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _runConversion() async {
    final ffmpegPath = _toolPathsController.effectiveFfmpegPath;
    final ffprobePath = _toolPathsController.effectiveFfprobePath;

    if (ffmpegPath == null || ffprobePath == null) {
      _showSnackBar('ffmpeg and ffprobe must be configured before converting.');
      return;
    }

    if (!_toolPathsController.ffmpegValidation.isValid ||
        !_toolPathsController.ffprobeValidation.isValid) {
      _showSnackBar('Fix the tool paths before converting.');
      return;
    }

    final request = _conversionSetupController.buildRequest(
      ffmpegPath: ffmpegPath,
      ffprobePath: ffprobePath,
    );

    if (request == null) {
      _showSnackBar('Select a source and fix the trim fields first.');
      return;
    }

    await _conversionRunController.run(request);
    _conversionSetupController.setSelectedSourcePath(null);
    _conversionSetupController.resetTrimValues();
  }

  void _syncTextControllers() {
    final ffmpegPath = _toolPathsController.settings.manualFfmpegPath ?? '';
    final ffprobePath = _toolPathsController.settings.manualFfprobePath ?? '';

    if (_ffmpegTextController.text != ffmpegPath) {
      _ffmpegTextController.value = _ffmpegTextController.value.copyWith(
        text: ffmpegPath,
        selection: TextSelection.collapsed(offset: ffmpegPath.length),
      );
    }

    if (_ffprobeTextController.text != ffprobePath) {
      _ffprobeTextController.value = _ffprobeTextController.value.copyWith(
        text: ffprobePath,
        selection: TextSelection.collapsed(offset: ffprobePath.length),
      );
    }

    if (_startTimeTextController.text != _conversionSetupController.startTimeText) {
      final startTimeText = _conversionSetupController.startTimeText;
      _startTimeTextController.value = _startTimeTextController.value.copyWith(
        text: startTimeText,
        selection: TextSelection.collapsed(offset: startTimeText.length),
      );
    }

    if (_endTimeTextController.text != _conversionSetupController.endTimeText) {
      final endTimeText = _conversionSetupController.endTimeText;
      _endTimeTextController.value = _endTimeTextController.value.copyWith(
        text: endTimeText,
        selection: TextSelection.collapsed(offset: endTimeText.length),
      );
    }
  }

  Future<void> _pickFfmpegPath() async {
    final filePath = await _pickFilePath(
      dialogTitle: 'Select ffmpeg executable',
      fallbackTitle: 'Enter ffmpeg path',
      fallbackMessage:
          'The desktop file picker is unavailable on this system. '
          'Enter the full path to the ffmpeg executable.',
    );
    if (filePath != null) {
      await _rememberPickedPath(filePath, isDirectory: false);
      await _toolPathsController.updateManualFfmpegPath(filePath);
    }
  }

  Future<void> _pickFfprobePath() async {
    final filePath = await _pickFilePath(
      dialogTitle: 'Select ffprobe executable',
      fallbackTitle: 'Enter ffprobe path',
      fallbackMessage:
          'The desktop file picker is unavailable on this system. '
          'Enter the full path to the ffprobe executable.',
    );
    if (filePath != null) {
      await _rememberPickedPath(filePath, isDirectory: false);
      await _toolPathsController.updateManualFfprobePath(filePath);
    }
  }

  Future<void> _pickSourcePath() async {
    if (_conversionSetupController.sourceType == SourceType.file) {
      _conversionSetupController.setSelectedSourcePath(
        await _pickFilePath(
          dialogTitle: 'Select media file',
          fallbackTitle: 'Enter media file path',
          fallbackMessage:
              'The desktop file picker is unavailable on this system. '
              'Enter the full path to the media file you want to convert.',
        ),
      );
      if (_conversionSetupController.selectedSourcePath != null) {
        await _rememberPickedPath(
          _conversionSetupController.selectedSourcePath!,
          isDirectory: false,
        );
      }
      return;
    }

    final directoryPath = await _pickDirectoryPath(
      dialogTitle: 'Select media folder',
      fallbackTitle: 'Enter media folder path',
      fallbackMessage:
          'The desktop folder picker is unavailable on this system. '
          'Enter the full path to the folder you want to scan.',
    );
    _conversionSetupController.setSelectedSourcePath(directoryPath);
    if (directoryPath != null) {
      await _rememberPickedPath(directoryPath, isDirectory: true);
    }
  }

  Future<String?> _pickFilePath({
    required String dialogTitle,
    required String fallbackTitle,
    required String fallbackMessage,
  }) async {
    try {
      if (Platform.isLinux) {
        return await _pickFilePathWithFileSelector(
          dialogTitle: dialogTitle,
          initialDirectory: _lastUsedDirectory,
        );
      }

      final result = await FilePicker.pickFiles(
        dialogTitle: dialogTitle,
        initialDirectory: _lastUsedDirectory,
      );
      return result?.files.singleOrNull?.path;
    } catch (error) {
      _showPickerFallbackNotice(error);
      return _showManualPathDialog(
        title: fallbackTitle,
        message: fallbackMessage,
      );
    }
  }

  Future<String?> _pickDirectoryPath({
    required String dialogTitle,
    required String fallbackTitle,
    required String fallbackMessage,
  }) async {
    try {
      if (Platform.isLinux) {
        return await getDirectoryPath(
          confirmButtonText: dialogTitle,
          initialDirectory: _lastUsedDirectory,
        );
      }

      return await FilePicker.getDirectoryPath(
        dialogTitle: dialogTitle,
        initialDirectory: _lastUsedDirectory,
      );
    } catch (error) {
      _showPickerFallbackNotice(error);
      return _showManualPathDialog(
        title: fallbackTitle,
        message: fallbackMessage,
      );
    }
  }

  void _showPickerFallbackNotice(Object error) {
    if (!mounted) {
      return;
    }

    final message = Platform.isLinux
        ? 'Desktop picker failed. Falling back to manual path entry.'
        : 'Picker failed. Falling back to manual path entry.';

    _showSnackBar(message);

    debugPrint('Picker error: $error');
  }

  void _showSnackBar(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String?> _showManualPathDialog({
    required String title,
    required String message,
  }) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              if (Platform.isLinux) ...[
                const SizedBox(height: 8),
                const Text(
                  'This can happen when the XDG desktop portal service is unavailable.',
                ),
              ],
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Full path',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(controller.text.trim());
              },
              child: const Text('Use path'),
            ),
          ],
        );
      },
    );

    controller.dispose();
    if (result == null || result.trim().isEmpty) {
      return null;
    }

    return result.trim();
  }

  Future<String?> _pickFilePathWithFileSelector({
    required String dialogTitle,
    String? initialDirectory,
  }) async {
    final file = await openFile(
      confirmButtonText: dialogTitle,
      initialDirectory: initialDirectory,
    );
    return file?.path;
  }

  Future<void> _loadLastUsedDirectory() async {
    final lastUsedDirectory = await _appSettingsService.loadLastUsedDirectory();
    if (!mounted) {
      _lastUsedDirectory = lastUsedDirectory;
      return;
    }

    setState(() {
      _lastUsedDirectory = lastUsedDirectory;
    });
  }

  Future<void> _rememberPickedPath(
    String selectedPath, {
    required bool isDirectory,
  }) async {
    final directoryPath = isDirectory ? selectedPath : path.dirname(selectedPath);
    _lastUsedDirectory = directoryPath;
    await _appSettingsService.saveLastUsedDirectory(directoryPath);
  }
}

class _HeaderBanner extends StatelessWidget {
  const _HeaderBanner({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF0E3B43), Color(0xFF176A75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resolve Media Converter',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Desktop converter for Resolve-ready WAV and DNxHR outputs, with '
            'tool setup, source selection, trimming, and batch progress.',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(
                isLoading ? Icons.sync : Icons.check_circle,
                color: const Color(0xFFF4C95D),
              ),
              const SizedBox(width: 10),
              Text(
                isLoading
                    ? 'Checking tools and stored settings...'
                    : 'Ready to scan, probe, and convert media.',
                style: theme.textTheme.bodyLarge?.copyWith(color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToolPathsCard extends StatelessWidget {
  const _ToolPathsCard({
    required this.controller,
    required this.ffmpegTextController,
    required this.ffprobeTextController,
    required this.onPickFfmpegPath,
    required this.onPickFfprobePath,
  });

  final ToolPathsController controller;
  final TextEditingController ffmpegTextController;
  final TextEditingController ffprobeTextController;
  final Future<void> Function() onPickFfmpegPath;
  final Future<void> Function() onPickFfprobePath;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: const Color(0xFFFBF9F4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            initiallyExpanded: false,
            collapsedBackgroundColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            leading: Icon(
              Icons.build_outlined,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              'Tool paths',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            subtitle: Text(
              'Optional overrides for ffmpeg and ffprobe.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            trailing: TextButton.icon(
              onPressed: controller.isLoading ? null : controller.redetectTools,
              icon: const Icon(Icons.refresh),
              label: const Text('Re-detect'),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Auto-detection is available, but you can override ffmpeg '
                  'and ffprobe independently when needed.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 20),
              _ToolField(
                label: 'FFmpeg',
                detectedPath: controller.detectionResult.detectedFfmpegPath,
                effectivePath: controller.effectiveFfmpegPath,
                validation: controller.ffmpegValidation,
                controller: ffmpegTextController,
                onChanged: controller.updateManualFfmpegPath,
                onClear: controller.clearManualFfmpegPath,
                onBrowse: onPickFfmpegPath,
              ),
              const SizedBox(height: 18),
              _ToolField(
                label: 'FFprobe',
                detectedPath: controller.detectionResult.detectedFfprobePath,
                effectivePath: controller.effectiveFfprobePath,
                validation: controller.ffprobeValidation,
                controller: ffprobeTextController,
                onChanged: controller.updateManualFfprobePath,
                onClear: controller.clearManualFfprobePath,
                onBrowse: onPickFfprobePath,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolField extends StatelessWidget {
  const _ToolField({
    required this.label,
    required this.detectedPath,
    required this.effectivePath,
    required this.validation,
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.onBrowse,
  });

  final String label;
  final String? detectedPath;
  final String? effectivePath;
  final ExecutableValidationResult validation;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final Future<void> Function() onBrowse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (validation.status) {
      ToolValidationStatus.valid => const Color(0xFF1F7A4C),
      ToolValidationStatus.invalid => const Color(0xFF9B2C2C),
      ToolValidationStatus.unknown => theme.colorScheme.secondary,
    };

    final statusLabel = switch (validation.status) {
      ToolValidationStatus.valid => 'Validated',
      ToolValidationStatus.invalid => 'Needs attention',
      ToolValidationStatus.unknown => 'Not checked yet',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: theme.textTheme.labelLarge?.copyWith(color: statusColor),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Detected path: ${detectedPath ?? 'Not found on system path'}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: onChanged,
          decoration: InputDecoration(
            labelText: 'Manual override',
            hintText: 'Leave empty to use auto-detection',
            border: const OutlineInputBorder(),
            suffixIcon: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: onBrowse,
                  icon: const Icon(Icons.folder_open),
                  tooltip: 'Browse for executable',
                ),
                IconButton(
                  onPressed: controller.text.isEmpty ? null : onClear,
                  icon: const Icon(Icons.close),
                  tooltip: 'Clear override',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Effective path: ${effectivePath ?? 'No executable available'}',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        if (validation.versionLine != null) ...[
          const SizedBox(height: 6),
          Text(validation.versionLine as String, style: theme.textTheme.bodySmall),
        ],
        if (validation.message != null) ...[
          const SizedBox(height: 6),
          Text(
            validation.message as String,
            style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
          ),
        ],
      ],
    );
  }
}

class _SourceSelectionCard extends StatelessWidget {
  const _SourceSelectionCard({
    required this.controller,
    required this.onPickSource,
  });

  final ConversionSetupController controller;
  final Future<void> Function() onPickSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sourceLabel = switch (controller.sourceType) {
      SourceType.file => 'Single file',
      SourceType.directory => 'Directory',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Source selection',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Choose one file or one folder. Directory mode only scans the selected folder’s top level.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            SegmentedButton<SourceType>(
              segments: const [
                ButtonSegment(
                  value: SourceType.file,
                  icon: Icon(Icons.audio_file),
                  label: Text('Single file'),
                ),
                ButtonSegment(
                  value: SourceType.directory,
                  icon: Icon(Icons.folder_copy),
                  label: Text('Directory'),
                ),
              ],
              selected: {controller.sourceType},
              onSelectionChanged: (selection) {
                controller.setSourceType(selection.first);
              },
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onPickSource,
              icon: const Icon(Icons.attach_file),
              label: Text('Choose $sourceLabel'),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                controller.selectedSourcePath ?? 'No source selected yet.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OutputModeCard extends StatelessWidget {
  const _OutputModeCard({required this.controller});

  final ConversionSetupController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Output placement',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<OutputMode>(
              segments: const [
                ButtonSegment(
                  value: OutputMode.sameFolderSuffix,
                  icon: Icon(Icons.drive_file_rename_outline),
                  label: Text('Same folder + suffix'),
                ),
                ButtonSegment(
                  value: OutputMode.resolveSubdirectory,
                  icon: Icon(Icons.create_new_folder),
                  label: Text('for_resolve subdir'),
                ),
              ],
              selected: {controller.outputMode},
              onSelectionChanged: (selection) {
                controller.setOutputMode(selection.first);
              },
            ),
            const SizedBox(height: 12),
            Text(
              controller.outputMode == OutputMode.sameFolderSuffix
                  ? 'Example: clip-for_resolve.mxf'
                  : 'Example: for_resolve/clip.mxf',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                _buildOutputPreview(controller),
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _buildOutputPreview(ConversionSetupController controller) {
    final sourcePath = controller.selectedSourcePath;
    final baseName = sourcePath == null
        ? 'source_name'
        : path.basenameWithoutExtension(sourcePath);

    final extension = controller.sourceType == SourceType.file ? '.wav or .mxf' : '.wav / .mxf';

    return switch (controller.outputMode) {
      OutputMode.sameFolderSuffix =>
        'Preview: $baseName-for_resolve$extension in the same folder.',
      OutputMode.resolveSubdirectory =>
        'Preview: for_resolve/$baseName$extension in a new subdirectory.',
    };
  }
}

class _TrimCard extends StatelessWidget {
  const _TrimCard({
    required this.controller,
    required this.startTimeTextController,
    required this.endTimeTextController,
  });

  final ConversionSetupController controller;
  final TextEditingController startTimeTextController;
  final TextEditingController endTimeTextController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Trim controls',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Start and end time are both optional. Accepted formats: SS, MM:SS, HH:MM:SS, HH:MM:SS.mmm.',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final useSideBySide = constraints.maxWidth >= 720;

                final startField = TextField(
                  controller: startTimeTextController,
                  onChanged: controller.updateStartTimeText,
                  decoration: InputDecoration(
                    labelText: 'Start time',
                    hintText: '00:00:12.500',
                    border: const OutlineInputBorder(),
                    errorText: controller.startTimeError,
                  ),
                );

                final endField = TextField(
                  controller: endTimeTextController,
                  onChanged: controller.updateEndTimeText,
                  decoration: InputDecoration(
                    labelText: 'End time',
                    hintText: '00:01:02.000',
                    border: const OutlineInputBorder(),
                    errorText: controller.endTimeError,
                  ),
                );

                if (!useSideBySide) {
                  return Column(
                    children: [
                      startField,
                      const SizedBox(height: 16),
                      endField,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: startField),
                    const SizedBox(width: 16),
                    Expanded(child: endField),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Text(
                controller.hasValidTrimRange
                    ? 'Trim inputs are valid. Leave both blank for a full conversion.'
                    : 'Fix the trim inputs before running a conversion.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExecutionCard extends StatelessWidget {
  const _ExecutionCard({
    required this.title,
    required this.controller,
    required this.onRunConversion,
    required this.canRun,
  });

  final String title;
  final ConversionRunController controller;
  final Future<void> Function() onRunConversion;
  final bool canRun;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: controller.results.isEmpty ? null : controller.clearResults,
                  child: const Text('Clear results'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: canRun ? onRunConversion : null,
                  icon: Icon(controller.isRunning ? Icons.sync : Icons.play_arrow),
                  label: Text(controller.isRunning ? 'Running...' : 'Convert'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (controller.totalJobs > 0) ...[
              LinearProgressIndicator(value: controller.progress),
              const SizedBox(height: 8),
              Text(
                '${controller.completedJobs}/${controller.totalJobs} processed'
                '${controller.currentItem == null ? '' : ' • ${path.basename(controller.currentItem!)}'}',
              ),
              const SizedBox(height: 16),
            ],
            if (controller.errorMessage != null) ...[
              Text(
                controller.errorMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (controller.results.isEmpty)
              Text(
                'Ready to validate tools, scan the selected source, probe media, build output jobs, and run ffmpeg sequentially.',
                style: theme.textTheme.bodyLarge,
              )
            else
              Column(
                children: [
                  for (final result in controller.results)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ResultRow(result: result),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.result});

  final ConversionResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusColor = switch (result.status) {
      ConversionStatus.success => const Color(0xFF1F7A4C),
      ConversionStatus.failed => theme.colorScheme.error,
      ConversionStatus.skipped => const Color(0xFF8A6D1D),
      ConversionStatus.queued => theme.colorScheme.primary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  path.basename(result.sourcePath),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                result.status.name,
                style: theme.textTheme.labelLarge?.copyWith(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Type: ${_mediaKindLabel(result.mediaKind)}',
            style: theme.textTheme.bodySmall,
          ),
          if (result.elapsed != null) ...[
            const SizedBox(height: 6),
            Text(
              'Conversion time: ${_formatElapsed(result.elapsed!)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
          if (result.destinationPath.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(result.destinationPath, style: theme.textTheme.bodySmall),
          ],
          if (result.errorMessage != null) ...[
            const SizedBox(height: 6),
            Text(
              result.errorMessage!,
              style: theme.textTheme.bodySmall?.copyWith(color: statusColor),
            ),
          ],
          if (result.logFilePath != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showLogDialog(context),
                icon: const Icon(Icons.article_outlined),
                label: const Text('View log'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showLogDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final logFilePath = result.logFilePath;

    if (logFilePath == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No log file is available for this item.')),
      );
      return;
    }

    try {
      final logText = await File(logFilePath).readAsString();
      if (!context.mounted) {
        return;
      }

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text('Conversion log • ${path.basename(result.sourcePath)}'),
            content: SizedBox(
              width: 720,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (result.elapsed != null) ...[
                    Text(
                      'Conversion time: ${_formatElapsed(result.elapsed!)}',
                      style: Theme.of(dialogContext).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                  ],
                  SelectableText(
                    logFilePath,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Flexible(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        logText,
                        style: Theme.of(dialogContext).textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } on FileSystemException {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not read log file: $logFilePath')),
      );
    }
  }

  String _mediaKindLabel(MediaKind mediaKind) {
    return switch (mediaKind) {
      MediaKind.audio => 'Audio',
      MediaKind.video => 'Video',
      MediaKind.unsupported => 'Unsupported',
    };
  }

  String _formatElapsed(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;
    final milliseconds = duration.inMilliseconds % 1000;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:'
          '${minutes.toString().padLeft(2, '0')}:'
          '${seconds.toString().padLeft(2, '0')}.'
          '${milliseconds.toString().padLeft(3, '0')}';
    }

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${milliseconds.toString().padLeft(3, '0')}';
  }
}
