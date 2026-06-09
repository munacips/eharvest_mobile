import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/services/review_service.dart';
import 'package:eharvest_mobile/widgets/pending_review_sheet.dart';
import 'package:eharvest_mobile/widgets/review_form.dart';
import 'package:eharvest_mobile/pages/account_page.dart';
import 'package:flutter/material.dart';

class OrderReviewSection extends StatefulWidget {
  final Order order;
  final LogisticsRequest? logisticsRequest;
  final int? currentUserId;
  final String? currentUserRole;
  final VoidCallback onReviewCreated;

  const OrderReviewSection({
    super.key,
    required this.order,
    required this.logisticsRequest,
    required this.currentUserId,
    required this.currentUserRole,
    required this.onReviewCreated,
  });

  @override
  State<OrderReviewSection> createState() => _OrderReviewSectionState();
}

class _OrderReviewSectionState extends State<OrderReviewSection> {
  bool _loading = true;
  String? _errorMessage;
  Set<int> _reviewedRevieweeIds = <int>{};
  Map<int, Review> _pendingReviewsByRevieweeId = <int, Review>{};

  @override
  void initState() {
    super.initState();
    _loadExistingReviews();
  }

  @override
  void didUpdateWidget(covariant OrderReviewSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentUserId != widget.currentUserId ||
        oldWidget.order.id != widget.order.id) {
      _loadExistingReviews();
    }
  }

  bool get _isReviewable {
    final status = _normalizedStatus(widget.order.status);
    return status == 'delivered' || status == 'completed';
  }

  Future<void> _loadExistingReviews() async {
    if (widget.currentUserId == null || widget.currentUserId == 0) {
      setState(() {
        _loading = false;
        _errorMessage = 'Authentication error. Please log in again.';
        _reviewedRevieweeIds = <int>{};
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final reviews = await ReviewService.fetchReviewsByReviewer(
        widget.currentUserId!,
      );
      final completedRevieweeIds = <int>{};
      final pendingByRevieweeId = <int, Review>{};
      for (final review in reviews) {
        final revieweeId = review.revieweeId;
        if (revieweeId <= 0) {
          continue;
        }
        if (review.status.trim().toUpperCase() == 'PENDING') {
          if (review.orderId == widget.order.id) {
            pendingByRevieweeId[revieweeId] = review;
          }
          continue;
        }
        completedRevieweeIds.add(revieweeId);
      }
      if (!mounted) return;
      setState(() {
        _reviewedRevieweeIds = completedRevieweeIds;
        _pendingReviewsByRevieweeId = pendingByRevieweeId;
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

  List<_ReviewTarget> _buildTargets() {
    if (!_isReviewable || widget.currentUserId == null) {
      return [];
    }

    final targets = <_ReviewTarget>[];
    final order = widget.order;
    final logisticsRequest = widget.logisticsRequest ?? order.logisticsRequest;
    final provider = logisticsRequest?.assignedProvider;

    if (_isBuyer) {
      if (order.farmer != null) {
        targets.add(
          _ReviewTarget(
            revieweeId: order.farmer!.id,
            displayName: order.farmer!.displayName,
            roleLabel: order.farmer!.role,
          ),
        );
      }
      if (provider != null) {
        targets.add(
          _ReviewTarget(
            revieweeId: provider.id,
            displayName: provider.displayName,
            roleLabel: provider.role,
          ),
        );
      }
    } else if (_isFarmer && order.buyer != null) {
      targets.add(
        _ReviewTarget(
          revieweeId: order.buyer!.id,
          displayName: order.buyer!.displayName,
          roleLabel: order.buyer!.role,
        ),
      );
    } else if (_isLogisticsProvider && provider != null) {
      if (provider.id == widget.currentUserId && order.buyer != null) {
        targets.add(
          _ReviewTarget(
            revieweeId: order.buyer!.id,
            displayName: order.buyer!.displayName,
            roleLabel: order.buyer!.role,
          ),
        );
      }
    }

    return targets;
  }

  bool get _isBuyer => _normalizedRole(widget.currentUserRole) == 'buyer';

  bool get _isFarmer => _normalizedRole(widget.currentUserRole) == 'farmer';

  bool get _isLogisticsProvider =>
      _normalizedRole(widget.currentUserRole) == 'logistics';

  String _normalizedRole(String? rawRole) {
    final normalized = (rawRole ?? '').trim().toLowerCase().replaceAll(
      RegExp(r'[\s-]+'),
      '_',
    );
    final baseRole = normalized.startsWith('role_')
        ? normalized.substring('role_'.length)
        : normalized;
    switch (baseRole) {
      case 'logistics_provider':
      case 'logisticsprovider':
      case 'logistics':
        return 'logistics';
      case 'buyer':
      case 'farmer':
        return baseRole;
      default:
        return baseRole;
    }
  }

  String _normalizedStatus(String rawStatus) {
    return rawStatus.trim().toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReviewable) {
      return const SizedBox.shrink();
    }

    final targets = _buildTargets();
    if (_loading) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.rate_review_outlined),
                const SizedBox(width: 8),
                const Text(
                  'Leave Review',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Reviews are available now that this order has been delivered.',
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            if (_errorMessage != null) ...[
              Container(
                width: double.infinity,
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
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _loadExistingReviews,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry loading review status'),
              ),
              const SizedBox(height: 8),
            ],
            if (targets.isEmpty)
              Text(
                'No review targets were found for this order.',
                style: TextStyle(color: Colors.grey[700]),
              )
            else
              ...targets.map(_buildTargetCard),
          ],
        ),
      ),
    );
  }

  Widget _buildTargetCard(_ReviewTarget target) {
    final alreadyReviewed = _reviewedRevieweeIds.contains(target.revieweeId);
    final pendingReview = _pendingReviewsByRevieweeId[target.revieweeId];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: alreadyReviewed ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () {
                    if (target.revieweeId > 0) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AccountPage(id: target.revieweeId),
                        ),
                      );
                    }
                  },
                  child: Text(
                    target.displayName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Color(primaryColour),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatRole(target.roleLabel),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          alreadyReviewed
              ? Chip(
                  label: const Text('Reviewed'),
                  backgroundColor: Colors.green.shade100,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                )
              : FilledButton(
                  onPressed: () => _openReviewForm(target, pendingReview),
                  child: Text(
                    pendingReview != null ? 'Complete Review' : 'Leave Review',
                  ),
                ),
        ],
      ),
    );
  }

  Future<void> _openReviewForm(
    _ReviewTarget target,
    Review? pendingReview,
  ) async {
    if (widget.currentUserId == null) return;

    final submitted = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        if (pendingReview != null) {
          return PendingReviewSheet(review: pendingReview);
        }
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: ReviewForm(
              reviewerId: widget.currentUserId!,
              revieweeId: target.revieweeId,
              revieweeName: target.displayName,
              revieweeRole: target.roleLabel,
              onSubmitted: (review) {
                if (!mounted) return;
                setState(() {
                  _reviewedRevieweeIds.add(review.revieweeId);
                });
                widget.onReviewCreated();
              },
            ),
          ),
        );
      },
    );
    if (submitted == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted successfully.')),
      );
    }
    if (submitted != true) {
      return;
    }
    await _loadExistingReviews();
    widget.onReviewCreated();
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

class _ReviewTarget {
  final int revieweeId;
  final String displayName;
  final String roleLabel;

  const _ReviewTarget({
    required this.revieweeId,
    required this.displayName,
    required this.roleLabel,
  });
}
