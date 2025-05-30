import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:memscape/screens/home/public_profile_screen.dart';
import '../models/photo_model.dart';

class PhotoCard extends StatelessWidget {
  final PhotoModel photo;

  const PhotoCard({super.key, required this.photo});

  Future<String?> fetchBase64Image(String? path) async {
    if (path == null || path.isEmpty) return null;

    try {
      final snapshot = await FirebaseDatabase.instance.ref(path).get();
      if (snapshot.exists) {
        return snapshot.value as String;
      }
    } catch (e) {
      debugPrint("❌ Error loading image: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: fetchBase64Image(photo.imagePath),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || snapshot.data == null) {
          return const Center(child: Text("❌ Failed to load image"));
        }

        final imageBytes = base64Decode(snapshot.data!);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Header: User avatar + name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) =>
                              PublicProfileScreen(uid: photo.uid), // <-- fixed
                    ),
                  );
                },
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundImage: AssetImage("assets/default_user.png"),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "User: ${photo.uid.substring(0, 6)}", // or displayName if available
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            /// 🔹 Image
            ClipRRect(
              borderRadius: BorderRadius.circular(0),
              child: Image.memory(
                imageBytes,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
              ),
            ),

            /// 🔹 Caption, Location, Timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    photo.caption,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  if (photo.location.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        photo.location,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      photo.timestamp.toLocal().toString().split('.')[0],
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),
          ],
        );
      },
    );
  }
}

// import 'dart:convert';
// import 'package:flutter/material.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../models/photo_model.dart';

// class PhotoCard extends StatelessWidget {
//   final PhotoModel photo;

//   const PhotoCard({super.key, required this.photo});

//   Future<String?> fetchBase64Image(String? path) async {
//     if (path == null || path.isEmpty) return null;

//     try {
//       final snapshot = await FirebaseDatabase.instance.ref(path).get();
//       if (snapshot.exists) {
//         return snapshot.value as String;
//       }
//     } catch (e) {
//       debugPrint("❌ Error loading image: $e");
//     }
//     return null;
//   }

//   @override
//   Widget build(BuildContext context) {
//     return FutureBuilder<String?>(
//       future: fetchBase64Image(photo.imagePath),
//       // ← fetch from RTDB
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting) {
//           return const Center(child: CircularProgressIndicator());
//         }

//         if (!snapshot.hasData || snapshot.data == null) {
//           return const Center(child: Text("❌ Failed to load image"));
//         }

//         final imageBytes = base64Decode(snapshot.data!);

//         return Card(
//           margin: const EdgeInsets.symmetric(vertical: 10),
//           elevation: 3,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(12),
//           ),
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               ClipRRect(
//                 borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(12),
//                 ),
//                 child: Image.memory(
//                   imageBytes,
//                   width: double.infinity,
//                   height: 200,
//                   fit: BoxFit.cover,
//                 ),
//               ),
//               Padding(
//                 padding: const EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       photo.caption,
//                       style: const TextStyle(
//                         fontSize: 16,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                     const SizedBox(height: 6),
//                     Text(
//                       photo.location,
//                       style: const TextStyle(fontSize: 14, color: Colors.grey),
//                     ),
//                     const SizedBox(height: 4),
//                     Text(
//                       photo.timestamp.toLocal().toString().split('.')[0],
//                       style: const TextStyle(fontSize: 12, color: Colors.grey),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
// }
