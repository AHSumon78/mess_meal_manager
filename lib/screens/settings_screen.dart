// lib/screens/settings_screen.dart
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../models/calculation_mode.dart';
import '../services/database_service.dart';
import '../services/drive_service.dart';
import '../services/settings_service.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Existing Settings variables
  final _settingsService = SettingsService();
  late AppSettings _currentSettings;
  bool _isLoading = true;
  final _breakfastRateController = TextEditingController();
  final _lunchRateController = TextEditingController();
  final _dinnerRateController = TextEditingController();
  final _breakfastWeightController = TextEditingController();
  final _lunchWeightController = TextEditingController();
  final _dinnerWeightController = TextEditingController();
  CalculationMode _selectedMode = CalculationMode.fixedRate;

  // Google Drive Sync variables
  final DriveService _driveService = DriveService();
  final DatabaseService _dbService = DatabaseService();
  String _driveStatus = 'Not signed in.';
  bool _isSignedIn = false;
  bool _isWorking = false;
  GoogleSignInAccount? _currentUser; // ইউজারের তথ্য রাখার জন্য

  @override
  void initState() {
    super.initState();
    _loadAllSettingsData();
  }

  Future<void> _loadAllSettingsData() async {
    // Load app settings
    _currentSettings = await _settingsService.loadSettings();
    setState(() {
      _selectedMode = _currentSettings.mode;
      _breakfastRateController.text = _currentSettings.breakfastRate.toString();
      _lunchRateController.text = _currentSettings.lunchRate.toString();
      _dinnerRateController.text = _currentSettings.dinnerRate.toString();
      _breakfastWeightController.text = _currentSettings.breakfastWeight
          .toString();
      _lunchWeightController.text = _currentSettings.lunchWeight.toString();
      _dinnerWeightController.text = _currentSettings.dinnerWeight.toString();
      _isLoading = false;
    });

    // Attempt to sign in to Google silently
    try {
      final account = await _driveService.signInSilently();
      if (account != null && mounted) {
        setState(() {
          _currentUser = account;
          _driveStatus = 'Signed in as ${account.displayName}';
          _isSignedIn = true;
        });
      }
    } catch (e) {
      debugPrint("Silent sign-in failed: $e");
    }
  }

  Future<void> _saveSettings() async {
    final breakfastRate = double.tryParse(_breakfastRateController.text);
    final lunchRate = double.tryParse(_lunchRateController.text);
    final dinnerRate = double.tryParse(_dinnerRateController.text);
    final breakfastWeight = double.tryParse(_breakfastWeightController.text);
    final lunchWeight = double.tryParse(_lunchWeightController.text);
    final dinnerWeight = double.tryParse(_dinnerWeightController.text);
    final totalWeight =
        (breakfastWeight ?? 0) + (lunchWeight ?? 0) + (dinnerWeight ?? 0);

    if (_selectedMode == CalculationMode.fixedRate &&
        ((breakfastRate == null || breakfastRate < 0) ||
            (lunchRate == null || lunchRate < 0) ||
            (dinnerRate == null || dinnerRate < 0))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid meal rates.')),
      );
      return;
    }

    if (_selectedMode == CalculationMode.expenseBased &&
        ((breakfastWeight == null || breakfastWeight < 0) ||
            (lunchWeight == null || lunchWeight < 0) ||
            (dinnerWeight == null || dinnerWeight < 0) ||
            totalWeight <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid meal weights.')),
      );
      return;
    }

    final newSettings = AppSettings(
      mode: _selectedMode,
      breakfastRate: breakfastRate ?? _currentSettings.breakfastRate,
      lunchRate: lunchRate ?? _currentSettings.lunchRate,
      dinnerRate: dinnerRate ?? _currentSettings.dinnerRate,
      breakfastWeight: breakfastWeight ?? _currentSettings.breakfastWeight,
      lunchWeight: lunchWeight ?? _currentSettings.lunchWeight,
      dinnerWeight: dinnerWeight ?? _currentSettings.dinnerWeight,
    );
    await _settingsService.saveSettings(newSettings);
    _currentSettings = newSettings;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings Saved Successfully!')),
      );
    }
  }

  @override
  void dispose() {
    _breakfastRateController.dispose();
    _lunchRateController.dispose();
    _dinnerRateController.dispose();
    _breakfastWeightController.dispose();
    _lunchWeightController.dispose();
    _dinnerWeightController.dispose();
    super.dispose();
  }

  // Functions for Google Drive Sync
  void _handleSignIn() async {
    setState(() => _isWorking = true);
    try {
      final account = await _driveService.signIn();
      if (account != null && mounted) {
        setState(() {
          _currentUser = account;
          _driveStatus = 'Signed in as ${account.displayName}';
          _isSignedIn = true;
        });
      } else if (mounted) {
        setState(() {
          _driveStatus = 'Sign-in failed.';
        });
      }
    } finally {
      if (mounted) setState(() => _isWorking = false);
    }
  }

  void _handleSignOut() async {
    await _driveService.signOut();
    if (mounted) {
      setState(() {
        _currentUser = null;
        _driveStatus = 'Not signed in.';
        _isSignedIn = false;
      });
    }
  }

  void _handleBackup() async {
    if (!_isSignedIn) return;
    setState(() {
      _isWorking = true;
    });
    final dbFile = await _dbService.getDatabaseFile();
    await _driveService.backupDatabase(dbFile, (progress) {
      if (mounted) {
        setState(() {
          _driveStatus = progress;
        });
      }
    });
    if (mounted) {
      setState(() {
        _isWorking = false;
      });
    }
  }

  void _handleRestore() async {
    if (!_isSignedIn) return;
    setState(() {
      _isWorking = true;
    });
    final dbPath = await _dbService.getDatabasePath();
    await _driveService.restoreDatabase(dbPath, (progress) {
      if (mounted) {
        setState(() {
          _driveStatus = progress;
        });
      }
    });
    if (mounted) {
      setState(() {
        _isWorking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings & Backup')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- Calculation Mode Selection ---
                const Text(
                  'Calculation Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                RadioListTile<CalculationMode>(
                  title: const Text('Fixed Rate Mode'),
                  value: CalculationMode.fixedRate,
                  groupValue: _selectedMode,
                  onChanged: (value) {
                    setState(() {
                      _selectedMode = value!;
                    });
                  },
                ),
                RadioListTile<CalculationMode>(
                  title: const Text('Expense Based Mode'),
                  subtitle: const Text(
                    'Daily expenses are divided by daily weighted meals.',
                  ),
                  value: CalculationMode.expenseBased,
                  groupValue: _selectedMode,
                  onChanged: (value) {
                    setState(() {
                      _selectedMode = value!;
                    });
                  },
                ),
                const Divider(height: 30),

                // --- Fixed Rate Inputs ---
                if (_selectedMode == CalculationMode.fixedRate) ...[
                  const Text(
                    'Fixed Meal Rates',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _breakfastRateController,
                    decoration: const InputDecoration(
                      labelText: 'Breakfast Rate',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lunchRateController,
                    decoration: const InputDecoration(
                      labelText: 'Lunch Rate',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dinnerRateController,
                    decoration: const InputDecoration(
                      labelText: 'Dinner Rate',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Meal Weights',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Daily meal rate = today\'s total expense / today\'s weighted total meals.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _breakfastWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Breakfast Weight',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _lunchWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Lunch Weight',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _dinnerWeightController,
                    decoration: const InputDecoration(
                      labelText: 'Dinner Weight',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Card(
                    elevation: 0,
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Example: weights 0.5, 1, 1 means B+L+D = 2.5 weighted meals for that member.',
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 30),

                // --- Save Button ---
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),

                const Divider(height: 40, thickness: 1),

                // --- Google Drive Backup Section (Improved Design) ---
                const Text(
                  'Google Drive Sync',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        if (_isSignedIn && _currentUser != null) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundImage: _currentUser!.photoUrl != null
                                  ? NetworkImage(_currentUser!.photoUrl!)
                                  : null,
                              child: _currentUser!.photoUrl == null
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(_currentUser!.displayName ?? 'User'),
                            subtitle: Text(_currentUser!.email),
                            trailing: IconButton(
                              icon: const Icon(
                                Icons.logout,
                                color: Colors.redAccent,
                              ),
                              onPressed: _handleSignOut,
                            ),
                          ),
                          const Divider(),
                        ],
                        Text(
                          _driveStatus,
                          style: TextStyle(
                            color: _isSignedIn ? Colors.green : Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                        const SizedBox(height: 15),
                        if (_isWorking)
                          const LinearProgressIndicator()
                        else if (!_isSignedIn)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.login),
                            label: const Text('Sign in with Google'),
                            onPressed: _handleSignIn,
                          )
                        else ...[
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _handleBackup,
                                  icon: const Icon(Icons.backup),
                                  label: const Text('Backup'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _handleRestore,
                                  icon: const Icon(Icons.restore),
                                  label: const Text('Restore'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}
