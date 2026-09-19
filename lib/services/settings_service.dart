// lib/services/settings_service.dart
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../models/calculation_mode.dart';

class SettingsService {
  static const _modeKey = 'app_calculation_mode';
  static const _breakfastRateKey = 'app_breakfast_rate';
  static const _lunchRateKey = 'app_lunch_rate';
  static const _dinnerRateKey = 'app_dinner_rate';
  static const _breakfastWeightKey = 'app_breakfast_weight';
  static const _lunchWeightKey = 'app_lunch_weight';
  static const _dinnerWeightKey = 'app_dinner_weight';

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modeKey, settings.mode.index);
    await prefs.setDouble(_breakfastRateKey, settings.breakfastRate);
    await prefs.setDouble(_lunchRateKey, settings.lunchRate);
    await prefs.setDouble(_dinnerRateKey, settings.dinnerRate);
    await prefs.setDouble(_breakfastWeightKey, settings.breakfastWeight);
    await prefs.setDouble(_lunchWeightKey, settings.lunchWeight);
    await prefs.setDouble(_dinnerWeightKey, settings.dinnerWeight);
  }

  Future<AppSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_modeKey) ?? 0;
    final mode = CalculationMode.values[modeIndex];
    final breakfastRate = prefs.getDouble(_breakfastRateKey) ?? 10.0;
    final lunchRate = prefs.getDouble(_lunchRateKey) ?? 40.0;
    final dinnerRate = prefs.getDouble(_dinnerRateKey) ?? 40.0;
    final breakfastWeight = prefs.getDouble(_breakfastWeightKey) ?? 0.5;
    final lunchWeight = prefs.getDouble(_lunchWeightKey) ?? 1.0;
    final dinnerWeight = prefs.getDouble(_dinnerWeightKey) ?? 1.0;
    return AppSettings(
      mode: mode,
      breakfastRate: breakfastRate,
      lunchRate: lunchRate,
      dinnerRate: dinnerRate,
      breakfastWeight: breakfastWeight,
      lunchWeight: lunchWeight,
      dinnerWeight: dinnerWeight,
    );
  }
}
