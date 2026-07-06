// ignore_for_file: avoid_print

enum UmamiLogLevel { verbose, debug, info, warning, error, none }

typedef UmamiLoggerCallback = void Function(
    UmamiLogLevel level, String message);

class UmamiLogger {
  final UmamiLogLevel minLevel;
  final UmamiLoggerCallback? customLogger;

  const UmamiLogger({this.minLevel = UmamiLogLevel.warning, this.customLogger});

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

  void verbose(String message) => log(UmamiLogLevel.verbose, message);
  void debug(String message) => log(UmamiLogLevel.debug, message);
  void info(String message) => log(UmamiLogLevel.info, message);
  void warning(String message) => log(UmamiLogLevel.warning, message);
  void error(String message) => log(UmamiLogLevel.error, message);
}
