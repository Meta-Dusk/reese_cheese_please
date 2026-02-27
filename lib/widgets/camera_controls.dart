import 'dart:io';
import 'dart:math';
import 'package:camera/camera.dart';
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

class FlashButton extends StatelessWidget {
  final FlashMode mode;
  final VoidCallback onTap;

  const FlashButton({super.key, required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    IconData icon = mode == FlashMode.always
        ? Icons.flash_on
        : mode == FlashMode.auto
        ? Icons.flash_auto
        : Icons.flash_off;
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class SettingsButton extends StatelessWidget {
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  const SettingsButton({
    super.key,
    required this.onPressed,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: IconButton(onPressed: onPressed, icon: Icon(Icons.settings)),
    );
  }
}

class FlipCameraButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FlipCameraButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(Icons.flip_camera_android),
    );
  }
}

class TimerButton extends StatelessWidget {
  final int timerSeconds;
  final VoidCallback onTap;

  const TimerButton({
    super.key,
    required this.timerSeconds,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: switch (timerSeconds) {
        3 => const Icon(Icons.timer_3_select),
        10 => const Icon(Icons.timer_10_select),
        _ => const Icon(Icons.timer),
      },
    );
  }
}
