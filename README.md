# Memscape

/lib
  ├── main.dart
  ├── core/           # Themes, constants
  ├── models/         # Data models (UserModel, PhotoModel)
  ├── providers/      # Riverpod/State mgmt
  ├── services/       # Firebase/HTTP logic
  ├── screens/        # UI pages
  ├── widgets/        # Reusable UI components


lib/
├── core/
│   ├── app_theme.dart          # Theme config
│   └── constants.dart          # App-wide constants (colors, strings, etc.)
│
├── models/
│   ├── user_model.dart
│   └── photo_model.dart
│
├── providers/
│   └── auth_provider.dart      # For FirebaseAuth state mgmt using Riverpod
│
├── services/
│   ├── firebase_auth_service.dart
│   └── firestore_service.dart
│
├── screens/
│   ├── splash_screen.dart
│   ├── auth/
│   │   ├── login_screen.dart
│   │   └── register_screen.dart
│   └── home/
│       └── home_screen.dart
│
├── widgets/
│   ├── custom_textfield.dart
│   ├── primary_button.dart
│   └── photo_card.dart
