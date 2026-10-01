import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import '../../../../core/theme/app_colors.dart';
import '../../data/repositories/macro_repository.dart';
import '../../data/services/ai_food_scanner_service.dart';
import '../../domain/models/meal_type.dart';
import 'ai_food_analysis_result_screen.dart';

/// Screen providing the LIVE CAMERA UI for scanning food meals
/// STRICT PRIVACY & FLOW:
/// - Uses device live camera ONLY.
/// - NO gallery upload, NO image picker, NO file picker.
/// - Releases camera hardware immediately after shutter press.
class AiFoodCameraScannerScreen extends StatefulWidget {
  final MacroRepository repository;
  final MealType initialMealType;
  final String dateString;

  const AiFoodCameraScannerScreen({
    super.key,
    required this.repository,
    this.initialMealType = MealType.lunch,
    required this.dateString,
  });

  @override
  State<AiFoodCameraScannerScreen> createState() => _AiFoodCameraScannerScreenState();
}

class _AiFoodCameraScannerScreenState extends State<AiFoodCameraScannerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  bool _isCameraInitialized = false;
  bool _isPermissionDenied = false;
  bool _isCapturing = false;
  bool _isAnalyzing = false;
  FlashMode _flashMode = FlashMode.off;
  int _selectedCameraIndex = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;
    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      // Free camera resource when app goes to background
      cameraController.dispose();
      _controller = null;
      _isCameraInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeCamera();
    super.dispose();
  }

  Future<void> _disposeCamera() async {
    final cameraController = _controller;
    _controller = null;
    if (cameraController != null) {
      await cameraController.dispose();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _isPermissionDenied = false;
          _isCameraInitialized = false;
          _errorMessage = 'No camera hardware detected on this device.';
        });
        return;
      }

      final camera = _availableCameras[_selectedCameraIndex];
      final controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      _controller = controller;

      await controller.initialize();
      await controller.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
          _isPermissionDenied = false;
          _errorMessage = null;
        });
      }
    } on CameraException catch (e) {
      debugPrint('[AI CAMERA] CameraException: ${e.code} - ${e.description}');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          if (e.code == 'CameraAccessDenied' || e.code == 'CameraAccessDeniedWithoutPrompt' || e.code == 'CameraAccessRestricted') {
            _isPermissionDenied = true;
            _errorMessage = 'Camera access was denied. Please allow camera access in Settings to scan your meal.';
          } else {
            _errorMessage = e.description ?? 'Failed to access camera.';
          }
        });
      }
    } catch (e) {
      debugPrint('[AI CAMERA] General initialization error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
          _errorMessage = 'Could not initialize camera: $e';
        });
      }
    }
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    HapticFeedback.selectionClick();

    FlashMode nextMode;
    switch (_flashMode) {
      case FlashMode.off:
        nextMode = FlashMode.torch;
        break;
      case FlashMode.torch:
        nextMode = FlashMode.auto;
        break;
      case FlashMode.auto:
      default:
        nextMode = FlashMode.off;
        break;
    }

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _flashMode = nextMode);
    } catch (_) {}
  }

  void _switchCamera() async {
    if (_availableCameras.length < 2) return;
    HapticFeedback.selectionClick();

    _selectedCameraIndex = (_selectedCameraIndex + 1) % _availableCameras.length;
    await _disposeCamera();
    await _initializeCamera();
  }

  Future<void> _captureAndAnalyze() async {
    if (_isCapturing || _isAnalyzing) return;

    // Trigger haptic shutter snap
    HapticFeedback.heavyImpact();

    setState(() {
      _isCapturing = true;
      _isAnalyzing = true;
    });

    try {
      String? capturedPath;

      if (_controller != null && _controller!.value.isInitialized) {
        final XFile photo = await _controller!.takePicture();
        capturedPath = photo.path;

        // Privacy rule: Immediately release/pause camera hardware after capture
        await _disposeCamera();
      }

      // If on desktop/simulator or camera was mocked, generate a standard test capture
      final scannerService = AiFoodScannerService();
      final result = capturedPath != null
          ? await scannerService.analyzeLivePhoto(capturedPath)
          : await scannerService.analyzeImageBytes(Uint8List(0));

      // Cleanup local temp file to follow privacy requirement
      if (capturedPath != null) {
        try {
          final tempFile = File(capturedPath);
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (_) {}
      }

      if (!mounted) return;

      // Navigate to confirmation & edit screen
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => AiFoodAnalysisResultScreen(
            scanResult: result,
            repository: widget.repository,
            initialMealType: widget.initialMealType,
            dateString: widget.dateString,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCapturing = false;
          _isAnalyzing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.surfaceElevated,
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: const TextStyle(color: Colors.white),
            ),
            action: SnackBarAction(
              label: 'RETRY',
              textColor: AppColors.primaryRed,
              onPressed: _initializeCamera,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 1. Live Camera Preview
            Positioned.fill(
              child: _buildCameraPreview(),
            ),

            // 2. Framing Guide Overlay & Guidance Text
            Positioned.fill(
              child: _buildFramingOverlay(),
            ),

            // 3. Top Action Controls (Back, Flash, Switch Camera)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: _buildTopBar(),
            ),

            // 4. Bottom Shutter Control Bar
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: _buildBottomControls(),
            ),

            // 5. Loading Overlay during AI Analysis
            if (_isAnalyzing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.85),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 56,
                          height: 56,
                          child: CircularProgressIndicator(
                            color: AppColors.primaryRed,
                            strokeWidth: 3.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'ANALYZING MEAL WITH AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Detecting foods and calculating nutrition estimates...',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraPreview() {
    if (_isPermissionDenied) {
      return _buildPermissionDeniedUI();
    }

    if (_errorMessage != null && !_isCameraInitialized) {
      return _buildFallbackSimulatorUI();
    }

    if (!_isCameraInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryRed),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRect(
          child: OverflowBox(
            alignment: Alignment.center,
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: constraints.maxWidth,
                height: constraints.maxWidth * _controller!.value.aspectRatio,
                child: CameraPreview(_controller!),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFramingOverlay() {
    return IgnorePointer(
      child: Column(
        children: [
          const SizedBox(height: 90),
          // Guidance Pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.crop_free, color: AppColors.primaryRed, size: 16),
                SizedBox(width: 8),
                Text(
                  'Place your full meal inside the frame',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Targeting Reticle / Square Viewfinder
          Center(
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: AppColors.primaryRed.withOpacity(0.6),
                  width: 2.0,
                ),
              ),
              child: Stack(
                children: [
                  // Corner accent brackets
                  Positioned(
                    top: 0,
                    left: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.primaryRed, width: 4),
                          left: BorderSide(color: AppColors.primaryRed, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          top: BorderSide(color: AppColors.primaryRed, width: 4),
                          right: BorderSide(color: AppColors.primaryRed, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.primaryRed, width: 4),
                          left: BorderSide(color: AppColors.primaryRed, width: 4),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: AppColors.primaryRed, width: 4),
                          right: BorderSide(color: AppColors.primaryRed, width: 4),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(),
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Close Button
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.6),
          child: IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 20),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),

        // Brand Pill
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primaryRed.withOpacity(0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.camera_alt, color: AppColors.primaryRed, size: 14),
              SizedBox(width: 6),
              Text(
                'AI LIVE SCANNER',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // Flash Toggle
        CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.6),
          child: IconButton(
            icon: Icon(
              _flashMode == FlashMode.off
                  ? Icons.flash_off
                  : (_flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_auto),
              color: _flashMode == FlashMode.off ? Colors.white70 : AppColors.gold,
              size: 20,
            ),
            onPressed: _toggleFlash,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomControls() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Left spacer or camera switch
            if (_availableCameras.length > 1)
              CircleAvatar(
                backgroundColor: Colors.white.withOpacity(0.15),
                radius: 22,
                child: IconButton(
                  icon: const Icon(Icons.flip_camera_ios, color: Colors.white, size: 20),
                  onPressed: _switchCamera,
                ),
              )
            else
              const SizedBox(width: 44),

            // Live Camera Shutter Button (NO gallery button!)
            GestureDetector(
              onTap: _captureAndAnalyze,
              child: Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryRed.withOpacity(0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Container(
                  margin: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(Icons.camera_alt, color: Colors.white, size: 30),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 44),
          ],
        ),
        const SizedBox(height: 12),
        const Text(
          'Live Camera Capture Only',
          style: TextStyle(
            color: Colors.white54,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionDeniedUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined, color: AppColors.primaryRed, size: 64),
            const SizedBox(height: 20),
            const Text(
              'Camera Permission Required',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Alpha X needs camera access so you can point your device at your food to scan and calculate nutritional macros.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: _initializeCamera,
              child: const Text('ENABLE CAMERA ACCESS', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackSimulatorUI() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.camera, color: AppColors.primaryRed, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Live Camera Simulator Feed',
              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Point camera at your meal and tap the shutter.',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: _initializeCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: AppColors.border),
              ),
              child: const Text('RETRY HARDWARE CAMERA'),
            ),
          ],
        ),
      ),
    );
  }
}
