import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../controllers/ble_controller.dart';
import '../widgets/device_tile.dart';
import 'device_screen.dart';

/// Device scanning screen
class ScanScreen extends StatefulWidget {
  const ScanScreen({Key? key}) : super(key: key);

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final BleController controller = Get.find<BleController>();

  @override
  void initState() {
    super.initState();
    controller.startScan();
  }

  @override
  void dispose() {
    controller.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                        'Scan for Devices',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1), // Deep blue
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    SizedBox(width: 48), // Balance the back button
                  ],
                ),
              ),
              
              // Scanning indicator
              Obx(() {
                if (controller.isScanning.value) {
                  return Container(
                    margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Color(0xFF00BCD4).withOpacity(0.4),
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
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(Color(0xFF00BCD4)),
                          ),
                        ),
                        SizedBox(width: 16),
                        Text(
                          'Scanning for jump ropes...',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF0D47A1), // Deep blue
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return SizedBox.shrink();
              }),
              
              // Device list
              Expanded(
                child: Obx(() {
                  // Filter results to only show jump rope devices
                  final allResults = controller.scanResults;
                  final results = allResults.where((result) {
                    final name = result.device.platformName.toUpperCase();
                    return name.startsWith('TY') || 
                           name.startsWith('ROGUE') || 
                           name.startsWith('YS137') ||
                           name.startsWith('YX') ||
                           name.startsWith('YS838');
                  }).toList();
                  
                  if (results.isEmpty && !controller.isScanning.value) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bluetooth_disabled,
                            size: 80,
                            color: Color(0xFF0D47A1).withOpacity(0.3),
                          ),
                          SizedBox(height: 24),
                          Text(
                            'No devices found',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D47A1), // Deep blue
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Make sure your jump rope is turned on',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF424242), // Dark gray
                            ),
                          ),
                          SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: () => controller.startScan(),
                            icon: Icon(Icons.refresh),
                            label: Text('Scan Again'),
                          ),
                        ],
                      ),
                    );
                  }
                  
                  return ListView.builder(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: results.length,
                    itemBuilder: (context, index) {
                      final result = results[index];
                      return DeviceTile(
                        result: result,
                        onTap: () async {
                          await controller.stopScan();
                          
                          // Show connecting dialog
                          Get.dialog(
                            Center(
                              child: Container(
                                margin: EdgeInsets.all(32),
                                padding: EdgeInsets.all(32),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF0D47A1).withOpacity(0.2),
                                      blurRadius: 20,
                                      offset: Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation(
                                        Color(0xFF00BCD4), // Cyan
                                      ),
                                      strokeWidth: 3,
                                    ),
                                    SizedBox(height: 24),
                                    Text(
                                      'Connecting...',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D47A1), // Deep blue
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            barrierDismissible: false,
                          );
                          
                          try {
                            await controller.connectToDevice(result.device);
                            
                            // Close connecting dialog
                            Get.back();
                            
                            // Navigate to device screen
                            Get.off(() => DeviceScreen());
                          } catch (e) {
                            // Close connecting dialog
                            Get.back();
                            
                            // Show detailed error
                            print('Connection error in UI: $e');
                            
                            Get.snackbar(
                              'Connection Failed',
                              e.toString(),
                              backgroundColor: Colors.red.withOpacity(0.8),
                              colorText: Colors.white,
                              duration: Duration(seconds: 5),
                              mainButton: TextButton(
                                onPressed: () {
                                  // Retry connection
                                  controller.connectToDevice(result.device);
                                },
                                child: Text('Retry', style: TextStyle(color: Colors.white)),
                              ),
                            );
                          }
                        },
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
}
