import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/review_service.dart';
import 'package:eharvest_mobile/pages/account_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReviewsSection extends StatefulWidget {
  final int userId;
  final String title;

  const ReviewsSection({
    super.key,
    required this.userId,
    this.title = 'Reviews',
  });

  @override
  State<ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<ReviewsSection> {
  List<Review> _reviews = [];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  @override
  void didUpdateWidget(covariant ReviewsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadReviews();
    }
  }

  Future<void> _loadReviews() async {
    if (widget.userId <= 0) {
      setState(() {
        _reviews = [];
        _loading = false;
        _errorMessage = 'Unable to load reviews for this user.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final reviews = await ReviewService.fetchReviewsByReviewee(widget.userId);
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } on ReviewApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.reviews_outlined),
                const SizedBox(width: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              _buildErrorState()
            else ...[
              _buildSummary(),
              const SizedBox(height: 16),
              if (_reviews.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'No reviews received yet.',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                )
              else
                ListView.separated(
                  itemCount: _reviews.length,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildReviewTile(_reviews[index]),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: _loadReviews,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final totalReviews = _reviews.length;
    final averageRating = totalReviews == 0
        ? 0.0
        : _reviews.map((review) => review.rating).reduce((a, b) => a + b) /
              totalReviews;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.star, color: Colors.amber.shade700),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  averageRating == 0 ? '-' : averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$totalReviews review${totalReviews == 1 ? '' : 's'} received',
                  style: TextStyle(color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewTile(Review review) {
    final reviewerName = review.reviewer?.displayName.isNotEmpty == true
        ? review.reviewer!.displayName
        : 'Reviewer #${review.reviewerId}';
    final reviewerRole = _formatRole(review.reviewer?.role ?? '');
    final formattedDate = DateFormat('MMM d, yyyy').format(review.createdAt);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        if (review.reviewerId > 0) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountPage(id: review.reviewerId),
                            ),
                          );
                        }
                      },
                      child: Text(
                        reviewerName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(primaryColour),
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                    if (reviewerRole.isNotEmpty)
                      Text(
                        reviewerRole,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                  ],
                ),
              ),
              _buildRatingPill(review.rating),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            review.comment.isNotEmpty ? review.comment : 'No comment provided.',
          ),
          const SizedBox(height: 10),
          Text(
            formattedDate,
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildRatingPill(int rating) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 16, color: Colors.amber.shade700),
          const SizedBox(width: 4),
          Text(
            rating.toString(),
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.amber.shade900,
            ),
          ),
        ],
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
