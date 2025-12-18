/// BLE Protocol Constants for YX Smart Jump Rope
class BleConstants {
  // Service UUID
  static const String serviceUuid = "00001910-0000-1000-8000-00805f9b34fb";
  
  // Characteristic UUIDs
  static const String writeCharacteristicUuid = "00002b11-0000-1000-8000-00805f9b34fb";
  static const String notifyCharacteristicUuid = "00002b10-0000-1000-8000-00805f9b34fb";
  
  // Device name prefixes
  static const List<String> deviceNamePrefixes = ["TY", "Rogue", "YS137", "YX","YS838"];
  
  // Protocol Commands
  static const int cmdGetDeviceInfo = 0x01;
  static const int cmdSetTime = 0x02;
  static const int cmdGetDeviceState = 0x03;
  static const int cmdSetMode = 0x04;
  static const int cmdSetAutoPush = 0x05;
  static const int cmdRealtimeData = 0x06;
  static const int cmdGetExerciseData = 0x07;
  
  // Connection Parameters
  static const int mtuSize = 131;
  static const int scanTimeout = 20; // seconds
  static const int connectionTimeout = 10; // seconds
}
