// view_pdf_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_file/open_file.dart';

class ViewPdfScreen extends StatelessWidget {
  final File? file;
  final String? fileUrl;

  const ViewPdfScreen({Key? key, this.file, this.fileUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PDF Report")),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (file != null && file!.existsSync()) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text("Open Local Report"),
          onPressed: () => OpenFile.open(file!.path),
        ),
      );
    }

    if (fileUrl != null && fileUrl!.isNotEmpty) {
      return Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.open_in_browser),
          label: const Text("Open Online Report"),
          onPressed: () async {
            final uri = Uri.tryParse(fileUrl!);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Unable to open the report URL")),
              );
            }
          },
        ),
      );
    }

    return const Center(child: Text("No report available"));
  }
}
