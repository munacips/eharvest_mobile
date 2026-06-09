import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/review_service.dart';
import 'package:eharvest_mobile/widgets/pending_review_sheet.dart';
import 'package:eharvest_mobile/pages/account_page.dart';
import 'package:flutter/material.dart';

class PendingReviewsPage extends StatefulWidget {
  const PendingReviewsPage({super.key});

  @override
  State<PendingReviewsPage> createState() => _PendingReviewsPageState();
}

class _PendingReviewsPageState extends State<PendingReviewsPage> {
  List<Review> _reviews = <Review>[];
  bool _loading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPendingReviews();
  }

  Future<void> _loadPendingReviews() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final reviews = await ReviewService.getPendingReviewsForCurrentUser();
      if (!mounted) return;
      setState(() {
        _reviews = reviews;
        _loading = false;
      });
    } on ReviewApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _openReview(Review review) async {
    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PendingReviewSheet(review: review),
    );

    if (submitted != true || !mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Review submitted successfully.')),
    );
    await _loadPendingReviews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pending Reviews'),
        backgroundColor: Color(primaryColour),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadPendingReviews,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        children: [
          SizedBox(height: 240),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }

    if (_errorMessage != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 56, color: Colors.red.shade300),
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.red.shade700),
          ),
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _loadPendingReviews,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_reviews.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.mark_chat_read_outlined,
            size: 56,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'You have no pending reviews right now.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Delivered orders that still need feedback will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reviews.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
    );
  }

  Widget _buildReviewCard(Review review) {
    final revieweeName = review.reviewee?.displayName.isNotEmpty == true
        ? review.reviewee!.displayName
        : 'User #${review.revieweeId}';
    final revieweeRole = _formatRole(review.reviewee?.role ?? '');

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openReview(review),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: Color(primaryColour).withValues(alpha: 0.12),
                foregroundColor: Color(primaryDarkColour),
                child: const Icon(Icons.rate_review_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: review.revieweeId > 0
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => AccountPage(id: review.revieweeId),
                                ),
                              );
                            }
                          : null,
                      child: Text(
                        revieweeName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: review.revieweeId > 0
                              ? Color(primaryColour)
                              : Colors.black,
                          decoration: review.revieweeId > 0
                              ? TextDecoration.underline
                              : null,
                        ),
                      ),
                    ),
                    if (revieweeRole.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        revieweeRole,
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoPill('Order #${review.orderId}'),
                        _infoPill(review.status.toUpperCase()),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoPill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey[800],
          fontWeight: FontWeight.w600,
          fontSize: 12,
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
