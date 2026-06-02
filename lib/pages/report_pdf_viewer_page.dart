import 'dart:js_interop';
import 'dart:typed_data';

import 'package:eharvest_mobile/global_variables.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

// Web-only imports — tree-shaken away on native platforms
import 'dart:ui_web' as ui_web
    if (dart.library.io) 'package:eharvest_mobile/stubs/ui_web_stub.dart';
import 'package:web/web.dart' as web
    if (dart.library.io) 'package:eharvest_mobile/stubs/web_stub.dart';

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
  String? _blobUrl;
  String? _viewType;

  @override
  void initState() {
    super.initState();
    _currentPdfBytes = widget.pdfBytes;
    _initWebViewer();

    print('PDF bytes length: ${_currentPdfBytes.length}');
    if (_currentPdfBytes.isNotEmpty) {
      final headerLength =
          _currentPdfBytes.length >= 8 ? 8 : _currentPdfBytes.length;
      final headerBytes = _currentPdfBytes.sublist(0, headerLength);
      final headerText = String.fromCharCodes(headerBytes);
      print('PDF header bytes: $headerBytes');
      print('PDF header text: $headerText');
    } else {
      print('PDF header bytes: []');
    }
  }

  void _initWebViewer() {
    if (!kIsWeb) return;

    // Revoke previous blob URL to avoid memory leaks
    if (_blobUrl != null) {
      web.URL.revokeObjectURL(_blobUrl!);
    }

    final blob = web.Blob(
      [_currentPdfBytes.toJS].toJS,
      web.BlobPropertyBag(type: 'application/pdf'),
    );
    _blobUrl = web.URL.createObjectURL(blob);
    _viewType = 'pdf-iframe-${_blobUrl.hashCode}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType!, (int viewId) {
      final iframe = web.HTMLIFrameElement()
        ..src = _blobUrl!
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.border = 'none';
      return iframe;
    });
  }

  @override
  void dispose() {
    if (kIsWeb && _blobUrl != null) {
      web.URL.revokeObjectURL(_blobUrl!);
    }
    super.dispose();
  }

  Future<void> _retry() async {
    if (widget.onRetry == null) return;

    setState(() => _isRetrying = true);
    try {
      final bytes = await widget.onRetry!.call();
      if (!mounted) return;
      setState(() {
        _currentPdfBytes = bytes;
        _initWebViewer();
      });
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

  Widget _buildPdfViewer() {
    if (kIsWeb) {
      if (_blobUrl == null || _viewType == null) {
        return const Center(child: Text('Failed to load PDF'));
      }
      // Uses the browser's native PDF renderer via an iframe —
      // far more reliable on Flutter Web than SfPdfViewer.memory()
      return HtmlElementView(viewType: _viewType!);
    }

    // Native (Android / iOS) — unchanged
    return SfPdfViewer.memory(
      _currentPdfBytes,
      canShowScrollHead: true,
      canShowScrollStatus: true,
    );
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
      body: _buildPdfViewer(),
    );
  }
}