class ConversionProgress {
  const ConversionProgress({
    required this.processed,
    this.total,
    this.speed,
  });

  final Duration processed;
  final Duration? total;
  final double? speed;

  double? get fraction {
    final total = this.total;
    if (total == null || total.inMicroseconds <= 0) {
      return null;
    }
    final value = processed.inMicroseconds / total.inMicroseconds;
    return value.clamp(0, 1).toDouble();
  }

  Duration? get eta {
    final total = this.total;
    final speed = this.speed;
    if (total == null || speed == null || speed <= 0) {
      return null;
    }
    final remaining = total - processed;
    if (remaining.isNegative) {
      return Duration.zero;
    }
    return Duration(
      microseconds: (remaining.inMicroseconds / speed).round(),
    );
  }
}
