import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:eharvest_mobile/global_variables.dart';

class NotificationApiService {
  /// Registers the FCM token with the backend.
  ///
  /// Sends the FCM token to the backend so the server can send push notifications
  /// to this device. The deviceType is automatically detected (android/ios).
  ///
  /// Returns true if registration is successful, false otherwise.
  static Future<bool> registerToken({
    required String userId,
    required String fcmToken,
    required String deviceType,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${api}notifications/register-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'fcmToken': fcmToken,
          'deviceType': deviceType,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      } else {
        print('Failed to register token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error registering token: $e');
      return false;
    }
  }

  /// Deactivates the FCM token with the backend.
  ///
  /// Notifies the backend that this FCM token should no longer receive
  /// push notifications. Called when the user logs out.
  ///
  /// Returns true if deactivation is successful, false otherwise.
  static Future<bool> deactivateToken({required String fcmToken}) async {
    try {
      final response = await http.delete(
        Uri.parse('${api}notifications/deactivate-token'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'fcmToken': fcmToken}),
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        return true;
      } else {
        print('Failed to deactivate token: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Error deactivating token: $e');
      return false;
    }
  }
}
