import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_controller.dart';
import '../services/permission_service.dart';
import '../widgets/gradient_button.dart';
import '../widgets/stat_card.dart';
import 'scan_screen.dart';
import 'history_screen.dart';
import 'device_screen.dart';

/// Home/Dashboard screen
class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<BleController>();

    return Scaffold(
      backgroundColor: Color(0xFFF0F4F8), // Light blue-gray background
      body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context),
                SizedBox(height: 40),
                
                // Connection Status
                Obx(() => _buildConnectionStatus(context, controller)),
                SizedBox(height: 32),
                
                // Quick Stats (if connected)
                Obx(() {
                  if (controller.isConnected && controller.deviceInfo.value != null) {
                    return _buildQuickStats(controller);
                  }
                  return SizedBox.shrink();
                }),
                
                SizedBox(height: 32),
                
                // Action Buttons
                Obx(() => _buildActionButtons(context, controller)),
              ],
            ),
          ),
        ),

    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'JumpEezzz',
          style: TextStyle(
            fontSize: 42,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1), // Deep blue
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Smart Jump Rope Companion',
          style: TextStyle(
            fontSize: 16,
            color: Color(0xFF424242), // Dark gray
          ),
        ),
      ],
    );
  }

  Widget _buildConnectionStatus(BuildContext context, BleController controller) {
    final isConnected = controller.isConnected;
    
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
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isConnected 
                  ? Color(0xFF4CAF50).withOpacity(0.2) 
                  : Color(0xFFD32F2F).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Color(0xFF4CAF50) : Color(0xFFD32F2F),
              size: 28,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnected ? 'Connected' : 'Disconnected',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1), // Deep blue
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  isConnected 
                      ? controller.connectedDevice?.platformName ?? 'Jump Rope'
                      : 'No device connected',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF424242), // Dark gray
                  ),
                ),
              ],
            ),
          ),
          if (isConnected)
            IconButton(
              onPressed: () {
                Get.to(() => DeviceScreen());
              },
              icon: Icon(Icons.arrow_forward_ios, color: Color(0xFF0D47A1), size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickStats(BleController controller) {
    final deviceInfo = controller.deviceInfo.value!;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Device Status',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D47A1), // Deep blue
          ),
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Battery',
                value: '${deviceInfo.batteryLevel}%',
                icon: Icons.battery_charging_full,
                color: deviceInfo.batteryLevel > 20 
                    ? Color(0xFF4CAF50) // Green
                    : Color(0xFFFF9800), // Orange
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
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, BleController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!controller.isConnected)
          GradientButton(
            text: 'Scan for Device',
            icon: Icons.bluetooth_searching,
            onPressed: () async {
              // Request permissions
              final hasPermissions = await PermissionService.requestBlePermissions();
              
              if (!hasPermissions) {
                Get.snackbar(
                  'Permissions Required',
                  'Bluetooth permissions are required to scan for devices',
                  snackPosition: SnackPosition.BOTTOM,
                  mainButton: TextButton(
                    onPressed: () => PermissionService.openSettings(),
                    child: Text('Settings'),
                  ),
                );
                return;
              }
              
              Get.to(() => ScanScreen());
            },
          ),
        
        SizedBox(height: 16),
        
        GradientButton(
          text: 'Exercise History',
          icon: Icons.history,
          gradient: LinearGradient(
            colors: [Color(0xFF00BCD4), Color(0xFF2196F3)], // Cyan to blue
          ),
          onPressed: () {
            Get.to(() => HistoryScreen());
          },
        ),
        
        SizedBox(height: 32),
        
        // Info section
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
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
              Row(
                children: [
                  Icon(Icons.info_outline, color: Color(0xFF0D47A1), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Getting Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0D47A1), // Deep blue
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              Text(
                '1. Turn on your jump rope\n'
                '2. Tap "Scan for Device"\n'
                '3. Select your device from the list\n'
                '4. Start jumping!',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF424242), // Dark gray
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
