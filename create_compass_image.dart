import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';

// This is a utility file to generate a compass background image
// Run this file with Flutter to generate the compass image asset
void main() async {
  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final Canvas canvas = Canvas(recorder);
  final Size size = Size(400, 400);

  // Draw the compass circle
  final Paint circlePaint = Paint()
    ..color = Color(0xFFFFFFFF)
    ..style = PaintingStyle.fill;

  canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2, circlePaint);

  // Draw compass circle border
  final Paint borderPaint = Paint()
    ..color = Color(0xFF000000)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 4;

  canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width / 2 - 2, borderPaint);

  // Draw compass directions (N, E, S, W)
  final TextPainter textPainter = TextPainter(
    textAlign: TextAlign.center,
    textDirection: TextDirection.ltr,
  );

  // North
  textPainter.text = TextSpan(
    text: 'N',
    style: TextStyle(
      color: Colors.red,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, 10));

  // East
  textPainter.text = TextSpan(
    text: 'E',
    style: TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(size.width - textPainter.width - 10, size.height / 2 - textPainter.height / 2));

  // South
  textPainter.text = TextSpan(
    text: 'S',
    style: TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(size.width / 2 - textPainter.width / 2, size.height - textPainter.height - 10));

  // West
  textPainter.text = TextSpan(
    text: 'W',
    style: TextStyle(
      color: Colors.black,
      fontSize: 24,
      fontWeight: FontWeight.bold,
    ),
  );
  textPainter.layout();
  textPainter.paint(canvas, Offset(10, size.height / 2 - textPainter.height / 2));

  // Draw degree markers
  for (int i = 0; i < 360; i += 15) {
    double radian = i * 3.141592653589793 / 180;
    double innerRadius = size.width / 2 - 20;
    double outerRadius = (i % 45 == 0) ? size.width / 2 - 35 : size.width / 2 - 25;
    
    double x1 = size.width / 2 + innerRadius * math.cos(radian);
    double y1 = size.height / 2 + innerRadius * math.sin(radian);
    double x2 = size.width / 2 + outerRadius * math.cos(radian);
    double y2 = size.height / 2 + outerRadius * math.sin(radian);
    
    final Paint tickPaint = Paint()
      ..color = (i % 45 == 0) ? Colors.black : Colors.grey
      ..strokeWidth = (i % 45 == 0) ? 3 : 1;
    
    canvas.drawLine(Offset(x1, y1), Offset(x2, y2), tickPaint);
    
    // Draw degree numbers for every 30 degrees
    if (i % 30 == 0) {
      String degreeText = i.toString();
      textPainter.text = TextSpan(
        text: degreeText,
        style: TextStyle(
          color: Colors.black,
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
      );
      textPainter.layout();
      
      double textX = size.width / 2 + (innerRadius - 15) * math.cos(radian) - textPainter.width / 2;
      double textY = size.height / 2 + (innerRadius - 15) * math.sin(radian) - textPainter.height / 2;
      
      textPainter.paint(canvas, Offset(textX, textY));
    }
  }

  // Draw decorative center
  final Paint centerPaint = Paint()
    ..color = Color(0xFF0000FF)
    ..style = PaintingStyle.fill;
  
  canvas.drawCircle(Offset(size.width / 2, size.height / 2), 10, centerPaint);

  final ui.Picture picture = recorder.endRecording();
  final ui.Image img = await picture.toImage(size.width.toInt(), size.height.toInt());
  final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  final Uint8List pngBytes = byteData!.buffer.asUint8List();

  // Create assets directory if it doesn't exist
  Directory('assets').createSync(recursive: true);
  Directory('assets/images').createSync(recursive: true);

  // Write the image file
  await File('assets/images/compass_bg.png').writeAsBytes(pngBytes);
  
  print('Compass background image created successfully!');
}
