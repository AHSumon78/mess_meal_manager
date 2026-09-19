// lib/models/app_settings.dart

import 'calculation_mode.dart';

/// Holds all the global settings for the app.
class AppSettings {
  final CalculationMode mode;
  final double breakfastRate;
  final double lunchRate;
  final double dinnerRate;
  final double breakfastWeight;
  final double lunchWeight;
  final double dinnerWeight;

  AppSettings({
    // By default, the app will start in Fixed Rate mode.
    this.mode = CalculationMode.fixedRate,
    this.breakfastRate = 10.0,
    this.lunchRate = 40.0,
    this.dinnerRate = 40.0,
    this.breakfastWeight = 0.5,
    this.lunchWeight = 1.0,
    this.dinnerWeight = 1.0,
  });
}
