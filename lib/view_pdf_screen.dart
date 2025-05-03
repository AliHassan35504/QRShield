import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:open_file/open_file.dart';

class ViewPdfScreen extends StatefulWidget {
  final File file;

  const ViewPdfScreen({Key? key, required this.file}) : super(key: key);

  @override
  State<ViewPdfScreen> createState() => _ViewPdfScreenState();
}

class _ViewPdfScreenState extends State<ViewPdfScreen> {
  late final PdfControllerPinch _pdfController;

  @override
  void initState() {
    super.initState();
    _pdfController = PdfControllerPinch(document: PdfDocument.openFile(widget.file.path));
  }

  @override
  void dispose() {
    _pdfController.dispose();
    super.dispose();
  }

  void _openExternally() async {
    final result = await OpenFile.open(widget.file.path);
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open PDF externally.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Threat Report'),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: _openExternally,
            tooltip: 'Open externally',
          ),
        ],
      ),
      body: PdfViewPinch(controller: _pdfController),
    );
  }
}
