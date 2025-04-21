import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:auto_size_text/auto_size_text.dart';





class OverlayScreen extends StatefulWidget {
  @override
  _OverlayScreenState createState() => _OverlayScreenState();
}

class _OverlayScreenState extends State<OverlayScreen> {
  List<Map<String, dynamic>> textData = [];
  int touchCount=0;



  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((data) {
      setState(() {
        List<dynamic> decodedData = jsonDecode(data);
        textData =
            decodedData.map((item) => item as Map<String, dynamic>).toList();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Padding(
        padding: const EdgeInsets.only(top: 50),
        child: LayoutBuilder(
          builder: (context, constraints) {
            double devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
            double screenWidth = constraints.maxWidth * devicePixelRatio;
            double screenHeight = constraints.maxHeight * devicePixelRatio;

            print("Screen Size: ${screenWidth}x${screenHeight}");

            return SafeArea(
              child: Stack(
                children: [
                  //🔴 Red border around the whole screen
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.red, width: 5),
                        ),
                      ),
                    ),
                  ),
              
                  // 📝 Translated text overlays
                  ...textData.map((data) {
                    print(
                        "Rendering: ${data["translatedText"]} at ${data["boundingBox"]}");
                    Rect boundingBox = Rect.fromLTWH(
                      data["boundingBox"]["left"].toDouble() / devicePixelRatio,
                      data["boundingBox"]["top"].toDouble() / devicePixelRatio,
                      data["boundingBox"]["width"].toDouble() /
                          devicePixelRatio,
                      data["boundingBox"]["height"].toDouble() /
                          devicePixelRatio,
                    );
              
                    return Positioned(
                      left: boundingBox.left,
                      top: boundingBox.top,
                      child: Container(
                        width: boundingBox.width,
                        height: boundingBox.height * 2,
                        padding: EdgeInsets.all(4),
                        color: Color(data["backgroundColor"]),
                        child: AutoSizeText(
                          minFontSize: 5,
                          data["translatedText"],
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(data["fontColor"]),
                          ),
                          maxLines: data["numLines"], // Let it to the same number of lines as the original text.
                          //overflow: TextOverflow.ellipsis,
                        ),
                        // child: FittedBox(
                        //   child: Text(
                        //     data["translatedText"],
                        //     style: TextStyle(fontSize: 16, color: Color(data["fontColor"])),
                        //   ),
                        // ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
