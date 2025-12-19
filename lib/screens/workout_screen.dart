import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_controller.dart';
import '../models/exercise_data.dart';

/// Real-time workout screen - Ultra Simple
class WorkoutScreen extends StatefulWidget {
  final ExerciseMode mode;
  final int targetValue;

  const WorkoutScreen({
    Key? key,
    required this.mode,
    required this.targetValue,
  }) : super(key: key);

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> with SingleTickerProviderStateMixin {
  final BleController controller = Get.find<BleController>();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _triggerPulse() {
    _pulseController.forward().then((_) => _pulseController.reverse());
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        final shouldPop = await _showExitConfirmation();
        return shouldPop ?? false;
      },
      child: Scaffold(
        backgroundColor: Color(0xFFF0F4F8), // Light blue-gray background
        body: SafeArea(
            child: Column(
              children: [
                // Simple Header
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () async {
                          final shouldExit = await _showExitConfirmation();
                          if (shouldExit == true) {
                            Get.back();
                          }
                        },
                        icon: Icon(Icons.close, color: Color(0xFF1565C0), size: 28),
                      ),
                      Text(
                        'JUMP ROPE',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1), // Deep blue
                          letterSpacing: 2,
                        ),
                      ),
                      SizedBox(width: 48), // Balance
                    ],
                  ),
                ),

                // Main Jump Count Display
                Expanded(
                  child: Center(
                    child: Obx(() {
                      final exerciseData = controller.currentExerciseData.value;
                      final jumpCount = exerciseData?.jumpCount ?? 0;
                      
                      // Trigger pulse animation when count changes
                      if (jumpCount > 0) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _triggerPulse();
                        });
                      }
                      
                      return ScaleTransition(
                        scale: _pulseAnimation,
                        child: SingleChildScrollView(
                          physics: BouncingScrollPhysics(),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                            // Connection Status Indicator
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: Color(0xFF00BCD4), // Cyan
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'CONNECTED',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 20),
                            
                            // Instruction Banner
                            Container(
                              margin: EdgeInsets.symmetric(horizontal: 32),
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Color(0xFFFFF9C4), // Light yellow
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Color(0xFFFBC02D), // Yellow
                                  width: 2,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.info_outline, color: Color(0xFFF57F17), size: 24),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Press the button on your jump rope to start',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFFF57F17), // Dark yellow
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            SizedBox(height: 20),
                            
                            // Jump Count
                            Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFF0D47A1), // Deep blue
                                    Color(0xFF1565C0), // Dark blue
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Color(0xFF0D47A1).withOpacity(0.3),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      jumpCount.toString(),
                                      style: TextStyle(
                                        fontSize: 96,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        height: 1,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'JUMPS',
                                      style: TextStyle(
                                        fontSize: 20,
                                        letterSpacing: 4,
                                        color: Colors.white.withOpacity(0.9),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            SizedBox(height: 60),
                            
                            // Duration / Target Display
                            if (widget.mode == ExerciseMode.countdown && widget.targetValue > 0)
                              // Countdown Mode: Show Time Remaining
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Color(0xFF0D47A1).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(25),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.timer, color: Color(0xFF0D47A1), size: 24),
                                    SizedBox(width: 8),
                                    Text(
                                      _formatTimeRemaining(widget.targetValue, exerciseData?.duration ?? 0),
                                      style: TextStyle(
                                        fontSize: 24,
                                        color: Color(0xFF0D47A1), // Deep blue
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'remaining',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF0D47A1).withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else if (widget.mode == ExerciseMode.count && widget.targetValue > 0)
                              // Count Mode: Show Jumps Remaining
                               Container(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                decoration: BoxDecoration(
                                  color: Color(0xFF0D47A1).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(25), 
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'TARGET: ${widget.targetValue}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D47A1),
                                      ),
                                    ),
                                    Text(
                                      '${(widget.targetValue - jumpCount).clamp(0, 99999)} to go',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF0D47A1).withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              // Free Jump: Show Elapsed Time
                              if (exerciseData != null)
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0D47A1).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(25),
                                    border: Border.all(
                                      color: Color(0xFF0D47A1).withOpacity(0.4),
                                      width: 2,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.timer, color: Color(0xFF0D47A1), size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        exerciseData.formattedDuration,
                                        style: TextStyle(
                                          fontSize: 18,
                                          color: Color(0xFF0D47A1), // Deep blue
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                          ],
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                
                // Stop Button
                Padding(
                  padding: EdgeInsets.all(32),
                  child: Obx(() => Container(
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Color(0xFF0D47A1).withOpacity(0.3),
                          blurRadius: 15,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: controller.isLoading.value ? null : () async {
                        await controller.stopExercise();
                        Get.back();
                        
                        Get.snackbar(
                          'Success',
                          'Exercise saved!',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Color(0xFF00BCD4), // Cyan
                          colorText: Colors.white,
                          margin: EdgeInsets.all(16),
                          borderRadius: 12,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0D47A1), // Deep blue
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 0,
                      ),
                      child: controller.isLoading.value
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.stop_circle_outlined, size: 28, color: Colors.white),
                                SizedBox(width: 12),
                                Text(
                                  'STOP EXERCISE',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  )),
                ),
              ],
            ),
          ),
        ),
    );
  }

  String _formatTimeRemaining(int targetSeconds, int elapsedSeconds) {
    final remaining = (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);
    final minutes = remaining ~/ 60;
    final seconds = remaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Future<bool?> _showExitConfirmation() {
    return Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Stop Exercise?',
          style: TextStyle(
            color: Color(0xFF0D47A1), // Deep blue
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          'Your progress will be saved.',
          style: TextStyle(
            color: Color(0xFF212121), // Dark gray
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(
              'Continue',
              style: TextStyle(
                color: Color(0xFF00BCD4), // Cyan
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Get.back(result: true);
            },
            child: Text(
              'Stop',
              style: TextStyle(
                color: Color(0xFFD32F2F), // Red
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
