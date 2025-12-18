import '../utils/byte_utils.dart';

/// Device state enum
enum DeviceState {
  idle,
  exercising,
  paused,
  ended,
  charging,
  lowBattery,
  ota;

  static DeviceState fromByte(int value) {
    switch (value) {
      case 0x00:
        return DeviceState.idle;
      case 0x01:
        return DeviceState.exercising;
      case 0x02:
        return DeviceState.paused;
      case 0x03:
        return DeviceState.ended;
      case 0x04:
        return DeviceState.charging;
      case 0x05:
        return DeviceState.lowBattery;
      default:
        return DeviceState.ota;
    }
  }

  String get displayName {
    switch (this) {
      case DeviceState.idle:
        return 'Idle';
      case DeviceState.exercising:
        return 'Exercising';
      case DeviceState.paused:
        return 'Paused';
      case DeviceState.ended:
        return 'Ended';
      case DeviceState.charging:
        return 'Charging';
      case DeviceState.lowBattery:
        return 'Low Battery';
      case DeviceState.ota:
        return 'OTA Mode';
    }
  }
}

/// Device information model
class DeviceInfo {
  final String serialNumber;
  final String softwareVersion;
  final String bleVersion;
  final String macAddress;
  final DeviceState state;
  final int batteryLevel; // 0-100

  DeviceInfo({
    required this.serialNumber,
    required this.softwareVersion,
    required this.bleVersion,
    required this.macAddress,
    this.state = DeviceState.idle,
    this.batteryLevel = 0,
  });

  /// Parse device info from response (command 0x01)
  factory DeviceInfo.fromInfoBytes(List<int> data) {
    // Parse null-terminated strings
    final strings = ByteUtils.parseNullTerminatedStrings(data, 3);
    
    String sn = strings.isNotEmpty ? strings[0] : 'Unknown';
    String software = strings.length > 1 ? strings[1] : 'Unknown';
    String ble = strings.length > 2 ? strings[2] : 'Unknown';
    String mac = strings.length > 3 
        ? ByteUtils.formatHexString(strings[3].codeUnits) 
        : 'Unknown';

    return DeviceInfo(
      serialNumber: sn,
      softwareVersion: software,
      bleVersion: ble,
      macAddress: mac,
    );
  }

  /// Parse device state from response (command 0x03)
  static DeviceState parseState(List<int> data) {
    if (data.length >= 4) {
      return DeviceState.fromByte(data[3]);
    }
    return DeviceState.idle;
  }

  /// Parse battery level from response (command 0x03)
  static int parseBattery(List<int> data) {
    if (data.length >= 5) {
      return data[4];
    }
    return 0;
  }

  /// Copy with method
  DeviceInfo copyWith({
    String? serialNumber,
    String? softwareVersion,
    String? bleVersion,
    String? macAddress,
    DeviceState? state,
    int? batteryLevel,
  }) {
    return DeviceInfo(
      serialNumber: serialNumber ?? this.serialNumber,
      softwareVersion: softwareVersion ?? this.softwareVersion,
      bleVersion: bleVersion ?? this.bleVersion,
      macAddress: macAddress ?? this.macAddress,
      state: state ?? this.state,
      batteryLevel: batteryLevel ?? this.batteryLevel,
    );
  }
}
