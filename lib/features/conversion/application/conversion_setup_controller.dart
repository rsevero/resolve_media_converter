import 'package:flutter/foundation.dart';

import '../../../models/conversion_enums.dart';
import '../../../services/trim_parser_service.dart';

class ConversionSetupController extends ChangeNotifier {
  ConversionSetupController({TrimParserService? trimParserService})
      : _trimParserService = trimParserService ?? const TrimParserService();

  final TrimParserService _trimParserService;

  SourceType _sourceType = SourceType.file;
  OutputMode _outputMode = OutputMode.sameFolderSuffix;
  String? _selectedSourcePath;
  String _startTimeText = '';
  String _endTimeText = '';
  String? _startTimeError;
  String? _endTimeError;

  SourceType get sourceType => _sourceType;
  OutputMode get outputMode => _outputMode;
  String? get selectedSourcePath => _selectedSourcePath;
  String get startTimeText => _startTimeText;
  String get endTimeText => _endTimeText;
  String? get startTimeError => _startTimeError;
  String? get endTimeError => _endTimeError;

  bool get hasSourceSelection =>
      _selectedSourcePath != null && _selectedSourcePath!.trim().isNotEmpty;

  bool get hasValidTrimRange => _startTimeError == null && _endTimeError == null;

  void setSourceType(SourceType value) {
    if (_sourceType == value) {
      return;
    }

    _sourceType = value;
    _selectedSourcePath = null;
    notifyListeners();
  }

  void setOutputMode(OutputMode value) {
    if (_outputMode == value) {
      return;
    }

    _outputMode = value;
    notifyListeners();
  }

  void setSelectedSourcePath(String? value) {
    final normalized = value?.trim();
    _selectedSourcePath = normalized == null || normalized.isEmpty ? null : normalized;
    notifyListeners();
  }

  void updateStartTimeText(String value) {
    _startTimeText = value;
    _validateTrimRange();
    notifyListeners();
  }

  void updateEndTimeText(String value) {
    _endTimeText = value;
    _validateTrimRange();
    notifyListeners();
  }

  bool validateBeforeConversion() {
    _validateTrimRange();
    notifyListeners();
    return hasValidTrimRange && hasSourceSelection;
  }

  void _validateTrimRange() {
    final startResult = _trimParserService.parse(_startTimeText);
    final endResult = _trimParserService.parse(_endTimeText);

    _startTimeError = startResult.errorMessage;
    _endTimeError = endResult.errorMessage;

    if (_startTimeError != null || _endTimeError != null) {
      return;
    }

    if (startResult.duration != null &&
        endResult.duration != null &&
        endResult.duration! <= startResult.duration!) {
      _endTimeError = 'End time must be greater than start time.';
    }
  }
}
