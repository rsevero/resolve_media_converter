import '../models/trim_parse_result.dart';

class TrimParserService {
  const TrimParserService();

  TrimParseResult parse(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) {
      return const TrimParseResult.empty();
    }

    final segments = trimmed.split(':');
    if (segments.length > 3) {
      return const TrimParseResult.invalid(
        'Use SS, MM:SS, HH:MM:SS, or HH:MM:SS.mmm.',
      );
    }

    final hasMilliseconds = segments.last.contains('.');
    final secondsParts = segments.last.split('.');
    if (secondsParts.length > 2) {
      return const TrimParseResult.invalid('Too many decimal separators.');
    }

    final integerParts = <int>[];
    for (var index = 0; index < segments.length; index++) {
      final part = index == segments.length - 1 ? secondsParts.first : segments[index];
      if (part.isEmpty) {
        return const TrimParseResult.invalid('Time values cannot be empty.');
      }

      final parsed = int.tryParse(part);
      if (parsed == null) {
        return const TrimParseResult.invalid('Time values must be numeric.');
      }
      if (parsed < 0) {
        return const TrimParseResult.invalid('Time values cannot be negative.');
      }

      integerParts.add(parsed);
    }

    var milliseconds = 0;
    if (hasMilliseconds) {
      final fraction = secondsParts.elementAtOrNull(1) ?? '';
      if (fraction.isEmpty || fraction.length > 3 || int.tryParse(fraction) == null) {
        return const TrimParseResult.invalid(
          'Milliseconds must use one to three digits.',
        );
      }

      milliseconds = int.parse(fraction.padRight(3, '0'));
    }

    while (integerParts.length < 3) {
      integerParts.insert(0, 0);
    }

    final hours = integerParts[integerParts.length - 3];
    final minutes = integerParts[integerParts.length - 2];
    final seconds = integerParts[integerParts.length - 1];

    if (minutes >= 60) {
      return const TrimParseResult.invalid('Minutes must be lower than 60.');
    }
    if (seconds >= 60 && segments.length > 1) {
      return const TrimParseResult.invalid('Seconds must be lower than 60.');
    }

    return TrimParseResult.valid(
      Duration(
        hours: hours,
        minutes: minutes,
        seconds: seconds,
        milliseconds: milliseconds,
      ),
    );
  }
}
