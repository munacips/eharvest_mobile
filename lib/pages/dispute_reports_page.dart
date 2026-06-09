import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/dispute_report.dart';
import 'package:eharvest_mobile/services/dispute_report_service.dart';
import 'package:eharvest_mobile/pages/account_page.dart';

class DisputeReportsPage extends StatefulWidget {
  const DisputeReportsPage({super.key});

  @override
  State<DisputeReportsPage> createState() => _DisputeReportsPageState();
}

class _DisputeReportsPageState extends State<DisputeReportsPage> {
  List<DisputeReport> _reports = <DisputeReport>[];
  bool _loading = true;
  String? _errorMessage;
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final reports = await DisputeReportService.fetchMyReports();
      // Sort reports by createdAt descending (newest first)
      reports.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        _reports = reports;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('My Filed Reports'),
        backgroundColor: Color(primaryColour),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _loadReports,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        children: const [
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
              onPressed: _loadReports,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_reports.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 80),
          Icon(
            Icons.gavel_outlined,
            size: 56,
            color: Colors.green.shade300,
          ),
          const SizedBox(height: 16),
          const Text(
            'You have not filed any reports.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Complaints and disputes you file against other users will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _buildReportCard(_reports[index]),
    );
  }

  Widget _buildReportCard(DisputeReport report) {
    final reportedName = report.filedAgainstUsername.isNotEmpty == true
        ? report.filedAgainstUsername
        : 'User #${report.filedAgainstId}';

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Report #${report.id}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                _statusBadge(report.attendedTo),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text(
                  'Reported User: ',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                GestureDetector(
                  onTap: report.filedAgainstId > 0
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AccountPage(id: report.filedAgainstId),
                            ),
                          );
                        }
                      : null,
                  child: Text(
                    reportedName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(primaryColour),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Reason / Description:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 4),
            Text(
              report.description,
              style: const TextStyle(fontSize: 14, height: 1.3),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  _dateFormat.format(report.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(bool resolved) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: resolved ? Colors.green.shade50 : Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: resolved ? Colors.green.shade200 : Colors.amber.shade300,
        ),
      ),
      child: Text(
        resolved ? 'RESOLVED' : 'PENDING',
        style: TextStyle(
          color: resolved ? Colors.green.shade800 : Colors.amber.shade800,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}
