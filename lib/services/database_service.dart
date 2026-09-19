// lib/services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/a.dart';
import '../models/calculation_mode.dart';
import '../models/member.dart';
import '../models/meal_record.dart';
import '../models/payment.dart';
import '../models/expense.dart';
import 'billing_service.dart';
import 'settings_service.dart';
import 'dart:io';

class DatabaseService {
  // --- Singleton pattern setup ---
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  // Add these two new functions inside your DatabaseService class

  Future<String> getDatabasePath() async {
    final path = await getDatabasesPath();
    return join(path, 'mess_meal.db');
  }

  Future<File> getDatabaseFile() async {
    final path = await getDatabasePath();
    return File(path);
  }

  // --- Initialize database and create tables ---
  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'mess_meal.db');
    return await openDatabase(path, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(
      'CREATE TABLE members(id TEXT PRIMARY KEY, name TEXT NOT NULL, joiningDate TEXT NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE meal_records(id TEXT PRIMARY KEY, memberId TEXT NOT NULL, date TEXT NOT NULL, breakfastCount INTEGER NOT NULL, lunchCount INTEGER NOT NULL, dinnerCount INTEGER NOT NULL)',
    );
    await db.execute(
      'CREATE TABLE expenses(id TEXT PRIMARY KEY, date TEXT NOT NULL, amount REAL NOT NULL, description TEXT)',
    );
    await db.execute(
      'CREATE TABLE payments(id TEXT PRIMARY KEY, memberId TEXT NOT NULL, amount REAL NOT NULL, date TEXT NOT NULL)',
    );
  }

  // --- Member Functions ---
  Future<void> insertMember(Member member) async {
    final db = await database;
    await db.insert(
      'members',
      member.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Member>> getAllMembers() async {
    final db = await database;

    // Get the start and end dates of the current month
    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);
    final lastDayOfMonth = DateTime(now.year, now.month + 1, 0);

    final startDate = firstDayOfMonth.toIso8601String().substring(0, 10);
    final endDate = lastDayOfMonth.toIso8601String().substring(0, 10);

    // This raw SQL query calculates the total meals for each member for the current month and sorts them
    const String query = '''
    SELECT 
      m.id, 
      m.name, 
      m.joiningDate
    FROM 
      members m
    LEFT JOIN (
      SELECT 
        memberId, 
        SUM(breakfastCount + lunchCount + dinnerCount) as totalMeals
      FROM 
        meal_records
      WHERE 
        date >= ? AND date <= ?  -- Filter for the current month
      GROUP BY 
        memberId
    ) as mealCounts ON m.id = mealCounts.memberId
    ORDER BY 
      COALESCE(mealCounts.totalMeals, 0) DESC, m.name ASC
  ''';

    final List<Map<String, dynamic>> maps = await db.rawQuery(query, [
      startDate,
      endDate,
    ]);

    return List.generate(maps.length, (i) => Member.fromMap(maps[i]));
  }

  // --- MealRecord Functions ---
  Future<List<MealRecord>> getMealsForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'meal_records',
      where: 'date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  Future<List<MealRecord>> getAllMeals() async {
    final db = await database;
    final maps = await db.query('meal_records');
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  Future<List<MealRecord>> getMealsForMonth(int year, int month) async {
    final db = await database;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startDate = firstDayOfMonth.toIso8601String().substring(0, 10);
    final endDate = lastDayOfMonth.toIso8601String().substring(0, 10);
    final maps = await db.query(
      'meal_records',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
    );
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  Future<void> upsertMealRecord(MealRecord record) async {
    final db = await database;
    final dateOnly = record.date.toIso8601String().substring(0, 10);

    // existing চেক করার দরকার নেই যদি আইডি ইউনিকভাবে সেট করা থাকে
    // সরাসরি insert with replace ব্যবহার করলে কোড অনেক ফাস্ট হবে
    Map<String, dynamic> data = record.toMap();
    data['date'] = dateOnly; // নিশ্চিত করো শুধু YYYY-MM-DD সেভ হচ্ছে

    await db.insert(
      'meal_records',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
      // এই conflictAlgorithm একাই Add এবং Update (Upsert) এর কাজ করে দেবে
    );
  }

  Future<Map<String, int>> getTodaysMealSummary(String date) async {
    final db = await database;
    final maps = await db.query(
      'meal_records',
      where: 'date = ?',
      whereArgs: [date],
    );
    int totalBreakfast = 0, totalLunch = 0, totalDinner = 0;
    for (var map in maps) {
      totalBreakfast += (map['breakfastCount'] as int);
      totalLunch += (map['lunchCount'] as int);
      totalDinner += (map['dinnerCount'] as int);
    }
    return {
      'breakfast': totalBreakfast,
      'lunch': totalLunch,
      'dinner': totalDinner,
    };
  }

  // --- Payment Functions ---
  Future<void> addPayment(Payment payment) async {
    final db = await database;
    await db.insert(
      'payments',
      payment.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Payment>> getPaymentsForMember(String memberId) async {
    final db = await database;
    final maps = await db.query(
      'payments',
      where: 'memberId = ?',
      whereArgs: [memberId],
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  // --- Expense Functions ---
  Future<void> insertExpense(Expense expense) async {
    final db = await database;
    await db.insert(
      'expenses',
      expense.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Expense>> getAllExpenses() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('expenses');
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  // Add this new function inside your DatabaseService class
  Future<List<MealRecord>> getAllMealsForMember(String memberId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meal_records',
      where: 'memberId = ?',
      whereArgs: [memberId],
    );
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  // Add this new function inside your DatabaseService class
  Future<List<MealRecord>> getMealsForMemberInMonth(
    String memberId,
    int year,
    int month,
  ) async {
    final db = await database;
    // Format the month to be two digits (e.g., 9 becomes '09')
    final monthString = month.toString().padLeft(2, '0');
    final datePattern =
        '$year-$monthString-%'; // Creates a pattern like '2025-09-%'

    final List<Map<String, dynamic>> maps = await db.query(
      'meal_records',
      where: 'memberId = ? AND date LIKE ?',
      whereArgs: [memberId, datePattern],
      orderBy: 'date ASC', // Show oldest date first
    );
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  // Add this new function inside your DatabaseService class
  Future<List<MemberWithBalance>> getAllMembersWithBalance() async {
    // We need SettingsService to get the meal rates
    final settingsService = SettingsService();
    final settings = await settingsService.loadSettings();

    final allMembers = await getAllMembers();
    final allMeals = await getAllMeals();
    final allExpenses = await getAllExpenses();
    final List<MemberWithBalance> membersWithBalance = [];

    // Loop through each member to calculate their balance
    for (var member in allMembers) {
      // Get ALL meals for this member, not just for the month
      final meals = await getMealsForMember(member.id);

      // Get all payments for this member (this part was already correct)
      final payments = await getPaymentsForMember(member.id);

      // --- NEW: Get the last payment date for sorting ---
      final lastPaymentDate = await getLastPaymentDateForMember(member.id);

      final totalCost = settings.mode == CalculationMode.expenseBased
          ? BillingService.calculateExpenseBasedCostByDate(
              settings,
              meals,
              allMeals,
              allExpenses,
            )
          : BillingService.calculateMealCost(settings, meals);

      // Calculate total paid (all time)
      double totalPaid = 0;
      for (var payment in payments) {
        totalPaid += payment.amount;
      }

      // Calculate final balance (all time)
      final balance = totalPaid - totalCost;

      // Add the member with their calculated balance and last payment date to our list
      membersWithBalance.add(
        MemberWithBalance(
          member: member,
          balance: balance,
          totalCost: totalCost,
          lastPaymentDate: lastPaymentDate, // <-- Pass the date
        ),
      );
    }

    // --- NEW: Sort the list based on lastPaymentDate (newest first) ---
    membersWithBalance.sort((a, b) {
      if (a.lastPaymentDate == null && b.lastPaymentDate == null) return 0;
      if (a.lastPaymentDate == null) {
        return 1; // Members with no payments go to the bottom
      }
      if (b.lastPaymentDate == null) {
        return -1; // Members with payments come first
      }
      return b.lastPaymentDate!.compareTo(
        a.lastPaymentDate!,
      ); // Newest date first
    });

    return membersWithBalance;
  }

  // Fetches all meal records for a specific member across all time
  Future<List<MealRecord>> getMealsForMember(String memberId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'meal_records',
      where: 'memberId = ?',
      whereArgs: [memberId],
    );
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  Future<List<MemberWithBalance>> getAllMembersWithBalanceForMonth(
    int year,
    int month,
  ) async {
    final settingsService = SettingsService();
    final settings = await settingsService.loadSettings();
    final allMembers = await getAllMembers();
    final monthlyMeals = await getMealsForMonth(year, month);
    final monthlyExpenses = await getExpensesForMonth(year, month);
    final List<MemberWithBalance> membersWithBalance = [];

    for (var member in allMembers) {
      // Get meals and payments for the specified month
      final meals = await getMealsForMemberInMonth(member.id, year, month);
      final payments = await getPaymentsForMemberInMonth(
        member.id,
        year,
        month,
      );

      // Get the last payment date (all-time) for sorting
      final lastPaymentDate = await getLastPaymentDateForMember(member.id);

      // --- NEW: Calculate individual meal counts (for PDF) ---
      int totalB = 0;
      int totalL = 0;
      int totalD = 0;

      for (var meal in meals) {
        totalB += meal.breakfastCount;
        totalL += meal.lunchCount;
        totalD += meal.dinnerCount;
      }

      final totalCost = settings.mode == CalculationMode.expenseBased
          ? BillingService.calculateExpenseBasedCostByDate(
              settings,
              meals,
              monthlyMeals,
              monthlyExpenses,
            )
          : BillingService.calculateMealCost(settings, meals);

      double totalPaid = payments.fold(0.0, (sum, p) => sum + p.amount);
      final balance = totalPaid - totalCost;

      membersWithBalance.add(
        MemberWithBalance(
          member: member,
          balance: balance,
          totalCost: totalCost,
          lastPaymentDate: lastPaymentDate,
          totalBreakfast: totalB, // Pass breakfast count
          totalLunch: totalL, // Pass lunch count
          totalDinner: totalD, // Pass dinner count
        ),
      );
    }

    // --- UNCHANGED: Sorting logic is still based on lastPaymentDate ---
    membersWithBalance.sort((a, b) {
      if (a.lastPaymentDate == null && b.lastPaymentDate == null) return 0;
      if (a.lastPaymentDate == null) return 1;
      if (b.lastPaymentDate == null) return -1;
      return b.lastPaymentDate!.compareTo(a.lastPaymentDate!);
    });

    return membersWithBalance;
  }

  Future<List<Payment>> getPaymentsForMemberInMonth(
    String memberId,
    int year,
    int month,
  ) async {
    final db = await database;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startDate = firstDayOfMonth.toIso8601String().substring(0, 10);
    final endDate = lastDayOfMonth.toIso8601String().substring(0, 10);
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'memberId = ? AND date >= ? AND date <= ?',
      whereArgs: [memberId, startDate, endDate],
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  // Add this new function inside your DatabaseService class
  Future<List<Payment>> getAllPayments() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      orderBy: 'date DESC',
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }
  // Add these new functions inside your DatabaseService class

  // Gets all meal records from the beginning up to a specific date
  Future<List<MealRecord>> getAllMealsUpTo(String date) async {
    final db = await database;
    final maps = await db.query(
      'meal_records',
      where: 'date <= ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => MealRecord.fromMap(maps[i]));
  }

  // Gets all expenses from the beginning up to a specific date
  Future<List<Expense>> getAllExpensesUpTo(String date) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'date <= ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  // Gets expenses for a single, specific date
  Future<List<Expense>> getExpensesForDate(String date) async {
    final db = await database;
    final maps = await db.query(
      'expenses',
      where: 'date = ?',
      whereArgs: [date],
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }
  // Add these two new functions inside your DatabaseService class

  // To update a member's details (like their name)
  Future<void> updateMember(Member member) async {
    final db = await database;
    await db.update(
      'members',
      member.toMap(),
      where: 'id = ?',
      whereArgs: [member.id],
    );
  }

  // To delete a member and all their related data (meals, payments)
  Future<void> deleteMember(String memberId) async {
    final db = await database;
    await db.transaction((txn) async {
      // Delete all payments associated with the member
      await txn.delete(
        'payments',
        where: 'memberId = ?',
        whereArgs: [memberId],
      );
      // Delete all meal records associated with the member
      await txn.delete(
        'meal_records',
        where: 'memberId = ?',
        whereArgs: [memberId],
      );
      // Finally, delete the member themselves
      await txn.delete('members', where: 'id = ?', whereArgs: [memberId]);
    });
  }

  // Add this new function inside your DatabaseService class
  Future<void> deleteExpense(String expenseId) async {
    final db = await database;
    await db.delete('expenses', where: 'id = ?', whereArgs: [expenseId]);
  }
  // Add these two new functions inside your DatabaseService class

  // Fetches all payments for a given month and year
  Future<List<Payment>> getPaymentsForMonth(int year, int month) async {
    final db = await database;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startDate = firstDayOfMonth.toIso8601String().substring(0, 10);
    final endDate = lastDayOfMonth.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
    );
    return List.generate(maps.length, (i) => Payment.fromMap(maps[i]));
  }

  // Fetches all expenses for a given month and year
  Future<List<Expense>> getExpensesForMonth(int year, int month) async {
    final db = await database;
    final firstDayOfMonth = DateTime(year, month, 1);
    final lastDayOfMonth = DateTime(year, month + 1, 0);
    final startDate = firstDayOfMonth.toIso8601String().substring(0, 10);
    final endDate = lastDayOfMonth.toIso8601String().substring(0, 10);

    final List<Map<String, dynamic>> maps = await db.query(
      'expenses',
      where: 'date >= ? AND date <= ?',
      whereArgs: [startDate, endDate],
    );
    return List.generate(maps.length, (i) => Expense.fromMap(maps[i]));
  }

  // Add this new helper function inside DatabaseService class
  Future<DateTime?> getLastPaymentDateForMember(String memberId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'payments',
      where: 'memberId = ?',
      whereArgs: [memberId],
      orderBy: 'date DESC', // Sort by date in descending order
      limit: 1, // Get only the first one (the latest)
    );
    if (maps.isNotEmpty) {
      return DateTime.parse(maps.first['date']);
    }
    return null;
  }
}
