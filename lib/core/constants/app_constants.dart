class AppConstants {
  // App info
  static const String appName = 'HisabKitab';
  static const String appVersion = '1.0.0';
  static const String appSlogan = 'Split expenses, not friendships';

  // Firebase collections
  static const String usersCollection = 'users';
  static const String groupsCollection = 'groups';
  static const String expensesCollection = 'expenses';
  static const String settlementsCollection = 'settlements';

  // Shared preferences keys
  static const String darkModeKey = 'dark_mode';
  static const String userIdKey = 'user_id';
  static const String userLoggedInKey = 'user_logged_in';
  static const String currencyKey = 'currency';
  static const String languageKey = 'language';

  // Currency symbols
  static const Map<String, String> currencySymbols = {
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'INR': '₹',
    'CAD': 'C\$',
    'AUD': 'A\$',
    'CNY': '¥',
    'RUB': '₽',
  };

  // Default expense categories with emojis
  static const Map<String, String> expenseCategories = {
    'Food': '🍕',
    'Transportation': '🚗',
    'Accommodation': '🏠',
    'Entertainment': '🎬',
    'Shopping': '🛍️',
    'Utilities': '💡',
    'Health': '⚕️',
    'Education': '📚',
    'Travel': '✈️',
    'Gifts': '🎁',
    'Other': '📝',
  };

  // Route names
  static const String splashRoute = '/splash';
  static const String onboardingRoute = '/onboarding';
  static const String loginRoute = '/login';
  static const String signupRoute = '/signup';
  static const String forgotPasswordRoute = '/forgot-password';
  static const String homeRoute = '/home';
  static const String groupsRoute = '/groups';
  static const String groupDetailRoute = '/group-detail';
  static const String createGroupRoute = '/create-group';
  static const String addExpenseRoute = '/add-expense';
  static const String expenseDetailRoute = '/expense-detail';
  static const String settlementsRoute = '/settlements';
  static const String settleUpRoute = '/settle-up';
  static const String profileRoute = '/profile';
  static const String settingsRoute = '/settings';
  static const String analyticsRoute = '/analytics';

  // Animation durations
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 350);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // API endpoints (for currency conversion)
  static const String currencyApiBaseUrl =
      'https://api.exchangerate-api.com/v4/latest/';

  // Validation regex patterns
  static const String emailRegex = r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$';
  static const String passwordRegex = r'^.{6,}$'; // At least 6 characters
  static const String phoneRegex = r'^\+?[0-9]{8,15}$';

  // App Store and Play Store links
  static const String appStoreLink =
      'https://apps.apple.com/app/hisabkitab/id123456789';
  static const String playStoreLink =
      'https://play.google.com/store/apps/details?id=com.example.hisabkitab';
}
