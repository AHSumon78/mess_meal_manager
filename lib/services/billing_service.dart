import '../models/app_settings.dart';
import '../models/calculation_mode.dart';
import '../models/expense.dart';
import '../models/meal_record.dart';

class BillingService {
  static int mealCount(Iterable<MealRecord> meals) {
    return meals.fold(0, (sum, meal) => sum + meal.totalMeals);
  }

  static double weightedMealCount(AppSettings settings, MealRecord meal) {
    return (meal.breakfastCount * settings.breakfastWeight) +
        (meal.lunchCount * settings.lunchWeight) +
        (meal.dinnerCount * settings.dinnerWeight);
  }

  static double totalWeightedMealCount(
    AppSettings settings,
    Iterable<MealRecord> meals,
  ) {
    return meals.fold(
      0.0,
      (sum, meal) => sum + weightedMealCount(settings, meal),
    );
  }

  static double expenseTotal(Iterable<Expense> expenses) {
    return expenses.fold(0.0, (sum, expense) => sum + expense.amount);
  }

  static double calculateExpenseBasedCostByDate(
    AppSettings settings,
    Iterable<MealRecord> targetMeals,
    Iterable<MealRecord> allMealsInPeriod,
    Iterable<Expense> expensesInPeriod,
  ) {
    final totalMealsByDate = <String, double>{};
    for (final meal in allMealsInPeriod) {
      final dateKey = _dateKey(meal.date);
      totalMealsByDate[dateKey] =
          (totalMealsByDate[dateKey] ?? 0) + weightedMealCount(settings, meal);
    }

    final expensesByDate = <String, double>{};
    for (final expense in expensesInPeriod) {
      final dateKey = _dateKey(expense.date);
      expensesByDate[dateKey] = (expensesByDate[dateKey] ?? 0) + expense.amount;
    }

    double totalCost = 0;
    for (final meal in targetMeals) {
      final dateKey = _dateKey(meal.date);
      final dailyWeightedMeals = totalMealsByDate[dateKey] ?? 0;
      if (dailyWeightedMeals <= 0) continue;

      final dailyRate = (expensesByDate[dateKey] ?? 0) / dailyWeightedMeals;
      totalCost += weightedMealCount(settings, meal) * dailyRate;
    }
    return totalCost;
  }

  static double calculateMealCost(
    AppSettings settings,
    Iterable<MealRecord> meals, {
    double expensePool = 0,
    double totalMealsInPool = 0,
  }) {
    if (settings.mode == CalculationMode.expenseBased) {
      if (totalMealsInPool <= 0) return 0;
      final perMealRate = expensePool / totalMealsInPool;
      return totalWeightedMealCount(settings, meals) * perMealRate;
    }

    return meals.fold(0.0, (sum, meal) {
      return sum +
          (meal.breakfastCount * settings.breakfastRate) +
          (meal.lunchCount * settings.lunchRate) +
          (meal.dinnerCount * settings.dinnerRate);
    });
  }

  static String _dateKey(DateTime date) {
    return date.toIso8601String().substring(0, 10);
  }
}
