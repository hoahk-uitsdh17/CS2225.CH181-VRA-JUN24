import 'dart:io';
import 'dart:ui';
import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as imglib;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_vision/flutter_vision.dart';

import 'package:sigdet/signdetail.dart';

late List<CameraDescription> cameras;
main() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  runApp(
    const MaterialApp(
      home: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late FlutterVision vision;
  @override
  void initState() {
    super.initState();
    vision = FlutterVision();
  }

  @override
  void dispose() async {
    super.dispose();
    await vision.closeTesseractModel();
    await vision.closeYoloModel();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: YoloVideo(vision: vision),
    );
  }
}

class YoloVideo extends StatefulWidget {
  final FlutterVision vision;
  const YoloVideo({Key? key, required this.vision}) : super(key: key);

  @override
  State<YoloVideo> createState() => _YoloVideoState();
}

class _YoloVideoState extends State<YoloVideo> {
  late CameraController controller;
  late List<Map<String, dynamic>> yoloResults;
  CameraImage? cameraImage;
  bool isLoaded = false;
  bool isDetecting = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async {
    cameras = await availableCameras();
    controller = CameraController(cameras[0], ResolutionPreset.medium);
    controller.initialize().then((value) {
      loadYoloModel().then((value) {
        setState(() {
          isLoaded = true;
          isDetecting = false;
          yoloResults = [];
        });
      });
    });
  }

  @override
  void dispose() async {
    super.dispose();
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Size size = MediaQuery.of(context).size;
    if (!isLoaded) {
      return const Scaffold(
        body: Center(
          child: Text("Model not loaded, waiting for it"),
        ),
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: CameraPreview(
            controller,
          ),
        ),
        ...displayBoxesAroundRecognizedObjects(size),
        Positioned(
          bottom: 75,
          width: MediaQuery.of(context).size.width,
          child: Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                  width: 5, color: Colors.white, style: BorderStyle.solid),
            ),
            child: isDetecting
                ? IconButton(
                    onPressed: () async {
                      stopDetection();
                    },
                    icon: const Icon(
                      Icons.stop,
                      color: Colors.red,
                    ),
                    iconSize: 50,
                  )
                : IconButton(
                    onPressed: () async {
                      await startDetection();
                    },
                    icon: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                    ),
                    iconSize: 50,
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> loadYoloModel() async {
    await widget.vision.loadYoloModel(
        labels: 'assets/models/labelmap.txt',
        modelPath: 'assets/models/last_float32.tflite',
        modelVersion: "yolov8",
        numThreads: 2,
        useGpu: true);
    setState(() {
      isLoaded = true;
    });
  }

  Future<void> yoloOnFrame(CameraImage cameraImage) async {
    final result = await widget.vision.yoloOnFrame(
        bytesList: cameraImage.planes.map((plane) => plane.bytes).toList(),
        imageHeight: cameraImage.height,
        imageWidth: cameraImage.width,
        iouThreshold: 0.4,
        confThreshold: 0.4,
        classThreshold: 0.5);
    if (result.isNotEmpty) {
      await convertYUV420toImageColor(cameraImage);
      setState(() {
        yoloResults = result;
      });
    }
  }

  Future<void> startDetection() async {
    setState(() {
      isDetecting = true;
    });
    if (controller.value.isStreamingImages) {
      return;
    }
    if (controller.value.isTakingPicture) {
      return;
    }
    await controller.startImageStream((image) async {
      if (isDetecting) {
        // final imageBytes = image.planes.map((plane) {
        //   debugPrint("plane ${plane}");
        //   return plane.bytes.toList();
        // });
        // final imageBytes = image.planes.first.bytes.buffer;

        // call save image file method
        // saveImageFile(imageBytes)
        //     .then((res) =>
        //         {debugPrint("save image file successfull filepath: $res")})
        //     .catchError(
        //         (err) => {debugPrint("error on save image file error: $err")});
        cameraImage = image;
        // final directory = await getApplicationDocumentsDirectory();
        // File("${directory.path}/temp.jpg").writeAsBytes(ig.image.);
        // final xFile = await controller.takePicture();
        // xFile.saveTo("${directory.path}/temp.jpg");
        // final bytes = await File(xFile.path).readAsBytes();
        // File("${directory.path}/temp.jpg").writeAsBytesSync(bytes);
        yoloOnFrame(image);
      }
    });
  }

  Future<Image> convertYUV420toImageColor(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel as int;
      // debugPrint("uvRowStride: " + uvRowStride.toString());
      // debugPrint("uvPixelStride: " + uvPixelStride.toString());

      // imgLib -> Image package from https://pub.dartlang.org/packages/image
      var img = imglib.Image(width: height, height: width);

      // Fill image buffer with plane[0] from YUV420_888
      for (int x = 0; x < width; x++) {
        for (int y = 0; y < height; y++) {
          final int uvIndex =
              uvPixelStride * (x / 2).floor() + uvRowStride * (y / 2).floor();
          final int index = y * width + x;

          final yp = image.planes[0].bytes[index];
          final up = image.planes[1].bytes[uvIndex];
          final vp = image.planes[2].bytes[uvIndex];
          // Calculate pixel color
          int r = (yp + vp * 1436 / 1024 - 179).round().clamp(0, 255);
          int g = (yp - up * 46549 / 131072 + 44 - vp * 93604 / 131072 + 91)
              .round()
              .clamp(0, 255);
          int b = (yp + up * 1814 / 1024 - 227).round().clamp(0, 255);
          // color: 0x FF  FF  FF  FF
          //           A   B   G   R
          img.data?.setPixel(height - 1 - y, x, imglib.ColorRgb8(r, g, b));
        }
      }

      imglib.JpegEncoder jpegEncoder = imglib.JpegEncoder();
      final jpeg = jpegEncoder.encode(img);

      final directory = await getApplicationDocumentsDirectory();
      File("${directory.path}/temp.jpg").writeAsBytes(jpeg);
      debugPrint(">>>>>>>>>>>> DONE");
      return Image.memory(jpeg);
    } catch (e) {
      debugPrint(">>>>>>>>>>>> ERROR: ${e.toString()}");
      throw Error();
    }
  }

