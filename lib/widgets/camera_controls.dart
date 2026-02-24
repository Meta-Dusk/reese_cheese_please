import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';

class ShutterButton extends StatelessWidget {
  final VoidCallback onTap;
  const ShutterButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.circle, size: 85, color: Colors.white10),
          const Icon(Icons.circle, size: 70, color: Colors.white),
        ],
      ),
    );
  }
}

class GalleryButton extends StatelessWidget {
  final String? lastImagePath;
  final bool isFrontCamera;
  final VoidCallback onTap;
  final ColorFilter warmTint;

  const GalleryButton({
    super.key,
    required this.lastImagePath,
    required this.isFrontCamera,
    required this.onTap,
    required this.warmTint,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
          color: Colors.white10,
        ),
        child: ClipOval(
          child: lastImagePath != null
              ? Transform(
                  alignment: Alignment.center,
                  transform: isFrontCamera
                      ? Matrix4.rotationY(pi)
                      : Matrix4.identity(),
                  child: ColorFiltered(
                    colorFilter: warmTint,
                    child: Image.file(File(lastImagePath!), fit: BoxFit.cover),
                  ),
                )
              : const Icon(Icons.photo, color: Colors.white),
        ),
      ),
    );
  }
}
