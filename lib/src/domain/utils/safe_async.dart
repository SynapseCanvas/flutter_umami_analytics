import 'package:flutter_umami_analytics/src/domain/logger/umami_logger.dart';

Future<T?> safeAsync<T>(
  Future<T> Function() operation, {
  UmamiLogger? logger,
  String? errorMessage,
  void Function(Object error)? onError,
}) async {
  try {
    return await operation();
  } catch (e) {
    final handler = onError;
    if (handler != null) {
      handler(e);
    } else if (logger != null) {
      logger.warning(
        errorMessage != null ? '$errorMessage: $e' : 'safeAsync error: $e',
      );
    }
    return null;
  }
}

Future<bool> safeBool(
  Future<void> Function() operation, {
  UmamiLogger? logger,
  String? errorMessage,
  void Function(Object error)? onError,
}) async {
  final result = await safeAsync<bool>(
    () async {
      await operation();
      return true;
    },
    logger: logger,
    errorMessage: errorMessage,
    onError: onError,
  );
  return result ?? false;
}