  Future<void> stopDetection() async {
    setState(() {
      isDetecting = false;
      yoloResults.clear();
    });
  }

  List<Widget> displayBoxesAroundRecognizedObjects(Size screen) {
    if (yoloResults.isEmpty) return [];

    double factorX = screen.width / (cameraImage?.height ?? 1);
    double factorY = screen.height / (cameraImage?.width ?? 1);

    Color colorPick = const Color.fromARGB(255, 50, 233, 30);

    return yoloResults.map((result) {
      final cropName = DateTime.now().microsecondsSinceEpoch.toString();
      var x = result["box"][0];
      var y = result["box"][1];
      var width = (result["box"][2] - result["box"][0]);
      var height = (result["box"][3] - result["box"][1]);
      return Positioned(
        left: x * factorX,
        top: y * factorY,
        width: width * factorX,
        height: height * factorY,
        child: GestureDetector(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.all(Radius.circular(10.0)),
              border: Border.all(color: Colors.pink, width: 2.0),
            ),
            child: Text(
              "${result['tag']} ${(result['box'][4] * 100).toStringAsFixed(0)}%",
              style: TextStyle(
                background: Paint()..color = colorPick,
                color: Colors.white,
                fontSize: 18.0,
              ),
            ),
          ),
          onTap: () async {
            final directory = await getApplicationDocumentsDirectory();
            imglib.Image imgLoad = imglib.decodeImage(
                    File("${directory.path}/temp.jpg").readAsBytesSync())
                as imglib.Image;
            final dataImage = imglib.copyCrop(imgLoad,
                x: x.round(),
                y: y.round(),
                width: width.round(),
                height: height.round());
            await File("${directory.path}/$cropName.jpg")
                .writeAsBytes(imglib.encodeJpg(dataImage));
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => SignDetail(
                        path: cropName,
                        left: x,
                        top: y,
                        width: width,
                        height: height,
                      )),
            );
          },
        ),
      );
    }).toList();
  }
}
