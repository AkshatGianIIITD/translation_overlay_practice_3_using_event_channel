
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

class ScreenShareApp extends StatefulWidget {
  @override
  _ScreenShareAppState createState() => _ScreenShareAppState();
}

class _ScreenShareAppState extends State<ScreenShareApp> {
  static const platform = MethodChannel('screen_share');
  static const eventChannel = EventChannel('screen_capture_event');

  Uint8List? imageBytes;
  bool isProcessing = false;
  bool debugFlag = true;

  TextRecognizer? textRecognizer;
  OnDeviceTranslator? translator;

  TranslateLanguage _targetLanguage = TranslateLanguage.hindi;
  TextRecognitionScript _selectedScript = TextRecognitionScript.latin;

  DateTime? _lastProcessedTime;
  String? _lastFrameHash;

  @override
  void initState() {
    super.initState();
    initializeTextRecognizer();
    translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: _targetLanguage,
    );
    Future.microtask(() async {
      if (!await FlutterOverlayWindow.isPermissionGranted()) {
        await FlutterOverlayWindow.requestPermission();
      }
    });

    eventChannel.receiveBroadcastStream().listen((data) async {
      if (data == null) {
        print("The data is null");
        return;
      }

      if (isProcessing) return;

      if (_lastProcessedTime != null &&
          DateTime.now().difference(_lastProcessedTime!) <
              Duration(milliseconds: 500)) {
        return;
      }

      String currentHash = data.hashCode.toString();
      if (_lastFrameHash == currentHash) return;
      _lastFrameHash = currentHash;

      _lastProcessedTime = DateTime.now();
      isProcessing = true;

      try {
        data = data.replaceAll(RegExp(r'\s'), '');
        imageBytes = base64Decode(data.trim());

        List<Map<String, dynamic>> textData =
            await extractTextFromFrame(imageBytes!);
        List<Map<String, dynamic>> translatedTextData =
            await translateTextBlocks(textData);

        if (!await FlutterOverlayWindow.isActive()) {
          sendOverlayData(translatedTextData);
          debugFlag = false;
        } else {
          FlutterOverlayWindow.shareData(jsonEncode(translatedTextData));
        }
      } catch (e) {
        debugPrint("Error processing frame: $e");
      } finally {
        isProcessing = false;
      }
    });
  }

  void initializeTextRecognizer() {
    textRecognizer?.close();
    textRecognizer = TextRecognizer(script: _selectedScript);
  }

  void startScreenCapture() async {
    await platform.invokeMethod('startScreenCapture');
  }

  void stopScreenCapture() async {
    await platform.invokeMethod('stopScreenCapture');
    await FlutterOverlayWindow.closeOverlay();
  }

  int _pixelToInt(img.Pixel pixel) {
    return (pixel.a.toInt() << 24) |
        (pixel.r.toInt() << 16) |
        (pixel.g.toInt() << 8) |
        pixel.b.toInt();
  }

  int _getDominantColor(img.Image image) {
    final colorCount = <int, int>{};

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final color = _pixelToInt(pixel);
        colorCount[color] = (colorCount[color] ?? 0) + 1;
      }
    }

    return colorCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  int _getFontColor(img.Image image, int bgColor, {int threshold = 100}) {
    final colorCount = <int, int>{};

    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final color = _pixelToInt(pixel);
        if (_colorDistance(color, bgColor) > threshold) {
          colorCount[color] = (colorCount[color] ?? 0) + 1;
        }
      }
    }

    if (colorCount.isEmpty) return 0xFF000000;
    return colorCount.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  double _colorDistance(int color1, int color2) {
    int r1 = (color1 >> 16) & 0xFF;
    int g1 = (color1 >> 8) & 0xFF;
    int b1 = color1 & 0xFF;

    int r2 = (color2 >> 16) & 0xFF;
    int g2 = (color2 >> 8) & 0xFF;
    int b2 = color2 & 0xFF;

    return sqrt(pow(r1 - r2, 2) + pow(g1 - g2, 2) + pow(b1 - b2, 2));
  }

  Future<List<Map<String, dynamic>>> extractTextFromFrame(
      Uint8List imageBytes) async {
    final stopwatch = Stopwatch()..start();

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/temp_image.jpg');
    await tempFile.writeAsBytes(imageBytes);

    final inputImage = InputImage.fromFilePath(tempFile.path);
    final RecognizedText recognizedText =
        await textRecognizer!.processImage(inputImage);

    img.Image? image = img.decodeImage(imageBytes);

    List<Map<String, dynamic>> textData = [];
    for (TextBlock block in recognizedText.blocks) {
      final rect = block.boundingBox;

      final cropped = img.copyCrop(
        image!,
        x: rect.left.toInt(),
        y: rect.top.toInt(),
        width: rect.width.toInt(),
        height: rect.height.toInt(),
      );

      final bgColor = _getDominantColor(cropped);
      final flutterBgColor = Color(bgColor);
      final fontColor = _getFontColor(cropped, bgColor);
      final flutterFontColor = Color(fontColor);

      textData.add({
        "text": block.text,
        "boundingBox": {
          "left": block.boundingBox.left,
          "top": block.boundingBox.top,
          "width": block.boundingBox.width,
          "height": block.boundingBox.height,
        },
        "backgroundColor": flutterBgColor.value,
        "fontColor": flutterFontColor.value,
        "numLines": block.lines.length,
      });
    }

    stopwatch.stop();
    print("Processing Time: ${stopwatch.elapsedMilliseconds} ms");

    return textData;
  }

  Future<List<Map<String, dynamic>>> translateTextBlocks(
      List<Map<String, dynamic>> textData) async {
    for (var data in textData) {
      data["translatedText"] = await translator!.translateText(data["text"]);
    }
    return textData;
  }

  void sendOverlayData(List<Map<String, dynamic>> textData) async {
    Size screenSize = MediaQuery.of(context).size;
    double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

    for (var data in textData) {
      data["boundingBox"]["left"] *= devicePixelRatio;
      data["boundingBox"]["top"] *= devicePixelRatio;
      data["boundingBox"]["width"] *= devicePixelRatio;
      data["boundingBox"]["height"] *= devicePixelRatio;
    }

    print("Actual Screen Size: ${screenSize.width} x ${screenSize.height}");
    print("Device Pixel Ratio: $devicePixelRatio");
    Future.delayed(Duration(milliseconds: 300), () async {
      await FlutterOverlayWindow.showOverlay(
        overlayContent: jsonEncode(textData),
        height: WindowSize.fullCover,
        width: (screenSize.width * devicePixelRatio).toInt(),
        enableDrag: false,
        flag: OverlayFlag.clickThrough,
        //startPosition: OverlayPosition(0, 0),
        startPosition: OverlayPosition(0, -20),
      );
    });
  }

  @override
  void dispose() {
    textRecognizer?.close();
    translator?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final availableScripts = TextRecognitionScript.values;
    final availableLanguages = TranslateLanguage.values;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF4A90E2),
        scaffoldBackgroundColor: Color(0xFFF4F6F8),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFF4A90E2),
          foregroundColor: Colors.white,
          elevation: 4,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFF4A90E2),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: Color(0xFF1A1A1A)),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: Text("ScreenLingo")),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Column(
                    children: [
                      Text("Detect Script"),
                      SizedBox(height: 5),
                      DropdownButton<TextRecognitionScript>(
                        value: _selectedScript,
                        items: availableScripts.map((script) {
                          return DropdownMenuItem(
                            value: script,
                            child: Text(script.name),
                          );
                        }).toList(),
                        onChanged: (newScript) {
                          setState(() {
                            _selectedScript = newScript!;
                            initializeTextRecognizer();
                          });
                        },
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward, color: Colors.grey),
                  Column(
                    children: [
                      Text("Translate to"),
                      SizedBox(height: 5),
                      DropdownButton<TranslateLanguage>(
                        value: _targetLanguage,
                        items: availableLanguages.map((lang) {
                          return DropdownMenuItem(
                            value: lang,
                            child: Text(lang.name),
                          );
                        }).toList(),
                        onChanged: (newLang) {
                          setState(() {
                            _targetLanguage = newLang!;
                            translator?.close();
                            translator = OnDeviceTranslator(
                              sourceLanguage: TranslateLanguage.english,
                              targetLanguage: _targetLanguage,
                            );
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
              SizedBox(height: 20),
              Expanded(
                child: Card(
                  elevation: 5,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  color: Colors.grey.shade100,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 15,top: 20),
                        child: Text("Preview Text", style: TextStyle(fontSize: 25, fontWeight: FontWeight.w500, color: Colors.black54),),
                      ),
                      SizedBox(height: 20,),
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 16,right: 16,bottom: 16),
                          child: Text(
                            "Technology has become an essential part of modern life, affecting nearly every aspect of our daily activities.  ",
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                              height:
                                  1.5, // Adjusts line height for better readability
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: startScreenCapture,
                    child: Text("Start Overlay"),
                  ),
                  SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: stopScreenCapture,
                    child: Text("Stop Overlay"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
