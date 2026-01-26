import 'package:flutter/material.dart';

/// Centralized validation utilities for the app
class Validators {
  /// Validate email format
  static String? email(String? value) {
    if (value == null || value.isEmpty) {
      return 'Email is required';
    }

    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  /// Validate password strength
  /// Returns null if valid, error message if invalid
  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }

    if (value.length < 8) {
      return 'Password must be at least 8 characters';
    }

    // Check for at least one uppercase letter
    if (!value.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    // Check for at least one lowercase letter
    if (!value.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    // Check for at least one number
    if (!value.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null;
  }

  /// Get password strength (0-4)
  /// 0 = very weak, 1 = weak, 2 = fair, 3 = good, 4 = strong
  static int getPasswordStrength(String password) {
    if (password.isEmpty) return 0;

    int strength = 0;

    // Length check
    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;

    // Character variety checks
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;

    // Cap at 4
    return strength > 4 ? 4 : strength;
  }

  /// Get password strength label
  static String getPasswordStrengthLabel(int strength) {
    switch (strength) {
      case 0:
        return 'Very Weak';
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Strong';
      default:
        return 'Unknown';
    }
  }

  /// Get password strength color
  static Color getPasswordStrengthColor(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return Colors.red;
      case 2:
        return Colors.orange;
      case 3:
        return Colors.yellow;
      case 4:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  /// Validate username
  /// Username must be 3-20 characters, alphanumeric with underscores and dots
  /// Cannot start or end with dot or underscore
  /// Cannot have consecutive dots or underscores
  static String? username(String? value) {
    if (value == null || value.isEmpty) {
      return 'Username is required';
    }

    if (value.length < 3) {
      return 'Username must be at least 3 characters';
    }

    if (value.length > 20) {
      return 'Username cannot exceed 20 characters';
    }

    // Check for valid characters (alphanumeric, underscore, dot)
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(value)) {
      return 'Username can only contain letters, numbers, dots, and underscores';
    }

    // Cannot start or end with dot or underscore
    if (value.startsWith('.') ||
        value.startsWith('_') ||
        value.endsWith('.') ||
        value.endsWith('_')) {
      return 'Username cannot start or end with dot or underscore';
    }

    // Cannot have consecutive dots or underscores
    if (value.contains('..') ||
        value.contains('__') ||
        value.contains('._') ||
        value.contains('_.')) {
      return 'Username cannot have consecutive special characters';
    }

    return null;
  }

  /// Validate display name
  static String? displayName(String? value) {
    if (value == null || value.isEmpty) {
      return 'Display name is required';
    }

    if (value.length < 2) {
      return 'Display name must be at least 2 characters';
    }

    if (value.length > 50) {
      return 'Display name cannot exceed 50 characters';
    }

    return null;
  }

  /// Validate phone number
  static String? phoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Phone number is required';
    }

    // Remove any non-digit characters for validation
    final digitsOnly = value.replaceAll(RegExp(r'[^\d]'), '');

    if (digitsOnly.length < 9) {
      return 'Phone number must be at least 9 digits';
    }

    if (digitsOnly.length > 15) {
      return 'Phone number cannot exceed 15 digits';
    }

    return null;
  }

  /// Validate URL
  static String? url(String? value) {
    if (value == null || value.isEmpty) {
      return null; // URL is optional
    }

    final urlRegex = RegExp(
      r'^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&//=]*)$',
    );

    if (!urlRegex.hasMatch(value)) {
      return 'Please enter a valid URL';
    }

    return null;
  }

  /// Validate bio/about text
  static String? bio(String? value, {int maxLength = 150}) {
    if (value == null || value.isEmpty) {
      return null; // Bio is optional
    }

    if (value.length > maxLength) {
      return 'Bio cannot exceed $maxLength characters';
    }

    return null;
  }

  /// Validate required field
  static String? required(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  /// Validate minimum length
  static String? minLength(String? value, int min, String fieldName) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.length < min) {
      return '$fieldName must be at least $min characters';
    }

    return null;
  }

  /// Validate maximum length
  static String? maxLength(String? value, int max, String fieldName) {
    if (value == null || value.isEmpty) {
      return null;
    }

    if (value.length > max) {
      return '$fieldName cannot exceed $max characters';
    }

    return null;
  }
}
