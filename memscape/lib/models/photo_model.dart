class PhotoModel {
  final String uid;
  final String? imageBase64; // ⛔ Used only at runtime, NOT in Firestore
  final String? imagePath; // ✅ Stored in Firestore as a reference
  final String caption;
  final String location;
  final DateTime timestamp;
  final double? lat;
  final double? lng;
  final bool isPublic;
  final List<String> likes;
  final List<Map<String, dynamic>> comments;

  final String? id; // Add this

  PhotoModel({
    this.id, // new
    required this.uid,
    this.imageBase64,
    this.imagePath,
    required this.caption,
    required this.location,
    required this.timestamp,
    this.lat,
    this.lng,
    required this.isPublic,
    this.likes = const [],
    this.comments = const [],
  });

  /// ✅ Firestore-safe version of the object
  Map<String, dynamic> toMap() => {
    'uid': uid,
    'imagePath': imagePath, // ✅ only store image path
    'caption': caption,
    'location': location,
    'timestamp': timestamp.toIso8601String(),
    'lat': lat,
    'lng': lng,
    'isPublic': isPublic,
    'likes': likes,
    'comments': comments,
  };

  /// ✅ Factory to recreate object from Firestore (does NOT include base64)
  factory PhotoModel.fromMap(Map<String, dynamic> map, [String? id]) =>
      PhotoModel(
        id: id, // Optional
        uid: map['uid'],
        imagePath: map['imagePath'],
        caption: map['caption'],
        location: map['location'],
        timestamp: DateTime.parse(map['timestamp']),
        lat: map['lat']?.toDouble(),
        lng: map['lng']?.toDouble(),
        isPublic: map['isPublic'] ?? true,
        likes: List<String>.from(map['likes'] ?? []),
        comments: List<Map<String, dynamic>>.from(map['comments'] ?? []),
      );

  /// Used internally to modify state or copy with updated imagePath
  PhotoModel copyWith({
    String? uid,
    String? imageBase64,
    String? imagePath,
    String? caption,
    String? location,
    DateTime? timestamp,
    double? lat,
    double? lng,
    bool? isPublic,
    List<String>? likes,
    List<Map<String, dynamic>>? comments,
  }) {
    return PhotoModel(
      uid: uid ?? this.uid,
      imageBase64: imageBase64 ?? this.imageBase64, // ✅ runtime only
      imagePath: imagePath ?? this.imagePath,
      caption: caption ?? this.caption,
      location: location ?? this.location,
      timestamp: timestamp ?? this.timestamp,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      isPublic: isPublic ?? this.isPublic,
      likes: likes ?? this.likes,
      comments: comments ?? this.comments,
    );
  }
}

// class PhotoModel {
//   final String uid;
//   final String? imageBase64; // ⛔ Used only at runtime, NOT in Firestore
//   final String? imagePath; // ✅ Stored in Firestore as a reference
//   final String caption;
//   final String location;
//   final DateTime timestamp;
//   final double? lat;
//   final double? lng;
//   final bool isPublic;
//   final List<String> likes;
//   final List<Map<String, dynamic>> comments;

//   PhotoModel({
//     required this.uid,
//     this.imageBase64, // will NOT be stored in Firestore
//     this.imagePath,
//     required this.caption,
//     required this.location,
//     required this.timestamp,
//     this.lat,
//     this.lng,
//     required this.isPublic,
//     this.likes = const [],
//     this.comments = const [],
//   });

//   /// ✅ Firestore-safe version of the object
//   Map<String, dynamic> toMap() => {
//     'uid': uid,
//     'imagePath': imagePath, // ✅ only store image path
//     'caption': caption,
//     'location': location,
//     'timestamp': timestamp.toIso8601String(),
//     'lat': lat,
//     'lng': lng,
//     'isPublic': isPublic,
//     'likes': likes,
//     'comments': comments,
//   };

//   /// ✅ Factory to recreate object from Firestore (does NOT include base64)
//   factory PhotoModel.fromMap(Map<String, dynamic> map) => PhotoModel(
//     uid: map['uid'],
//     imagePath: map['imagePath'],
//     caption: map['caption'],
//     location: map['location'],
//     timestamp: DateTime.parse(map['timestamp']),
//     lat: map['lat']?.toDouble(),
//     lng: map['lng']?.toDouble(),
//     isPublic: map['isPublic'] ?? true,
//     likes: List<String>.from(map['likes'] ?? []),
//     comments: List<Map<String, dynamic>>.from(map['comments'] ?? []),
//   );

//   /// Used internally to modify state or copy with updated imagePath
//   PhotoModel copyWith({
//     String? uid,
//     String? imageBase64,
//     String? imagePath,
//     String? caption,
//     String? location,
//     DateTime? timestamp,
//     double? lat,
//     double? lng,
//     bool? isPublic,
//     List<String>? likes,
//     List<Map<String, dynamic>>? comments,
//   }) {
//     return PhotoModel(
//       uid: uid ?? this.uid,
//       imageBase64: imageBase64 ?? this.imageBase64, // ✅ runtime only
//       imagePath: imagePath ?? this.imagePath,
//       caption: caption ?? this.caption,
//       location: location ?? this.location,
//       timestamp: timestamp ?? this.timestamp,
//       lat: lat ?? this.lat,
//       lng: lng ?? this.lng,
//       isPublic: isPublic ?? this.isPublic,
//       likes: likes ?? this.likes,
//       comments: comments ?? this.comments,
//     );
//   }
// }
