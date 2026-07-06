// ignore_for_file: avoid_print

/// Pluggable logging policy for the SDK (domain layer, logger).
///
/// Default sink is the global [print]; consumers can intercept all
/// log emission by passing a [customLogger] callback. Used internally by
/// the concrete tracking collector and the other `infrastructure` adapters.
library;

/// Severity ladder for SDK log messages.
///
/// Variants are ordered ascending; a logger with [UmamiLogger.minLevel]
/// set to a given value drops any entry whose `index` is lower. The
/// `none` sentinel mutes everything.
///
/// Drop [verbose] entries (most granular) to `error` (only failures).
enum UmamiLogLevel {
  /// Most granular trace — includes per-call payloads and timings.
  verbose,

  /// Diagnostic detail useful while developing locally.
  debug,

  /// Lifecycle / state-change messages (queue flushes, sends).
  info,

  /// Recoverable anomalies (transport retries, missing optional state).
  warning,

  /// Failures that prevented an operation from completing.
  error,

  /// Sentinel that disables all logging regardless of [UmamiLogger.minLevel].
  none,
}

/// Custom log sink signature: receives the originating [UmamiLogLevel]
/// and the pre-formatted message produced by [UmamiLogger.log].
typedef UmamiLoggerCallback = void Function(
    UmamiLogLevel level, String message);

/// Sink for SDK log messages.
///
/// Stateless apart from its [minLevel] / [customLogger] configuration.
/// Use the [verbose], [debug], [info], [warning], [error] helpers or the
/// generic [log] entry-point; entries below [minLevel] are dropped
/// before formatting.
class UmamiLogger {
  /// Lowest severity that will actually be dispatched.
  ///
  /// Defaults to [UmamiLogLevel.warning]; entries whose `index` is lower
  /// than this value are silently dropped.
  final UmamiLogLevel minLevel;

  /// Optional override sink. When `null`, [log] falls back to [print].
  final UmamiLoggerCallback? customLogger;

  /// Creates a logger.
  ///
  /// [minLevel] defaults to [UmamiLogLevel.warning]; [customLogger]
  /// defaults to `null` (which routes output through [print]).
  const UmamiLogger({this.minLevel = UmamiLogLevel.warning, this.customLogger});

  /// Formats `[Umami] [LEVEL] message` and dispatches it.
  ///
  /// Entries with `level.index < minLevel.index` are no-ops. When
  /// [customLogger] is non-null it receives the formatted message;
  /// otherwise the message is forwarded to [print].
  void log(UmamiLogLevel level, String message) {
    if (level.index < minLevel.index) return;
    final formatted = '[Umami] [${level.name.toUpperCase()}] $message';
    final logger = customLogger;
    if (logger != null) {
      logger(level, formatted);
      return;
    }
    print(formatted);
  }

  /// Convenience wrapper for [log] at [UmamiLogLevel.verbose].
  void verbose(String message) => log(UmamiLogLevel.verbose, message);

  /// Convenience wrapper for [log] at [UmamiLogLevel.debug].
  void debug(String message) => log(UmamiLogLevel.debug, message);

  /// Convenience wrapper for [log] at [UmamiLogLevel.info].
  void info(String message) => log(UmamiLogLevel.info, message);

  /// Convenience wrapper for [log] at [UmamiLogLevel.warning].
  void warning(String message) => log(UmamiLogLevel.warning, message);

  /// Convenience wrapper for [log] at [UmamiLogLevel.error].
  void error(String message) => log(UmamiLogLevel.error, message);
}
