// lib/models/calculation_mode.dart

/// Defines the two different methods for calculating meal costs.
enum CalculationMode {
  /// Bill is calculated based on fixed rates per meal.
  fixedRate,

  /// Bill is calculated based on total expenses and total meals.
  expenseBased,
}
