# YXTS Jump Rope SDK - Quick Reference

## BLE Connection Parameters

### Standard YXTS Devices
```
Service UUID:        00001910-0000-1000-8000-00805f9b34fb
Write Characteristic: 00002b11-0000-1000-8000-00805f9b34fb  
Notify Characteristic: 00002b10-0000-1000-8000-00805f9b34fb
MTU Size:            131 bytes
```

### YS838 Devices (Auto-detected)
```
Service UUID:        000000ff-0000-1000-8000-00805f9b34fb
Write Characteristic: 0000ff02-0000-1000-8000-00805f9b34fb
Notify Characteristic: 0000ff01-0000-1000-8000-00805f9b34fb
MTU Size:            131 bytes
```

## Command Reference

### 0x01 - Get Device Information
**Request:**
```
[0x01, 0x01, 0x01]
```

**Response:** 40 bytes
```
Byte 0-1:   Length (0x01, 0x26)
Byte 2:     Command (0x01)
Byte 3-22:  Serial Number (null-terminated string)
Byte 23-29: Software Version (null-terminated string)
Byte 30-33: BLE Version (null-terminated string)
Byte 34-39: MAC Address (6 bytes)
```

**Example:**
```dart
await writeCharacteristic.write([0x01, 0x01, 0x01], withoutResponse: true);
```

---

### 0x02 - Set Time & Weight
**Request:**
```
[0x01, 0x07, 0x02, UTC_Time(4 bytes), Weight(2 bytes)]
```

**Parameters:**
- **UTC_Time**: 4 bytes, big-endian, seconds since Unix epoch
- **Weight**: 2 bytes, big-endian, in kilograms

**Example:**
```dart
final utcTime = DateTime.now().millisecondsSinceEpoch ~/ 1000;
final weight = 70; // kg

final command = [
  0x01, 0x07, 0x02,
  (utcTime >> 24) & 0xFF,
  (utcTime >> 16) & 0xFF,
  (utcTime >> 8) & 0xFF,
  utcTime & 0xFF,
  (weight >> 8) & 0xFF,
  weight & 0xFF,
];

await writeCharacteristic.write(command, withoutResponse: true);
```

---

### 0x03 - Get Device State
**Request:**
```
[0x01, 0x01, 0x03]
```

**Response:** Variable length
```
Byte 0-1:   Length
Byte 2:     Command (0x03)
Byte 3:     Battery Level (0-100%)
Byte 4:     Device State
            0x00 = Idle
            0x01 = Exercising
            0x02 = Paused
            0x03 = Charging
```

**Example:**
```dart
await writeCharacteristic.write([0x01, 0x01, 0x03], withoutResponse: true);
```

---

### 0x04 - Set Exercise Mode
**Request:**
```
[0x01, 0x07, 0x04, State, Mode, Target(4 bytes)]
```

**Parameters:**
- **State**: 
  - `0x00` = Standby
  - `0x01` = Start
  - `0x02` = End
- **Mode**:
  - `0x00` = Free Jump (no limit)
  - `0x01` = Countdown (time-based)
  - `0x02` = Count (jump count goal)
- **Target**: 4 bytes, big-endian
  - For Countdown: seconds
  - For Count: jump count
  - For Free Jump: 0

**⚠️ Important:** YS838 devices disconnect when receiving this command. Skip for YS838.

**Example:**
```dart
// Start countdown mode for 60 seconds
final command = [
  0x01, 0x07, 0x04,
  0x01,  // Start
  0x01,  // Countdown mode
  0x00, 0x00, 0x00, 0x3C,  // 60 seconds
];

await writeCharacteristic.write(command, withoutResponse: true);
```

---

### 0x05 - Set Auto-Push
**Request:**
```
[0x01, 0x02, 0x05, Enable]
```

**Parameters:**
- **Enable**:
  - `0x00` = Disable auto-push
  - `0x01` = Enable auto-push

**Response:**
```
[0x01, 0x02, 0x05, Status]
```

**Example:**
```dart
// Enable auto-push
await writeCharacteristic.write([0x01, 0x02, 0x05, 0x01], withoutResponse: true);
```

---

### 0x06 - Real-time Data (Auto-pushed)
**Notification:** 31 bytes (same format as 0x07)

This data is automatically sent by the device when auto-push is enabled.

**Format:** Same as command 0x07 response (see below)

---

### 0x07 - Get Exercise Data
**Request:**
```
[0x01, 0x01, 0x07]
```

