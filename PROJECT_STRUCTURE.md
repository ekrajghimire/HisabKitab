# HisabKitab Project Structure

This document provides an overview of the HisabKitab project structure, explaining the organization of directories and files.

## Directory Structure

```
lib/
├── core/                      # Core functionality used across the app
│   ├── constants/             # App-wide constants
│   │   └── app_constants.dart # Constants for the app (strings, routes, etc.)
│   ├── services/              # Services for external APIs and functionality
│   │   └── firebase_service.dart # Firebase initialization and services
│   ├── theme/                 # App theming
│   │   └── app_theme.dart     # Theme configuration (colors, styles, etc.)
│   ├── utils/                 # Utility functions
│   │   └── app_utils.dart     # Common utility functions
│   └── widgets/               # Shared widgets used across the app
│       └── ...
│
├── features/                  # App features organized by domain
│   ├── analytics/             # Analytics feature
│   │   ├── providers/         # State management for analytics
│   │   ├── screens/           # UI screens for analytics
│   │   │   └── analytics_screen.dart
│   │   └── widgets/           # Widgets specific to analytics
│   │
│   ├── auth/                  # Authentication feature
│   │   ├── providers/         # State management for auth
│   │   │   └── auth_provider.dart
│   │   ├── screens/           # UI screens for auth
│   │   │   ├── forgot_password_screen.dart
│   │   │   ├── login_screen.dart
│   │   │   ├── signup_screen.dart
│   │   │   └── splash_screen.dart
│   │   └── widgets/           # Widgets specific to auth
│   │
│   ├── dashboard/             # Dashboard feature (main app screen)
│   │   ├── providers/         # State management for dashboard
│   │   ├── screens/           # UI screens for dashboard
│   │   │   └── home_screen.dart
│   │   └── widgets/           # Widgets specific to dashboard
│   │
│   ├── expenses/              # Expenses feature
│   │   ├── providers/         # State management for expenses
│   │   │   └── expenses_provider.dart
│   │   ├── screens/           # UI screens for expenses
│   │   │   └── recent_expenses_screen.dart
│   │   └── widgets/           # Widgets specific to expenses
│   │
│   ├── groups/                # Groups feature
│   │   ├── providers/         # State management for groups
│   │   │   └── groups_provider.dart
│   │   ├── screens/           # UI screens for groups
│   │   │   └── groups_screen.dart
│   │   └── widgets/           # Widgets specific to groups
│   │
│   ├── profile/               # User profile feature
│   │   ├── providers/         # State management for profile
│   │   ├── screens/           # UI screens for profile
│   │   │   └── profile_screen.dart
│   │   └── widgets/           # Widgets specific to profile
│   │
│   └── settings/              # App settings feature
│       ├── providers/         # State management for settings
│       │   └── theme_provider.dart
│       ├── screens/           # UI screens for settings
│       └── widgets/           # Widgets specific to settings
│
├── models/                    # Data models
│   ├── expense_model.dart     # Expense data model
│   ├── group_model.dart       # Group data model
│   ├── settlement_model.dart  # Settlement data model
│   └── user_model.dart        # User data model
│
└── main.dart                  # App entry point
```

## Key Components

### Core

The `core` directory contains functionality that is used across the entire app:

- **constants**: App-wide constants like strings, routes, and configuration values
- **services**: Services for external APIs and functionality like Firebase
- **theme**: App theming including colors, text styles, and other visual elements
- **utils**: Utility functions for common tasks
- **widgets**: Reusable widgets used across multiple features

### Features

The `features` directory organizes code by domain, following a feature-first architecture:

- **analytics**: Expense analytics and insights
- **auth**: User authentication (login, signup, password reset)
- **dashboard**: Main app dashboard and navigation
- **expenses**: Expense management
- **groups**: Group management
- **profile**: User profile management
- **settings**: App settings

Each feature contains:
- **providers**: State management using Provider pattern
- **screens**: UI screens for the feature
- **widgets**: UI components specific to the feature

### Models

The `models` directory contains data models that represent the core entities in the app:

- **expense_model.dart**: Represents an expense with details like amount, description, etc.
- **group_model.dart**: Represents a group of users who share expenses
- **settlement_model.dart**: Represents a payment between users to settle debts
- **user_model.dart**: Represents a user of the app

### Main

The `main.dart` file is the entry point of the app, setting up providers, themes, and navigation.

## Architecture

HisabKitab follows a clean architecture approach with:

1. **Presentation Layer**: UI components (screens and widgets)
2. **Business Logic Layer**: State management with Provider
3. **Data Layer**: Models and services for data access

The app uses:
- **Provider** for state management
- **Firebase** for backend services (Authentication, Firestore, Storage)
- **Material Design** for UI components

## Development Guidelines

1. **Feature-First Organization**: Add new functionality within the appropriate feature directory
2. **Separation of Concerns**: Keep UI, business logic, and data access separate
3. **Reusable Components**: Extract common UI elements into the core/widgets directory
4. **Consistent Naming**: Follow consistent naming conventions for files and classes
5. **Documentation**: Document complex logic and public APIs 