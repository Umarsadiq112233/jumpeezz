import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../controllers/ble_controller.dart';
import '../models/exercise_data.dart';

/// Exercise history screen
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8), // Light blue-gray background
      body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.arrow_back, color: Color(0xFF0D47A1), size: 28),
                    ),
                    Expanded(
                      child: Text(
                        'Exercise History',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1), // Deep blue
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48),
                  ],
                ),
              ),
              
              // History list
              Expanded(
                child: Obx(() {
                  final history = controller.exerciseHistory;
                  
                  if (history.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.history,
                            size: 80,
                            color: Color(0xFF0D47A1).withOpacity(0.3),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'No exercise history',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1), // Deep blue
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Start jumping to see your workouts here',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF424242), // Dark gray
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: EdgeInsets.all(16),
                    itemCount: history.length,
                    itemBuilder: (context, index) {
                      final exercise = history[index];
                      final dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
                      
                      return Container(
                        margin: EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Color(0xFF0D47A1).withOpacity(0.2),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF0D47A1).withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showExerciseDetails(context, exercise),
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Color(0xFF0D47A1).withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          Icons.fitness_center,
                                          color: Color(0xFF0D47A1), // Deep blue
                                          size: 24,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              exercise.mode.displayName,
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0D47A1), // Deep blue
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Text(
                                              dateFormat.format(exercise.startTime),
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Color(0xFF424242), // Dark gray
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () {
                                          _showDeleteConfirmation(controller, index);
                                        },
                                        icon: Icon(Icons.delete_outline, color: Color(0xFFD32F2F), size: 24),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildStatItem(
                                          'Jumps',
                                          exercise.jumpCount.toString(),
                                          Icons.trending_up,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          'Duration',
                                          exercise.formattedDuration,
                                          Icons.timer,
                                        ),
                                      ),
                                      Expanded(
                                        child: _buildStatItem(
                                          'Calories',
                                          exercise.calories.toString(),
                                          Icons.local_fire_department,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
            ],
          ),
        ),

    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Color(0xFF0D47A1), size: 20),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1), // Deep blue
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFF424242), // Dark gray
          ),
        ),
      ],
    );
  }

  void _showExerciseDetails(BuildContext context, ExerciseData exercise) {
    Get.bottomSheet(
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF0D47A1).withOpacity(0.2),
              blurRadius: 20,
              offset: Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Exercise Details',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1), // Deep blue
              ),
            ),
            SizedBox(height: 24),
            _buildDetailRow('Mode', exercise.mode.displayName),
            _buildDetailRow('Jumps', exercise.jumpCount.toString()),
            _buildDetailRow('Duration', exercise.formattedDuration),
            _buildDetailRow('Calories', '${exercise.calories} kcal'),
            _buildDetailRow('Frequency', '${exercise.realtimeFrequency} jumps/min'),
            _buildDetailRow('Double Unders', exercise.doubleUnderCount.toString()),
            _buildDetailRow('Max Continuous', exercise.maxContinuousJumps.toString()),
            _buildDetailRow('Interruptions', exercise.interruptionCount.toString()),
          ],
        ),
      ),
      backgroundColor: Colors.transparent,
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF424242), // Dark gray
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1), // Deep blue
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BleController controller, int index) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Delete Exercise?',
          style: TextStyle(
            color: Color(0xFF0D47A1), // Deep blue
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Text(
          'This action cannot be undone.',
          style: TextStyle(
            color: Color(0xFF424242), // Dark gray
            fontSize: 16,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF757575), // Medium gray
                fontSize: 16,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              controller.deleteExercise(index);
              Get.back();
            },
            child: Text(
              'Delete',
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
