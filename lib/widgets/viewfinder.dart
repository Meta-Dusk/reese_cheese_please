import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraViewfinder extends StatelessWidget {
  final CameraController controller;
  final bool showGrid;
  final bool showLevel;
  final double tiltAngle;

  const CameraViewfinder({
    super.key,
    required this.controller,
    required this.showGrid,
    required this.showLevel,
    required this.tiltAngle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1, // Forces square
        child: ClipRect(
          child: Stack(
            children: [
              // 1. The Scaled Camera Feed
              LayoutBuilder(
                builder: (context, constraints) {
                  var aspectRatio = controller.value.aspectRatio;
                  var scale =
                      1 /
                      (aspectRatio *
                          constraints.maxWidth /
                          constraints.maxHeight);
                  if (scale < 1) scale = 1 / scale;

                  return Transform.scale(
                    scale: scale,
                    child: Center(child: CameraPreview(controller)),
                  );
                },
              ),
              // 2. Overlays
              if (showGrid) _buildGridLines(),
              if (showLevel) _buildLevelIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridLines() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                const Spacer(),
                Divider(color: Colors.white38, thickness: 1),
                const Spacer(),
                Divider(color: Colors.white38, thickness: 1),
                const Spacer(),
              ],
            ),
            Row(
              children: [
                const Spacer(),
                VerticalDivider(color: Colors.white38, thickness: 1),
                const Spacer(),
                VerticalDivider(color: Colors.white38, thickness: 1),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelIndicator() {
    bool isLevel = tiltAngle.abs() < 0.05;
    return IgnorePointer(
      child: Center(
        child: OverflowBox(
          maxWidth: double.infinity,
          child: Transform.rotate(
            angle: -tiltAngle,
            child: Container(
              width: 5000,
              height: 1.5,
              decoration: BoxDecoration(
                color: isLevel ? Colors.greenAccent : Colors.white54,
                boxShadow: [
                  if (isLevel)
                    const BoxShadow(
                      color: Colors.greenAccent,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
