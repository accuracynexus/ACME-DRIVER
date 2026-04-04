import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand - Custom Palette
  static const Color primary = Color(0xFF4d148c);      // Deep Purple
  static const Color primaryLight = Color(0xFF7c3bb3);
  static const Color primaryDark = Color(0xFF2a0a52);
  static const Color accent = Color(0xFFff6200);       // Vibrant Orange

  // Background
  static const Color background = Color(0xFFF5F7FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEEF2F7);

  // Status colors
  static const Color statusAvailable = Color(0xFF2E7D32);
  static const Color statusBusy = Color(0xFFE65100);
  static const Color statusOffline = Color(0xFF757575);

  // Order status colors
  static const Color orderAssigned = Color(0xFF1565C0);
  static const Color orderAccepted = Color(0xFF0288D1);
  static const Color orderPickedUp = Color(0xFF6A1B9A);
  static const Color orderOnTheWay = Color(0xFFF57F17);
  static const Color orderDelivered = Color(0xFF2E7D32);
  static const Color orderCancelled = Color(0xFFC62828);

  // Text
  static const Color textPrimary = Color(0xFF1A1D23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders / dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Feedback
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFF57F17);
  static const Color error = Color(0xFFC62828);
  static const Color info = Color(0xFF0288D1);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D47A1), Color(0xFF1565C0)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF5F7FA)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
