import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/review_service.dart';
import 'package:eharvest_mobile/widgets/star_rating_input.dart';
import 'package:flutter/material.dart';

class PendingReviewSheet extends StatefulWidget {
  final Review review;

  const PendingReviewSheet({super.key, required this.review});

  @override
  State<PendingReviewSheet> createState() => _PendingReviewSheetState();
}

class _PendingReviewSheetState extends State<PendingReviewSheet> {
  late final TextEditingController _commentController;
  int _rating = 0;
  bool _submitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _rating = widget.review.rating < 0
        ? 0
        : (widget.review.rating > 5 ? 5 : widget.review.rating);
    _commentController = TextEditingController(text: widget.review.comment);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
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
      await ReviewService.submitPendingReview(
        reviewId: widget.review.id,
        rating: _rating,
        comment: _commentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ReviewApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final revieweeName = widget.review.reviewee?.displayName.isNotEmpty == true
        ? widget.review.reviewee!.displayName
        : 'User #${widget.review.revieweeId}';
    final revieweeRole = _formatRole(widget.review.reviewee?.role ?? '');

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.rate_review_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Review $revieweeName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              if (revieweeRole.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  revieweeRole,
                  style: TextStyle(color: Colors.grey[600], letterSpacing: 0.4),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Order #${widget.review.orderId}',
                style: TextStyle(color: Colors.grey[700]),
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
                  hintText: 'Share your experience...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _submitting
                          ? null
                          : () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _submitting ? null : _submit,
                      child: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Submit'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatRole(String role) {
    final cleaned = role.trim();
    if (cleaned.isEmpty) return '';
    return cleaned
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(
          (part) => part.length == 1
              ? part.toUpperCase()
              : '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}',
        )
        .join(' ');
  }
}
