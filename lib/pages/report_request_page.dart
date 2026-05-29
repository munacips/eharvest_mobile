import 'dart:typed_data';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:eharvest_mobile/models/report_descriptor.dart';
import 'package:eharvest_mobile/pages/report_pdf_viewer_page.dart';
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
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    for (final param in widget.report.params) {
      _controllers[param] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate(String param) async {
    final initialDate =
        DateTime.tryParse(_controllers[param]?.text ?? '') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
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
    for (final entry in _controllers.entries) {
      final value = entry.value.text.trim();
      if (value.isNotEmpty) {
        queryParams[entry.key] = value;
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
      case 'warehouseId':
        return 'Warehouse ID';
      default:
        return param.replaceAllMapped(
          RegExp(r'(^|_)([a-z])'),
          (match) => '${match.group(1) == '_' ? ' ' : ''}${match.group(2)!.toUpperCase()}',
        );
    }
  }

  TextInputType _keyboardTypeForParam(String param) {
    switch (param) {
      case 'farmerId':
      case 'sellerId':
      case 'warehouseId':
        return TextInputType.number;
      default:
        return TextInputType.text;
    }
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
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }

    return TextFormField(
      controller: _controllers[param],
      keyboardType: _keyboardTypeForParam(param),
      decoration: InputDecoration(
        labelText: _labelForParam(param),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            if (widget.report.params.isEmpty)
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'This report does not require any parameters.',
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
                    children: widget.report.params
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
                onPressed: _isGenerating ? null : _generateReport,
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
