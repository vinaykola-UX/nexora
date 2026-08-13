# Nexora AI - Flutter Mobile Application

College-aware AI assistant for students, teachers/staff and administrators at BVC Engineering College.

## Project Overview

**Nexora AI** is a production-quality Flutter application built for Android and iOS platforms. It provides an intelligent conversational interface powered by college-specific knowledge, helping students and staff access information about academics, placement, regulations, and study materials.

### Key Information
- **Organization**: BVC Engineering College
- **Contact**: bvccollageai@gmail.com
- **Target Platforms**: Android & iOS
- **Architecture**: Feature-first with clean architecture principles
- **State Management**: Riverpod
- **Navigation**: go_router

---

## Development Phases

The project is developed in structured phases to ensure clean, incremental progress:

- **PHASE 0**: ✅ Project inspection & architecture
- **PHASE 1**: UI implementation from Figma design (IN PROGRESS)
- **PHASE 2**: Navigation & local application state
- **PHASE 3**: Firebase Authentication
- **PHASE 4**: Firestore database + user profiles + chat history
- **PHASE 5**: Cloudflare API/backend
- **PHASE 6**: AI provider integration
- **PHASE 7**: Knowledge base / RAG
- **PHASE 8**: File & profile-image storage
- **PHASE 9**: Security, rate limiting, authorization
- **PHASE 10**: Testing, optimization, release builds

---

## Project Structure

```
lib/
├── main.dart                          # Application entry point
├── app/
│   ├── app.dart                       # App configuration
│   ├── router/
│   │   └── app_router.dart            # go_router configuration
│   └── theme/
│       ├── theme.dart                 # ThemeData
│       ├── colors.dart                # Color palette
│       ├── typography.dart            # Text styles
│       └── spacing.dart               # Spacing & layout constants
├── core/
│   ├── constants/
│   │   └── app_constants.dart         # App-wide constants
│   ├── errors/
│   │   └── app_exception.dart         # Exception hierarchy
│   ├── extensions/                    # Dart extension methods
│   ├── utils/                         # Utility functions
│   ├── widgets/                       # Reusable components
│   │   ├── nexora_button.dart
│   │   ├── nexora_textfield.dart
│   │   └── nexora_widgets.dart
│   └── theme/                         # Theme configuration
├── features/
│   ├── splash/
│   │   └── presentation/screens/
│   │       └── splash_screen.dart
│   ├── onboarding/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           └── onboarding_screen.dart
│   ├── authentication/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           └── login_screen.dart
│   ├── terms/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           └── terms_screen.dart
│   ├── chat/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       ├── widgets/
│   │       └── screens/
│   │           ├── start_chat_screen.dart
│   │           └── chat_screen.dart
│   ├── chat_history/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   ├── profile/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │       └── screens/
│   │           └── profile_screen.dart
│   ├── knowledge_base/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   └── admin/
│       ├── data/
│       ├── domain/
│       └── presentation/
├── models/
│   ├── user_model.dart
│   └── chat_model.dart
├── services/
│   ├── auth_service.dart
│   ├── firebase_service.dart
│   ├── api_service.dart
│   └── storage_service.dart
└── test/
    ├── unit/
    ├── widget/
    └── integration/
```

---

## Technology Stack

### Core Framework
- **Flutter**: 3.0+
- **Dart**: 3.0+

### State Management
- **Riverpod** 2.5.0: Modern, type-safe state management
- **flutter_riverpod**: Flutter integration for Riverpod

### Navigation & Routing
- **go_router** 14.0.0: Production-grade declarative routing

### Backend Services
- **Firebase Core** 27.0.0
- **Firebase Auth** 5.1.0: Authentication
- **Cloud Firestore** 5.1.0: Database
- **Firebase Storage** 12.1.0: File storage
- **Firebase Analytics** 11.1.0: Analytics

### UI & Design
- **google_fonts** 6.0.0: Custom fonts
- **flutter_svg** 2.0.0: SVG support
- **cached_network_image** 3.3.0: Image caching

### API & HTTP
- **http** 1.1.0: HTTP client
- **dio** 5.4.0: Advanced HTTP client

### Local Storage
- **shared_preferences** 2.2.0: Simple key-value storage
- **hive** 2.2.0: Fast local database
- **hive_flutter** 1.1.0

### Utilities
- **intl** 0.19.0: Internationalization
- **uuid** 4.0.0: UUID generation
- **connectivity_plus** 6.0.0: Network connectivity
- **package_info_plus** 5.0.0: Package info
- **logger** 2.1.0: Logging
- **image_picker** 1.0.0: Image selection
- **permission_handler** 11.4.0: Runtime permissions

