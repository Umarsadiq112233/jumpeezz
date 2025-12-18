import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../constants/ble_constants.dart';
import '../models/exercise_data.dart';
import '../utils/byte_utils.dart';

/// BLE Service for YX Smart Jump Rope
class BleService {
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _writeCharacteristic;
  BluetoothCharacteristic? _notifyCharacteristic;

  StreamSubscription? _notificationSubscription;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  final List<StreamSubscription<List<int>>> _characteristicSubscriptions = [];
  final StreamController<List<int>> _notificationController =
      StreamController.broadcast();
  final StreamController<BluetoothConnectionState> _connectionStateController =
      StreamController.broadcast();

  Stream<List<int>> get notificationStream => _notificationController.stream;
  Stream<BluetoothConnectionState> get connectionStateStream =>
      _connectionStateController.stream;

  bool get isConnected {
    if (_connectedDevice == null) return false;
    try {
      // Check the actual connection state from the device
      return _connectedDevice!.isConnected;
    } catch (e) {
      print('Error checking connection state: $e');
      return false;
    }
  }
  BluetoothDevice? get connectedDevice => _connectedDevice;

  /// Start scanning for jump rope devices
  Future<void> startScan() async {
    try {
      print('🚀 BLE SERVICE v2.0 - Starting Scan...');
      // Scan without service filter to find all devices
      // We'll filter by name in the UI instead
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: BleConstants.scanTimeout),
      );
    } catch (e) {
      print('Error starting scan: $e');
      rethrow;
    }
  }

  /// Stop scanning
  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Get scan results stream
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// Connect to a device
  Future<void> connect(BluetoothDevice device) async {
    int maxRetries = 3;
    int retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        print('========================================');
        print(
          '🔵 CONNECTING TO DEVICE (Attempt ${retryCount + 1}/$maxRetries)',
        );
        print('Device Name: ${device.platformName}');
        print('Device ID: ${device.remoteId}');
        print('========================================');

        // Add a small delay before connection attempt (helps with error 133)
        if (retryCount > 0) {
          final delayMs = 1000 * retryCount; // 1s, 2s, 3s
          print('⏳ Waiting ${delayMs}ms before retry...');
          await Future.delayed(Duration(milliseconds: delayMs));
        }

        await device.connect(
          timeout: Duration(seconds: BleConstants.connectionTimeout),
        );
        _connectedDevice = device;

        print('✅ Connection established');

        // CRITICAL FIX: Cancel any existing connection state listener first
        _connectionStateSubscription?.cancel();
        
        // Listen to connection state and STORE the subscription
        _connectionStateSubscription = device.connectionState.listen((state) {
          print('📡 Connection state changed: $state');
          _connectionStateController.add(state);
          if (state == BluetoothConnectionState.disconnected) {
            print('⚠️ Device disconnected');
            _cleanup();
          }
        });

        print('🔍 Discovering services...');

        // Discover services
        List<BluetoothService> services = await device.discoverServices();
        print('✅ Found ${services.length} services');

        // Log all services
        for (var service in services) {
          print('  Service: ${service.uuid}');
        }

        // DEBUG MODE: Log all services and their characteristics
        print('🔍 DEBUG MODE: Exploring all services and characteristics...');
        for (var service in services) {
          print('📦 Service: ${service.uuid}');
          for (var char in service.characteristics) {
            print('  📝 Characteristic: ${char.uuid}');
            print(
              '     Properties: write=${char.properties.write}, '
              'writeWithoutResponse=${char.properties.writeWithoutResponse}, '
              'notify=${char.properties.notify}, '
              'indicate=${char.properties.indicate}',
            );
          }
        }

        // Continue with rest of connection setup...
        await _setupServiceAndCharacteristics(device, services);

        // If we got here, connection was successful
        print('========================================');
        print('✅ CONNECTION SETUP COMPLETE!');
        print('========================================');
        return; // Success, exit retry loop
      } catch (e, stackTrace) {
        retryCount++;

        print('========================================');
        print('❌ CONNECTION ATTEMPT ${retryCount} FAILED!');
        print('Error: $e');

        // Check if it's the dreaded error 133
        if (e.toString().contains('133') ||
            e.toString().contains('ANDROID_SPECIFIC_ERROR')) {
          print('⚠️ Detected Android Error 133 (GATT_ERROR)');
          print('💡 This usually means:');
          print('   1. Device needs to be unpaired in phone settings');
          print('   2. Bluetooth cache needs clearing');
          print('   3. Device is not ready for connection');

          if (retryCount < maxRetries) {
            print('🔄 Will retry connection...');
            // Disconnect before retry
            try {
              await device.disconnect();
            } catch (_) {}
            continue; // Retry
          }
        }

        print('Stack trace:');
        print(stackTrace);
        print('========================================');
        _cleanup();

        if (retryCount >= maxRetries) {
          throw Exception(
            'Failed to connect after $maxRetries attempts. '
            'Error 133 detected - Please:\n'
            '1. Go to phone Settings > Bluetooth\n'
            '2. Forget/Unpair the "TY" device\n'
            '3. Turn Bluetooth OFF and ON\n'
            '4. Try connecting again in the app',
          );
        }
      }
    }
  }

  /// Setup service and characteristics after connection
  Future<void> _setupServiceAndCharacteristics(
    BluetoothDevice device,
    List<BluetoothService> services,
  ) async {
    print('');
    print('🔧 ===========================================');
    print('🔧 STARTING SERVICE & CHARACTERISTIC SETUP');
    print('🔧 ===========================================');

    // CRITICAL: Subscribe to ALL services with notify/indicate characteristics
    // The Wireshark shows handle 0x0012 receives notifications, which might be in a different service

    List<BluetoothCharacteristic> allNotifyCharacteristics = [];
    List<BluetoothCharacteristic> allWriteCharacteristics = [];

    // First, collect ALL notify and write characteristics from ALL services
    for (var service in services) {
      final serviceUuidStr = service.uuid.toString().toLowerCase();
      print('');
      print('📦 Analyzing Service: $serviceUuidStr');

      for (var char in service.characteristics) {
        final charUuidStr = char.uuid.toString().toLowerCase();
        print('  ├─ Char: $charUuidStr');
        print(
          '  │  Properties: W=${char.properties.write}, WNR=${char.properties.writeWithoutResponse}, N=${char.properties.notify}, I=${char.properties.indicate}',
        );

        if (char.properties.notify || char.properties.indicate) {
          allNotifyCharacteristics.add(char);
          print('  │  ✅ Added to notify list');
        }

        if (char.properties.write || char.properties.writeWithoutResponse) {
          allWriteCharacteristics.add(char);
          print('  │  ✅ Added to write list');
        }
      }
    }

    print('');
    print('📊 SUMMARY:');
    print(
      '  Total Notify/Indicate characteristics found: ${allNotifyCharacteristics.length}',
    );
    print(
      '  Total Write characteristics found: ${allWriteCharacteristics.length}',
    );
    print('');

    if (allNotifyCharacteristics.isEmpty || allWriteCharacteristics.isEmpty) {
      throw Exception('No suitable characteristics found!');
    }

    // Find our service (try exact match first, then auto-detect)
    BluetoothService? targetService;

    // First try: exact UUID match
    for (var service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BleConstants.serviceUuid.toLowerCase()) {
        targetService = service;
        print('✅ Target service found (exact match): ${service.uuid}');
        break;
      }
    }

    // Second try: find any service that has both write and notify characteristics
    if (targetService == null) {
      print(
        '⚠️ Expected service UUID not found, searching for compatible service...',
      );
      for (var service in services) {
        // Skip standard Bluetooth services
        final serviceUuidStr = service.uuid.toString().toLowerCase();
        if (serviceUuidStr.startsWith('00001800') || // Generic Access
            serviceUuidStr.startsWith('00001801') || // Generic Attribute
            serviceUuidStr.startsWith('0000180a') || // Device Information
            serviceUuidStr.startsWith('0000180f')) {
          // Battery Service
          continue;
        }

        bool hasWrite = false;
        bool hasNotify = false;

        for (var char in service.characteristics) {
          if (char.properties.write || char.properties.writeWithoutResponse) {
            hasWrite = true;
          }
          if (char.properties.notify || char.properties.indicate) {
            hasNotify = true;
          }
        }

        if (hasWrite && hasNotify) {
          targetService = service;
          print('✅ Compatible service found: ${service.uuid}');
          print('   This service has both write and notify capabilities');
          break;
        }
      }
    }

    if (targetService == null) {
      print('❌ ERROR: No compatible service found!');
      print('Expected service UUID: ${BleConstants.serviceUuid}');
      print('Available services:');
      for (var service in services) {
        print('  - ${service.uuid}');
      }
      throw Exception(
        'No compatible BLE service found. Please share the console output to identify the correct service.',
      );
    }

    print('🔍 Getting characteristics from target service...');

    // Get characteristics - try exact UUID match first
    for (var characteristic in targetService.characteristics) {
      final uuid = characteristic.uuid.toString().toLowerCase();
      print('  Characteristic: $uuid');
      print(
        '    Properties: write=${characteristic.properties.write}, '
        'writeWithoutResponse=${characteristic.properties.writeWithoutResponse}, '
        'notify=${characteristic.properties.notify}, '
        'indicate=${characteristic.properties.indicate}',
      );

      if (uuid == BleConstants.writeCharacteristicUuid.toLowerCase()) {
        _writeCharacteristic = characteristic;
        print('  ✅ Write characteristic found (exact match)');
      } else if (uuid == BleConstants.notifyCharacteristicUuid.toLowerCase()) {
        _notifyCharacteristic = characteristic;
        print('  ✅ Notify characteristic found (exact match)');
      }
    }

    // If exact match not found, auto-detect based on properties
    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      print('⚠️ Exact UUIDs not found, auto-detecting based on properties...');

      for (var characteristic in targetService.characteristics) {
        if (_writeCharacteristic == null &&
            (characteristic.properties.write ||
                characteristic.properties.writeWithoutResponse)) {
          _writeCharacteristic = characteristic;
          print(
            '  ✅ Write characteristic auto-detected: ${characteristic.uuid}',
          );
        }

        if (_notifyCharacteristic == null &&
            (characteristic.properties.notify ||
                characteristic.properties.indicate)) {
          _notifyCharacteristic = characteristic;
          print(
            '  ✅ Notify characteristic auto-detected: ${characteristic.uuid}',
          );
        }
      }
    }

    if (_writeCharacteristic == null || _notifyCharacteristic == null) {
      print('❌ ERROR: Required characteristics not found!');
      print(
        'Write characteristic: ${_writeCharacteristic != null ? "Found" : "Missing"}',
      );
      print(
        'Notify characteristic: ${_notifyCharacteristic != null ? "Found" : "Missing"}',
      );
      print('Available characteristics in service ${targetService.uuid}:');
      for (var char in targetService.characteristics) {
        print(
          '  - ${char.uuid} (write: ${char.properties.write}, '
          'writeWithoutResponse: ${char.properties.writeWithoutResponse}, '
          'notify: ${char.properties.notify}, '
          'indicate: ${char.properties.indicate})',
        );
      }
      throw Exception(
        'Required characteristics not found. Please share the console output.',
      );
    }

    print('');
    print('🔔 ===========================================');
    print('🔔 SUBSCRIBING TO ALL NOTIFY CHARACTERISTICS');
    print('🔔 ===========================================');

    // CRITICAL FIX: Subscribe to ALL notify/indicate characteristics
    // This ensures we don't miss data coming from unexpected handles
    int subscriptionCount = 0;
    for (var char in allNotifyCharacteristics) {
      try {
        print('');
        print(
          '📡 Setting up listener ${subscriptionCount + 1}/${allNotifyCharacteristics.length}: ${char.uuid}',
        );

        // Set up listener and STORE the subscription to prevent garbage collection
        final subscription = char.onValueReceived.listen(
          (value) {
            print('');
            print('🔔 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
            print('🔔 NOTIFICATION FROM: ${char.uuid}');
            print(
              '🔔 RAW HEX: ${value.map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase()).join(' ')}',
            );
            print('🔔 RAW DEC: ${value.join(' ')}');
            print('🔔 LENGTH: ${value.length} bytes');
            print('🔔 ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

            if (value.isNotEmpty) {
              // Only send to main notification stream
              _notificationController.add(value);
            } else {
              print('⚠️ Empty notification received');
            }
          },
          onError: (error) {
            print('❌ Notification error on ${char.uuid}: $error');
          },
        );

        // CRITICAL: Store subscription to prevent garbage collection
        _characteristicSubscriptions.add(subscription);

        // Enable notifications
        await char.setNotifyValue(true);
        subscriptionCount++;
        print('✅ Subscribed successfully');

        // Small delay between subscriptions
        await Future.delayed(Duration(milliseconds: 100));
      } catch (e) {
        print('⚠️ Failed to subscribe to ${char.uuid}: $e');
        // Continue with other characteristics
      }
    }

    print('');
    print(
      '✅ Subscribed to $subscriptionCount/${allNotifyCharacteristics.length} notify characteristics',
    );
    print('');

    // Wait a bit before setting MTU
    print('⏳ Waiting 500ms before setting MTU...');
    await Future.delayed(Duration(milliseconds: 500));

    // Set MTU
    try {
      print('📶 Setting MTU to ${BleConstants.mtuSize}...');
      final mtu = await device.requestMtu(BleConstants.mtuSize);
      print('✅ MTU set to: $mtu');
    } catch (e) {
      print('⚠️ Failed to set MTU: $e (continuing anyway)');
    }

    // Wait a bit for the subscription to be fully active and MTU to settle
    print('⏳ Waiting 2000ms for all subscriptions to stabilize...');
    await Future.delayed(Duration(milliseconds: 2000));

    print('');
    print('✅ ===========================================');
    print('✅ SETUP COMPLETE - READY TO RECEIVE DATA');
    print('✅ ===========================================');
    print('');
  }

  /// Disconnect from device
  Future<void> disconnect() async {
    if (_connectedDevice != null) {
      try {
        await _connectedDevice!.disconnect();
      } catch (e) {
        print('Disconnect error: $e');
      }
      _cleanup();
    }
  }

  /// Clean up resources
  void _cleanup() {
    _notificationSubscription?.cancel();
    _notificationSubscription = null;

    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;

    // Cancel all characteristic subscriptions
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();

    _writeCharacteristic = null;
    _notifyCharacteristic = null;
    _connectedDevice = null;
  }

  /// Send command to device
  Future<void> _sendCommand(List<int> command) async {
    if (_writeCharacteristic == null) {
      throw Exception('Not connected to device');
    }

    try {
      print('Sending command: ${ByteUtils.formatHexString(command)}');

      // Use writeWithoutResponse if the characteristic supports it
      final useWriteWithoutResponse =
          _writeCharacteristic!.properties.writeWithoutResponse;

      await _writeCharacteristic!.write(
        command,
        withoutResponse: useWriteWithoutResponse,
      );

      print(
        'Command sent successfully (writeWithoutResponse: $useWriteWithoutResponse)',
      );
    } catch (e) {
      print('Failed to send command: $e');
      rethrow;
    }
  }

  /// Get device information (command 0x01)
  Future<void> getDeviceInfo() async {
    print('📤 Requesting device info...');

    // Try writing command
    await _sendCommand([0x01, 0x01, 0x01]);
  }

  /// Test if device sends data spontaneously (for physical activity)
  Future<void> testSpontaneousData() async {
    print('🧪 Testing for spontaneous notifications...');
    print('💡 Try jumping with the rope now!');
    print('⏱️ Waiting 10 seconds for any notifications...');

    await Future.delayed(Duration(seconds: 10));
    print('✅ Test complete - check logs above for any notifications');
  }

  /// Set UTC time and weight (command 0x02)
  Future<void> setTimeAndWeight(int timestamp, int weightKg) async {
    final timeBytes = ByteUtils.convertIntTo4Bytes(timestamp);
    final weightBytes = ByteUtils.convertIntTo2Bytes(weightKg);

    await _sendCommand([0x01, 0x07, 0x02, ...timeBytes, ...weightBytes]);
  }

  /// Get device state (command 0x03)
  Future<void> getDeviceState() async {
    await _sendCommand([0x01, 0x01, 0x03]);
  }

  /// Set exercise mode (command 0x04)
  /// state: 0=Standby, 1=Start, 2=End
  /// mode: 0=Free Jump, 1=Countdown, 2=Count
  /// targetValue: seconds for countdown, jumps for count mode
  Future<void> setExerciseMode(
    int state,
    ExerciseMode mode,
    int targetValue,
  ) async {
    final targetBytes = ByteUtils.convertIntTo4Bytes(targetValue);

    await _sendCommand([
      0x01,
      0x07,
      0x04,
      state,
      mode.toByte(),
      ...targetBytes,
    ]);
  }

  /// Enable/disable auto push (command 0x05)
  Future<void> setAutoPush(bool enabled) async {
    await _sendCommand([0x01, 0x02, 0x05, enabled ? 0x01 : 0x00]);
  }

  /// Get exercise data (command 0x07)
  Future<void> getExerciseData() async {
    await _sendCommand([0x01, 0x01, 0x07]);
  }

  /// Dispose resources
  void dispose() {
    _notificationController.close();
    _connectionStateController.close();
    _notificationSubscription?.cancel();
    _connectionStateSubscription?.cancel();

    // Cancel all characteristic subscriptions
    for (var subscription in _characteristicSubscriptions) {
      subscription.cancel();
    }
    _characteristicSubscriptions.clear();
  }
}
