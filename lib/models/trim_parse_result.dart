class TrimParseResult {
  const TrimParseResult.valid(this.duration)
      : errorMessage = null,
        hasValue = true;

  const TrimParseResult.empty()
      : duration = null,
        errorMessage = null,
        hasValue = false;

  const TrimParseResult.invalid(this.errorMessage)
      : duration = null,
        hasValue = true;

  final Duration? duration;
  final String? errorMessage;
  final bool hasValue;

  bool get isValid => errorMessage == null;
}
