import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:reese_gift/display_picture_screen.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:sensors_plus/sensors_plus.dart';

Future<void> main() async {
  // Ensure plugin services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Get the list of available cameras
  final cameras = await availableCameras();

  // Select the first camera (usually the back one)
  final firstCamera = cameras.first;

  runApp(
    MaterialApp(
      theme: ThemeData.dark(),
      home: PolaroidCamera(camera: firstCamera),
    ),
  );
}

class PolaroidCamera extends StatefulWidget {
  final CameraDescription camera;

  const PolaroidCamera({super.key, required this.camera});

  @override
  State<PolaroidCamera> createState() => _PolaroidCameraState();
}

// TODO: Don't forget to add easter eggs
class _PolaroidCameraState extends State<PolaroidCamera> {
  late CameraController _controller;
  Future<void>? _initializeControllerFuture;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  FlashMode _currentFlashMode = FlashMode.off;
  String? _lastImagePath;
  bool _isCapturing = false;
  int _timerSeconds = 0;
  int _currentCount = 0;
  bool _isCountingDown = false;
  bool _showGrid = false;
  double _tiltAngle = 0.0;
  StreamSubscription? _accelerometerSubcription;
  bool _showLevel = false;
  bool _isImageSaved = false;

  @override
  void initState() {
    super.initState();
    _setupCamera();
    _setupAccelerometer();
  }

  void _setupAccelerometer() {
    _accelerometerSubcription = accelerometerEventStream().listen(
      (AccelerometerEvent event) {
        double newAngle = atan2(event.x, event.y);
        if (mounted) {
          setState(() {
            _tiltAngle = (_tiltAngle * 0.9) + (newAngle * 0.1);
          });
        }
      },
      onError: (error) {
        debugPrint("Sensor Error: $error");
      },
    );
  }

  Future<void> _setupCamera() async {
    _cameras = await availableCameras();
    if (_cameras.isNotEmpty) {
      _initCamera(_cameras[_selectedCameraIndex]);
    }
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller = CameraController(camera, ResolutionPreset.medium);
    _initializeControllerFuture = _controller.initialize();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _accelerometerSubcription?.cancel();
    super.dispose();
  }

  void _toggleCamera() {
    if (_cameras.length < 2) return;
    _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;
    _initCamera(_cameras[_selectedCameraIndex]);
  }

  void _toggleFlash() async {
    FlashMode newMode = _currentFlashMode == FlashMode.off
        ? FlashMode.always
        : _currentFlashMode == FlashMode.always
        ? FlashMode.auto
        : FlashMode.off;

    await _controller.setFlashMode(newMode);
    setState(() => _currentFlashMode = newMode);
  }

  bool isCurrentCamFront() {
    var currentCam = _cameras[_selectedCameraIndex];
    return currentCam.lensDirection == CameraLensDirection.front;
  }

  void onSaveSuccess() {
    setState(() {
      _isImageSaved = true;
    });
  }

