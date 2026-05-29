import 'dart:typed_data';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ReportPdfViewerPage extends StatefulWidget {
  final String title;
  final Uint8List pdfBytes;
  final Future<Uint8List> Function()? onRetry;

  const ReportPdfViewerPage({
    super.key,
    required this.title,
    required this.pdfBytes,
    this.onRetry,
  });

  @override
  State<ReportPdfViewerPage> createState() => _ReportPdfViewerPageState();
}

class _ReportPdfViewerPageState extends State<ReportPdfViewerPage> {
  late Uint8List _currentPdfBytes;
  bool _isRetrying = false;

  @override
  void initState() {
    super.initState();
    _currentPdfBytes = widget.pdfBytes;
    print('PDF bytes length: ${_currentPdfBytes.length}');
    if (_currentPdfBytes.isNotEmpty) {
      final headerLength = _currentPdfBytes.length >= 8
          ? 8
          : _currentPdfBytes.length;
      final headerBytes = _currentPdfBytes.sublist(0, headerLength);
      final headerText = String.fromCharCodes(headerBytes);
      print('PDF header bytes: $headerBytes');
      print('PDF header text: $headerText');
    } else {
      print('PDF header bytes: []');
    }
  }

  Future<void> _retry() async {
    if (widget.onRetry == null) return;

    setState(() => _isRetrying = true);
    try {
      final bytes = await widget.onRetry!.call();
      if (!mounted) return;
      setState(() => _currentPdfBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) {
        setState(() => _isRetrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Color(primaryColour),
        foregroundColor: Colors.white,
        actions: [
          if (widget.onRetry != null)
            IconButton(
              onPressed: _isRetrying ? null : _retry,
              icon: _isRetrying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.refresh),
              tooltip: 'Regenerate',
            ),
        ],
      ),
      body: SfPdfViewer.memory(
        _currentPdfBytes,
        canShowScrollHead: true,
        canShowScrollStatus: true,
      ),
    );
  }
}