---

## Design System

### Color Palette (Nexora Warm Light)

#### Primary Colors
- **Primary**: `#FFA500` (Warm Orange)
- **Primary Light**: `#FFD580`
- **Primary Dark**: `#CC8400`

#### Backgrounds
- **Background**: `#FAF8F3` (Warm Light)
- **Surface**: `#FFFFFF` (White)
- **Surface Light**: `#FEFAF5`

#### Text Colors
- **Text**: `#2D2D2D` (Dark)
- **Text Secondary**: `#666666`
- **Text Muted**: `#999999`
- **Text Light**: `#CCCCCC`

#### Semantic Colors
- **Success**: `#4CAF50`
- **Error**: `#F44336`
- **Warning**: `#FFC107`
- **Info**: `#2196F3`

### Typography
- **Font Family**: Poppins
- **Heading 1**: 32px, Bold (700)
- **Heading 2**: 28px, Bold (700)
- **Heading 3**: 24px, Bold (700)
- **Heading 4**: 20px, Bold (700)
- **Body Large**: 18px, Medium (500)
- **Body Medium**: 16px, Regular (400)
- **Body Small**: 14px, Regular (400)
- **Label**: 14-16px, Semi-bold (600)
- **Caption**: 12px, Regular (400)

### Spacing Scale
- **xs**: 4px
- **sm**: 8px
- **md**: 12px
- **lg**: 16px
- **xl**: 20px
- **xxl**: 24px
- **xxxl**: 32px
- **huge**: 48px

### Border Radius
- **xs**: 4px
- **sm**: 8px
- **md**: 12px
- **lg**: 16px
- **xl**: 20px
- **xxl**: 24px

---

## Screen Flow

```
Splash Screen
    ↓
Onboarding (BVC + Nexora AI)
    ↓
Login (College Account)
    ↓
Terms & Privacy
    ↓
Start Chat (Topic Selection)
    ↓
Chat Interface
    ├── Chat (with history drawer)
    ├── Chat History (drawer)
    └── Profile (drawer)
```

---

## Screens Implemented (Phase 1)

### 1. Splash Screen
- Logo and app name
- Loading state
- Navigation to onboarding

### 2. Onboarding
- Multiple slides with key features
- Page indicators
- Skip/Continue navigation

### 3. Login
- Email/College ID input
- Password input
- Forgot password link
- Google login button
- Sign up prompt

### 4. Terms & Privacy
- Terms of Service content
- Privacy Policy content
- Checkbox agreements
- Continue button (enabled only when both agreed)

### 5. Start Chat
- Topic cards (Academic Regulations, Placement, Study Material, General)
- "Start from scratch" option
- Navigation to chat

### 6. Chat
- Message list with user/AI bubbles
- Message input field
- Send button
- Chat history trigger (drawer)
- New chat button
- Menu options

### 7. Profile
- Profile avatar with initials
- User information display
- Change password
- Privacy settings
- Notifications preferences
- Logout

---

## Reusable Components

All components use the Nexora design system consistently:

### Buttons
- `NexoraButton`: Primary filled button
- `NexoraOutlineButton`: Secondary outline button
- `NexoraTextButton`: Text-only button

### Inputs
- `NexoraTextField`: Customizable text input with validation

### Layout & Display
- `NexoraAppBar`: Consistent app bar
- `NexoraCard`: Reusable card container
- `NexoraAvatar`: User avatar with initials
- `NexoraLoadingIndicator`: Loading spinner
- `NexoraErrorView`: Error state display
- `NexoraEmptyState`: Empty state display

---

## Setup & Installation

### Prerequisites
- Flutter 3.0+
- Dart 3.0+
- Android Studio / Xcode
- Git

