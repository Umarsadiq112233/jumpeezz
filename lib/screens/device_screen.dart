import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_controller.dart';
import '../models/exercise_data.dart';
import '../widgets/gradient_button.dart';
import '../widgets/stat_card.dart';
import 'workout_screen.dart';

/// Connected device screen
class DeviceScreen extends StatefulWidget {
  const DeviceScreen({Key? key}) : super(key: key);

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  final BleController controller = Get.find<BleController>();
  
  ExerciseMode _selectedMode = ExerciseMode.freeJump;
  int _targetValue = 0;
  final _targetController = TextEditingController();
  bool _autoPushEnabled = false;

  @override
  void dispose() {
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8), // Light blue-gray background
      body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Get.back(),
                      icon: Icon(Icons.arrow_back, color: Color(0xFF0D47A1), size: 28),
                    ),
                    Expanded(
                      child: Text(
                        'Device Control',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1), // Deep blue
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await controller.disconnect();
                        Get.back();
                      },
                      icon: Icon(Icons.bluetooth_disabled, color: Color(0xFFD32F2F), size: 28),
                    ),
                  ],
                ),
                
                SizedBox(height: 24),
                
                // Device Info
                Obx(() {
                  final deviceInfo = controller.deviceInfo.value;
                  if (deviceInfo != null) {
                    return Column(
                      children: [
                        _buildDeviceInfo(deviceInfo),
                        SizedBox(height: 24),
                        
                        // Battery & Status
                        Row(
                          children: [
                            Expanded(
                              child: StatCard(
                                title: 'Battery',
                                value: '${deviceInfo.batteryLevel}%',
                                icon: Icons.battery_charging_full,
                                color: deviceInfo.batteryLevel > 20 
                                    ? Colors.green 
                                    : Colors.orange,
                              ),
                            ),
                            SizedBox(width: 16),
                            Expanded(
                              child: StatCard(
                                title: 'Status',
                                value: deviceInfo.state.displayName,
                                icon: Icons.info_outline,
                                color: Color(0xFF00BCD4), // Cyan
                              ),
                            ),
                          ],
                        ),
                        
                        SizedBox(height: 32),
                      ],
                    );
                  }
                  return SizedBox.shrink();
                }),
                
                // Exercise Mode Selection
                _buildModeSelection(),
                
                SizedBox(height: 24),
                
                // Target Value Input (for countdown/count modes)
                if (_selectedMode != ExerciseMode.freeJump)
                  _buildTargetInput(),
                SizedBox(height: 24),
                // Auto Push Toggle
                _buildAutoPushToggle(),
                SizedBox(height: 32),
                // Action Buttons
                _buildActionButtons(),
                SizedBox(height: 24),
                // Settings
                _buildSettings(),
              ],
            ),
          ),
        ),
    );
  }

  Widget _buildDeviceInfo(deviceInfo) {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Device Information',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1), // Deep blue
            ),
          ),
          SizedBox(height: 16),
          _buildInfoRow('Serial Number', deviceInfo.serialNumber),
          _buildInfoRow('Software', deviceInfo.softwareVersion),
          _buildInfoRow('BLE Version', deviceInfo.bleVersion),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Color(0xFF424242), // Dark gray
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Color(0xFF212121), // Very dark gray
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelection() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercise Mode',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1), // Deep blue
            ),
          ),
          SizedBox(height: 16),
          ...ExerciseMode.values.map((mode) {
            return RadioListTile<ExerciseMode>(
              title: Text(
                mode.displayName,
                style: TextStyle(
                  color: Color(0xFF212121), // Very dark gray
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                _getModeDescription(mode),
                style: TextStyle(
                  color: Color(0xFF424242), // Dark gray
                  fontSize: 12,
                ),
              ),
              value: mode,
              groupValue: _selectedMode,
              activeColor: Color(0xFF0D47A1), // Deep blue
              onChanged: (value) {
                setState(() {
                  _selectedMode = value!;
                  _targetController.clear();
                  _targetValue = 0;
                });
              },
            );
          }).toList(),
        ],
      ),
    );
  }

  String _getModeDescription(ExerciseMode mode) {
    switch (mode) {
      case ExerciseMode.freeJump:
        return 'Jump freely without limits';
      case ExerciseMode.countdown:
        return 'Set a time goal in seconds';
      case ExerciseMode.count:
        return 'Set a jump count goal';
    }
  }

  Widget _buildTargetInput() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _selectedMode == ExerciseMode.countdown 
                ? 'Target Duration (seconds)' 
                : 'Target Jumps',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1), // Deep blue
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: TextInputType.number,
            style: TextStyle(
              color: Color(0xFF212121), // Very dark gray
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: _selectedMode == ExerciseMode.countdown 
                  ? 'e.g., 300 (5 minutes)' 
                  : 'e.g., 100',
              hintStyle: TextStyle(
                color: Color(0xFF757575), // Medium gray
              ),
              filled: true,
              fillColor: Color(0xFFF5F5F5), // Light gray
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Color(0xFF0D47A1).withOpacity(0.3),
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Color(0xFF0D47A1),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              _targetValue = int.tryParse(value) ?? 0;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAutoPushToggle() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Real-time Data Push',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1), // Deep blue
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Receive live updates during exercise',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF424242), // Dark gray
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _autoPushEnabled,
            activeColor: Color(0xFF0D47A1), // Deep blue
            onChanged: (value) {
              setState(() {
                _autoPushEnabled = value;
              });
              controller.setAutoPush(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(() => GradientButton(
          text: 'Start Exercise',
          icon: Icons.play_arrow,
          isLoading: controller.isLoading.value,
          onPressed: () async {
            try {
              // Start exercise first
              await controller.startExercise(_selectedMode, _targetValue);
              
              // Wait a bit to ensure everything is stable
              await Future.delayed(Duration(milliseconds: 500));
              
              // Check if still connected before navigating
              if (controller.isConnected) {
                // Navigate to workout screen
                Get.to(() => WorkoutScreen(
                  mode: _selectedMode,
                  targetValue: _targetValue,
                ));
              } else {
                // Show error if disconnected
                Get.snackbar(
                  'Connection Lost',
                  'Device disconnected. Please reconnect and try again.',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.withOpacity(0.8),
                  colorText: Colors.white,
                  duration: Duration(seconds: 3),
                );
              }
            } catch (e) {
              // Error already shown by controller
              print('Error in device screen: $e');
            }
          },
        )),
      ],
    );
  }

  Widget _buildSettings() {
    return Container(
      padding: EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0D47A1), // Deep blue
            ),
          ),
          SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.access_time, color: Color(0xFF0D47A1), size: 24),
            title: Text(
              'Sync Time & Weight',
              style: TextStyle(
                color: Color(0xFF212121), // Very dark gray
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              'Update device time and user weight',
              style: TextStyle(
                color: Color(0xFF424242), // Dark gray
                fontSize: 12,
              ),
            ),
            trailing: Icon(Icons.arrow_forward_ios, color: Color(0xFF757575), size: 16),
            onTap: () => _showSyncDialog(),
          ),
        ],
      ),
    );
  }

  void _showSyncDialog() {
    final weightController = TextEditingController(text: '65');
    
    Get.dialog(
      AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'Sync Time & Weight',
          style: TextStyle(
            color: Color(0xFF0D47A1), // Deep blue
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: weightController,
              keyboardType: TextInputType.number,
              style: TextStyle(
                color: Color(0xFF212121), // Very dark gray
                fontSize: 16,
              ),
              decoration: InputDecoration(
                labelText: 'Weight (kg)',
                labelStyle: TextStyle(
                  color: Color(0xFF757575), // Medium gray
                ),
                filled: true,
                fillColor: Color(0xFFF5F5F5), // Light gray
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Color(0xFF0D47A1).withOpacity(0.3),
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Color(0xFF0D47A1),
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
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
            onPressed: () async {
              final weight = int.tryParse(weightController.text) ?? 65;
              await controller.syncTimeAndWeight(weight);
              Get.back();
              
              Get.snackbar(
                'Success',
                'Time and weight synced!',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Color(0xFF4CAF50), // Green
                colorText: Colors.white,
              );
            },
            child: Text(
              'Sync',
              style: TextStyle(
                color: Color(0xFF0D47A1), // Deep blue
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
