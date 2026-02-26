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
    Widget scaledCameraFeed = LayoutBuilder(
      builder: (context, constraints) {
        double aspectRatio = controller.value.aspectRatio;
        double cMaxWidth = constraints.maxWidth;
        double cMaxHeight = constraints.maxHeight;
        double scale = 1 / (aspectRatio * cMaxWidth / cMaxHeight);
        if (scale < 1) scale = 1 / scale;

        return Transform.scale(
          scale: scale,
          child: Center(child: CameraPreview(controller)),
        );
      },
    );

    return Center(
      child: AspectRatio(
        aspectRatio: 1, // Forces square
        child: ClipRect(
          child: Stack(
            children: [
              scaledCameraFeed,
              // Overlays
              if (showGrid) _buildGridLines(),
              if (showLevel) _buildLevelIndicator(),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildSimpleGrid() {
    Widget widget = Divider(color: Colors.white38, thickness: 1);
    return [const Spacer(), widget, const Spacer(), widget, const Spacer()];
  }

  Widget _buildGridLines() {
    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.white12, width: 1),
        ),
        child: Stack(
          children: [
            Column(children: _buildSimpleGrid()),
            Row(children: _buildSimpleGrid()),
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
