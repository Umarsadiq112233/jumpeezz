/// Utility functions for byte array conversions
class ByteUtils {
  /// Convert int to 4 bytes (big-endian)
  static List<int> convertIntTo4Bytes(int value) {
    return [
      (value >> 24) & 0xFF,
      (value >> 16) & 0xFF,
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Convert int to 2 bytes (big-endian)
  static List<int> convertIntTo2Bytes(int value) {
    return [
      (value >> 8) & 0xFF,
      value & 0xFF,
    ];
  }

  /// Convert bytes to int (big-endian)
  static int bytesToInt(List<int> bytes) {
    int value = 0;
    for (int i = 0; i < bytes.length; i++) {
      value += (bytes[i] & 0xFF) << ((bytes.length - 1 - i) * 8);
    }
    return value;
  }

  /// Format byte array as hex string
  static String formatHexString(List<int> bytes, {bool withSpaces = true}) {
    return bytes
        .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(withSpaces ? ' ' : '');
  }

  /// Parse null-terminated strings from byte array
  static List<String> parseNullTerminatedStrings(List<int> data, int startIndex) {
    List<String> results = [];
    int start = startIndex;
    
    for (int i = startIndex; i < data.length; i++) {
      if (data[i] == 0x00 && i > start) {
        // Found null terminator
        results.add(String.fromCharCodes(data.sublist(start, i)));
        start = i + 1;
      }
    }
    
    // Add remaining bytes if any (for MAC address or last string)
    if (start < data.length) {
      results.add(String.fromCharCodes(data.sublist(start)));
    }
    
    return results;
  }
}
