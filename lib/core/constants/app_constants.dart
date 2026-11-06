/// Application constants
class AppConstants {
  AppConstants._();

  // API Configuration
  static const String cloudflareApiBaseUrl = 'https://nexora-bvc-api-2026.vkola306.workers.dev';
  static const String workerBaseUrl = 'https://nexora-bvc-api-2026.vkola306.workers.dev';
  static const String healthEndpoint = '/health';
  static const Duration apiTimeout = Duration(seconds: 30);

  // Firebase Configuration
  static const String firebaseProjectId = 'nexorabvcai';
  static const String firebaseWebApiKey = 'AIzaSyDMI7UxOrVxb9E8GBavhNA60-DA5_54Tcw';
  static const String firebaseAppId = '1:1056749020398:web:ab4abc8a5f6397120f3fff';

  // College Information
  static const String collegeName = 'BVC Engineering College';
  static const String collegeEmail = 'bvccollageai@gmail.com';

  // Application Info
  static const String appName = 'Nexora AI';
  static const String appVersion = '1.0.0';

  // Pagination
  static const int paginationPageSize = 20;
  static const int defaultChatHistoryLimit = 50;

  // Chat Configuration
  static const int maxMessageLength = 4000;
  static const Duration chatLoadingTimeout = Duration(seconds: 45);

  // File Upload
  static const int maxFileSize = 10 * 1024 * 1024; // 10 MB
  static const List<String> allowedImageMimeTypes = [
    'image/jpeg',
    'image/png',
    'image/webp',
  ];

  static const List<String> allowedDocumentMimeTypes = [
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'text/plain',
  ];

  // Session Duration
  static const Duration sessionTimeout = Duration(minutes: 30);

  // Shared Preferences Keys
  static const String prefKeyAuthToken = 'auth_token';
  static const String prefKeyRefreshToken = 'refresh_token';
  static const String prefKeyUserId = 'user_id';
  static const String prefKeyUserRole = 'user_role';
  static const String prefKeyOnboardingComplete = 'onboarding_complete';
  static const String prefKeyTermsAccepted = 'terms_accepted';
  static const String prefKeyThemeMode = 'theme_mode';
  static const String prefKeyLanguage = 'language';
}

/// Error messages
class ErrorMessages {
  ErrorMessages._();

  static const String networkError =
      'Unable to connect. Please check your internet connection.';
  static const String serverError = 'Server error. Please try again later.';
  static const String authenticationError = 'Authentication failed. Please log in again.';
  static const String authorizationError = 'You do not have permission to access this.';
  static const String notFoundError = 'Resource not found.';
  static const String validationError = 'Invalid input. Please check and try again.';
  static const String timeoutError = 'Request timed out. Please try again.';
  static const String cacheError = 'Failed to load cached data.';
  static const String fileError = 'File operation failed.';
  static const String fileTooLargeError = 'File size exceeds the maximum limit.';
  static const String invalidFileType = 'This file type is not allowed.';
  static const String uploadError = 'File upload failed. Please try again.';
  static const String unknownError = 'An unexpected error occurred.';
  static const String emptyFieldError = 'This field cannot be empty.';
  static const String invalidEmailError = 'Please enter a valid email address.';
  static const String weakPasswordError =
      'Password must be at least 8 characters with uppercase, lowercase, and numbers.';
  static const String passwordMismatchError = 'Passwords do not match.';
  static const String accountLockedError =
      'Your account has been locked. Please contact support.';
  static const String userNotFoundError = 'User account not found.';
  static const String invalidCredentialsError = 'Invalid email or password.';
}

/// Success messages
class SuccessMessages {
  SuccessMessages._();

  static const String loginSuccess = 'Logged in successfully!';
  static const String logoutSuccess = 'Logged out successfully.';
  static const String registrationSuccess = 'Account created successfully!';
  static const String profileUpdateSuccess = 'Profile updated successfully!';
  static const String profileImageUpdateSuccess = 'Profile image updated!';
  static const String passwordChangeSuccess = 'Password changed successfully!';
  static const String passwordResetSent = 'Password reset link sent to your email.';
  static const String fileUploadSuccess = 'File uploaded successfully!';
  static const String chatDeleteSuccess = 'Chat deleted successfully.';
  static const String chatPinSuccess = 'Chat pinned successfully.';
  static const String chatUnpinSuccess = 'Chat unpinned successfully.';
  static const String chatRenameSuccess = 'Chat renamed successfully.';
  static const String copiedToClipboard = 'Copied to clipboard!';
}
