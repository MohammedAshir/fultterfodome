import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:fodome/pages/home.dart';
import 'package:fodome/widgets/progress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as Im;
import 'package:uuid/uuid.dart';
import 'package:geocoding/geocoding.dart';

final ButtonStyle raisedButtonStyle = ElevatedButton.styleFrom(
  primary: Colors.deepOrange,
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8.0),
  ),
);
late DateTime timestamp;
firebase_storage.FirebaseStorage storage =
    firebase_storage.FirebaseStorage.instance;
final ImagePicker _picker = ImagePicker();

class Upload extends StatefulWidget {
  @override
  _UploadState createState() => _UploadState();
}

class _UploadState extends State<Upload>
    with AutomaticKeepAliveClientMixin<Upload> {
  TextEditingController titleController = TextEditingController();
  TextEditingController descriptionController = TextEditingController();
  TextEditingController quantityController = TextEditingController();
  TextEditingController shelflifeController = TextEditingController();
  TextEditingController locationController = TextEditingController();

  bool _validateTitle = false;
  bool _validateDescription = false;
  bool _validateQuantity = false;
  bool _validateShelflife = false;
  bool _validateLocation = false;

  var lat = 0.0;
  var long = 0.0;
  PickedFile? file;
  bool isUploading = false;
  String postId = Uuid().v4();
  var image;

  bool _isSnackbarActive = false;
  final ScrollController _scrollController = ScrollController();

  handleTakePhoto() async {
    Navigator.pop(context);
    PickedFile? file = await _picker.getImage(
      source: ImageSource.camera,
      maxHeight: 675,
      maxWidth: 960,
    );
    setState(() {
      this.file = file;
      if (file != null) {
        this.image = File(file.path);
      }
    });
  }

  handleChooseFromGallery() async {
    Navigator.pop(context);
    PickedFile? file = await _picker.getImage(source: ImageSource.gallery);
    setState(() {
      this.file = file;
      if (file != null) {
        this.image = File(file.path);
      }
    });
  }

  selectImage(parentContext) {
    setState(() {
      // file = null;
      isUploading = false;
      locationController.clear();
      titleController.clear();
      descriptionController.clear();
      quantityController.clear();
      shelflifeController.clear();
      // postId = Uuid().v4();
    });
    return showDialog(
        context: parentContext,
        builder: (context) {
          return SimpleDialog(
            title: Text("Create Post"),
            children: <Widget>[
              SimpleDialogOption(
                  child: Text("Photo with Camera"), onPressed: handleTakePhoto),
              SimpleDialogOption(
                  child: Text("Image from Gallery"),
                  onPressed: handleChooseFromGallery),
              SimpleDialogOption(
                child: Text("Cancel"),
                onPressed: () => Navigator.pop(context),
              )
            ],
          );
        });
  }

  Widget buildSplashScreen() {
    return Container(
      color: Theme.of(context).accentColor.withOpacity(0.6),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          SvgPicture.asset('assets/images/upload.svg', height: 260.0),
          Padding(
            padding: EdgeInsets.only(top: 20.0),
            child: ElevatedButton(
              child: Text(
                "Upload Food Image",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22.0,
                ),
              ),
              style: raisedButtonStyle,
              onPressed: () => selectImage(context),
            ),
          ),
        ],
      ),
    );
  }

  clearImage() {
    setState(() {
      file = null;
    });
  }

  compressImage() async {
    final tempDir = await getTemporaryDirectory();
    final path = tempDir.path;
    Im.Image? imageFile = Im.decodeImage(image.readAsBytesSync());
    final compressedImageFile = File('$path/img_$postId.jpg')
      ..writeAsBytesSync(Im.encodeJpg(imageFile!, quality: 50));
    setState(() {
      image = compressedImageFile;
    });
  }

  Future<String> uploadImage(imageFile) async {
    firebase_storage.Reference ref = storage.ref().child('post_$postId.jpg');
    firebase_storage.UploadTask uploadTask = ref.putFile(imageFile);
    print('File Uploaded');
    var imageUrl = await (await uploadTask).ref.getDownloadURL();
    String url = imageUrl.toString();
    return url;
  }

  createPostInFirestore(
      {required String mediaUrl,
      String? location,
      String? title,
      String? description,
      String? quantity,
      String? shelfLife}) {
    setState(() {
      timestamp = DateTime.now();
    });
    postsRef.doc(currentUser!.id).collection("userPosts").doc(postId).set({
      "postId": postId,
      "ownerId": currentUser!.id,
      "username": currentUser!.username,
      "mediaUrl": mediaUrl,
      "description": description,
      "location": location,
      "timestamp": timestamp,
      "likes": {},
      "title": title,
      "shelfLife": shelfLife,
      "quantity": quantity,
    });

    timelineRef.add({
      "postId": postId,
      "ownerId": currentUser!.id,
      "username": currentUser!.username,
      "displayName": currentUser!.displayName,
      "mediaUrl": mediaUrl,
      "description": description,
      "location": location,
      "timestamp": timestamp,
      "title": title,
      "shelfLife": shelfLife,
      "quantity": quantity,
      "isVerified": false,
      "latitude": lat,
      "longitude": long,
    });
  }

  handleSubmit() async {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            SizedBox(
              child: CircularProgressIndicator(
                strokeWidth: 3.0,
              ),
              height: 20.0,
              width: 20.0,
            ),
            Text("   Uploading...")
          ],
        ),
      ),
    );
    compressImage();
    String mediaUrl = await uploadImage(image);
    createPostInFirestore(
      mediaUrl: mediaUrl,
      location: locationController.text,
      title: titleController.text,
      description: descriptionController.text,
      quantity: quantityController.text,
      shelfLife: shelflifeController.text,
    );
    // locationController.clear();
    // titleController.clear();
    // descriptionController.clear();
    // quantityController.clear();
    // shelflifeController.clear();

    setState(() {
      file = null;
      postId = Uuid().v4();
    });
  }

  handlePost() {
    setState(() {
      isUploading = true;
      titleController.text.trim().isEmpty
          ? _validateTitle = true
          : _validateTitle = false;
      descriptionController.text.trim().isEmpty
          ? _validateDescription = true
          : _validateDescription = false;
      quantityController.text.trim().isEmpty
          ? _validateQuantity = true
          : _validateQuantity = false;
      shelflifeController.text.trim().isEmpty
          ? _validateShelflife = true
          : _validateShelflife = false;
      locationController.text.trim().isEmpty
          ? _validateLocation = true
          : _validateLocation = false;
    });

    if (titleController.text.trim().isNotEmpty &&
        descriptionController.text.trim().isNotEmpty &&
        quantityController.text.trim().isNotEmpty &&
        shelflifeController.text.trim().isNotEmpty &&
        locationController.text.trim().isNotEmpty) {
      _scrollController.animateTo(_scrollController.position.minScrollExtent,
          duration: Duration(milliseconds: 300), curve: Curves.fastOutSlowIn);
      handleSubmit();
      // isUploading = true;
    } else {
      setState(() {
        isUploading = false;
      });
      if (!_isSnackbarActive) {
        setState(() {
          _isSnackbarActive = true;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("Fill all fields!")))
            .closed
            .then((SnackBarClosedReason reason) {
          // snackbar is now closed.
          setState(() {
            _isSnackbarActive = false;
          });
        });
      }
    }
  }

  Scaffold buildUploadForm() {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white70,
        leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Colors.black),
            onPressed: clearImage),
        title: Text(
          "Post Details",
          style: TextStyle(color: Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () {
              isUploading ? null : handlePost();
            },
            child: Text(
              isUploading ? "Please Wait" : "Post",
              style: TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
                fontSize: 20.0,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        children: <Widget>[
          if (isUploading) linearProgress(),
          Container(
            height: 220.0,
            width: MediaQuery.of(context).size.width * 0.8,
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.cover,
                      image: FileImage(image),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: 10.0),
          ),
          ListTile(
            leading: Text(
              "Title:",
              style: TextStyle(fontSize: 17.0),
            ),
            title: Container(
              width: 250.0,
              child: TextField(
                controller: titleController,
                decoration: InputDecoration(
                  hintText: "Enter a title...",
                  errorText: _validateTitle ? 'Title Can\'t Be Empty' : null,
                  // border: InputBorder.none,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Text(
              "Description:",
              style: TextStyle(fontSize: 17.0),
            ),
            title: Container(
              width: 250.0,
              child: TextField(
                controller: descriptionController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: "Enter a description...",
                  errorText: _validateDescription
                      ? 'Description Can\'t Be Empty'
                      : null,
                  // border: InputBorder.none,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Text(
              "Quantity:",
              style: TextStyle(fontSize: 17.0),
            ),
            title: Container(
              width: 250.0,
              child: TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  hintText: "Enter details about weight and quantity...",
                  errorText:
                      _validateQuantity ? 'Quantity Can\'t Be Empty' : null,
                  // border: InputBorder.none,
                ),
              ),
            ),
          ),
          ListTile(
            leading: Text(
              "Shelf Life:",
              style: TextStyle(fontSize: 17.0),
            ),
            title: Container(
              width: 250.0,
              child: TextField(
                controller: shelflifeController,
                decoration: InputDecoration(
                  hintText: "Best time to eat before expiry...",
                  errorText:
                      _validateShelflife ? 'Shelf Life Can\'t Be Empty' : null,
                  // border: InputBorder.none,
                ),
              ),
            ),
          ),
          Divider(),
          ListTile(
            leading: Icon(
              Icons.pin_drop,
              color: Colors.orange,
              size: 35.0,
            ),
            title: Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                width: 250.0,
                child: TextField(
                  enabled: false,
                  controller: locationController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText:
                        "Where was this photo taken?\nClick below to get Location",
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          if (_validateLocation)
            Center(
              child: Text(
                "Location Can\'t Be Empty\nPlease enable Location and try again!",
                style: TextStyle(
                  color: Colors.red,
                ),
              ),
            ),
          Container(
            width: 200.0,
            height: 100.0,
            alignment: Alignment.center,
            child: ElevatedButton.icon(
              label: Text(
                "Use Current Location",
                style: TextStyle(color: Colors.white),
              ),
              style: raisedButtonStyle,
              onPressed: () {
                FocusScope.of(context).requestFocus(new FocusNode());
                getUserLocation();
              },
              icon: Icon(
                Icons.my_location,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  getUserLocation() async {
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      lat = position.latitude;
      long = position.longitude;
    });
    List<Placemark> placemarks = await GeocodingPlatform.instance
        .placemarkFromCoordinates(position.latitude, position.longitude);
    Placemark placemark = placemarks[0];
    String completeAddress =
        '${placemark.subLocality} ${placemark.locality}, ${placemark.subAdministrativeArea}, ${placemark.administrativeArea} ${placemark.postalCode}, ${placemark.country}';
    // String completeAddress = address([
    //   placemark.subLocality,
    //   placemark.locality,
    //   placemark.subAdministrativeArea,
    //   placemark.administrativeArea
    // ]);
    // print(completeAddress);
    locationController.text = completeAddress;
  }

  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return file == null ? buildSplashScreen() : buildUploadForm();
  }

  // String address(List list) {
  //   late var text;
  //   int flag = 0;
  //   try {
  //     var lengthOfArr = 4; //sublocality, locality, district, state
  //     if (list[lengthOfArr - 1] != null) {
  //       for (int idx = 0; idx < lengthOfArr - 1; idx++) {
  //         if (list[idx].length > 2 && list[idx + 1].length > 2) {
  //           text = list[idx] + ", " + list[idx + 1];
  //           if (idx <= 1) {
  //             flag = 1;
  //           }
  //           break;
  //         }
  //       }
  //     }
  //     if (flag == 0) {
  //       if (list[0].length > 2 && list[2].length > 2) {
  //         text = list[0] + ", " + list[2];
  //       } else if (list[0].length > 2 && list[3].length > 2) {
  //         text = list[0] + ", " + list[3];
  //       } else if (list[1].length > 2 && list[3].length > 2) {
  //         text = list[1] + ", " + list[3];
  //       }
  //     } else {
  //       text += ", " + list[3];
  //     }
  //   } on Exception catch (_) {
  //     print('Length Null.. No locaction');
  //   }
  //   return text;
  // }
}
