import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../config/onesignal_config.dart';
import '../utils/logger.dart';

class OneSignalService {
  /// Инициализация OneSignal
  static Future<void> initialize() async {
    // Debug логи
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    
    // Инициализация с App ID
    OneSignal.initialize(OneSignalConfig.appId);

    // Запрос разрешения на уведомления
    await OneSignal.Notifications.requestPermission(true);

    log('OneSignal initialized');
  }

  /// Получить OneSignal Player ID
  static String? getPlayerId() {
    final subscriptionId = OneSignal.User.pushSubscription.id;
    log('OneSignal Player ID: $subscriptionId');
    return subscriptionId;
  }

  /// Подождать пока OneSignal Player ID станет доступным
  static Future<String?> waitForPlayerId({int maxAttempts = 10}) async {
    for (int i = 0; i < maxAttempts; i++) {
      final playerId = getPlayerId();
      if (playerId != null) {
        log('OneSignal Player ID received: $playerId');
        return playerId;
      }
      await Future.delayed(const Duration(seconds: 1));
      log('Waiting for OneSignal Player ID... attempt ${i + 1}/$maxAttempts');
    }
    log('OneSignal Player ID timeout after $maxAttempts attempts');
    return null;
  }

  /// Установить External User ID (для связки с нашим user_id)
  static Future<void> setExternalUserId(String userId) async {
    OneSignal.login(userId);
    log('OneSignal External User ID set: $userId');
  }

    /// Настройка обработчика входящих уведомлений
    static void setupNotificationHandlers() {
    // Когда уведомление приходит (приложение открыто)
    OneSignal.Notifications.addForegroundWillDisplayListener((event) {
        log('Notification received in foreground: ${event.notification.body}');
        // Уведомление автоматически показывается
    });

    // Когда пользователь кликает на уведомление
    OneSignal.Notifications.addClickListener((event) {
        log('Notification clicked: ${event.notification.body}');
        
        // TODO: Открыть карту с локацией отправителя
        // Пока просто логируем
    });
    }
}