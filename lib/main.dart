import 'dart:async';
import 'dart:math';

import 'package:reese_gift/display_picture_screen.dart';
import 'widgets/viewfinder.dart';
import 'widgets/camera_controls.dart';

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
  final firstCamera = cameras.isNotEmpty ? cameras.first : null;

  runApp(
    MaterialApp(
      title: "ReeseCheesePlease",
      theme: ThemeData.dark(),
      home: PolaroidCamera(camera: firstCamera),
    ),
  );
}

class PolaroidCamera extends StatefulWidget {
  final CameraDescription? camera;

  const PolaroidCamera({super.key, this.camera});

  @override
  State<PolaroidCamera> createState() => _PolaroidCameraState();
}

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
    } else {
      debugPrint("No cameras found on this device.");
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
    if (_cameras.isEmpty) return false;
    var currentCam = _cameras[_selectedCameraIndex];
    return currentCam.lensDirection == CameraLensDirection.front;
  }

  void onSaveSuccess() {
    setState(() {
      _isImageSaved = true;
    });
  }

  void _openGallery() async {
    if (_isImageSaved || _lastImagePath == null) {
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

      setState(() {
        _isCapturing = false;
        _lastImagePath = image.path;
        _isImageSaved = false;
      });

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
      debugPrint("Error taking picture: $e");
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
  Widget _buildOverlays() {
    return IgnorePointer(
      child: Stack(
        children: [
          // Shutter Flash Effect
          AnimatedOpacity(
            opacity: _isCapturing ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 100),
            child: Container(color: Colors.white),
          ),

          // Timer Countdown Text
          if (_isCountingDown)
            Center(
              child: Text(
                '$_currentCount',
                style: const TextStyle(
                  fontSize: 120,
                  fontWeight: FontWeight.bold,
                  color: Colors.white70,
                  shadows: [
                    Shadow(
                      blurRadius: 10,
                      color: Colors.black54,
                      offset: Offset(2, 2),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        FlashButton(mode: _currentFlashMode, onTap: _toggleFlash),
        TimerButton(
          timerSeconds: _timerSeconds,
          onTap: () => setState(() {
            _timerSeconds = (_timerSeconds == 0)
                ? 3
                : (_timerSeconds == 3 ? 10 : 0);
          }),
        ),
        SettingsButton(onPressed: _showSettings),
      ],
    );
  }

  Widget _buildBottomBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        GalleryButton(
          lastImagePath: _lastImagePath,
          isFrontCamera: isCurrentCamFront(),
          onTap: _openGallery,
          warmTint: warmTint(),
        ),
        ShutterButton(onTap: _startTimerAndCapture),
        FlipCameraButton(onPressed: _toggleCamera),
      ],
    );
  }

  Widget _buildSideBar() {
    return Container(
      width: 120,
      color: Colors.black,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FlashButton(mode: _currentFlashMode, onTap: _toggleFlash),
          ShutterButton(onTap: _startTimerAndCapture),
          FlipCameraButton(onPressed: _toggleCamera),
        ],
      ),
    );
  }

  // * --- MAIN BUILD METHOD ---
  @override
  Widget build(BuildContext context) {
    Widget viewfinderWidget = FutureBuilder(
      future: _initializeControllerFuture,
      builder: (context, asyncSnapshot) {
        if (_cameras.isEmpty) {
          return const Center(child: Text("No camera detected."));
        }
        if (asyncSnapshot.connectionState == ConnectionState.done) {
          return CameraViewfinder(
            controller: _controller,
            showGrid: _showGrid,
            showLevel: _showLevel,
            tiltAngle: _tiltAngle,
          );
        }
        return const Center(child: CircularProgressIndicator());
      },
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            OrientationBuilder(
              builder: (context, orientation) {
                bool isPortrait = orientation == Orientation.portrait;

                return isPortrait
                    ? Column(
                        children: [
                          _buildTopBar(), // Keep top bar at the top
                          const Spacer(),
                          viewfinderWidget,
                          const Spacer(),
                          _buildBottomBar(), // Custom bar for Portrait
                          const SizedBox(height: 40),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(child: viewfinderWidget),
                          _buildSideBar(), // Custom bar for Landscape
                        ],
                      );
              },
            ),

            _buildOverlays(),
          ],
        ),
      ),
    );
  }
}
