import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/review_service.dart';
import 'package:eharvest_mobile/widgets/star_rating_input.dart';
import 'package:flutter/material.dart';

class ReviewForm extends StatefulWidget {
  final int reviewerId;
  final int revieweeId;
  final String revieweeName;
  final String revieweeRole;
  final ValueChanged<Review>? onSubmitted;

  const ReviewForm({
    super.key,
    required this.reviewerId,
    required this.revieweeId,
    required this.revieweeName,
    required this.revieweeRole,
    this.onSubmitted,
  });

  @override
  State<ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends State<ReviewForm> {
  final TextEditingController _commentController = TextEditingController();
  int _rating = 0;
  bool _submitting = false;
  bool _submitted = false;
  String? _errorMessage;
  Review? _createdReview;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating < 1 || _rating > 5) {
      setState(() {
        _errorMessage = 'Please select a rating between 1 and 5 stars.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      final review = await ReviewService.createReview(
        reviewerId: widget.reviewerId,
        revieweeId: widget.revieweeId,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _submitted = true;
        _createdReview = review;
      });
      widget.onSubmitted?.call(review);
    } on ReviewApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _errorMessage = e.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted && _createdReview != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Colors.green[50],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 44),
                  const SizedBox(height: 12),
                  const Text(
                    'Review submitted successfully.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your review for ${widget.revieweeName} has been saved.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.green[900]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: const Text('Close'),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.rate_review_outlined),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Review ${widget.revieweeName}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          widget.revieweeRole.toUpperCase(),
          style: TextStyle(color: Colors.grey[600], letterSpacing: 1.1),
        ),
        const SizedBox(height: 16),
        Text(
          'Rating',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 8),
        StarRatingInput(
          rating: _rating,
          enabled: !_submitting,
          onChanged: (value) {
            setState(() {
              _rating = value;
              _errorMessage = null;
            });
          },
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _commentController,
          enabled: !_submitting,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: 'Comment',
            hintText: 'Tell them what went well...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
        ],
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: FilledButton(
            onPressed: _submitting ? null : _submitReview,
            child: _submitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Submit Review'),
          ),
        ),
      ],
    );
  }
}
