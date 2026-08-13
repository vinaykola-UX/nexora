# Nexora AI - First Test Run Checklist

## Pre-Test Setup

### Prerequisites
- [ ] Flutter SDK installed (3.0+)
- [ ] Dart SDK installed (3.0+)
- [ ] Android Studio or Xcode installed
- [ ] Emulator or physical device connected
- [ ] 2GB+ disk space available

### Verify Installation
```bash
flutter --version
dart --version
flutter doctor
```

---

## Initial Setup (5 minutes)

### Step 1: Navigate to Project
```bash
cd c:\Users\Admin\nexora
```

### Step 2: Get Dependencies
```bash
flutter pub get
```
⏱️ Expected time: 2-3 minutes  
✅ Success: "Got dependencies"

### Step 3: Generate Code
```bash
dart run build_runner build
```
⏱️ Expected time: 1-2 minutes  
✅ Success: "Build complete"

### Step 4: Check Analysis
```bash
flutter analyze
```
✅ Expected: No errors or "N issues found" with 0 errors

---

## First Run (Android)

### Option A: Android Emulator
```bash
flutter emulators
# Look for android emulator
flutter emulators --launch <emulator_name>
# Wait for emulator to start
flutter run
```

### Option B: Physical Android Device
1. Connect via USB
2. Enable USB debugging
3. Run: `flutter devices` (verify device shows)
4. Run: `flutter run`

### Expected Output
✅ Splash screen appears
✅ App loads successfully
✅ Can navigate through all screens
✅ No console errors

---

## First Run (iOS)

### Prerequisites
- [ ] Mac with Xcode
- [ ] iOS 12.0+
- [ ] Pods installed

### Setup
```bash
cd ios
pod install
cd ..
```

### Run on Simulator
```bash
flutter run -d 'iPhone 15'
```

### Run on Device
```bash
flutter run
# Select device when prompted
```

### Expected Output
✅ Splash screen appears
✅ App loads successfully
✅ Can navigate through all screens
✅ No console errors

---

## Functionality Testing

### Splash Screen
- [ ] Logo (N) displays
- [ ] App name "Nexora AI" displays
- [ ] Tagline displays
- [ ] Transitions to onboarding after delay

### Onboarding
- [ ] Slide 1 displays
- [ ] Page indicators show (dots)
- [ ] "Continue" button works
- [ ] "Skip" button works
- [ ] Navigates through all 3 slides
- [ ] Final slide shows "Get Started"

### Login Screen
- [ ] Email input accepts text
- [ ] Password input obscures text
- [ ] "Show password" toggle works
- [ ] "Forgot password" link tappable
- [ ] "Login" button works
- [ ] "Login with Google" button tappable
- [ ] Sign up link tappable

### Terms Screen
- [ ] Terms text displays
- [ ] Privacy text displays
- [ ] Agree to Terms checkbox works
- [ ] Agree to Privacy checkbox works
- [ ] Continue button disabled when unchecked
- [ ] Continue button enabled when both checked

### Start Chat Screen
- [ ] 4 topic cards display
- [ ] Each card is tappable
- [ ] "Start from scratch" button works

### Chat Screen
- [ ] Message list displays
- [ ] Mock AI message shows
- [ ] Text input accepts text
- [ ] Send button works
- [ ] New message appears in list
- [ ] Auto-response appears
- [ ] History drawer icon works
- [ ] Menu icon works
- [ ] New chat button works

### Profile Screen
- [ ] Avatar displays with initials
- [ ] User name displays
- [ ] Role displays
- [ ] Settings buttons are tappable
- [ ] Logout button visible
- [ ] Logout confirmation dialog works

---

## Visual Quality Check

