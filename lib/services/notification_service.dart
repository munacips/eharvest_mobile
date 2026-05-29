import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eharvest_mobile/services/notification_api_service.dart';
import 'package:eharvest_mobile/firebase_options.dart';

/// Handles Firebase Cloud Messaging (FCM) initialization and notification management.
class NotificationService {
  static final FirebaseMessaging _firebaseMessaging =
      FirebaseMessaging.instance;

  static late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  /// Initializes Firebase and FCM.
  ///
  /// This method:
  /// 1. Initializes Firebase with platform-specific configuration
  /// 2. Requests notification permissions from the user
  /// 3. Sets up flutter_local_notifications for foreground notification popups
  /// 4. Retrieves the FCM token and registers it with the backend
  /// 5. Configures a listener for token refresh events
  static Future<void> init() async {
    try {
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Initialize flutter_local_notifications
      _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

      // Platform-specific initialization for local notifications
      if (Platform.isAndroid) {
        const AndroidInitializationSettings androidSettings =
            AndroidInitializationSettings('@mipmap/ic_launcher');
        const InitializationSettings initSettings = InitializationSettings(
          android: androidSettings,
        );
        await _flutterLocalNotificationsPlugin.initialize(initSettings);
      } else if (Platform.isIOS) {
        const DarwinInitializationSettings iosSettings =
            DarwinInitializationSettings(
              requestAlertPermission: true,
              requestBadgePermission: true,
              requestSoundPermission: true,
            );
        const InitializationSettings initSettings = InitializationSettings(
          iOS: iosSettings,
        );
        await _flutterLocalNotificationsPlugin.initialize(initSettings);
      }

      // Request notification permissions (with timeout to avoid hanging
      // when Firebase is unavailable, e.g. on emulators)
      final NotificationSettings settings = await _firebaseMessaging
          .requestPermission(
            alert: true,
            announcement: true,
            badge: true,
            carPlay: false,
            criticalAlert: false,
            provisional: false,
            sound: true,
          )
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('Permission request timed out, skipping notifications');
              return const NotificationSettings(
                authorizationStatus: AuthorizationStatus.denied,
                alert: AppleNotificationSetting.disabled,
                announcement: AppleNotificationSetting.disabled,
                badge: AppleNotificationSetting.disabled,
                carPlay: AppleNotificationSetting.disabled,
                criticalAlert: AppleNotificationSetting.disabled,
                sound: AppleNotificationSetting.disabled,
                lockScreen: AppleNotificationSetting.disabled,
                notificationCenter: AppleNotificationSetting.disabled,
                showPreviews: AppleShowPreviewSetting.never,
                timeSensitive: AppleNotificationSetting.disabled,
                providesAppNotificationSettings:
                    AppleNotificationSetting.disabled,
              );
            },
          );

      // Only proceed with token registration if user granted permission
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get FCM token and register with backend (with timeout to avoid
        // hanging when Firebase servers are unreachable)
        final String? token = await _firebaseMessaging.getToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('FCM token fetch timed out, skipping token registration');
            return null;
          },
        );
        if (token != null && token.isNotEmpty) {
          await _registerTokenWithBackend(token);
        }

        // Listen for token refresh and re-register
        _firebaseMessaging.onTokenRefresh.listen((newToken) {
          _registerTokenWithBackend(newToken);
        });
      }

      // Setup notification listeners
      await setupListeners();
    } catch (e) {
      print('Error initializing Firebase: $e');
      // Don't crash the app, just log the error
    }
  }

  /// Registers the FCM token with the backend.
  static Future<void> _registerTokenWithBackend(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userIdStr = prefs.getString('userId');

      if (userIdStr == null || userIdStr.isEmpty) {
        print('User ID not found, skipping token registration');
        return;
      }

      final String deviceType = Platform.isAndroid
          ? 'android'
          : (Platform.isIOS ? 'ios' : 'web');

      final bool success = await NotificationApiService.registerToken(
        userId: userIdStr,
        fcmToken: token,
        deviceType: deviceType,
      );

      if (success) {
        // Cache the token locally for logout
        await prefs.setString('fcmToken', token);
        print('FCM token registered successfully');
      }
    } catch (e) {
      print('Error registering token with backend: $e');
    }
  }

  /// Sets up listeners for different notification scenarios:
  /// - Foreground: App is open - shows local notification popup
  /// - Background: App is minimized - FCM handles it automatically
  /// - Terminated: App was closed - onMessageOpenedApp handles resume
  static Future<void> setupListeners() async {
    // Handle foreground messages (app is open)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Foreground message: ${message.notification?.title}');
      showLocalNotification(
        message.notification?.title,
        message.notification?.body,
      );
    });

    // Handle messages when app is opened from terminated state
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print('Message opened app from terminated state: ${message.data}');
      _handleMessageNavigation(message);
    });

    // Handle background messages (when app is minimized)
    // Note: This is handled automatically by FCM on Android/iOS
    // We just log it for debugging
    if (Platform.isAndroid) {
      FirebaseMessaging.onBackgroundMessage(_backgroundMessageHandler);
    }
  }

  /// Background message handler (called when app is not running or minimized).
  /// This is a top-level function that must be a static method or standalone function.
  static Future<void> _backgroundMessageHandler(RemoteMessage message) async {
    print('Background message: ${message.notification?.title}');
    // You can handle background logic here if needed
    // For most cases, FCM automatically shows the notification
  }

  /// Displays a local notification popup using flutter_local_notifications.
  /// Used to show notifications while the app is in the foreground.
  static Future<void> showLocalNotification(String? title, String? body) async {
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'eharvest_notifications',
            'eHarvest Notifications',
            channelDescription: 'Notifications from eHarvest',
            importance: Importance.max,
            priority: Priority.high,
            showWhen: true,
            icon: '@drawable/ic_stat_notification',
          );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );

      await _flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecond,
        title ?? 'eHarvest',
        body ?? 'You have a new notification',
        notificationDetails,
      );
    } catch (e) {
      print('Error showing local notification: $e');
    }
  }

  /// Handles navigation based on notification message data.
  /// This is called when the user taps a notification from the terminated state.
  static void _handleMessageNavigation(RemoteMessage message) {
    // Extract custom data from the message
    final Map<String, dynamic> data = message.data;

    // Example: Navigate based on notification type
    // You can customize this based on your app's navigation needs
    if (data.containsKey('type') && data['type'] == 'order') {
      // Navigate to orders page
      print('Navigating to orders with data: $data');
    }
  }

  /// Deletes the FCM token and deactivates it on the backend.
  /// Should be called on logout.
  static Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? fcmToken = prefs.getString('fcmToken');

      if (fcmToken != null && fcmToken.isNotEmpty) {
        // Deactivate token on backend
        await NotificationApiService.deactivateToken(fcmToken: fcmToken);

        // Delete from local cache
        await prefs.remove('fcmToken');
        print('FCM token deleted successfully');
      }

      // Also delete the Firebase token
      await _firebaseMessaging.deleteToken();
    } catch (e) {
      print('Error deleting FCM token: $e');
    }
  }
}