  void _openGallery() async {
    if (_lastImagePath == null) return;

    if (_isImageSaved) {
      // Open gallery
      try {
        await Gal.open();
      } catch (e) {
        debugPrint("Could not open gallery: $e");
      }
    } else {
      // Show preview
      try {
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => DisplayPictureScreen(
              imagePath: _lastImagePath!,
              isFrontCamera: isCurrentCamFront(),
              onSaveSuccess: onSaveSuccess,
            ),
          ),
        );
      } catch (e) {
        debugPrint("Could not open preview: $e");
      }
    }
  }

  void _takePicture() async {
    setState(() => _isCapturing = true);
    HapticFeedback.mediumImpact();

    if (_initializeControllerFuture == null ||
        !_controller.value.isInitialized) {
      return;
    }

    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();

      setState(() => _isCapturing = false);
      setState(() => _lastImagePath = image.path);

      if (!mounted) return;

      HapticFeedback.mediumImpact();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DisplayPictureScreen(
            imagePath: image.path,
            isFrontCamera: isCurrentCamFront(),
            onSaveSuccess: onSaveSuccess,
          ),
        ),
      );
    } catch (e) {
      setState(() => _isCapturing = false);
      // print(e);
    }
  }

  void _startTimerAndCapture() async {
    if (_timerSeconds == 0) {
      _takePicture();
      return;
    }

    setState(() {
      _isCountingDown = true;
      _currentCount = _timerSeconds;
    });

    // Countdown
    for (int i = _timerSeconds; i > 0; i--) {
      setState(() => _currentCount = i);
      await Future.delayed(const Duration(seconds: 1));
    }

    setState(() => _isCountingDown = false);
    _takePicture();
  }

  void _showSettings() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Camera Settings",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.grid_on),
                    title: const Text("Show Grid Lines"),
                    trailing: Switch(
                      value: _showGrid,
                      onChanged: (value) {
                        setState(() => _showGrid = value);
                        setModalState(() => _showGrid = value);
                      },
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.horizontal_distribute),
                    title: const Text("Show Level Indicator"),
                    trailing: Switch(
                      value: _showLevel,
                      onChanged: (value) {
                        setState(() => _showLevel = value);
                        setModalState(() => _showLevel = value);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // * --- UI HELPER METHODS ---
  Widget _buildLevelIndicator() {
    bool isLevel = _tiltAngle.abs() < 0.1;
    // debugPrint("isLevel: $isLevel, _tiltAngle: $_tiltAngle");

    return IgnorePointer(
      child: Center(
        child: Transform.rotate(
          angle: -_tiltAngle,
          child: Container(
            width: 240,
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
                Divider(color: Colors.white38, height: 1, thickness: 1),
                const Spacer(),
                Divider(color: Colors.white38, height: 1, thickness: 1),
                const Spacer(),
              ],
            ),
            Row(
              children: [
                const Spacer(),
                VerticalDivider(color: Colors.white38, width: 1, thickness: 1),
                const Spacer(),
                VerticalDivider(color: Colors.white38, width: 1, thickness: 1),
                const Spacer(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewfinder() {
    // If the future hasn't been created yet, show a loader
    if (_initializeControllerFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    var scaledCameraFeed = LayoutBuilder(
      builder: (context, constraints) {
        var aspectRatio = _controller.value.aspectRatio;
        var cMaxWidth = constraints.maxWidth;
        var cMaxHeight = constraints.maxHeight;
        var scale = 1 / (aspectRatio * cMaxWidth / cMaxHeight);
        if (scale < 1) scale = 1 / scale;

        return Transform.scale(
          scale: scale,
          child: Center(child: CameraPreview(_controller)),
        );
      },
    );

    var mainWidget = Center(
      child: AspectRatio(
        aspectRatio: 1, // Forces square
        child: ClipRect(
          child: Stack(
            children: [
              scaledCameraFeed,
              if (_showGrid) _buildGridLines(),
              if (_showLevel) _buildLevelIndicator(),
            ],
          ),
        ),
      ),
    );

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          return mainWidget;
        }
        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildGalleryButton() {
    var galleryIcon = ClipOval(
      child: _lastImagePath != null
          ? Transform(
              alignment: Alignment.center,
              // Flip the preview if it was a front camera shot
              transform: isCurrentCamFront()
                  ? Matrix4.rotationY(pi)
                  : Matrix4.identity(),
              child: ColorFiltered(
                colorFilter: warmTint(),
                child: Image.file(File(_lastImagePath!), fit: BoxFit.cover),
              ),
            )
          : const Icon(Icons.photo, color: Colors.white),
    );

    return GestureDetector(
      onTap: _openGallery,
      // TODO: Wrap container in hero
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white24, width: 2),
          color: Colors.white10,
        ),
        child: galleryIcon,
      ),
    );
  }

  Widget _buildShutterButton() {
    return GestureDetector(
      onTap: _startTimerAndCapture,
      child: Stack(
        alignment: Alignment.center,
        children: [
          const Icon(Icons.circle, size: 85, color: Colors.white10),
          const Icon(Icons.circle, size: 70, color: Colors.white),
        ],
      ),
    );
  }

  Widget _buildFlashButton() {
    IconData icon = _currentFlashMode == FlashMode.always
        ? Icons.flash_on
        : _currentFlashMode == FlashMode.auto
        ? Icons.flash_auto
        : Icons.flash_off;
    return IconButton(
      onPressed: _toggleFlash,
      icon: Icon(icon, color: Colors.white),
    );
  }

  Widget _buildTimerButton() {
    return IconButton(
      onPressed: () {
        setState(() {
          if (_timerSeconds == 0) {
            _timerSeconds = 3;
          } else if (_timerSeconds == 3) {
            _timerSeconds = 10;
          } else {
            _timerSeconds = 0;
          }
        });
      },
      icon: switch (_timerSeconds) {
        3 => const Icon(Icons.timer_3_select),
        10 => const Icon(Icons.timer_10_select),
        _ => const Icon(Icons.timer),
      },
    );
  }

  Widget _buildSettingsButton() {
    return IconButton(onPressed: _showSettings, icon: Icon(Icons.settings));
  }

  Widget _buildFlipCameraButton() {
    // ? Maybe try adding a flip animation
    return IconButton(
      onPressed: _toggleCamera,
      icon: const Icon(Icons.flip_camera_android),
    );
  }

  // * --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    var portraitLayout = Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildFlashButton(),
            _buildTimerButton(),
            _buildSettingsButton(),
          ],
        ),
        const Spacer(),
        _buildViewfinder(),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildGalleryButton(),
            _buildShutterButton(),
            _buildFlipCameraButton(),
          ],
        ),
        const SizedBox(height: 40),
      ],
    );

    var landscapeLayout = Row(
      children: [
        Expanded(child: _buildViewfinder()),
        Container(
          width: 120,
          color: Colors.black,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildFlashButton(),
              _buildShutterButton(),
              _buildFlipCameraButton(),
            ],
          ),
        ),
      ],
    );

    var orientationBuilder = OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.portrait) {
          return portraitLayout;
        } else {
          return landscapeLayout;
        }
      },
    );

    var mainStack = Stack(
      children: [
        orientationBuilder,

        // Shutter Flash Overlay
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: _isCapturing ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeIn,
            child: Container(color: Color(0xFFFFF9E5)),
          ),
        ),

        if (_isCountingDown)
          Center(
            child: Text(
              "$_currentCount",
              style: const TextStyle(
                fontSize: 120,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
              ),
            ),
          ),
      ],
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(child: mainStack),
    );
  }
}
