// ignore_for_file: unused_import

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:translation_overlay_practice_3_using_event_channel/overlay_screen.dart';
import 'package:translation_overlay_practice_3_using_event_channel/screen_share_app.dart';




void main() {
  runApp(MyApp());
  
}

@pragma("vm:entry-point")
void overlayMain() {
  runApp(OverlayScreen());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ScreenShareApp(),
    );
  }
}




