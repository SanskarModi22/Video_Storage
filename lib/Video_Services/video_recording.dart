

import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart';
import 'package:video_player/video_player.dart';

import '../Firebase Services/storage.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Image Picker Demo',
      home: MyHomePage(title: 'Image Picker Example'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<XFile>? _imageFileList;
  String? downUrl;
  set _imageFile(XFile? value) {
    _imageFileList = value == null ? null : [value];
  }

  UploadTask? task;
  File? files;
  dynamic _pickImageError;

  //VIDEO AREA...............................................................
  bool isVideo = false;

  VideoPlayerController? _controller;
  VideoPlayerController? _toBeDisposed;
  String? _retrieveDataError;

  final ImagePicker _picker = ImagePicker();
  final TextEditingController maxWidthController = TextEditingController();
  final TextEditingController maxHeightController = TextEditingController();
  final TextEditingController qualityController = TextEditingController();
//.............................................................
  Future<void> _playVideo(XFile? file) async {
    //Used for playing the video
    if (file != null && mounted) {
      await _disposeVideoController();
      late VideoPlayerController controller;
      if (kIsWeb) {
        controller = VideoPlayerController.network(file.path);
      } else {
        controller = VideoPlayerController.file(File(file.path));
      }
      _controller = controller;
      // In web, most browsers won't honor a programmatic call to .play
      // if the video has a sound track (and is not muted).
      // Mute the video so it auto-plays in web!
      // This is not needed if the call to .play is the result of user
      // interaction (clicking on a "play" button, for example).
      final double volume = kIsWeb ? 0.0 : 1.0;
      await controller.setVolume(volume);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      setState(() {});
    }
  }

  void _onImageButtonPressed(ImageSource source,
      {BuildContext? context, bool isMultiImage = false}) async {
    if (_controller != null) {
      await _controller!.setVolume(0.0);
    }
    if (isVideo) {
      final XFile? file = await _picker.pickVideo(
          source: source, maxDuration: const Duration(seconds: 10));
      setState(() {
        files = File(file!.path);
      });
      await _playVideo(file);
    } else if (isMultiImage) {
      await _displayPickImageDialog(context!,
          (double? maxWidth, double? maxHeight, int? quality) async {
        try {
          final pickedFileList = await _picker.pickMultiImage(
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            imageQuality: quality,
          );
          setState(() {
            _imageFileList = pickedFileList;
          });
        } catch (e) {
          setState(() {
            _pickImageError = e;
          });
        }
      });
    } else {
      await _displayPickImageDialog(context!,
          (double? maxWidth, double? maxHeight, int? quality) async {
        try {
          final pickedFile = await _picker.pickImage(
            source: source,
            maxWidth: maxWidth,
            maxHeight: maxHeight,
            imageQuality: quality,
          );
          setState(() {
            _imageFile = pickedFile;
            files = File(pickedFile!.path);
          });
        } catch (e) {
          setState(() {
            _pickImageError = e;
          });
        }
      });
    }
  } //Image button pressed

  @override
  void deactivate() {
    if (_controller != null) {
      _controller!.setVolume(0.0);
      _controller!.pause();
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _disposeVideoController();
    maxWidthController.dispose();
    maxHeightController.dispose();
    qualityController.dispose();
    super.dispose();
  }

  Future<void> _disposeVideoController() async {
    if (_toBeDisposed != null) {
      await _toBeDisposed!.dispose();
    }
    _toBeDisposed = _controller;
    _controller = null;
  }

  /**
   * ? Used for previewing a video
   */
  Widget _previewVideo() {
    final Text? retrieveError = _getRetrieveErrorWidget();
    if (retrieveError != null) {
      return retrieveError;
    }
    if (_controller == null) {
      return const Text(
        'You have not yet picked a video',
        textAlign: TextAlign.center,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(10.0),
      child: AspectRatioVideo(_controller),
    );
  }

  Widget _previewImages({BuildContext? context}) {
    final Text? retrieveError = _getRetrieveErrorWidget();
    if (retrieveError != null) {
      return retrieveError;
    }
    if (_imageFileList != null) {
      return Semantics(
          child: SizedBox(
            width: MediaQuery.of(context!).size.width,
            height: double.parse(maxHeightController.text),
            child: Center(
              child: ListView.builder(
                reverse: true,
                shrinkWrap: true,
                scrollDirection: Axis.horizontal,
                key: UniqueKey(),
                itemBuilder: (context, index) {
                  // Why network for web?
                  // See https://pub.dev/packages/image_picker#getting-ready-for-the-web-platform
                  return Semantics(
                    label: 'image_picker_example_picked_image',
                    child: kIsWeb
                        ? Image.network(_imageFileList![index].path)
                        : Image.file(File(_imageFileList![index].path)),
                  );
                },
                itemCount: _imageFileList!.length,
              ),
            ),
          ),
          label: 'image_picker_example_picked_images');
    } else if (_pickImageError != null) {
      return Text(
        'Pick image error: $_pickImageError',
        textAlign: TextAlign.center,
      );
    } else {
      return const Text(
        'You have not yet picked an image.',
        textAlign: TextAlign.center,
      );
    }
  } //IMAGE SECTION

  Widget _handlePreview({BuildContext? context}) {
    //VIDEO PART
    if (isVideo) {
      return _previewVideo();
    } else {
      return _previewImages(context: context);
    }
  }

  void _removeImage() {
    setState(() {
      _imageFileList = null;
      files=null;
      task=null;
      downUrl=null;
    });
  }

  void _removeVideo() {
    setState(() {
      _controller = null;
      files=null;
      task=null;
      downUrl=null;
    });
  }

  void _removeMedia() {
    if (isVideo)
      _removeVideo();
    else
      _removeImage();
  }

  Future<void> retrieveLostData() async {
    final LostDataResponse response = await _picker.retrieveLostData();
    if (response.isEmpty) {
      return;
    }
    if (response.file != null) {
      if (response.type == RetrieveType.video) {
        isVideo = true;
        await _playVideo(response.file);
      } else {
        isVideo = false;
        setState(() {
          _imageFile = response.file;
          _imageFileList = response.files;
        });
      }
    } else {
      _retrieveDataError = response.exception!.code;
    }
  } //VIDEO PART

  @override
  Widget build(BuildContext context) {
    final fileName = files != null ? basename(files!.path) : 'No File Selected';
    return Scaffold(
backgroundColor: Colors.orangeAccent[100],
      appBar: AppBar(
        backgroundColor: Colors.indigoAccent,
        centerTitle: true,
        title: Text('Media Storage'),
      ),
      body: SingleChildScrollView(
        child: Center(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            !kIsWeb && defaultTargetPlatform == TargetPlatform.android
                ? FutureBuilder<void>(
                    future: retrieveLostData(),
                    builder:
                        (BuildContext context, AsyncSnapshot<void> snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.waiting:
                          return const Text(
                            'You have not yet picked an image.',
                            textAlign: TextAlign.center,
                          );
                        case ConnectionState.done:
                          return _handlePreview(context: context);
                        default:
                          if (snapshot.hasError) {
                            return Text(
                              'Pick image/video error: ${snapshot.error}}',
                              textAlign: TextAlign.center,
                            );
                          } else {
                            return const Text(
                              'You have not yet picked an image.',
                              textAlign: TextAlign.center,
                            );
                          }
                      }
                    },
                  )
                : _handlePreview(context: context),
            Container(
              margin: EdgeInsets.all(10.0),
              child: Text(
                fileName,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,),textAlign: TextAlign.start
                ,
              ),
            ),
            Container(
              margin: EdgeInsets.all(8.0),
              child: Card(
                color: Colors.deepOrangeAccent[100],
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                child: Container(
                  margin: EdgeInsets.all(8.0),
                  width: MediaQuery.of(context).size.width,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        'Image Section',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.greenAccent,
                              ),
                            ),
                            onPressed: () {
                              isVideo = false;
                              _onImageButtonPressed(ImageSource.gallery,
                                  context: context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(Icons.photo),
                                Text('Single Image'),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.greenAccent,
                              ),
                            ),
                            onPressed: () {
                              isVideo = false;
                              _onImageButtonPressed(
                                ImageSource.gallery,
                                context: context,
                                isMultiImage: true,
                              );
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(Icons.photo_library),
                                Text('Multiple Images'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.greenAccent,
                              ),
                            ),
                            onPressed: () {
                              isVideo = false;
                              _onImageButtonPressed(ImageSource.camera,
                                  context: context);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(Icons.camera_alt),
                                Text('Capture Image'),
                              ],
                            ),
                          )
                        ],
                      ),
                      Text(
                        'Video Section',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.redAccent,
                              ),
                            ),
                            onPressed: () {
                              isVideo = true;
                              _onImageButtonPressed(ImageSource.camera);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: const [
                                Icon(Icons.videocam),
                                Text('Record Video'),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.redAccent,
                              ),
                            ),
                            onPressed: () {
                              isVideo = true;
                              _onImageButtonPressed(ImageSource.gallery);
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(Icons.video_library),
                                Text('Video from Gallery'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Text(
                        'Delete',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.purpleAccent,
                              ),
                            ),
                            onPressed: () {
                              _removeMedia();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Icon(Icons.delete),
                                Text('Delete Media'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Text(
                        'Upload To Firestore',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          ElevatedButton(
                            style: ButtonStyle(
                              backgroundColor: MaterialStateProperty.all(
                                Colors.pinkAccent,
                              ),
                            ),
                            onPressed: () {
                              UploadFile();
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  child: Image.asset(
                                    "assets/firebase-logo.png",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Text(' Upload To Firebase'),
                              ],
                            ),
                          ),
                        ],
                      ),
                      task != null ? buildUploadStatus(task!) : Container(),
                      Container(
                        margin: EdgeInsets.all(8),
                        child: Text(
                          'Download Link :$downUrl',
                          textAlign: TextAlign.start,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.cyan
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          ],
        )),
      ), //This is importanat
      // floatingActionButton: Column(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: <Widget>[
      //     //PHOTO AREA..........................................
      //     Semantics(
      //       label: 'image_picker_example_from_gallery',
      //       child: FloatingActionButton(
      //         onPressed: () {
      //           isVideo = false;
      //           _onImageButtonPressed(ImageSource.gallery, context: context);
      //         },
      //         heroTag: 'image0',
      //         tooltip: 'Pick Image from gallery',
      //         child: const Icon(Icons.photo),
      //       ),
      //     ), //Single image
      //     Padding(
      //       padding: const EdgeInsets.only(top: 16.0),
      //       child: FloatingActionButton(
      //         onPressed: () {
      //           isVideo = false;
      //           _onImageButtonPressed(
      //             ImageSource.gallery,
      //             context: context,
      //             isMultiImage: true,
      //           );
      //         },
      //         heroTag: 'image1',
      //         tooltip: 'Pick Multiple Image from gallery',
      //         child: const Icon(Icons.photo_library),
      //       ),
      //     ), //Multiple images
      //     Padding(
      //       padding: const EdgeInsets.only(top: 16.0),
      //       child: FloatingActionButton(
      //         onPressed: () {
      //           isVideo = false;
      //           _onImageButtonPressed(ImageSource.camera, context: context);
      //         },
      //         heroTag: 'image2',
      //         tooltip: 'Take a Photo',
      //         child: const Icon(Icons.camera_alt),
      //       ),
      //     ),
      //     //Photo clicking
      //     //.........................................................
      //
      //     //VIDEO AREA...................................................
      //     Padding(
      //       padding: const EdgeInsets.only(top: 16.0),
      //       child: FloatingActionButton(
      //         backgroundColor: Colors.red,
      //         onPressed: () {
      //           isVideo = true;
      //           _onImageButtonPressed(ImageSource.gallery);
      //         },
      //         heroTag: 'video0',
      //         tooltip: 'Pick Video from gallery',
      //         child: const Icon(Icons.video_library),
      //       ),
      //     ),
      //     Padding(
      //       padding: const EdgeInsets.only(top: 16.0),
      //       child: FloatingActionButton(
      //         backgroundColor: Colors.red,
      //         onPressed: () {
      //           isVideo = true;
      //           _onImageButtonPressed(ImageSource.camera);
      //         },
      //         heroTag: 'video1',
      //         tooltip: 'Take a Video',
      //         child: const Icon(Icons.videocam),
      //       ),
      //     ),
      //     //.................................................
      //   ],
      // ),
    );
  }

  Future UploadFile() async {
    if (files == null) return;
    final fileName = basename(files!.path);
    final destination = 'files/$fileName';
    task = FirebaseApi.uploadFile(destination, files!);
    setState(() {});

    if (task == null) return;

    final snapshot = await task!.whenComplete(() {});
    final urlDownload = await snapshot.ref.getDownloadURL();
    setState(() {
      downUrl = urlDownload;
    });
    print('Download-Link: $urlDownload');
  }

  Widget buildUploadStatus(UploadTask task) => StreamBuilder<TaskSnapshot>(
        stream: task.snapshotEvents,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            final snap = snapshot.data!;
            final progress = snap.bytesTransferred / snap.totalBytes;
            final percentage = (progress * 100).toStringAsFixed(2);

            return Text(
              'Progress- $percentage %',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            );
          } else {
            return Container();
          }
        },
      );

  Text? _getRetrieveErrorWidget() {
    if (_retrieveDataError != null) {
      final Text result = Text(_retrieveDataError!);
      _retrieveDataError = null;
      return result;
    }
    return null;
  }

  Future<void> _displayPickImageDialog(
      BuildContext context, OnPickImageCallback onPick) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Add optional parameters'),
            content: Column(
              children: <Widget>[
                TextField(
                  controller: maxWidthController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(hintText: "Enter maxWidth if desired"),
                ),
                TextField(
                  controller: maxHeightController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration:
                      InputDecoration(hintText: "Enter maxHeight if desired"),
                ),
                TextField(
                  controller: qualityController,
                  keyboardType: TextInputType.number,
                  decoration:
                      InputDecoration(hintText: "Enter quality if desired"),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                child: const Text('CANCEL'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                  child: const Text('PICK'),
                  onPressed: () {
                    double? width = maxWidthController.text.isNotEmpty
                        ? double.parse(maxWidthController.text)
                        : null;
                    double? height = maxHeightController.text.isNotEmpty
                        ? double.parse(maxHeightController.text)
                        : null;
                    int? quality = qualityController.text.isNotEmpty
                        ? int.parse(qualityController.text)
                        : null;
                    onPick(width, height, quality);
                    Navigator.of(context).pop();
                  }),
            ],
          );
        });
  }
}

typedef void OnPickImageCallback(
    double? maxWidth, double? maxHeight, int? quality);

class AspectRatioVideo extends StatefulWidget {
  AspectRatioVideo(this.controller);

  final VideoPlayerController? controller;

  @override
  AspectRatioVideoState createState() => AspectRatioVideoState();
}

class AspectRatioVideoState extends State<AspectRatioVideo> {
  VideoPlayerController? get controller => widget.controller;
  bool initialized = false;

  void _onVideoControllerUpdate() {
    if (!mounted) {
      return;
    }
    if (initialized != controller!.value.isInitialized) {
      initialized = controller!.value.isInitialized;
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    controller!.addListener(_onVideoControllerUpdate);
  }

  @override
  void dispose() {
    controller!.removeListener(_onVideoControllerUpdate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (initialized) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller!.value.aspectRatio,
          child: VideoPlayer(controller!),
        ),
      );
    } else {
      return Container();
    }
  }
}
