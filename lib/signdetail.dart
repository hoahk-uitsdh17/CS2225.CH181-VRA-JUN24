import 'dart:io' as Io;

import "package:flutter/material.dart";
import "package:image/image.dart" as imglib;
import "package:path_provider/path_provider.dart";

class SignDetail extends StatefulWidget {
  SignDetail(
      {required this.path,
      required this.left,
      required this.top,
      required this.width,
      required this.height,
      super.key});

  final dynamic path;
  final dynamic left;
  final dynamic top;
  final dynamic width;
  final dynamic height;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  State<SignDetail> createState() => _SignDetailState();
}

class _SignDetailState extends State<SignDetail> {
  final cropName = DateTime.now().microsecondsSinceEpoch.toString();

  @override
  void initState() {
    super.initState();
    // init();
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   init();
    // });
  }

  init() async {
    final directory = await getApplicationDocumentsDirectory();
    imglib.Image imgLoad = imglib.decodeImage(
            Io.File("${directory.path}/temp.jpg").readAsBytesSync())
        as imglib.Image;
    final dataImage = imglib.copyCrop(imgLoad,
        x: widget.left.round(),
        y: widget.top.round(),
        width: widget.width.round(),
        height: widget.height.round());
    await Io.File("${directory.path}/$cropName.jpg")
        .writeAsBytes(imglib.encodeJpg(dataImage));
  }

  Future<Io.File> _getLocalFile(String filename) async {
    String dir = (await getApplicationDocumentsDirectory()).path;
    Io.File f = Io.File('$dir/$filename');
    return f;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: widget._scaffoldKey,
        appBar: AppBar(
          title: const Text(
            "Sign detail",
          ),
        ),
        body: Column(children: [
          Flexible(
              child: FractionallySizedBox(
            heightFactor: 1,
            child: FutureBuilder(
                future: _getLocalFile("${widget.path}.jpg"),
                builder:
                    (BuildContext context, AsyncSnapshot<Io.File> snapshot) {
                  switch (snapshot.connectionState) {
                    case ConnectionState.waiting:
                      return const Text('Loading....');
                    default:
                      if (snapshot.hasError) {
                        return Text('Error: ${snapshot.error}');
                      } else {
                        debugPrint("${snapshot.data}");
                        if (snapshot.data != null) {
                          return Image.file(snapshot.data!);
                        } else {
                          return const Text('Loading....');
                        }
                      }
                  }
                }),
          )),
          // )
        ]));
  }
}
