# Nexora AI - Quick Reference Card

## 🚀 Quick Start

```bash
# Clone and setup
git clone <repo>
cd nexora
flutter pub get
dart run build_runner build
flutter run
```

## 📍 File Locations

| What | Where |
|------|-------|
| Add new screen | `lib/features/[feature]/presentation/screens/` |
| Add new component | `lib/core/widgets/` |
| Add new route | `lib/app/router/app_router.dart` |
| Design constants | `lib/core/theme/` |
| Models | `lib/models/` |
| Services | `lib/services/` |

## 🎨 Using Design System

```dart
// Colors
Color(NexoraColors.primary)
Color(NexoraColors.background)
Color(NexoraColors.text)

// Typography
NexoraTypography.heading1
NexoraTypography.bodyMedium
NexoraTypography.button

// Spacing
NexoraSpacing.lg      // 16px
NexoraSpacing.xxxl    // 32px
NexoraSpacing.radiusLG // 16px border radius
```

## 🧩 Common Components

```dart
// Button
NexoraButton(
  label: 'Continue',
  onPressed: () {},
)

// Text Input
NexoraTextField(
  label: 'Email',
  hint: 'your@email.com',
)

// Card
NexoraCard(
  child: Text('Content'),
  onTap: () {},
)

// Avatar
NexoraAvatar(
  initials: 'JS',
  size: 100,
)
```

## 🛣️ Routes

```dart
context.push(RoutePaths.login);     // Push
context.go(RoutePaths.splash);      // Replace
context.pop();                       // Go back
```

## 📊 State (Riverpod - Phase 2)

```dart
// Create provider
final counterProvider = StateProvider((ref) => 0);

// Use in widget
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final counter = ref.watch(counterProvider);
    return Text('$counter');
  }
}
```

## ✅ Before Committing

```bash
flutter analyze     # Check for errors
dart format lib/    # Format code
flutter test        # Run tests
flutter run -v      # Test on device
```

## 📱 Screens

| Screen | Path | Status |
|--------|------|--------|
| Splash | `/` | ✅ |
| Onboarding | `/onboarding` | ✅ |
| Login | `/login` | ✅ |
| Terms | `/terms` | ✅ |
| Start Chat | `/start-chat` | ✅ |
| Chat | `/chat` | ✅ |
| Profile | `/profile` | ✅ |

## 🎯 Current Phase

**Phase 1**: ✅ Complete - All screens built with mock data  
**Phase 2**: 📋 Next - Implement Riverpod state management  
**Phase 3**: ⏳ Future - Firebase authentication

## 📚 Documentation

- `README.md` - Full documentation
- `DEVELOPMENT.md` - Developer guide
- `PROJECT_STRUCTURE.md` - Architecture overview
- `PHASE_0_COMPLETION.md` - Detailed checklist

## 🐛 Troubleshooting

```bash
# Clean build issues
flutter clean
flutter pub get
flutter run

# iOS issues
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..

# Generate code
dart run build_runner build
```

## 💡 Tips

- Use const constructors
- Use design system constants (no magic numbers)
- Create reusable components
- Handle errors gracefully
- Test frequently
- Commit often

## 👥 Contact

- Email: bvccollageai@gmail.com
- Lead: [TBD]

---

**Status**: Phase 1 Complete ✅ | Phase 2 Next 🚀  
**Updated**: 2026-08-13
