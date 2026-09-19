// lib/screens/add_edit_meals_screen.dart
import 'package:flutter/material.dart';
import '../models/member.dart';
import '../models/meal_record.dart';
import '../services/database_service.dart';

class AddEditMealsScreen extends StatefulWidget {
  const AddEditMealsScreen({super.key});

  @override
  State<AddEditMealsScreen> createState() => _AddEditMealsScreenState();
}

class _AddEditMealsScreenState extends State<AddEditMealsScreen> {
  final dbService = DatabaseService();
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  List<Member> _members = [];
  Map<String, List<int>> _mealCounts = {};
  Map<String, bool> _isTicked = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    _members = await dbService.getAllMembers();
    for (var member in _members) {
      _mealCounts[member.id] = [0, 0, 0];
      _isTicked[member.id] = false; // ডিফল্টভাবে false
    }
    await _loadMealsForSelectedDate();
    setState(() => _isLoading = false);
  }

  Future<void> _loadMealsForSelectedDate() async {
    final dateString = _selectedDate.toIso8601String().substring(0, 10);
    final mealsForDate = await dbService.getMealsForDate(dateString);

    for (var mealRecord in mealsForDate) {
      if (_mealCounts.containsKey(mealRecord.memberId)) {
        _mealCounts[mealRecord.memberId] = [
          mealRecord.breakfastCount,
          mealRecord.lunchCount,
          mealRecord.dinnerCount,
        ];
        // যদি কোনো একটি মিলও ০ এর বেশি থাকে, তবে টিক True করে দিন
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _selectDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        _isLoading = true;
        for (var member in _members) {
          _mealCounts[member.id] = [0, 0, 0];
        }
      });
      await _loadMealsForSelectedDate();
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveMeals() async {
    for (var member in _members) {
      final counts = _mealCounts[member.id] ?? [0, 0, 0];

      // র্যান্ডম UUID এর বদলে মেম্বার আইডি এবং তারিখ মিলিয়ে আইডি তৈরি করো
      final String dateString = _selectedDate.toIso8601String().substring(
        0,
        10,
      );
      final String uniqueId = "${member.id}_$dateString";

      final mealRecord = MealRecord(
        id: uniqueId, // এখন আইডি সবসময় একই থাকবে ওই মেম্বার ও তারিখের জন্য
        memberId: member.id,
        date: _selectedDate,
        breakfastCount: counts[0],
        lunchCount: counts[1],
        dinnerCount: counts[2],
      );
      await dbService.upsertMealRecord(mealRecord);
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Meals Saved Successfully!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add / Edit Meals'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Text(
                    'Date: ${_selectedDate.toLocal().toString().substring(0, 10)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _members.length,
                    itemBuilder: (context, index) {
                      final member = _members[index];
                      final counts = _mealCounts[member.id] ?? [0, 0, 0];

                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8.0,
                            vertical: 12.0,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // মেম্বারের নাম এবং টিক বক্স
                              Row(
                                children: [
                                  Checkbox(
                                    value: _isTicked[member.id] ?? false,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _isTicked[member.id] = value ?? false;
                                        if (_isTicked[member.id] == true) {
                                          // টিক দিলে ডিফল্টভাবে সব মিল ১ হবে
                                          _mealCounts[member.id] = [1, 1, 1];
                                        } else {
                                          // টিক সরালে সব ০ হবে
                                          _mealCounts[member.id] = [0, 0, 0];
                                        }
                                      });
                                    },
                                  ),
                                  Expanded(
                                    child: Text(
                                      member.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 15),
                              Row(
                                children: [
                                  Expanded(
                                    child: MealInput(
                                      label: 'সকাল (B)',
                                      count: counts[0],
                                      onChanged: (newCount) {
                                        setState(() {
                                          if (_mealCounts.containsKey(
                                            member.id,
                                          )) {
                                            _mealCounts[member.id]![0] =
                                                newCount;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: MealInput(
                                      label: 'দুপুর (L)',
                                      count: counts[1],
                                      onChanged: (newCount) {
                                        setState(() {
                                          if (_mealCounts.containsKey(
                                            member.id,
                                          )) {
                                            _mealCounts[member.id]![1] =
                                                newCount;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: MealInput(
                                      label: 'রাত (D)',
                                      count: counts[2],
                                      onChanged: (newCount) {
                                        setState(() {
                                          if (_mealCounts.containsKey(
                                            member.id,
                                          )) {
                                            _mealCounts[member.id]![2] =
                                                newCount;
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SizedBox(height: 50),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: _saveMeals,
        child: const Icon(Icons.save),
      ),
    );
  }
}

// MealInput widget is more compact now for the new design
// Replace your old MealInput class with this new, more compact version
class MealInput extends StatelessWidget {
  final String label;
  final int count;
  final ValueChanged<int> onChanged;

  MealInput({
    super.key,
    required this.label,
    required this.count,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Label with a smaller font size
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 2), // Reduced space
        // The counter row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Smaller minus button
            IconButton(
              icon: const Icon(
                Icons.remove_circle,
                color: Colors.redAccent,
                size: 22,
              ), // Smaller icon
              onPressed: () {
                if (count > 0) {
                  onChanged(count - 1);
                }
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),

            // Smaller space
            const SizedBox(width: 1),

            // Count with a smaller font size
            Text(
              count.toString(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ), // Smaller font
            ),

            // Smaller space
            const SizedBox(width: 1),

            // Smaller plus button
            IconButton(
              icon: const Icon(
                Icons.add_circle,
                color: Colors.green,
                size: 22,
              ), // Smaller icon
              onPressed: () {
                onChanged(count + 1);
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }
}
