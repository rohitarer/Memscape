import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:memscape/services/firestore_service.dart';
import '../../models/photo_model.dart';
import '../../widgets/custom_textfield.dart';
import '../../widgets/primary_button.dart';

// ... (imports unchanged)

class UploadPhotoScreen extends ConsumerStatefulWidget {
  const UploadPhotoScreen({super.key});

  @override
  ConsumerState<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
}

class _UploadPhotoScreenState extends ConsumerState<UploadPhotoScreen> {
  File? _selectedImage;
  final captionController = TextEditingController();
  final locationController = TextEditingController();
  bool isLoading = false;
  final picker = ImagePicker();
  double? _lat;
  double? _lng;
  bool isPublic = true;

  @override
  void initState() {
    super.initState();
    getCurrentLocation();
  }

  Future<void> pickImage() async {
    try {
      final picked = await picker.pickImage(source: ImageSource.gallery);
      if (picked != null) {
        final file = File(picked.path);
        final sizeInMB = await file.length() / (1024 * 1024);
        if (sizeInMB > 5) {
          _showSnackBar("❌ Image too large. Please pick one under 5MB.");
          return;
        }
        setState(() => _selectedImage = file);
      } else {
        _showSnackBar("⚠️ No image selected.");
      }
    } catch (e) {
      _showSnackBar("❌ Image selection failed: $e");
    }
  }

  Future<void> getCurrentLocation() async {
    try {
      final permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw Exception("❌ Location permission denied");
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final city =
          placemarks.isNotEmpty
              ? placemarks.first.locality ?? 'Unknown'
              : 'Unknown';

      setState(() {
        locationController.text = city;
        _lat = position.latitude;
        _lng = position.longitude;
      });
    } catch (e) {
      debugPrint("❌ Failed to get location: $e");
      locationController.text = 'Unknown';
    }
  }

  Future<String> encodeImageToBase64(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    return base64Encode(bytes);
  }

  Future<void> uploadMemory() async {
    if (_selectedImage == null) {
      _showSnackBar("❗ Please select an image.");
      return;
    }

    if (captionController.text.trim().isEmpty ||
        locationController.text.trim().isEmpty) {
      _showSnackBar("⚠️ Please enter a caption and location.");
      return;
    }

    setState(() => isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("❌ User not authenticated");

      final locationInput = locationController.text.trim();
      double finalLat, finalLng;

      try {
        final locationList = await locationFromAddress(locationInput);
        finalLat = locationList.first.latitude;
        finalLng = locationList.first.longitude;
      } catch (_) {
        if (_lat != null && _lng != null) {
          finalLat = _lat!;
          finalLng = _lng!;
        } else {
          throw Exception("❌ Unable to determine location coordinates.");
        }
      }

      final base64Image = await encodeImageToBase64(_selectedImage!);

      // Only metadata goes into Firestore
      final photo = PhotoModel(
        uid: user.uid,
        caption: captionController.text.trim(),
        location: locationInput,
        timestamp: DateTime.now(),
        lat: finalLat,
        lng: finalLng,
        isPublic: isPublic,
      );

      await FirestoreService().uploadPhoto(photo, base64Image);
      if (mounted) {
        Navigator.pop(context);
        _showSnackBar("✅ Memory uploaded successfully!");
      }
    } catch (e) {
      _showSnackBar("❌ Upload failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Memory")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: pickImage,
              child:
                  _selectedImage != null
                      ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          _selectedImage!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      )
                      : Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: Colors.grey[300],
                        ),
                        child: const Center(
                          child: Text("📷 Tap to select image"),
                        ),
                      ),
            ),
            const SizedBox(height: 20),
            CustomTextField(
              controller: captionController,
              label: "Caption",
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            CustomTextField(controller: locationController, label: "Location"),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: isPublic,
              title: const Text("Make this memory public"),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: (val) => setState(() => isPublic = val ?? true),
            ),
            const SizedBox(height: 24),
            isLoading
                ? const Center(child: CircularProgressIndicator())
                : PrimaryButton(text: "Upload Memory", onPressed: uploadMemory),
          ],
        ),
      ),
    );
  }
}

// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import 'package:memscape/services/firestore_service.dart';
// import '../../models/photo_model.dart';
// import '../../widgets/custom_textfield.dart';
// import '../../widgets/primary_button.dart';

// class UploadPhotoScreen extends ConsumerStatefulWidget {
//   const UploadPhotoScreen({super.key});

//   @override
//   ConsumerState<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
// }

// class _UploadPhotoScreenState extends ConsumerState<UploadPhotoScreen> {
//   File? _selectedImage;
//   final captionController = TextEditingController();
//   final locationController = TextEditingController();
//   bool isLoading = false;
//   final picker = ImagePicker();
//   double? _lat;
//   double? _lng;
//   bool isPublic = true;

