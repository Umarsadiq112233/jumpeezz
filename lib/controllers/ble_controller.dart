import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/device_info.dart';
import '../models/exercise_data.dart';
import '../services/ble_service.dart';
import '../utils/byte_utils.dart';

class BleController extends GetxController {
  final BleService _bleService = BleService();

  // Reactive State
  final Rx<BluetoothConnectionState> connectionState =
      BluetoothConnectionState.disconnected.obs;
  final RxBool isScanning = false.obs;
  final RxList<ScanResult> scanResults = <ScanResult>[].obs;
  final Rx<DeviceInfo?> deviceInfo = Rx<DeviceInfo?>(null);
  final Rx<ExerciseData?> currentExerciseData = Rx<ExerciseData?>(null);
  final RxList<ExerciseData> exerciseHistory = <ExerciseData>[].obs;
  final RxBool isLoading = false.obs;
  final RxString errorMessage = ''.obs;

  // Session State
  bool _isSessionActive = false;



  // Getters
  bool get isConnected {
    final connected = connectionState.value == BluetoothConnectionState.connected;
    print('🔍 isConnected check: connectionState=${connectionState.value}, result=$connected');
    return connected;
  }
  BluetoothDevice? get connectedDevice => _bleService.connectedDevice;

  // Subscriptions
  StreamSubscription? _scanSubscription;
  StreamSubscription? _connectionSubscription;
  StreamSubscription? _notificationSubscription;

  @override
  void onInit() {
    super.onInit();
    _loadExerciseHistory();
  }

  @override
  void onClose() {
    _scanSubscription?.cancel();
    _connectionSubscription?.cancel();
    _notificationSubscription?.cancel();
    _exerciseDataTimer?.cancel();
    _bleService.dispose();
    super.onClose();
  }

