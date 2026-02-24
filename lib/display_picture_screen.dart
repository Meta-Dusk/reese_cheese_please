import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

class DisplayPictureScreen extends StatefulWidget {
  final String imagePath;
  final bool isFrontCamera;
  final VoidCallback onSaveSuccess;

  const DisplayPictureScreen({
    super.key,
    required this.imagePath,
    required this.isFrontCamera,
    required this.onSaveSuccess,
  });

  @override
  State<DisplayPictureScreen> createState() => _DisplayPictureScreenState();
}

ColorFilter warmTint() {
  return const ColorFilter.matrix([
    1.1, 0.1, 0.1, 0, 10, // Slightly warm tint
    0.1, 1.0, 0.1, 0, 5,
    0.1, 0.1, 0.9, 0, -5,
    0, 0, 0, 1, 0,
  ]);
}

class _DisplayPictureScreenState extends State<DisplayPictureScreen> {
  double _opacity = 0.0;
  final TextEditingController _labelController = TextEditingController();
  final GlobalKey _boundaryKey = GlobalKey();

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    // Start the "development" fade-in after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() => _opacity = 1.0);
      }
    });
  }

  Future<Uint8List?> _capturePng() async {
    try {
      RenderRepaintBoundary boundary =
          _boundaryKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;

      // Use a high pixel ratio (3.0) so the saved photo isn't blurry
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );
      return byteData?.buffer.asUint8List();
    } catch (e) {
      // print(e);
      return null;
    }
  }

  String _generateFileName(Directory directory) {
    final DateTime now = DateTime.now();
    // Format: 2026-02-24_17-30-45 (Year-Month-Day_Hour-Minute-Second)
    final String formatter = DateFormat('yyyy-MM-dd_HH-mm-ss').format(now);
    return '${directory.path}/polaroid_$formatter.png';
  }

  @override
  Widget build(BuildContext context) {
    var imageNote = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: _labelController,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: 'PermanentMarker',
          fontSize: 18,
          color: Colors.black87,
        ),
        decoration: const InputDecoration(
          hintText: "Add a note...",
          hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
        ),
        maxLength: 30,
        buildCounter:
            (
              context, {
              required currentLength,
              required isFocused,
              required maxLength,
            }) => null,
      ),
    );

    var dynamicImage = AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(seconds: 4), // Classic slow reveal
      curve: Curves.easeIn,
      child: Transform(
        alignment: Alignment.center,
        // Apply horizontal flip if it was a front camera shot
        transform: widget.isFrontCamera
            ? Matrix4.rotationY(pi)
            : Matrix4.identity(),
        child: ColorFiltered(
          colorFilter: warmTint(),
          child: Image.file(
            File(widget.imagePath),
            width: 300,
            height: 300,
            fit: BoxFit.cover,
          ),
        ),
      ),
    );

    var imageComposite = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The "Developing" Image
        dynamicImage,
        const SizedBox(height: 20),
        // A space for a handwritten-style date or note
        imageNote,
      ],
    );

    var polaroidFrame = RepaintBoundary(
      key: _boundaryKey,
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          50,
        ), // Thick bottom handle
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(2),
          boxShadow: const [
            BoxShadow(
              color: Colors.black45,
              blurRadius: 20,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: imageComposite,
      ),
    );

    var actionButtons = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: () {
            if (context.mounted) Navigator.pop(context);
          },
          icon: const Icon(Icons.refresh),
          label: const Text("Retake"),
        ),
        const SizedBox(width: 20),
        ElevatedButton.icon(
          onPressed: () async {
            final bytes = await _capturePng();
            if (bytes == null) return;

            // Create a temporary file to save the bytes
            final directory = await getTemporaryDirectory();
            final imagePath = _generateFileName(directory);
            final file = File(imagePath);
            await file.writeAsBytes(bytes);

            // Save to gallery
            try {
              await Gal.putImage(imagePath);
              widget.onSaveSuccess();

              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Saved to Gallery! 📸"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } catch (e) {
              debugPrint("Failed to save photo: $e");
            }
          },
          icon: const Icon(Icons.download),
          label: const Text("Save"),
        ),
      ],
    );

    var column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The Physical Polaroid Frame
        polaroidFrame,
        const SizedBox(height: 40),
        // Action Buttons
        actionButtons,
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFF1A1A1A), // Deep dark background
      appBar: AppBar(
        title: const Text(
          'Developing...',
          style: TextStyle(fontFamily: 'monospace'),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(child: column),
    );
  }
}