//   @override
//   void initState() {
//     super.initState();
//     getCurrentLocation();
//   }

//   Future<void> pickImage() async {
//     try {
//       final picked = await picker.pickImage(source: ImageSource.gallery);
//       if (picked != null) {
//         setState(() => _selectedImage = File(picked.path));
//       }
//     } catch (e) {
//       debugPrint("❌ Error selecting image: $e");
//     }
//   }

//   Future<void> getCurrentLocation() async {
//     try {
//       final permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         throw Exception("❌ Location permission denied");
//       }

//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       final placemarks = await placemarkFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );

//       final city =
//           placemarks.isNotEmpty
//               ? placemarks.first.locality ?? 'Unknown'
//               : 'Unknown';

//       setState(() {
//         locationController.text = city;
//         _lat = position.latitude;
//         _lng = position.longitude;
//       });
//     } catch (e) {
//       debugPrint("❌ Failed to get location: $e");
//       locationController.text = 'Unknown';
//     }
//   }

//   Future<String> encodeImageToBase64(File imageFile) async {
//     try {
//       final bytes = await imageFile.readAsBytes();
//       return base64Encode(bytes);
//     } catch (e) {
//       throw Exception("❌ Image encoding failed: $e");
//     }
//   }

//   Future<void> uploadMemory() async {
//     if (_selectedImage == null ||
//         captionController.text.trim().isEmpty ||
//         locationController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please select an image and fill all fields."),
//         ),
//       );
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) throw Exception("❌ No user logged in");

//       final userLocationText = locationController.text.trim();
//       final geocoded = await locationFromAddress(userLocationText);
//       if (geocoded.isEmpty) throw Exception("❌ Location not found");

//       final base64Image = await encodeImageToBase64(_selectedImage!);

//       final photo = PhotoModel(
//         uid: currentUser.uid,
//         imageBase64: base64Image,
//         caption: captionController.text.trim(),
//         location: userLocationText,
//         timestamp: DateTime.now(),
//         lat: geocoded.first.latitude,
//         lng: geocoded.first.longitude,
//         isPublic: isPublic,
//       );

//       // ✅ Save full photo to Firestore
//       await FirestoreService().uploadPhoto(photo);

//       if (mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("✅ Memory uploaded successfully!")),
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ Upload failed: $e");
//       if (mounted) {
//         ScaffoldMessenger.of(
//           context,
//         ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
//       }
//     } finally {
//       if (mounted) setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Upload Memory")),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             GestureDetector(
//               onTap: pickImage,
//               child:
//                   _selectedImage != null
//                       ? ClipRRect(
//                         borderRadius: BorderRadius.circular(16),
//                         child: Image.file(
//                           _selectedImage!,
//                           height: 220,
//                           fit: BoxFit.cover,
//                         ),
//                       )
//                       : Container(
//                         height: 220,
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(16),
//                           color: Colors.grey[300],
//                         ),
//                         child: const Center(
//                           child: Text("📷 Tap to select image"),
//                         ),
//                       ),
//             ),
//             const SizedBox(height: 20),
//             CustomTextField(
//               controller: captionController,
//               label: "Caption",
//               maxLines: 2,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(controller: locationController, label: "Location"),
//             const SizedBox(height: 12),
//             CheckboxListTile(
//               contentPadding: EdgeInsets.zero,
//               value: isPublic,
//               title: const Text("Make this memory public"),
//               controlAffinity: ListTileControlAffinity.leading,
//               onChanged: (val) {
//                 setState(() => isPublic = val ?? true);
//               },
//             ),
//             const SizedBox(height: 24),
//             PrimaryButton(
//               text: isLoading ? "Uploading..." : "Upload Memory",
//               onPressed: isLoading ? null : uploadMemory,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// import 'dart:convert';
// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:image_picker/image_picker.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import 'package:memscape/services/realtime_database_service.dart';
// import 'package:memscape/services/firestore_service.dart';
// import '../../models/photo_model.dart';
// import '../../widgets/custom_textfield.dart';
// import '../../widgets/primary_button.dart';

// class UploadPhotoScreen extends ConsumerStatefulWidget {
//   const UploadPhotoScreen({super.key});

//   @override
//   ConsumerState<UploadPhotoScreen> createState() => _UploadPhotoScreenState();
// }

// class _UploadPhotoScreenState extends ConsumerState<UploadPhotoScreen> {
//   File? _selectedImage;
//   final captionController = TextEditingController();
//   final locationController = TextEditingController();
//   bool isLoading = false;
//   final picker = ImagePicker();
//   double? _lat;
//   double? _lng;
//   bool isPublic = true;

//   @override
//   void initState() {
//     super.initState();
//     getCurrentLocation();
//   }