  /// Start scanning
  Future<void> startScan() async {
    try {
      isScanning.value = true;
      scanResults.clear();
      errorMessage.value = '';

      await _bleService.startScan();

      _scanSubscription?.cancel();
      _scanSubscription = _bleService.scanResults.listen((results) {
        // Debug: Log all found devices
        for (var result in results) {
          print(
            '🔎 Scanned: ${result.device.platformName} (${result.device.remoteId}) RSSI: ${result.rssi}',
          );
        }

        // Filter by name prefixes if needed, or just show all
        // For now, we pass all results and let the UI filter or show them
        scanResults.value = results;
      });
    } catch (e) {
      errorMessage.value = 'Failed to start scan: $e';
      isScanning.value = false;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await _bleService.stopScan();
    isScanning.value = false;
  }

  /// Connect to device
  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      isLoading.value = true;
      errorMessage.value = '';

      // Stop scanning first
      await stopScan();

      await _bleService.connect(device);

      // Listen to connection state
      _connectionSubscription?.cancel();
      _connectionSubscription = _bleService.connectionStateStream.listen((
        state,
      ) {
        connectionState.value = state;
        if (state == BluetoothConnectionState.disconnected) {
          print('⚠️ Device disconnected - cleaning up');

          // Stop polling if disconnected
          _exerciseDataTimer?.cancel();
          _exerciseDataTimer = null;

          _handleDisconnect();

          // Only show notification if we're not in the middle of starting exercise
          // (device might disconnect temporarily when entering exercise mode)
          if (!isLoading.value) {
            Get.snackbar(
              'Disconnected',
              'Jump rope disconnected',
              snackPosition: SnackPosition.TOP,
              backgroundColor: Colors.red.withOpacity(0.8),
              colorText: Colors.white,
              duration: Duration(seconds: 3),
            );
          }
        } else if (state == BluetoothConnectionState.connected) {
          print('✅ Device connected/reconnected');
          // If we have an active exercise, restart polling
          if (currentExerciseData.value != null &&
              currentExerciseData.value!.state == ExerciseState.exercising) {
            print('🔄 Restarting exercise data polling after reconnection');
            _exerciseDataTimer?.cancel();
            _exerciseDataTimer = Timer.periodic(Duration(seconds: 1), (timer) {
              if (isConnected) {
                _bleService.getExerciseData().catchError((e) {
                  print('⚠️ Error requesting exercise data: $e');
                  if (e.toString().contains('Not connected') ||
                      e.toString().contains('disconnected')) {
                    timer.cancel();
                  }
                });
              } else {
                timer.cancel();
              }
            });
          }
        }
      });

      // Listen to notifications
      _notificationSubscription?.cancel();
      _notificationSubscription = _bleService.notificationStream.listen(
        _handleNotification,
      );

      // Wait for connection to stabilize - device needs time to be ready
      await Future.delayed(Duration(milliseconds: 3000));

      // SIMPLIFIED: Only get device info and enable auto-push
      // Avoid sending too many commands that might overwhelm the device
      try {
        // Get device info first
        await _bleService.getDeviceInfo();
        await Future.delayed(Duration(milliseconds: 1500));

        // CRITICAL: Enable auto-push for real-time data (command 0x05)
        // This is required to receive jump count updates automatically
        await _bleService.setAutoPush(true);
        print(
          '✅ Auto-push enabled - will receive real-time jump count updates',
        );

        // Wait a bit more to ensure everything is stable
        await Future.delayed(Duration(milliseconds: 1000));
      } catch (e) {
        print('⚠️ Error during initial setup: $e');
        // Continue anyway - connection is established
      }

      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'Connection failed: $e';
      isLoading.value = false;
      _handleDisconnect();
      rethrow;
    }
  }

  /// Handle disconnection
  void _handleDisconnect() {
    connectionState.value = BluetoothConnectionState.disconnected;
    deviceInfo.value = null;
    currentExerciseData.value = null;
    _notificationSubscription?.cancel();
  }

  /// Disconnect manually
  Future<void> disconnect() async {
    await _bleService.disconnect();
    _handleDisconnect();
  }

  /// Handle incoming data - Based on YXTS SDK structure
  void _handleNotification(List<int> data) {
    if (data.isEmpty) {
      print('⚠️ Received empty notification');
      return;
    }

    print('');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📱 NOTIFICATION RECEIVED');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📦 Raw HEX: ${ByteUtils.formatHexString(data)}');
    print('📏 Length: ${data.length} bytes');
    print('📋 Raw bytes: ${data.join(' ')}');

    // According to YXTS SDK, command byte is at index 2
    if (data.length < 3) {
      print('⚠️ Data too short (${data.length} bytes), skipping...');
      return;
    }

    final command = data[2];
    print(
      '🔍 Command at index 2: 0x${command.toRadixString(16).padLeft(2, '0')}',
    );
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');

    switch (command) {
      case 0x01: // Device Info
        try {
          deviceInfo.value = DeviceInfo.fromInfoBytes(data);
          print('✅ Parsed as Device Info');
          return;
        } catch (e) {
          print('❌ Failed to parse Device Info: $e');
        }
        break;

      case 0x03: // Device State
        try {
          if (deviceInfo.value != null) {
            deviceInfo.value = deviceInfo.value!.copyWith(
              state: DeviceInfo.parseState(data),
              batteryLevel: DeviceInfo.parseBattery(data),
            );
            print('✅ Parsed as Device State');
            return;
          }
        } catch (e) {
          print('❌ Failed to parse Device State: $e');
        }
        break;

      case 0x06: // Real-time data (auto-push)
      case 0x07: // Exercise data
        try {
          // According to YXTS SDK parse function:
          // - data[3] = state
          // - data[4-7] = start time (4 bytes)
          // - data[8-9] = duration (2 bytes)
          // - data[10-13] = jump count (4 bytes) - THIS IS WHAT WE NEED
          // - data[14-15] = interruption count (2 bytes)
          // - data[16-17] = max continuous jumps (2 bytes)
          // - data[18-19] = double under count (2 bytes)
          // - data[20-21] = realtime frequency (2 bytes)
          // - data[22-25] = calories (4 bytes)
          // - data[26] = mode
          // - data[27-30] = target value (4 bytes)

          if (data.length >= 31) {
            // Extract jump count from bytes 10-13 (4 bytes, big-endian)
            final jumpCount = ByteUtils.bytesToInt(data.sublist(10, 14));
            print('🎯 JUMP COUNT EXTRACTED: $jumpCount');
            print(
              '   Bytes 10-13: ${data.sublist(10, 14).map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}',
            );

            // Parse full exercise data
            try {
              currentExerciseData.value = ExerciseData.fromBytes(data);
              print('✅ Successfully parsed Exercise Data');
              print('   Jump Count: ${currentExerciseData.value?.jumpCount}');
              print('   Duration: ${currentExerciseData.value?.duration}s');
              print(
                '   State: ${currentExerciseData.value?.state.displayName}',
              );
              return;
            } catch (e) {
              print('❌ Error parsing ExerciseData: $e');
              // Still update jump count even if full parse fails
              if (jumpCount > 0) {
                _updateJumpCount(jumpCount);
              }
            }
          } else {
            print(
              '⚠️ Exercise data too short: ${data.length} bytes (need at least 31)',
            );
            // Try to extract jump count anyway if we have enough bytes
            if (data.length >= 14) {
              final jumpCount = ByteUtils.bytesToInt(data.sublist(10, 14));
              print('   Attempting to extract jump count: $jumpCount');
              if (jumpCount > 0) {
                _updateJumpCount(jumpCount);
              }
            }
          }
        } catch (e) {
          print('❌ Failed to parse Exercise Data: $e');
          print('   Stack trace: ${StackTrace.current}');

          // Last resort: Try to extract just jump count if data is long enough
          if (data.length >= 14) {
            try {
              final jumpCount = ByteUtils.bytesToInt(data.sublist(10, 14));
              print('   🔄 Last resort: Extracted jump count: $jumpCount');
              _updateJumpCount(jumpCount);
            } catch (e2) {
              print('   ❌ Failed to extract jump count: $e2');
            }
          }
        }
        break;

      default:
        print(
          '⚠️ Unknown command: 0x${command.toRadixString(16).padLeft(2, '0')}',
        );
        print('   Full data: ${ByteUtils.formatHexString(data)}');
        // Try to extract jump count from unknown format if possible
        if (data.length >= 14) {
          try {
            final jumpCount = ByteUtils.bytesToInt(data.sublist(10, 14));
            if (jumpCount > 0) {
              print(
                '   💡 Attempting to extract jump count from unknown format: $jumpCount',
              );
              _updateJumpCount(jumpCount);
            }
          } catch (_) {}
        }
    }
  }

  /// Helper method to update jump count
  void _updateJumpCount(int jumpCount) {
    if (!_isSessionActive) return;

    // Check for target completion
    _checkTargetCompletion(jumpCount);

    if (currentExerciseData.value != null) {
      currentExerciseData.value = currentExerciseData.value!.copyWith(
        jumpCount: jumpCount,
      );
    } else {
      // Create new minimal data
      final now = DateTime.now();
      currentExerciseData.value = ExerciseData(
        state: ExerciseState.exercising,
        startTime: now,
        duration: 0,
        jumpCount: jumpCount,
        interruptionCount: 0,
        maxContinuousJumps: 0,
        doubleUnderCount: 0,
        realtimeFrequency: 0,
        calories: (jumpCount * 0.1).toInt(), 
        mode: ExerciseMode.freeJump, 
        targetValue: 0,
      );
    }
    print('   ✅ Protocol Update: JumpCount=$jumpCount');
  }


  void _checkTargetCompletion(int currentJumps) {
    if (!_isSessionActive || currentExerciseData.value == null) return;
    
    final data = currentExerciseData.value!;
    
    // Count Mode (Target Jumps)
    if (data.mode == ExerciseMode.count && data.targetValue > 0) {
      if (currentJumps >= data.targetValue) {
        print('🎯 Target Jumps Reached! Stops.');
        stopExercise();
        Get.snackbar(
          'Goal Reached!',
          'You completed ${data.targetValue} jumps!',
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: Duration(seconds: 4),
        );
      }
    }
  }


  // Polling timer for exercise data
  Timer? _exerciseDataTimer;

  /// Start Exercise
  Future<void> startExercise(ExerciseMode mode, int targetValue) async {
    try {
      // Check connection first
      if (!isConnected) {
        throw Exception('Not connected to device. Please reconnect.');
      }

      isLoading.value = true;

      print('📤 Starting exercise via Protocol...');
      print('   Mode: ${mode.displayName}, Target: $targetValue');
      
      // CRITICAL: Send command 0x04 with state 0x01 (Start)
      // This command resets the device counter to zero.
      await _bleService.setExerciseMode(0x01, mode, targetValue);
      print('✅ Reset command (0x04, state=0x01) sent to device');

      // Start polling for exercise data every 1 second
      _exerciseDataTimer?.cancel();
      
      // Initialize Session State
      _isSessionActive = true;

      
      // Initialize local ExerciseData immediately so UI shows "0"
      currentExerciseData.value = ExerciseData(
        state: ExerciseState.exercising,
        startTime: DateTime.now(),
        duration: 0,
        jumpCount: 0,
        interruptionCount: 0,
        maxContinuousJumps: 0,
        doubleUnderCount: 0,
        realtimeFrequency: 0,
        calories: 0,
        mode: mode,
        targetValue: targetValue,
      );

      _exerciseDataTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        if (isConnected) {
          // Request exercise data (command 0x07)
          _bleService.getExerciseData().catchError((e) {
            print('⚠️ Error requesting exercise data: $e');
          });
        } else {
          print('⚠️ Not connected - will retry when reconnected');
        }
        
        // Update Duration locally since we control the start time
        if (_isSessionActive && currentExerciseData.value != null) {
          final start = currentExerciseData.value!.startTime;
          final duration = DateTime.now().difference(start).inSeconds;
          
          currentExerciseData.value = currentExerciseData.value!.copyWith(
            duration: duration,
          );
          
          // Check Countdown (Time) Target
          if (mode == ExerciseMode.countdown && targetValue > 0) {
            if (duration >= targetValue) {
               print('⏰ Time Target Reached! Stopping.');
               timer.cancel(); // Stop timer immediately
               stopExercise();
               Get.snackbar(
                'Time\'s Up!',
                'You completed your ${targetValue}s workout!',
                backgroundColor: Colors.green,
                colorText: Colors.white,
                duration: Duration(seconds: 4),
              );
            }
          }
        }
      });

      // Request data immediately
      if (isConnected) {
        _bleService.getExerciseData().catchError((e) {
          print('⚠️ Initial exercise data request failed: $e');
        });
      }

      print('✅ Exercise started - polling for data every 1 second');
      print(
        '   Auto-push is enabled - will also receive real-time notifications',
      );
      print('   Polling will continue even if device disconnects temporarily');

      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'Failed to start exercise: $e';
      isLoading.value = false;
      print('❌ Error starting exercise: $e');
      _exerciseDataTimer?.cancel();
      _exerciseDataTimer = null;
      rethrow;
    }
  }

  /// Stop Exercise
  Future<void> stopExercise() async {
    try {
      if (!_isSessionActive) return; // Already stopped
      
      isLoading.value = true;
      _isSessionActive = false;

      // Stop polling
      _exerciseDataTimer?.cancel();
      _exerciseDataTimer = null;

      // We still ask device to stop, just in case
      await _bleService.setExerciseMode(2, ExerciseMode.freeJump, 0);

      if (currentExerciseData.value != null) {
        await _saveExerciseToHistory(currentExerciseData.value!);
      }

      currentExerciseData.value = null;
      isLoading.value = false;
    } catch (e) {
      errorMessage.value = 'Failed to stop exercise: $e';
      isLoading.value = false;
    }
  }

  /// Sync Time
  Future<void> syncTimeAndWeight(int weightKg) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _bleService.setTimeAndWeight(timestamp, weightKg);
    } catch (e) {
      errorMessage.value = 'Failed to sync time: $e';
    }
  }

  /// Enable/disable auto push
  Future<void> setAutoPush(bool enabled) async {
    try {
      await _bleService.setAutoPush(enabled);
    } catch (e) {
      errorMessage.value = 'Failed to set auto push: $e';
    }
  }

  // History Management
  Future<void> _loadExerciseHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('exercise_history');
      if (jsonString != null) {
        final List<dynamic> jsonList = json.decode(jsonString);
        exerciseHistory.value = jsonList
            .map((e) => ExerciseData.fromJson(e))
            .toList();
      }
    } catch (e) {
      print('Error loading history: $e');
    }
  }

  Future<void> _saveExerciseToHistory(ExerciseData data) async {
    exerciseHistory.insert(0, data);
    await _persistExerciseHistory();
  }

  Future<void> deleteExercise(int index) async {
    if (index >= 0 && index < exerciseHistory.length) {
      exerciseHistory.removeAt(index);
      await _persistExerciseHistory();
    }
  }

  Future<void> _persistExerciseHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = exerciseHistory.map((e) => e.toJson()).toList();
    await prefs.setString('exercise_history', json.encode(jsonList));
  }
}
