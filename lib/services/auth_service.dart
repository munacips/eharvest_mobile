import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/notification_service.dart';

class AuthResult {
  final bool success;
  final String message;

  const AuthResult({required this.success, required this.message});
}

class AuthService {
  /// Logs in a user with the provided username and password.
  ///
  /// Returns true if login is successful, false otherwise.
  /// Stores token, userId, role, and sets logged_in to true in SharedPreferences on success.
  static Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${authApi}login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        // Extract token, userId, and role from response
        final String token = jsonResponse['token'] ?? '';
        final int userId = jsonResponse['userId'] ?? 0;
        final String role = jsonResponse['role'] ?? '';

        if (token.isEmpty || userId == 0 || role.isEmpty) {
          throw Exception('Invalid response: missing required fields');
        }

        // Store in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', token);
        await prefs.setInt('userId', userId);
        await prefs.setString('role', role);
        await prefs.setBool('logged_in', true);

        return true;
      } else if (response.statusCode == 401 || response.statusCode == 400) {
        // Invalid credentials
        return false;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      return false;
    }
  }

  /// Logs out the user by clearing SharedPreferences and deactivating FCM token.
  static Future<void> logout() async {
    // Delete FCM token and notify backend
    await NotificationService.deleteToken();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('logged_in', false);
    await prefs.remove('token');
    await prefs.remove('userId');
    await prefs.remove('role');
  }

  /// Retrieves the stored token from SharedPreferences.
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  /// Retrieves the stored userId from SharedPreferences.
  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('userId');
  }

  /// Retrieves the stored role from SharedPreferences.
  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  /// Checks if user is logged in.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('logged_in') ?? false;
  }

  /// Registers a user using a role-specific endpoint.
  static Future<AuthResult> register({
    required String username,
    required String firstName,
    required String lastName,
    required String email,
    required String phoneNumber,
    required String password,
    required String role,
    required String nationalId,
    required String address,
    String? farmName,
    String? farmLocation,
    String? companyName,
    String? licenseNumber,
    String? defensiveId,
  }) async {
    try {
      final roleKey = role.trim().toLowerCase().replaceAll(' ', '_');
      final endpointByRole = <String, String>{
        'farmer': '${api}farmers',
        'buyer': '${api}buyers',
        'logistics_provider': '${api}logistics-providers',
        'logisticsprovider': '${api}logistics-providers',
        'user': '${api}users',
      };
      final endpoint = endpointByRole[roleKey] ?? '${api}users';

      final payload = <String, dynamic>{
        'username': username.trim(),
        'firstName': firstName.trim(),
        'lastName': lastName.trim(),
        'email': email.trim(),
        'phoneNumber': phoneNumber.trim(),
        'password': password,
        'role': role.trim().toUpperCase(),
        'nationalId': nationalId.trim(),
        'address': address.trim(),
      };

      if (roleKey == 'farmer') {
        payload['farmName'] = (farmName ?? '').trim();
        payload['farmLocation'] = (farmLocation ?? '').trim();
        payload['successfulSales'] = 0; // Default value for new farmers
        payload['unsuccessfulSales'] = 0; // Default value for new farmers
      } else if (roleKey == 'buyer') {
        payload['companyName'] = (companyName ?? '').trim();
        payload['successfulBuys'] = 0; // Default value for new buyers
        payload['unsuccessfulBuys'] = 0; // Default value for new buyers
      } else if (roleKey == 'logistics_provider' ||
          roleKey == 'logisticsprovider') {
        payload['licenseNumber'] = (licenseNumber ?? '').trim();
        payload['defensiveId'] = (defensiveId ?? '').trim();
      }

      final response = await http.post(
        Uri.parse(endpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return const AuthResult(
          success: true,
          message: 'Account created successfully.',
        );
      }

      String message = 'Registration failed (${response.statusCode}).';
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          final backendMessage =
              decoded['message'] ?? decoded['error'] ?? decoded['details'];
          if (backendMessage != null && backendMessage.toString().isNotEmpty) {
            message = backendMessage.toString();
          }
        }
      } catch (_) {}

      return AuthResult(success: false, message: message);
    } catch (e) {
      return AuthResult(success: false, message: 'Registration failed: $e');
    }
  }
}
