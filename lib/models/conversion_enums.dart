enum SourceType { file, directory }

enum VideoRotation { none, clockwise90, rotate180, counterClockwise90, removeMetadata }

enum MediaKind { audio, video, unsupported }

enum OutputMode { sameFolderSuffix, resolveSubdirectory }

enum ConversionStatus { queued, success, failed, skipped }

enum ToolValidationStatus { unknown, valid, invalid }
