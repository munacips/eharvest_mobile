import 'dart:typed_data';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/report_descriptor.dart';
import 'package:eharvest_mobile/pages/report_pdf_viewer_page.dart';
import 'package:eharvest_mobile/services/auth_service.dart';
import 'package:eharvest_mobile/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReportRequestPage extends StatefulWidget {
  final ReportDescriptor report;

  const ReportRequestPage({super.key, required this.report});

  @override
  State<ReportRequestPage> createState() => _ReportRequestPageState();
}

class _ReportRequestPageState extends State<ReportRequestPage> {
  static const Set<String> _currentUserIdParamNames = <String>{
    'userid',
    'farmerid',
    'sellerid',
    'buyerid',
    'providerid',
    'logisticsproviderid',
    'driverid',
  };

  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  bool _isGenerating = false;
  bool _isLoadingSession = true;
  String? _errorMessage;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    for (final param in widget.report.params) {
      _controllers[param] = TextEditingController();
    }
    _loadSession();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSession() async {
    try {
      final userId = await AuthService.getUserId();
      if (!mounted) return;

      setState(() {
        _currentUserId = userId;
        _isLoadingSession = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserId = null;
        _isLoadingSession = false;
        _errorMessage = 'Unable to load your session. Please log in again.';
      });
    }
  }

  Future<void> _pickDate(String param) async {
    final minDate = DateTime(2020);
    final maxDate = DateTime(2100);
    final parsedDate = DateTime.tryParse(_controllers[param]?.text ?? '');
    var initialDate = parsedDate ?? DateTime.now();
    if (initialDate.isBefore(minDate)) {
      initialDate = minDate;
    } else if (initialDate.isAfter(maxDate)) {
      initialDate = maxDate;
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: minDate,
      lastDate: maxDate,
    );
    if (picked == null) return;

    setState(() {
      _controllers[param]?.text = _dateFormat.format(picked);
    });
  }

  Future<void> _generateReport() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    final queryParams = <String, String>{};
    for (final param in widget.report.params) {
      if (_isAutoIdParam(param)) {
        final currentUserId = _currentUserId;
        if (currentUserId == null) {
          const message = 'Authentication error. Please log in again.';
          setState(() {
            _isGenerating = false;
            _errorMessage = message;
          });
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text(message)));
          return;
        }
        queryParams[param] = currentUserId.toString();
        continue;
      }

      final value = _controllers[param]?.text.trim();
      if (value != null && value.isNotEmpty) {
        queryParams[param] = value;
      }
    }

    try {
      final pdfBytes = await ReportService.generateReport(
        reportName: widget.report.reportName,
        queryParams: queryParams,
      );
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ReportPdfViewerPage(
            title: widget.report.label,
            pdfBytes: pdfBytes,
            onRetry: () => _regenerateReport(queryParams),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() => _errorMessage = message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  Future<Uint8List> _regenerateReport(Map<String, String> queryParams) {
    return ReportService.generateReport(
      reportName: widget.report.reportName,
      queryParams: queryParams,
    );
  }

  String _canonicalParamName(String param) {
    return param.trim().replaceAll(RegExp(r'[_\-\s]+'), '').toLowerCase();
  }

  bool _isAutoIdParam(String param) {
    return _currentUserIdParamNames.contains(_canonicalParamName(param));
  }

  bool _isKnownNumericIdParam(String param) {
    return _isAutoIdParam(param);
  }

  List<String> get _visibleParams {
    return widget.report.params
        .where((param) => !_isAutoIdParam(param))
        .toList();
  }

  bool get _hasAutoCurrentUserParams {
    return widget.report.params.any(_isAutoIdParam);
  }

  String _labelForParam(String param) {
    switch (param) {
      case 'from':
        return 'From date';
      case 'to':
        return 'To date';
      case 'region':
        return 'Region';
      case 'status':
        return 'Status';
      case 'farmerId':
        return 'Farmer ID';
      case 'sellerId':
        return 'Seller ID';
      case 'buyerId':
        return 'Buyer ID';
      case 'warehouseId':
        return 'Warehouse ID';
      case 'providerId':
        return 'Provider ID';
      case 'logisticsProviderId':
        return 'Logistics provider ID';
      case 'driverId':
        return 'Driver ID';
      default:
        final spaced = param
            .replaceAll(RegExp(r'[_\-]+'), ' ')
            .replaceAllMapped(
              RegExp(r'([a-z0-9])([A-Z])'),
              (match) => '${match.group(1)} ${match.group(2)}',
            )
            .trim();
        if (spaced.isEmpty) return param;
        return spaced
            .split(RegExp(r'\s+'))
            .map(
              (word) => word.isEmpty
                  ? word
                  : '${word[0].toUpperCase()}${word.substring(1)}',
            )
            .join(' ');
    }
  }

  TextInputType _keyboardTypeForParam(String param) {
    return _isKnownNumericIdParam(param)
        ? TextInputType.number
        : TextInputType.text;
  }

  Widget _buildParamField(String param) {
    if (param == 'from' || param == 'to') {
      return TextFormField(
        controller: _controllers[param],
        readOnly: true,
        onTap: () => _pickDate(param),
        decoration: InputDecoration(
          labelText: _labelForParam(param),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return TextFormField(
      controller: _controllers[param],
      keyboardType: _keyboardTypeForParam(param),
      decoration: InputDecoration(
        labelText: _labelForParam(param),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleParams = _visibleParams;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.report.label),
        backgroundColor: Color(primaryColour),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.report.label,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(widget.report.description),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoadingSession)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 12),
                      Text('Preparing report options...'),
                    ],
                  ),
                ),
              )
            else if (widget.report.params.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('This report does not require any parameters.'),
                ),
              )
            else if (visibleParams.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Your account details will be applied automatically.',
                  ),
                ),
              )
            else
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: visibleParams
                        .map(
                          (param) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _buildParamField(param),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
            if (!_isLoadingSession &&
                _hasAutoCurrentUserParams &&
                visibleParams.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.person_outline),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your account ID will be included automatically.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isGenerating || _isLoadingSession
                    ? null
                    : _generateReport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(primaryColour),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                icon: _isGenerating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.picture_as_pdf_outlined),
                label: Text(_isGenerating ? 'Generating...' : 'Generate'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
