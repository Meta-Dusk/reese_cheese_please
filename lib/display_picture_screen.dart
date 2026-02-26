import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sensors_plus/sensors_plus.dart';

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
  bool _isExporting = false;
  StreamSubscription? _shakeSubscription;

  @override
  void initState() {
    super.initState();
    _startDevelopment();
    _initShakeDetection();
  }

  @override
  void dispose() {
    _shakeSubscription?.cancel();
    _labelController.dispose();
    super.dispose();
  }

  void _startDevelopment() {
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || _opacity >= 1.0) {
        timer.cancel();
        return;
      }
      setState(() {
        _opacity = (_opacity + 0.025).clamp(0.0, 1.0);
      });
    });
  }

  void _initShakeDetection() {
    // We use userAccelerometer to ignore gravity and only catch physical shakes
    _shakeSubscription = userAccelerometerEventStream().listen((
      UserAccelerometerEvent event,
    ) {
      // Calculate total movement magnitude
      double acceleration = sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );

      // THRESHOLD: 12-15 is a firm wiggle. 20+ is a violent shake.
      if (acceleration > 15 && _opacity < 1.0) {
        setState(() {
          _opacity = (_opacity + 0.10).clamp(0.0, 1.0);
        });
        HapticFeedback.lightImpact();
      }
      // debugPrint("Opacity: $_opacity");
      // debugPrint("acceleration: $acceleration, event: ${event.toString()}");
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
      debugPrint("Error capturing image: $e");
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
    Widget imageNote = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: TextField(
        controller: _labelController,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: 'PermanentMarker',
          fontSize: 18,
          color: Colors.black87.withValues(alpha: _opacity),
        ),
        decoration: InputDecoration(
          hintText: _isExporting ? null : "Add a note...",
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

    Widget dynamicImage = AnimatedOpacity(
      opacity: _opacity,
      duration: const Duration(milliseconds: 100),
      curve: Curves.linear,
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

    Widget imageComposite = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // The "Developing" Image
        dynamicImage,
        const SizedBox(height: 20),
        // A space for a handwritten-style date or note
        imageNote,
      ],
    );

    Widget polaroidFrame = RepaintBoundary(
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

    Widget actionButtons = Row(
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
            setState(() => _isExporting = true);

            FocusScope.of(context).unfocus();
            await Future.delayed(const Duration(milliseconds: 100));

            setState(() => _isExporting = false);

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

    Widget column = Column(
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
