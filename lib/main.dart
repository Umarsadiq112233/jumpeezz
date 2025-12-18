import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'controllers/ble_controller.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize controller 
    Get.put(BleController()); 
    
    return GetMaterialApp(
      title: 'JumpEezzz',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}
