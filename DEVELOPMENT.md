# Nexora AI - Development Quick Start Guide

## Quick Setup (5 minutes)

### Prerequisites
```bash
flutter --version  # Should be 3.0+
dart --version     # Should be 3.0+
```

### First Run
```bash
cd nexora
flutter pub get
dart run build_runner build
flutter run
```

---

## Key Files & Folders

| Path | Purpose |
|------|---------|
| `lib/main.dart` | App entry point |
| `lib/app/router/app_router.dart` | Navigation routes |
| `lib/core/theme/` | Design system (colors, fonts, spacing) |
| `lib/core/widgets/` | Reusable UI components |
| `lib/features/*/presentation/screens/` | Feature UI screens |
| `lib/models/` | Data models |
| `pubspec.yaml` | Dependencies |
| `README.md` | Full documentation |

---

## Design System Usage

### Colors
```dart
import 'core/theme/colors.dart';

Color primaryColor = Color(NexoraColors.primary);     // Orange
Color backgroundColor = Color(NexoraColors.background); // Warm light
Color textColor = Color(NexoraColors.text);          // Dark
```

### Typography
```dart
import 'core/theme/typography.dart';

// Use predefined styles
Text('Heading', style: NexoraTypography.heading1);
Text('Body', style: NexoraTypography.bodyMedium);
Text('Button', style: NexoraTypography.button);
```

### Spacing
```dart
import 'core/theme/spacing.dart';

SizedBox(height: NexoraSpacing.lg);  // 16px
Padding(padding: EdgeInsets.all(NexoraSpacing.md)); // 12px
BorderRadius.circular(NexoraSpacing.radiusLG);     // 16px
```

---

## Component Usage

### Buttons
```dart
// Primary button
NexoraButton(
  label: 'Continue',
  onPressed: () => print('Clicked'),
  width: double.infinity,
)

// Outline button
NexoraOutlineButton(
  label: 'Secondary',
  onPressed: () {},
)

// Text button
NexoraTextButton(
  label: 'Skip',
  onPressed: () {},
)
```

### Text Fields
```dart
NexoraTextField(
  label: 'Email',
  hint: 'Enter email',
  keyboardType: TextInputType.emailAddress,
  prefixIcon: Icons.email,
  validator: (value) {
    if (value?.isEmpty ?? true) return 'Required';
  },
)
```

### Cards
```dart
NexoraCard(
  child: Text('Content'),
  onTap: () {},
)
```

### Avatars
```dart
NexoraAvatar(
  initials: 'JS',
  size: 100,
  onTap: () {},
)
```

---

## Navigation

### Push new route
```dart
import 'package:go_router/go_router.dart';

// From anywhere in the app
context.push(RoutePaths.chat);
context.push('/chat/chatId123');
```

### Replace current route
```dart
context.go(RoutePaths.login);  // Replaces back stack
```

### Route paths
```dart
// Defined in lib/app/router/app_router.dart
RoutePaths.splash      // '/'
RoutePaths.onboarding  // '/onboarding'
RoutePaths.login       // '/login'
RoutePaths.terms       // '/terms'
RoutePaths.startChat   // '/start-chat'
RoutePaths.chat        // '/chat'
RoutePaths.profile     // '/profile'
```

---

## State Management (Riverpod)

### Creating a Provider
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Simple provider
final counterProvider = StateProvider((ref) => 0);

// Async provider (for API calls)
final userProvider = FutureProvider<User>((ref) async {
  return await fetchUser();
});

// State notifier provider (for complex state)
class UserNotifier extends StateNotifier<User?> {
  UserNotifier() : super(null);
  
  void updateUser(User user) => state = user;
}

final userNotifierProvider = StateNotifierProvider<UserNotifier, User?>(
  (ref) => UserNotifier(),
);
```

### Using Providers in Widgets
```dart
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterProvider);
    
    return Text('$counter');
  }
}
```

---

## Common Tasks

### Add a new feature
1. Create folder: `lib/features/feature_name/`
2. Create subfolders: `data/`, `domain/`, `presentation/`
3. Create screen: `presentation/screens/feature_screen.dart`
4. Add route to `lib/app/router/app_router.dart`

### Add a new screen
```dart
// File: lib/features/myfeature/presentation/screens/my_screen.dart
import 'package:flutter/material.dart';

class MyScreen extends StatelessWidget {
  const MyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('My Screen')),
      body: Center(child: Text('Content')),
    );
  }
}

// Add to router: lib/app/router/app_router.dart
GoRoute(
  path: '/my-feature',
  builder: (context, state) => MyScreen(),
),
```

### Add a new component
```dart
// File: lib/core/widgets/my_component.dart
import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';