### Installation Steps

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd nexora
   ```

2. **Get dependencies**
   ```bash
   flutter pub get
   ```

3. **Generate code (Riverpod, Hive)**
   ```bash
   dart run build_runner build
   ```

4. **Configure Firebase** (Phase 3)
   - Update `android/app/google-services.json`
   - Update `ios/Runner/GoogleService-Info.plist`
   - See Firebase setup instructions below

5. **Run the app**
   ```bash
   flutter run
   ```

---

## Firebase Setup

### Android Configuration
1. Update `android/app/google-services.json` with your Firebase project credentials
2. Ensure `android/build.gradle` has Google services plugin:
   ```gradle
   classpath 'com.google.gms:google-services:4.3.15'
   ```

### iOS Configuration
1. Update `ios/Runner/GoogleService-Info.plist` with your Firebase project credentials
2. Run `cd ios && pod install && cd ..`

### Firebase Console
1. Create a project: https://console.firebase.google.com
2. Enable authentication methods:
   - Email/Password
   - Google Sign-In
3. Create Firestore database in test mode initially
4. Add Android and iOS apps to the project

---

## Code Quality & Testing

### Code Analysis
```bash
flutter analyze
```

### Run Tests
```bash
flutter test
```

### Code Formatting
```bash
dart format lib/
```

### Linting
```bash
dart fix --apply
```

---

## Important Notes

### Phase 1 Implementation Status
- ✅ Project structure created
- ✅ Design system implemented
- ✅ All screens UI created (using mock data)
- ✅ Navigation setup with go_router
- ✅ Reusable components library
- ⏳ Firebase integration (Phase 3)
- ⏳ API integration (Phase 5)

### TODO for Next Phases

#### Phase 2 - State Management
- [ ] Create Riverpod providers for authentication state
- [ ] Implement onboarding state
- [ ] Implement chat state
- [ ] Implement profile state
- [ ] Add navigation guards based on authentication

#### Phase 3 - Firebase Authentication
- [ ] Initialize Firebase
- [ ] Implement email/password auth
- [ ] Implement Google Sign-In
- [ ] Add Apple Sign-In for iOS
- [ ] Add authentication error handling
- [ ] Add session management

#### Phase 4 - Firestore Database
- [ ] Design Firestore schema
- [ ] Implement user profiles
- [ ] Implement chat history storage
- [ ] Add Firestore security rules
- [ ] Implement pagination

#### Phase 5 - Cloudflare Backend
- [ ] Set up Cloudflare Worker
- [ ] Implement health endpoint
- [ ] Create API client
- [ ] Add request/response handling
- [ ] Implement error handling

#### Phase 6 - AI Integration
- [ ] Select AI provider
- [ ] Create AI service abstraction
- [ ] Implement message sending
- [ ] Add loading states
- [ ] Implement response handling

---

## Security Considerations

### Current Implementation
- Design system and UI only
- No sensitive data handling yet

### Future Implementation
- ✅ Never hardcode API keys or secrets
- ✅ Use Firebase security rules for authorization
- ✅ Implement secure authentication flow
- ✅ Use environment variables for configuration
- ✅ Validate all user inputs
- ✅ Implement rate limiting server-side
- ✅ Use HTTPS for all API calls
- ✅ Store sensitive data securely

---

## Troubleshooting

### Build Issues
- Run `flutter clean` and `flutter pub get`
- Delete `build/` directories
- For iOS: Delete `Pods/`, `Podfile.lock`, and run `pod install` again

### Hot Reload Issues
- Stop and restart `flutter run`
- Use `-d` to specify device if multiple are connected

### Firebase Issues
- Ensure correct `google-services.json` and `GoogleService-Info.plist`
- Check Firebase project ID matches configuration

---

## Contributing Guidelines

1. Work within the assigned phase
2. Follow Dart/Flutter best practices
3. Use the design system constants (colors, spacing, typography)
4. Create reusable components when appropriate
5. Write clear commit messages
6. Run `flutter analyze` before committing
7. Update README when adding new features

---

## Figma Design Reference

**Design Link**: [Nexora AI Mobile UI](https://www.figma.com/design/ghDQZUjw4RTnoN3SnUWdVD/Nexora-%E2%80%94-Mobile-UI)

The Figma design is the source of truth for:
- Visual hierarchy
- Typography
- Colors and contrast
- Spacing and alignment
- Button sizes and states
- Component interactions
- Animation/transition behavior

---

## Resources

- [Flutter Documentation](https://flutter.dev)
- [Dart Documentation](https://dart.dev)
- [Riverpod Documentation](https://riverpod.dev)
- [go_router Documentation](https://pub.dev/packages/go_router)
- [Firebase Flutter Documentation](https://firebase.flutter.dev)
- [Material Design 3](https://m3.material.io)

---

## Contact & Support

- **College Email**: bvccollageai@gmail.com
- **Project Manager**: [TBD]
- **Lead Developer**: [TBD]

---

**Last Updated**: 2026-08-13
**Current Phase**: Phase 1 - UI Implementation (Complete)
**Next Phase**: Phase 2 - Navigation & Local State Management
