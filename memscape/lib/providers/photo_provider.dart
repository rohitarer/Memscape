import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/photo_model.dart';
import '../services/firestore_service.dart';

/// 🔐 Fetch photos uploaded by the logged-in user
final userPhotosProvider = FutureProvider<List<PhotoModel>>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    if (kDebugMode) {
      debugPrint("⚠️ No user logged in. Returning empty photo list.");
    }
    return [];
  }

  try {
    final photos = await FirestoreService().fetchUserPhotos(userId: user.uid);
    if (kDebugMode) {
      debugPrint("✅ Fetched ${photos.length} user photos for UID: ${user.uid}");
    }
    return photos;
  } catch (e, st) {
    debugPrint("❌ Error in userPhotosProvider: $e");
    return Future.error(e, st);
  }
});

/// 🌍 Fetch public photos (for Explore Feed)
final publicPhotosProvider = FutureProvider<List<PhotoModel>>((ref) async {
  try {
    final publicPhotos = await FirestoreService().fetchPublicPhotos();
    if (kDebugMode) {
      debugPrint("🌐 Loaded ${publicPhotos.length} public photos.");
    }
    return publicPhotos;
  } catch (e, st) {
    debugPrint("❌ Error in publicPhotosProvider: $e");
    return Future.error(e, st);
  }
});

// import 'package:flutter/foundation.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import '../models/photo_model.dart';
// import '../services/firestore_service.dart';

// final userPhotosProvider = FutureProvider<List<PhotoModel>>((ref) async {
//   final user = FirebaseAuth.instance.currentUser;
//   if (user == null) {
//     if (kDebugMode) {
//       debugPrint("⚠️ No user logged in. Returning empty photo list.");
//     }
//     return [];
//   }

//   try {
//     final photos = await FirestoreService().fetchUserPhotos(userId: user.uid);
//     if (kDebugMode) {
//       debugPrint(
//         "✅ Successfully fetched ${photos.length} photos for user ${user.uid}",
//       );
//     }
//     return photos;
//   } catch (e, st) {
//     if (kDebugMode) {
//       debugPrint("❌ Firestore fetchUserPhotos error: $e");
//     }
//     // You can report this to Sentry/Crashlytics here
//     return Future.error(e, st);
//   }
// });
