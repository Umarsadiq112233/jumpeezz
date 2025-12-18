import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// Device tile for scan results
class DeviceTile extends StatelessWidget {
  final ScanResult result;
  final VoidCallback onTap;

  const DeviceTile({
    Key? key,
    required this.result,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final device = result.device;
    final rssi = result.rssi;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFF0D47A1).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.bluetooth,
                    color: Color(0xFF0D47A1), // Deep blue
                    size: 28,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.platformName.isNotEmpty 
                            ? device.platformName 
                            : 'Unknown Device',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D47A1), // Deep blue
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        device.remoteId.toString(),
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF424242), // Dark gray
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(
                      _getSignalIcon(rssi),
                      color: _getSignalColor(rssi),
                      size: 24,
                    ),
                    SizedBox(height: 4),
                    Text(
                      '$rssi dBm',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF424242), // Dark gray
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getSignalIcon(int rssi) {
    if (rssi >= -60) return Icons.signal_cellular_alt;
    if (rssi >= -70) return Icons.signal_cellular_alt_2_bar;
    return Icons.signal_cellular_alt_1_bar;
  }

  Color _getSignalColor(int rssi) {
    if (rssi >= -60) return Color(0xFF4CAF50); // Green
    if (rssi >= -70) return Color(0xFFFF9800); // Orange
    return Color(0xFFD32F2F); // Red
  }
}
