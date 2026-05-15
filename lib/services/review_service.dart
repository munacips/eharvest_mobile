import 'dart:convert';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:http/http.dart' as http;

class ReviewApiException implements Exception {
  final int statusCode;
  final String message;

  const ReviewApiException(this.statusCode, this.message);

  @override
  String toString() => message;
}

class ReviewService {
  static Future<Review> createReview({
    required int reviewerId,
    required int revieweeId,
    required int rating,
    required String comment,
  }) async {
    final response = await http.post(
      Uri.parse('${api}reviews'),
      headers: await _headers(),
      body: jsonEncode({
        'reviewerId': reviewerId,
        'revieweeId': revieweeId,
        'rating': rating,
        'comment': comment.trim(),
      }),
    );
    return _decodeReview(response, 'create review');
  }

  static Future<List<Review>> fetchReviews() async {
    final response = await http.get(
      Uri.parse('${api}reviews'),
      headers: await _headers(),
    );
    return _decodeReviewList(response, 'load reviews');
  }

  static Future<Review> fetchReview(int id) async {
    final response = await http.get(
      Uri.parse('${api}reviews/$id'),
      headers: await _headers(),
    );
    return _decodeReview(response, 'load review');
  }

  static Future<List<Review>> fetchReviewsByReviewer(int reviewerId) async {
    final response = await http.get(
      Uri.parse('${api}reviews/reviewer/$reviewerId'),
      headers: await _headers(),
    );
    return _decodeReviewList(response, 'load written reviews');
  }

  static Future<List<Review>> fetchReviewsByReviewee(int revieweeId) async {
    final response = await http.get(
      Uri.parse('${api}reviews/reviewee/$revieweeId'),
      headers: await _headers(),
    );
    return _decodeReviewList(response, 'load received reviews');
  }

  static Future<Review> updateReview(
    int id, {
    int? rating,
    String? comment,
  }) async {
    final payload = <String, dynamic>{
      if (rating != null) 'rating': rating,
      if (comment != null) 'comment': comment.trim(),
    };
    final response = await http.put(
      Uri.parse('${api}reviews/$id'),
      headers: await _headers(),
      body: jsonEncode(payload),
    );
    return _decodeReview(response, 'update review');
  }

  static Future<void> deleteReview(int id) async {
    final response = await http.delete(
      Uri.parse('${api}reviews/$id'),
      headers: await _headers(),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseError(response, 'delete review');
    }
  }

  static Future<Map<String, String>> _headers() async {
    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const ReviewApiException(
        401,
        'Authentication error. Please log in again.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static Review _decodeReview(http.Response response, String label) {
    final decoded = _decodePayload(response, label);
    if (decoded is Map<String, dynamic>) {
      return Review.fromJson(decoded);
    }
    throw const ReviewApiException(500, 'Invalid review response from server.');
  }

  static List<Review> _decodeReviewList(http.Response response, String label) {
    final decoded = _decodePayload(response, label);
    final items = _extractItems(decoded);
    return items
        .whereType<Map<String, dynamic>>()
        .map(Review.fromJson)
        .toList();
  }

  static dynamic _decodePayload(http.Response response, String label) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseError(response, label);
    }

    if (response.body.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      return jsonDecode(response.body);
    } catch (_) {
      throw const ReviewApiException(
        500,
        'Invalid response received from server.',
      );
    }
  }

  static List<Map<String, dynamic>> _extractItems(dynamic decoded) {
    final items = <Map<String, dynamic>>[];
    if (decoded is List) {
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          items.add(item);
        } else if (item is Map) {
          items.add(item.map((key, value) => MapEntry(key.toString(), value)));
        }
      }
      return items;
    }

    if (decoded is Map<String, dynamic>) {
      final content = decoded['content'];
      if (content is List) {
        return _extractItems(content);
      }
    }

    return items;
  }

  static ReviewApiException _parseError(http.Response response, String label) {
    final body = response.body.trim();
    String message;
    try {
      final decoded = body.isEmpty ? null : jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        message =
            decoded['message']?.toString() ??
            decoded['error']?.toString() ??
            _defaultMessage(response.statusCode, label);
      } else {
        message = _defaultMessage(response.statusCode, label);
      }
    } catch (_) {
      message = body.isNotEmpty
          ? body
          : _defaultMessage(response.statusCode, label);
    }
    return ReviewApiException(response.statusCode, message);
  }

  static String _defaultMessage(int statusCode, String label) {
    switch (statusCode) {
      case 400:
        return 'Unable to $label. Please check the order status, rating, and whether you have already reviewed this person.';
      case 404:
        return 'Review or user not found.';
      case 500:
        return 'Server error while trying to $label. Please try again later.';
      default:
        return 'Failed to $label ($statusCode).';
    }
  }
}
