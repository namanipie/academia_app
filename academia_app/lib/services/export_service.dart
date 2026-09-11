import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class ExportService {
  static Future<void> exportAndShare(GlobalKey boundaryKey, BuildContext context) async {
    try {
      final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      
      if (boundary == null) {
        throw Exception("Couldn't find timetable to capture");
      }

      // Convert boundary to image
      final image = await boundary.toImage(pixelRatio: 2.0); // High res
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) {
        throw Exception("Couldn't encode image bytes");
      }

      final buffer = byteData.buffer.asUint8List();

      // Save to temp directory for sharing
      final tempDir = await getTemporaryDirectory();
      final file = await File('${tempDir.path}/Academia_Timetable.png').create();
      await file.writeAsBytes(buffer);

      // Share using share_plus
      final xFile = XFile(file.path, mimeType: 'image/png');
      
      if (context.mounted) {
        final box = context.findRenderObject() as RenderBox?;
        // ignore: deprecated_member_use
        await Share.shareXFiles(
          [xFile],
          text: 'My Academia Timetable',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Couldn\'t create timetable image.', style: TextStyle(color: Colors.white))),
        );
      }
    }
  }
}
