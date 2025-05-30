import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import '../models/photo_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseDatabase _realtime = FirebaseDatabase.instance;

  static const String photosCollection = 'photos';
  static const String usersCollection = 'users';
  static const String base64ImagePath = 'images';

  /// Upload base64 to Realtime DB and metadata to Firestore (excluding base64)
  Future<void> uploadPhoto(PhotoModel photo, String base64Image) async {
    try {
      final docRef = _firestore.collection(photosCollection).doc();
      final imagePath = "$base64ImagePath/${docRef.id}";

      // Upload base64 image to Realtime Database
      await _realtime.ref(imagePath).set(base64Image);

      // Upload metadata to Firestore (excluding imageBase64)
      final updatedPhoto = photo.copyWith(
        imagePath: imagePath,
        imageBase64: null,
      );
      await docRef.set(updatedPhoto.toMap());

      // Add reference to user's document
      await uploadPhotoReference(photo.uid, docRef.id);

      print("✅ Firestore: Metadata saved | Realtime DB imagePath → $imagePath");
    } catch (e) {
      throw Exception("❌ Firestore uploadPhoto failed: $e");
    }
  }

  /// Fetch public photos (limit optional)
  Future<List<PhotoModel>> fetchPublicPhotos({int limit = 20}) async {
    try {
      final querySnapshot = await _firestore
          .collection(photosCollection)
          .where('isPublic', isEqualTo: true)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return querySnapshot.docs
          .map((doc) => PhotoModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception("❌ Firestore fetchPublicPhotos failed: $e");
    }
  }

  /// Real-time public photo stream
  Stream<List<PhotoModel>> getPublicPhotoStream() {
    return _firestore
        .collection(photosCollection)
        .where('isPublic', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => PhotoModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  /// Store reference in user's document
  Future<void> uploadPhotoReference(String uid, String imageId) async {
    try {
      await _firestore.collection(usersCollection).doc(uid).set({
        'photoRefs': FieldValue.arrayUnion([imageId]),
        'bio': "New memory added 🎉",
      }, SetOptions(merge: true));
    } catch (e) {
      throw Exception("❌ Failed to update user photoRefs: $e");
    }
  }

  /// Stream photo reference IDs from user doc
  Stream<List<String>> getUserPhotoReferences(String uid) {
    return _firestore.collection(usersCollection).doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null || !data.containsKey('photoRefs')) return [];
      final List<dynamic> rawList = data['photoRefs'];
      return rawList.map((e) => e.toString()).toList();
    });
  }

  /// Fetch all photos uploaded by specific user
  Future<List<PhotoModel>> fetchUserPhotos({required String userId}) async {
    try {
      final snapshot = await _firestore
          .collection(photosCollection)
          .where('uid', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => PhotoModel.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception("❌ Firestore fetchUserPhotos failed: $e");
    }
  }

  /// Toggle like for a photo
  Future<void> toggleLike(String photoId, String userId) async {
    final ref = _firestore.collection(photosCollection).doc(photoId);
    final snap = await ref.get();

    if (!snap.exists) return;

    final likes = (snap.data()?['likes'] as List?) ?? [];

    final isLiked = likes.contains(userId);
    await ref.update({
      'likes': isLiked
          ? FieldValue.arrayRemove([userId])
          : FieldValue.arrayUnion([userId]),
    });
  }

  /// Add comment to a photo
  Future<void> addComment(String photoId, String userId, String commentText) async {
    final ref = _firestore.collection(photosCollection).doc(photoId);
    final snap = await ref.get();

    if (!snap.exists) return;

    final newComment = {
      'uid': userId,
      'text': commentText,
      'timestamp': FieldValue.serverTimestamp(),
    };

    await ref.update({
      'comments': FieldValue.arrayUnion([newComment]),
    });
  }

  /// Fetch base64 image using imagePath
  Future<String?> fetchImageBase64(String imagePath) async {
    try {
      final snapshot = await _realtime.ref(imagePath).get();
      return snapshot.exists ? snapshot.value as String : null;
    } catch (e) {
      throw Exception("❌ Failed to fetch base64 image: $e");
    }
  }

  /// Follow/unfollow user
  Future<void> toggleFollow(String currentUserId, String targetUserId) async {
    final currentUserRef = _firestore.collection(usersCollection).doc(currentUserId);
    final targetUserRef = _firestore.collection(usersCollection).doc(targetUserId);

    final currentSnap = await currentUserRef.get();
    final currentData = currentSnap.data() ?? {};
    final currentFollowing = (currentData['following'] as List?) ?? [];
    final isFollowing = currentFollowing.contains(targetUserId);

    await currentUserRef.update({
      'following': isFollowing
          ? FieldValue.arrayRemove([targetUserId])
          : FieldValue.arrayUnion([targetUserId]),
    });

    await targetUserRef.update({
      'followers': isFollowing
          ? FieldValue.arrayRemove([currentUserId])
          : FieldValue.arrayUnion([currentUserId]),
    });
  }

  /// Check if current user follows the target user
  Future<bool> isFollowing(String currentUserId, String targetUserId) async {
    final currentUserSnap =
        await _firestore.collection(usersCollection).doc(currentUserId).get();
    final currentData = currentUserSnap.data() ?? {};
    final currentFollowing = (currentData['following'] as List?) ?? [];
    return currentFollowing.contains(targetUserId);
  }
}



// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_database/firebase_database.dart';
// import '../models/photo_model.dart';

// class FirestoreService {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseDatabase _realtime = FirebaseDatabase.instance;

//   static const String photosCollection = 'photos';
//   static const String usersCollection = 'users';
//   static const String base64ImagePath = 'images';

//   /// Upload base64 to Realtime DB and metadata to Firestore (excluding base64)
//   Future<void> uploadPhoto(PhotoModel photo, String base64Image) async {
//     try {
//       final docRef = _firestore.collection(photosCollection).doc();
//       final imagePath = "$base64ImagePath/${docRef.id}";

//       // Upload base64 image to Realtime Database
//       await _realtime.ref(imagePath).set(base64Image);

//       // Upload metadata to Firestore (excluding imageBase64)
//       final updatedPhoto = photo.copyWith(
//         imagePath: imagePath,
//         imageBase64: null,
//       );
//       await docRef.set(updatedPhoto.toMap());

//       // Add reference to user's document
//       await uploadPhotoReference(photo.uid, docRef.id);

//       print("✅ Firestore: Metadata saved | Realtime DB imagePath → $imagePath");
//     } catch (e) {
//       throw Exception("❌ Firestore uploadPhoto failed: $e");
//     }
//   }

//   /// Fetch public photos (limit optional)
//   Future<List<PhotoModel>> fetchPublicPhotos({int limit = 20}) async {
//     try {
//       final querySnapshot =
//           await _firestore
//               .collection(photosCollection)
//               .where('isPublic', isEqualTo: true)
//               .orderBy('timestamp', descending: true)
//               .limit(limit)
//               .get();

//       return querySnapshot.docs
//           .map((doc) => PhotoModel.fromMap(doc.data()))
//           .toList();
//     } catch (e) {
//       throw Exception("❌ Firestore fetchPublicPhotos failed: $e");
//     }
//   }

//   /// Real-time public photo stream
//   Stream<List<PhotoModel>> getPublicPhotoStream() {
//     return _firestore
//         .collection(photosCollection)
//         .where('isPublic', isEqualTo: true)
//         .orderBy('timestamp', descending: true)
//         .snapshots()
//         .map(
//           (snapshot) =>
//               snapshot.docs
//                   .map((doc) => PhotoModel.fromMap(doc.data()))
//                   .toList(),
//         );
//   }

//   /// Store reference in user's document
//   Future<void> uploadPhotoReference(String uid, String imageId) async {
//     try {
//       await _firestore.collection(usersCollection).doc(uid).set({
//         'photoRefs': FieldValue.arrayUnion([imageId]),
//         'bio': "New memory added 🎉",
//       }, SetOptions(merge: true));
//     } catch (e) {
//       throw Exception("❌ Failed to update user photoRefs: $e");
//     }
//   }

//   /// Stream photo reference IDs from user doc
//   Stream<List<String>> getUserPhotoReferences(String uid) {
//     return _firestore.collection(usersCollection).doc(uid).snapshots().map((
//       doc,
//     ) {
//       final data = doc.data();
//       if (data == null || !data.containsKey('photoRefs')) return [];
//       final List<dynamic> rawList = data['photoRefs'];
//       return rawList.map((e) => e.toString()).toList();
//     });
//   }

//   /// Fetch all photos uploaded by specific user
//   Future<List<PhotoModel>> fetchUserPhotos({required String userId}) async {
//     try {
//       final snapshot =
//           await _firestore
//               .collection(photosCollection)
//               .where('uid', isEqualTo: userId)
//               .orderBy('timestamp', descending: true)
//               .get();

//       return snapshot.docs
//           .map((doc) => PhotoModel.fromMap(doc.data()))
//           .toList();
//     } catch (e) {
//       throw Exception("❌ Firestore fetchUserPhotos failed: $e");
//     }
//   }

//   /// Toggle like for a photo
//   Future<void> toggleLike(String photoId, String userId) async {
//     final ref = _firestore.collection(photosCollection).doc(photoId);
//     final snap = await ref.get();

//     if (!snap.exists) return;

//     final likes = (snap.data()?['likes'] as List?) ?? [];

//     final isLiked = likes.contains(userId);
//     await ref.update({
//       'likes':
//           isLiked
//               ? FieldValue.arrayRemove([userId])
//               : FieldValue.arrayUnion([userId]),
//     });
//   }

//   /// Add comment to a photo
//   Future<void> addComment(
//     String photoId,
//     String userId,
//     String commentText,
//   ) async {
//     final ref = _firestore.collection(photosCollection).doc(photoId);
//     final snap = await ref.get();

//     if (!snap.exists) return;

//     final newComment = {
//       'uid': userId,
//       'text': commentText,
//       'timestamp': FieldValue.serverTimestamp(),
//     };

//     await ref.update({
//       'comments': FieldValue.arrayUnion([newComment]),
//     });
//   }

//   /// Fetch base64 image using imagePath
//   Future<String?> fetchImageBase64(String imagePath) async {
//     try {
//       final snapshot = await _realtime.ref(imagePath).get();
//       return snapshot.exists ? snapshot.value as String : null;
//     } catch (e) {
//       throw Exception("❌ Failed to fetch base64 image: $e");
//     }
//   }
// }