### Colors
- [ ] Primary orange is vibrant (#FFA500)
- [ ] Background is warm light (#FAF8F3)
- [ ] Text is dark and readable (#2D2D2D)
- [ ] Buttons stand out
- [ ] Proper contrast on all text

### Typography
- [ ] Headings are bold and prominent
- [ ] Body text is readable
- [ ] Font sizes are appropriate
- [ ] Text is not clipped

### Spacing
- [ ] No overlapping elements
- [ ] Consistent padding/margins
- [ ] Good use of white space
- [ ] Content fits screen

### Layout
- [ ] Nothing extends beyond edges
- [ ] Landscape mode works (if tested)
- [ ] All screens fit without scrolling (except where expected)
- [ ] Buttons are easily tappable

---

## Performance Check

### Startup Time
- [ ] App starts in < 3 seconds
- [ ] No visible lag
- [ ] Smooth animations (if any)

### Navigation
- [ ] Screen transitions are smooth
- [ ] No lag when tapping buttons
- [ ] No frame drops

### Console Output
- [ ] No errors in console
- [ ] No warnings (or only expected warnings)
- [ ] App doesn't crash

---

## Device-Specific Testing

### Android
- [ ] Correct Material Design look
- [ ] System back button works
- [ ] Safe area respected (notch if present)
- [ ] Software keyboard works

### iOS
- [ ] Correct iOS look
- [ ] Swipe back gesture works
- [ ] Safe area respected (notch if present)
- [ ] iOS keyboard works

---

## Common Issues & Solutions

### "Error: Build failed"
✅ Solution:
```bash
flutter clean
flutter pub get
dart run build_runner build
flutter run
```

### "Error: No connected devices"
✅ Solution:
1. Run `flutter devices` to verify
2. Start emulator first
3. Or connect physical device via USB

### "Gradle build failed"
✅ Solution (Android):
```bash
cd android
./gradlew clean
cd ..
flutter run
```

### "Pod install failed"
✅ Solution (iOS):
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
flutter run
```

### "Yellow warnings on screen"
✅ This is normal for debug builds - won't appear in release

### App crashes immediately
✅ Solution:
1. Check console for error messages
2. Run with verbose: `flutter run -v`
3. Check that all files exist

---

## Testing Report Template

```
╔═══════════════════════════════════════════════════════╗
║        NEXORA AI - FIRST TEST RUN REPORT              ║
╚═══════════════════════════════════════════════════════╝

Date: ________________
Device: ________________
Platform: [ ] Android  [ ] iOS
Test Duration: ________________

OVERALL RESULT: [ ] PASS  [ ] FAIL

SCREENS TESTED:
✅ Splash        [ ] Working  [ ] Issues: ________
✅ Onboarding    [ ] Working  [ ] Issues: ________
✅ Login         [ ] Working  [ ] Issues: ________
✅ Terms         [ ] Working  [ ] Issues: ________
✅ Start Chat    [ ] Working  [ ] Issues: ________
✅ Chat          [ ] Working  [ ] Issues: ________
✅ Profile       [ ] Working  [ ] Issues: ________

VISUAL QUALITY:
Colors: [ ] Perfect  [ ] Good  [ ] Needs Work
Typography: [ ] Perfect  [ ] Good  [ ] Needs Work
Spacing: [ ] Perfect  [ ] Good  [ ] Needs Work
Layout: [ ] Perfect  [ ] Good  [ ] Needs Work

PERFORMANCE:
Startup Time: ________ seconds
Navigation Speed: [ ] Smooth  [ ] Acceptable  [ ] Slow
No Crashes: [ ] Yes  [ ] No

ISSUES FOUND:
1. ________________________________
2. ________________________________
3. ________________________________

NOTES:
_______________________________________
_______________________________________
_______________________________________

Tester Name: ________________________
Signature: ________________________
```

---

## After First Successful Run

### Next Steps
1. ✅ Celebrate successful initial test!
2. [ ] Commit to git: `git add . && git commit -m "Initial Flutter project setup - Phase 0 complete"`
3. [ ] Document any issues found
4. [ ] Fix any bugs discovered
5. [ ] Proceed to Phase 2 - State Management

### Share Results
- [ ] Send report to team
- [ ] Update project status
- [ ] Schedule Phase 2 kickoff

---

## Contact for Issues

If you encounter any issues:
1. Check DEVELOPMENT.md for troubleshooting
2. Review PROJECT_STRUCTURE.md for architecture questions
3. Contact: bvccollageai@gmail.com

---

## Success Criteria

✅ App launches without crashes  
✅ All 7 screens display correctly  
✅ Navigation works between screens  
✅ Input fields accept text  
✅ Buttons respond to taps  
✅ No console errors (warnings OK)  
✅ Visual design looks professional  
✅ No performance issues  

---

**Start Testing**: Ready! 🚀

**Estimated Time**: 30-45 minutes  
**Difficulty**: Easy  
**No previous testing experience required**

Good luck! 🎉
