import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../providers/photo_provider.dart';
import '../../widgets/photo_card.dart';
import 'explore_map_screen.dart';
import 'upload_photo_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final user = FirebaseAuth.instance.currentUser;
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text("User not logged in. Please login again.")),
      );
    }

    final publicPhotosAsync = ref.watch(publicPhotosProvider);

    final screens = [
      /// 0: Explore Feed
      publicPhotosAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("❌ Error loading feed: $e")),
        data:
            (photos) =>
                photos.isEmpty
                    ? const Center(child: Text("🌍 No public photos yet."))
                    : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: photos.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder:
                          (context, index) => PhotoCard(photo: photos[index]),
                    ),
      ),

      /// 1: Explore Map
      const ExploreMapScreen(),

      /// 2: Upload
      const UploadPhotoScreen(),

      /// 3: Profile
      const ProfileScreen(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text("📸 Memscape"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () {
              ref.invalidate(publicPhotosProvider);
            },
          ),
        ],
      ),
      body: SafeArea(child: screens[_currentIndex]),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Theme.of(context).colorScheme.outline,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Map'),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_box_outlined),
            label: 'Upload',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:memscape/screens/home/explore_map_screen.dart';
// import 'package:memscape/screens/home/upload_photo_screen.dart';
// import 'package:memscape/widgets/photo_card.dart';

// import '../../providers/photo_provider.dart';

// class HomeScreen extends ConsumerStatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   ConsumerState<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends ConsumerState<HomeScreen> with SingleTickerProviderStateMixin {
//   late TabController _tabController;
//   final user = FirebaseAuth.instance.currentUser;

//   @override
//   void initState() {
//     super.initState();
//     _tabController = TabController(length: 2, vsync: this);
//   }

//   @override
//   void dispose() {
//     _tabController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     if (user == null) {
//       return const Scaffold(
//         body: Center(child: Text("User not logged in. Please login again.")),
//       );
//     }

//     final myPhotosAsync = ref.watch(userPhotosProvider);
//     final publicPhotosAsync = ref.watch(publicPhotosProvider);

//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("📸 Memscape"),
//         bottom: TabBar(
//           controller: _tabController,
//           tabs: const [
//             Tab(icon: Icon(Icons.lock), text: "My Memories"),
//             Tab(icon: Icon(Icons.public), text: "Explore Feed"),
//           ],
//         ),
//         actions: [
//           IconButton(
//             icon: const Icon(Icons.map_outlined),
//             tooltip: 'Explore Map',
//             onPressed: () {
//               Navigator.push(
//                 context,
//                 MaterialPageRoute(builder: (_) => const ExploreMapScreen()),
//               );
//             },
//           ),
//           IconButton(
//             icon: const Icon(Icons.refresh),
//             tooltip: 'Refresh',
//             onPressed: () {
//               ref.invalidate(userPhotosProvider);
//               ref.invalidate(publicPhotosProvider);
//             },
//           ),
//         ],
//       ),
//       body: TabBarView(
//         controller: _tabController,
//         children: [
//           /// 🔹 Tab 1: My Memories
//           myPhotosAsync.when(
//             loading: () => const Center(child: CircularProgressIndicator()),
//             error: (e, _) => Center(child: Text("❌ Error: $e")),
//             data: (photos) => photos.isEmpty
//                 ? const Center(child: Text("📭 No memories uploaded yet."))
//                 : ListView.separated(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: photos.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 12),
//                     itemBuilder: (context, index) => PhotoCard(photo: photos[index]),
//                   ),
//           ),

//           /// 🔹 Tab 2: Explore Feed
//           publicPhotosAsync.when(
//             loading: () => const Center(child: CircularProgressIndicator()),
//             error: (e, _) => Center(child: Text("❌ Error: $e")),
//             data: (photos) => photos.isEmpty
//                 ? const Center(child: Text("🌍 No public photos yet."))
//                 : ListView.separated(
//                     padding: const EdgeInsets.all(16),
//                     itemCount: photos.length,
//                     separatorBuilder: (_, __) => const SizedBox(height: 12),
//                     itemBuilder: (context, index) => PhotoCard(photo: photos[index]),
//                   ),
//           ),
//         ],
//       ),
//       floatingActionButton: FloatingActionButton.extended(
//         onPressed: () {
//           Navigator.push(
//             context,
//             MaterialPageRoute(builder: (_) => const UploadPhotoScreen()),
//           );
//         },
//         icon: const Icon(Icons.add_a_photo),
//         label: const Text("Upload"),
//       ),
//     );
//   }
// }