class MyComponent extends StatelessWidget {
  final String label;
  
  const MyComponent({
    Key? key,
    required this.label,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(NexoraSpacing.lg),
      decoration: BoxDecoration(
        color: Color(NexoraColors.surface),
        borderRadius: BorderRadius.circular(NexoraSpacing.radiusLG),
      ),
      child: Text(label),
    );
  }
}
```

---

## Testing

### Run all tests
```bash
flutter test
```

### Run specific test file
```bash
flutter test test/unit/models_test.dart
```

### Run with coverage
```bash
flutter test --coverage
```

---

## Code Quality

### Analyze code
```bash
flutter analyze
```

### Format code
```bash
dart format lib/
```

### Fix linting issues
```bash
dart fix --apply
```

---

## Debugging

### Enable debug mode
```bash
flutter run -v  # Verbose output
```

### Debug with DevTools
```bash
flutter run
# Then press 'd' to open DevTools in browser
```

### Print debugging
```dart
print('Debug: $value');  // Simple logging
debugPrint('Debug: $value');  // Flutter-aware logging
```

### Better logging
```dart
import 'package:logger/logger.dart';

final log = Logger();

log.d('Debug message');
log.i('Info message');
log.w('Warning message');
log.e('Error message', error: exception, stackTrace: stackTrace);
```

---

## Common Issues & Solutions

### `flutter run` fails
```bash
flutter clean
flutter pub get
flutter run
```

### Build cache issues
```bash
flutter clean
rm -rf build/
rm -rf pubspec.lock
flutter pub get
flutter run
```

### Hot reload not working
- Save file normally (single save)
- Stop and restart `flutter run`
- Or press 'R' in terminal

### Android emulator slow
```bash
flutter run -v  # See what's happening
# Or use real device
```

### iOS build fails
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter run
```

---

## Best Practices

### ✅ DO
- Use const constructors
- Use design system constants (colors, spacing, typography)
- Create reusable components
- Use immutable models
- Follow null safety
- Add proper error handling
- Write descriptive variable names
- Use proper git commit messages

### ❌ DON'T
- Use raw hex colors or magic numbers
- Create massive widgets (>300 lines)
- Use global variables
- Ignore warnings
- Commit secrets or .env files
- Use List.from() unnecessarily
- Ignore exceptions
- Skip null checks

---

## Phase Completion Checklist

Before marking a phase complete:
- [ ] All code compiled without errors
- [ ] `flutter analyze` shows no errors
- [ ] `flutter test` passes
- [ ] README updated
- [ ] Git committed with clear message
- [ ] Tested on both Android and iOS
- [ ] No console warnings during `flutter run`
- [ ] Design system used consistently
- [ ] Components properly documented

---

## Useful Commands

```bash
# List all available devices
flutter devices

# Run on specific device
flutter run -d device_id

# Build Android APK
flutter build apk --split-per-abi

# Build iOS IPA
flutter build ipa

# Get app version
flutter --version

# Create new Flutter project (don't use)
flutter create app_name

# Upgrade Flutter
flutter upgrade

# Pub commands
flutter pub get       # Get dependencies
flutter pub upgrade   # Upgrade dependencies
flutter pub outdated  # Check outdated packages

# Clean commands
flutter clean                   # Clean build files
dart run build_runner clean     # Clean generated files

# Code generation
dart run build_runner build             # Generate files once
dart run build_runner watch             # Watch & auto-generate
dart run build_runner build --delete-conflicting-outputs

# Testing
flutter test                    # Run all tests
flutter test test/mytest.dart   # Run specific test
flutter test --coverage         # Generate coverage report

# Analytics
flutter pub global activate google_analytics  # Enable analytics
flutter config --analytics      # Set analytics
```

---

## Phase Tracker

| Phase | Status | Key Tasks |
|-------|--------|-----------|
| 0 | ✅ Complete | Project structure, design system |
| 1 | ✅ Complete | UI implementation from Figma |
| 2 | 📋 Next | Riverpod state management |
| 3 | ⏳ Future | Firebase authentication |
| 4 | ⏳ Future | Firestore database |
| 5 | ⏳ Future | Cloudflare API |
| 6 | ⏳ Future | AI provider integration |
| 7 | ⏳ Future | Knowledge base / RAG |
| 8 | ⏳ Future | File storage |
| 9 | ⏳ Future | Security & authorization |
| 10 | ⏳ Future | Testing & optimization |

---

## Contact & Support

- **College Email**: bvccollageai@gmail.com
- **Documentation**: See README.md in project root
- **Issues**: Report in project tracker
- **Code Review**: Follow PR template

---

**Happy Coding! 🚀**