//   Future<void> pickImage() async {
//     try {
//       final picked = await picker.pickImage(source: ImageSource.gallery);
//       if (picked != null) {
//         setState(() => _selectedImage = File(picked.path));
//       }
//     } catch (e) {
//       debugPrint("❌ Error selecting image: $e");
//     }
//   }

//   Future<void> getCurrentLocation() async {
//     try {
//       final permission = await Geolocator.requestPermission();
//       if (permission == LocationPermission.denied ||
//           permission == LocationPermission.deniedForever) {
//         throw Exception("❌ Location permission denied");
//       }

//       final position = await Geolocator.getCurrentPosition(
//         desiredAccuracy: LocationAccuracy.high,
//       );
//       final placemarks = await placemarkFromCoordinates(
//         position.latitude,
//         position.longitude,
//       );

//       final city =
//           placemarks.isNotEmpty
//               ? placemarks.first.locality ?? 'Unknown'
//               : 'Unknown';

//       setState(() {
//         locationController.text = city;
//         _lat = position.latitude;
//         _lng = position.longitude;
//       });
//     } catch (e) {
//       debugPrint("❌ Failed to get location: $e");
//       locationController.text = 'Unknown';
//     }
//   }

//   Future<String> encodeImageToBase64(File imageFile) async {
//     try {
//       final bytes = await imageFile.readAsBytes();
//       return base64Encode(bytes);
//     } catch (e) {
//       throw Exception("❌ Image encoding failed: $e");
//     }
//   }

//   Future<void> uploadMemory() async {
//     if (_selectedImage == null ||
//         captionController.text.trim().isEmpty ||
//         locationController.text.trim().isEmpty) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text("Please select an image and fill all fields."),
//         ),
//       );
//       return;
//     }

//     setState(() => isLoading = true);

//     try {
//       final currentUser = FirebaseAuth.instance.currentUser;
//       if (currentUser == null) throw Exception("❌ No user logged in");

//       // 🌍 Geocode the entered location (not device GPS)
//       final userLocationText = locationController.text.trim();
//       final List<Location> geocoded = await locationFromAddress(
//         userLocationText,
//       );
//       if (geocoded.isEmpty) throw Exception("Location not found");

//       final base64Image = await encodeImageToBase64(_selectedImage!);

//       final photo = PhotoModel(
//         uid: currentUser.uid,
//         imageBase64: base64Image,
//         caption: captionController.text.trim(),
//         location: userLocationText,
//         timestamp: DateTime.now(),
//         lat: geocoded.first.latitude,
//         lng: geocoded.first.longitude,
//         isPublic: isPublic,
//       );

//       await RealtimeDatabaseService().uploadPhoto(photo);

//       // Upload reference to Firestore
//       final imageId =
//           "${photo.caption}_${photo.timestamp.millisecondsSinceEpoch}";
//       await FirestoreService().uploadPhotoReference(currentUser.uid, imageId);

//       if (mounted) {
//         Navigator.pop(context);
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(content: Text("✅ Memory uploaded successfully!")),
//         );
//       }
//     } catch (e) {
//       debugPrint("❌ Upload failed: $e");
//       ScaffoldMessenger.of(
//         context,
//       ).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
//     } finally {
//       setState(() => isLoading = false);
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(title: const Text("Upload Memory")),
//       body: SingleChildScrollView(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             GestureDetector(
//               onTap: pickImage,
//               child:
//                   _selectedImage != null
//                       ? ClipRRect(
//                         borderRadius: BorderRadius.circular(16),
//                         child: Image.file(
//                           _selectedImage!,
//                           height: 220,
//                           fit: BoxFit.cover,
//                         ),
//                       )
//                       : Container(
//                         height: 220,
//                         width: double.infinity,
//                         decoration: BoxDecoration(
//                           borderRadius: BorderRadius.circular(16),
//                           color: Colors.grey[300],
//                         ),
//                         child: const Center(
//                           child: Text("📷 Tap to select image"),
//                         ),
//                       ),
//             ),
//             const SizedBox(height: 20),
//             CustomTextField(
//               controller: captionController,
//               label: "Caption",
//               maxLines: 2,
//             ),
//             const SizedBox(height: 12),
//             CustomTextField(controller: locationController, label: "Location"),
//             const SizedBox(height: 12),
//             CheckboxListTile(
//               contentPadding: EdgeInsets.zero,
//               value: isPublic,
//               title: const Text("Make this memory public"),
//               controlAffinity: ListTileControlAffinity.leading,
//               onChanged: (val) {
//                 setState(() => isPublic = val ?? true);
//               },
//             ),
//             const SizedBox(height: 24),
//             PrimaryButton(
//               text: isLoading ? "Uploading..." : "Upload Memory",
//               onPressed: isLoading ? null : uploadMemory,
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
