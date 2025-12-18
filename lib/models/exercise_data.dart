import '../utils/byte_utils.dart';

/// Exercise state enum
enum ExerciseState {
  exercising,
  paused,
  ended,
  idle;

  static ExerciseState fromByte(int value) {
    switch (value) {
      case 0x00:
        return ExerciseState.exercising;
      case 0x01:
        return ExerciseState.paused;
      case 0x02:
        return ExerciseState.ended;
      default:
        return ExerciseState.idle;
    }
  }

  String get displayName {
    switch (this) {
      case ExerciseState.exercising:
        return 'Exercising';
      case ExerciseState.paused:
        return 'Paused';
      case ExerciseState.ended:
        return 'Ended';
      case ExerciseState.idle:
        return 'Idle';
    }
  }
}

/// Exercise mode enum
enum ExerciseMode {
  freeJump,
  countdown,
  count;

  static ExerciseMode fromByte(int value) {
    switch (value) {
      case 0x00:
        return ExerciseMode.freeJump;
      case 0x01:
        return ExerciseMode.countdown;
      case 0x02:
        return ExerciseMode.count;
      default:
        return ExerciseMode.freeJump;
    }
  }

  int toByte() {
    switch (this) {
      case ExerciseMode.freeJump:
        return 0x00;
      case ExerciseMode.countdown:
        return 0x01;
      case ExerciseMode.count:
        return 0x02;
    }
  }

  String get displayName {
    switch (this) {
      case ExerciseMode.freeJump:
        return 'Free Jump';
      case ExerciseMode.countdown:
        return 'Countdown';
      case ExerciseMode.count:
        return 'Count';
    }
  }
}

/// Exercise data model
class ExerciseData {
  final ExerciseState state;
  final DateTime startTime;
  final int duration; // seconds
  final int jumpCount;
  final int interruptionCount;
  final int maxContinuousJumps;
  final int doubleUnderCount;
  final int realtimeFrequency; // jumps per minute
  final int calories;
  final ExerciseMode mode;
  final int targetValue;

  ExerciseData({
    required this.state,
    required this.startTime,
    required this.duration,
    required this.jumpCount,
    required this.interruptionCount,
    required this.maxContinuousJumps,
    required this.doubleUnderCount,
    required this.realtimeFrequency,
    required this.calories,
    required this.mode,
    required this.targetValue,
  });

  /// Parse exercise data from byte array
  /// According to YXTS SDK: data structure starts at index 3
  /// - data[3] = state
  /// - data[4-7] = start time (4 bytes)
  /// - data[8-9] = duration (2 bytes)
  /// - data[10-13] = jump count (4 bytes)
  /// - data[14-15] = interruption count (2 bytes)
  /// - data[16-17] = max continuous jumps (2 bytes)
  /// - data[18-19] = double under count (2 bytes)
  /// - data[20-21] = realtime frequency (2 bytes)
  /// - data[22-25] = calories (4 bytes)
  /// - data[26] = mode
  /// - data[27-30] = target value (4 bytes)
  factory ExerciseData.fromBytes(List<int> data) {
    // Need at least 31 bytes (index 0-30)
    if (data.length < 31) {
      throw ArgumentError('Invalid exercise data length: ${data.length} (need at least 31 bytes)');
    }

    return ExerciseData(
      state: ExerciseState.fromByte(data[3]),
      startTime: DateTime.fromMillisecondsSinceEpoch(
        ByteUtils.bytesToInt(data.sublist(4, 8)) * 1000,
      ),
      duration: ByteUtils.bytesToInt(data.sublist(8, 10)),
      jumpCount: ByteUtils.bytesToInt(data.sublist(10, 14)), // 4 bytes, big-endian
      interruptionCount: ByteUtils.bytesToInt(data.sublist(14, 16)),
      maxContinuousJumps: ByteUtils.bytesToInt(data.sublist(16, 18)),
      doubleUnderCount: ByteUtils.bytesToInt(data.sublist(18, 20)),
      realtimeFrequency: ByteUtils.bytesToInt(data.sublist(20, 22)),
      calories: ByteUtils.bytesToInt(data.sublist(22, 26)),
      mode: ExerciseMode.fromByte(data[26]),
      targetValue: ByteUtils.bytesToInt(data.sublist(27, 31)),
    );
  }

  /// Convert to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'state': state.index,
      'startTime': startTime.millisecondsSinceEpoch,
      'duration': duration,
      'jumpCount': jumpCount,
      'interruptionCount': interruptionCount,
      'maxContinuousJumps': maxContinuousJumps,
      'doubleUnderCount': doubleUnderCount,
      'realtimeFrequency': realtimeFrequency,
      'calories': calories,
      'mode': mode.index,
      'targetValue': targetValue,
    };
  }

  /// Create from JSON
  factory ExerciseData.fromJson(Map<String, dynamic> json) {
    return ExerciseData(
      state: ExerciseState.values[json['state']],
      startTime: DateTime.fromMillisecondsSinceEpoch(json['startTime']),
      duration: json['duration'],
      jumpCount: json['jumpCount'],
      interruptionCount: json['interruptionCount'],
      maxContinuousJumps: json['maxContinuousJumps'],
      doubleUnderCount: json['doubleUnderCount'],
      realtimeFrequency: json['realtimeFrequency'],
      calories: json['calories'],
      mode: ExerciseMode.values[json['mode']],
      targetValue: json['targetValue'],
    );
  }

  /// Formatted duration string (HH:MM:SS)
  String get formattedDuration {
    final hours = duration ~/ 3600;
    final minutes = (duration % 3600) ~/ 60;
    final seconds = duration % 60;
    
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Copy with method for updates
  ExerciseData copyWith({
    ExerciseState? state,
    DateTime? startTime,
    int? duration,
    int? jumpCount,
    int? interruptionCount,
    int? maxContinuousJumps,
    int? doubleUnderCount,
    int? realtimeFrequency,
    int? calories,
    ExerciseMode? mode,
    int? targetValue,
  }) {
    return ExerciseData(
      state: state ?? this.state,
      startTime: startTime ?? this.startTime,
      duration: duration ?? this.duration,
      jumpCount: jumpCount ?? this.jumpCount,
      interruptionCount: interruptionCount ?? this.interruptionCount,
      maxContinuousJumps: maxContinuousJumps ?? this.maxContinuousJumps,
      doubleUnderCount: doubleUnderCount ?? this.doubleUnderCount,
      realtimeFrequency: realtimeFrequency ?? this.realtimeFrequency,
      calories: calories ?? this.calories,
      mode: mode ?? this.mode,
      targetValue: targetValue ?? this.targetValue,
    );
  }
}