**Response:** 31 bytes
```
Byte 0-1:   Length (0x01, 0x1D)
Byte 2:     Command (0x07)
Byte 3:     Exercise State
            0x00 = Exercising
            0x01 = Paused
            0x03 = Idle
Byte 4-7:   Start Time (UTC, 4 bytes, big-endian)
Byte 8-9:   Duration (seconds, 2 bytes, big-endian)
Byte 10-13: Jump Count (4 bytes, big-endian) ⭐ PRIMARY DATA
Byte 14-15: Interruption Count (2 bytes, big-endian)
Byte 16-17: Trip Count (2 bytes, big-endian)
Byte 18-21: Calories (4 bytes, big-endian)
Byte 22-25: Max Frequency (4 bytes, big-endian)
Byte 26-29: Average Frequency (4 bytes, big-endian)
Byte 30:    Reserved
```

**Example:**
```dart
// Request exercise data
await writeCharacteristic.write([0x01, 0x01, 0x07], withoutResponse: true);

// Parse response
void parseExerciseData(List<int> data) {
  if (data.length < 31) return;
  
  final state = data[3];
  final duration = (data[8] << 8) | data[9];
  final jumpCount = (data[10] << 24) | (data[11] << 16) | (data[12] << 8) | data[13];
  
  print('State: $state');
  print('Duration: ${duration}s');
  print('Jump Count: $jumpCount');
}
```

---

## Data Parsing Utilities

### Big-Endian to Integer
```dart
int bytesToInt(List<int> bytes) {
  int value = 0;
  for (int i = 0; i < bytes.length; i++) {
    value += (bytes[i] & 0xFF) << ((bytes.length - 1 - i) * 8);
  }
  return value;
}

// Usage
final jumpCount = bytesToInt(data.sublist(10, 14));
```

### Integer to Big-Endian Bytes
```dart
List<int> intToBytes(int value, int byteCount) {
  List<int> bytes = [];
  for (int i = byteCount - 1; i >= 0; i--) {
    bytes.add((value >> (i * 8)) & 0xFF);
  }
  return bytes;
}

// Usage
final timeBytes = intToBytes(utcTime, 4);
```

---

## Common Workflows

### Initial Connection Setup
```dart
1. Connect to device
2. Discover services
3. Auto-detect service & characteristics
4. Subscribe to notify characteristic
5. Set MTU to 131
6. Send Get Device Info (0x01)
7. Enable Auto-Push (0x05, 0x01)
8. Ready for exercise
```

### Start Exercise (Standard YXTS)
```dart
1. Send Set Exercise Mode (0x04)
2. Start polling timer (1 second interval)
3. Send Get Exercise Data (0x07) every second
4. Receive data via 0x06 (auto-push) and 0x07 (response)
5. Parse jump count from bytes 10-13
6. Update UI
```

### Start Exercise (YS838)
```dart
1. Skip Set Exercise Mode (causes disconnection)
2. Show instruction to user: "Press button on device"
3. Start polling timer (1 second interval)
4. Send Get Exercise Data (0x07) every second
5. Device auto-pushes data (0x06) when user starts
6. Parse jump count from bytes 10-13
7. Update UI
```

### Stop Exercise
```dart
1. Stop polling timer
2. Send Set Exercise Mode (0x04, state=0x02)
3. Get final exercise data (0x07)
4. Save to history
5. Return to device screen
```

---

## Error Codes

### Android GATT Errors
```
133 = GATT_ERROR
     Solution: Unpair device in Bluetooth settings, reconnect

19  = REMOTE_USER_TERMINATED_CONNECTION
     Solution: For YS838, skip exercise mode command
```

### Common Issues

**Device not found in scan:**
- Check device name matches filter
- Ensure device is powered on
- Verify Bluetooth permissions

**Connection fails:**
- Unpair device in phone settings
- Restart Bluetooth
- Try automatic retry (max 3 attempts)

**No data received:**
- Check auto-push is enabled (0x05)
- Verify notification subscription
- Ensure polling timer is active

**Jump count not updating:**
- Check connection state
- Verify device is in exercising state
- Check bytes 10-13 in response data

---

## Testing Commands

### Test Connection
```dart
// Should receive 40-byte response with device info
await write([0x01, 0x01, 0x01]);
```

### Test Auto-Push
```dart
// Should receive [0x01, 0x02, 0x05, 0x01] response
await write([0x01, 0x02, 0x05, 0x01]);
```

### Test Exercise Data
```dart
// Should receive 31-byte response
await write([0x01, 0x01, 0x07]);
```

---

## Best Practices

1. **Always use `writeWithoutResponse: true`** for faster communication
2. **Set MTU to 131** for optimal data transfer
3. **Subscribe to all notify characteristics** to ensure data reception
4. **Implement retry logic** for Android Error 133
5. **Use dual strategy** (auto-push + polling) for reliable data
6. **Validate data length** before parsing
7. **Handle disconnections gracefully** with automatic reconnect
8. **Clean up subscriptions** on disconnect to prevent memory leaks

---

**SDK Version:** 1.0  
**Compatible Devices:** TY, ROGUE, YS137, YX, YS838  
**Last Updated:** 2025-12-11
