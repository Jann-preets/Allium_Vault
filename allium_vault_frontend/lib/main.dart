import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:provider/provider.dart';

// --- Firebase Imports ---
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

// --- Data Models ---
class StockEntry {
  final String quantity;
  final DateTime arrivalDate;
  StockEntry({required this.quantity, required this.arrivalDate});
  factory StockEntry.fromJson(Map<String, dynamic> json) => StockEntry(
      quantity: json['stock_quantity'] ?? 'N/A',
      arrivalDate: DateTime.parse(json['arrival_date']));
}

// NEW: Data model for the Energy Report
class EnergyReport {
  final double totalHours;
  final double estimatedCost;
  EnergyReport({this.totalHours = 0.0, this.estimatedCost = 0.0});
  factory EnergyReport.fromJson(Map<String, dynamic> json) => EnergyReport(
        totalHours: json['total_hours']?.toDouble() ?? 0.0,
        estimatedCost: json['estimated_cost_inr']?.toDouble() ?? 0.0,
      );
}

// --- State Management Class ---
class VaultState with ChangeNotifier {
  String _status = "Loading...";
  double _temperature = 0.0;
  double _humidity = 0.0;
  double _gasLevel = 0.0;
  List<StockEntry> _stockHistory = [];

  // NEW: State variables for Fan and Energy
  String _fanMode = "AUTO";
  EnergyReport _energyReport = EnergyReport();

  String get status => _status;
  double get temperature => _temperature;
  double get humidity => _humidity;
  double get gasLevel => _gasLevel;
  List<StockEntry> get stockHistory => _stockHistory;
  String get fanMode => _fanMode;
  EnergyReport get energyReport => _energyReport;

  final String _ipAddress = "192.168.1.12";

  Future<void> fetchData() async {
    await Future.wait([
      fetchSensorData(),
      fetchStockHistory(),
      fetchEnergyReport(), // Added this to the refresh cycle
    ]);
  }

  Future<void> fetchSensorData() async {
    final String apiUrl = "http://$_ipAddress:5000/api/latest-data";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _status = data['status'] ?? 'N/A';
        _temperature = data['temperature']?.toDouble() ?? 0.0;
        _humidity = data['humidity']?.toDouble() ?? 0.0;
        _gasLevel = data['gas_level']?.toDouble() ?? 0.0;
      }
    } catch (e) {
      _status = "Connection Failed";
    }
    notifyListeners();
  }

  // NEW: API call to set the Fan Mode
  Future<void> setFanMode(String mode) async {
    _fanMode = mode;
    notifyListeners();
    final String apiUrl = "http://$_ipAddress:5000/api/fan-control";
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'mode': mode}),
      );
      if (response.statusCode == 200) {
        await fetchEnergyReport(); // Refresh energy immediately when toggling
      }
    } catch (e) {
      print("Fan control error: $e");
    }
  }

  // NEW: API call to get Energy data
  Future<void> fetchEnergyReport() async {
    final String apiUrl = "http://$_ipAddress:5000/api/energy-report";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        _energyReport = EnergyReport.fromJson(json.decode(response.body));
      }
    } catch (e) {
      print("Energy report error: $e");
    }
    notifyListeners();
  }

  Future<void> fetchStockHistory() async {
    final String apiUrl = "http://$_ipAddress:5000/api/stock-history";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _stockHistory = data.map((json) => StockEntry.fromJson(json)).toList();
      }
    } catch (e) {}
    notifyListeners();
  }

  Future<bool> addStock(String quantity, DateTime? date) async {
    final String apiUrl = "http://$_ipAddress:5000/api/stock";
    if (date == null || quantity.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'stock_quantity': "$quantity kg",
          'arrival_date': date.toIso8601String()
        }),
      );
      if (response.statusCode == 201) {
        await fetchStockHistory();
        return true;
      }
    } catch (e) {
      return false;
    }
    return false;
  }

  Future<void> registerDevice() async {
    await FirebaseMessaging.instance.requestPermission();
    final fcmToken = await FirebaseMessaging.instance.getToken();
    if (fcmToken == null) return;
    final String apiUrl = "http://$_ipAddress:5000/api/register-device";
    try {
      await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'token': fcmToken}),
      );
    } catch (e) {}
  }
}

// --- Main App and UI ---
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  runApp(
    ChangeNotifierProvider(
        create: (context) => VaultState(), child: const AlliumVaultApp()),
  );
}

class AlliumVaultApp extends StatelessWidget {
  const AlliumVaultApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Allium Vault',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.teal,
        scaffoldBackgroundColor: const Color(0xFF121212),
        cardColor: const Color(0xFF1E1E1E),
        appBarTheme: const AppBarTheme(backgroundColor: Color(0xFF1E1E1E)),
        dialogBackgroundColor: const Color(0xFF2A2A2A),
        colorScheme: ColorScheme.fromSwatch(brightness: Brightness.dark)
            .copyWith(secondary: Colors.tealAccent),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final vaultState = context.read<VaultState>();
    Future.microtask(() async {
      await vaultState.registerDevice();
      await vaultState.fetchData();
    });
    _timer = Timer.periodic(const Duration(seconds: 30), (Timer t) {
      vaultState.fetchData();
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null && mounted) {
        final status = message.data['status'] ?? 'Warning';
        _showStatusAlert(
            status, message.notification?.title, message.notification?.body);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VaultState>(
      builder: (context, vaultState, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Allium Vault Dashboard"),
            actions: [
              IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: () => vaultState.fetchData())
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSectionTitle('Real-Time Monitoring'),
              const SizedBox(height: 10),
              _buildStatusCircle(vaultState.status),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDataCard(
                      "Temperature",
                      "${vaultState.temperature.toStringAsFixed(1)} °C",
                      Icons.thermostat_outlined),
                  _buildDataCard(
                      "Humidity",
                      "${vaultState.humidity.toStringAsFixed(1)} %",
                      Icons.water_drop_outlined),
                ],
              ),
              const SizedBox(height: 10),
              Center(
                  child: _buildDataCard(
                      "Gas Level",
                      "${vaultState.gasLevel.toStringAsFixed(0)} PPM",
                      Icons.air_outlined)),

              const Divider(height: 40, thickness: 1),

              // NEW SECTION: Manual Fan Controls
              _buildSectionTitle('Manual Fan Controls'),
              const SizedBox(height: 10),
              _buildFanControlCard(vaultState),

              const Divider(height: 40, thickness: 1),

              // NEW SECTION: Energy Monitoring
              _buildSectionTitle('Energy Monitoring (30 Days)'),
              const SizedBox(height: 10),
              _buildEnergyCard(vaultState.energyReport),

              const Divider(height: 40, thickness: 1),

              _buildSectionTitle('Stock Management'),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                icon: const Icon(Icons.add_shopping_cart),
                label: const Text('Add New Stock'),
                onPressed: () => _showAddStockDialog(context, vaultState),
              ),
              const SizedBox(height: 10),
              _buildStockHistoryList(vaultState.stockHistory),
            ],
          ),
        );
      },
    );
  }

  // --- NEW UI HELPER WIDGETS ---

  Widget _buildFanControlCard(VaultState vaultState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ["ON", "OFF", "AUTO"].map((mode) {
            bool isSelected = vaultState.fanMode == mode;
            return ElevatedButton(
              onPressed: () => vaultState.setFanMode(mode),
              style: ElevatedButton.styleFrom(
                backgroundColor: isSelected ? Colors.teal : Colors.grey[800],
                foregroundColor: Colors.white,
              ),
              child: Text(mode),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEnergyCard(EnergyReport report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildEnergyInfo("Runtime", "${report.totalHours} hrs"),
            _buildEnergyInfo(
                "Est. Cost", "₹${report.estimatedCost.toStringAsFixed(2)}"),
          ],
        ),
      ),
    );
  }

  Widget _buildEnergyInfo(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.grey)),
        const SizedBox(height: 5),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- EXISTING UI HELPER WIDGETS ---

  void _showStatusAlert(String status, String? title, String? body) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        Color color = _getStatusColor(status);
        IconData icon = Icons.info_outline;
        switch (status.toLowerCase()) {
          case 'danger':
            icon = Icons.error_outline;
            break;
          case 'warning':
            icon = Icons.warning_amber_rounded;
            break;
          case 'healthy':
            icon = Icons.check_circle_outline;
            break;
        }
        return AlertDialog(
          title: Text(title ?? "AI Status Update"),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: color, size: 50),
            const SizedBox(height: 20),
            Text(body ?? "AI analysis complete.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
          ]),
          actions: <Widget>[
            TextButton(
                child: const Text('OK'),
                onPressed: () => Navigator.of(context).pop())
          ],
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title,
        style: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(color: Colors.tealAccent));
  }

  Widget _buildStatusCircle(String status) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _getStatusColor(status), width: 8)),
      child: Center(
        child: Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(status)),
        ),
      ),
    );
  }

  Widget _buildDataCard(String title, String value, IconData icon) {
    return Card(
      elevation: 5,
      child: Container(
        width: 150,
        height: 150,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.tealAccent),
            const SizedBox(height: 10),
            Text(title,
                style: Theme.of(context).textTheme.titleMedium,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 5),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildStockHistoryList(List<StockEntry> history) {
    if (history.isEmpty) {
      return const Center(
          child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text("No stock entries yet.")));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final entry = history[index];
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(child: Text('${index + 1}')),
            title: Text(entry.quantity),
            subtitle: Text(
                'Arrived on: ${entry.arrivalDate.toLocal()}'.split(' ')[0]),
          ),
        );
      },
    );
  }

  Future<void> _showAddStockDialog(
      BuildContext context, VaultState vaultState) async {
    final quantityController = TextEditingController();
    DateTime? selectedDate = DateTime.now();
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add New Stock Entry'),
              content: SingleChildScrollView(
                child: ListBody(
                  children: <Widget>[
                    TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Quantity (in kg)'),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Arrival: ${selectedDate!.toLocal()}'
                            .split(' ')[0]),
                        TextButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate!,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now());
                            if (picked != null) {
                              setDialogState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: const Text('Choose Date'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                    child: const Text('Cancel'),
                    onPressed: () => Navigator.of(context).pop()),
                TextButton(
                  child: const Text('Save'),
                  onPressed: () async {
                    if (quantityController.text.isEmpty) return;
                    showDialog(
                        context: context,
                        builder: (context) =>
                            const Center(child: CircularProgressIndicator()),
                        barrierDismissible: false);
                    bool success = await vaultState.addStock(
                        quantityController.text, selectedDate);
                    if (mounted) Navigator.of(context).pop();
                    if (mounted) Navigator.of(context).pop();
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                            content: Text(success
                                ? 'Stock added successfully!'
                                : 'Failed to add stock.'),
                            backgroundColor:
                                success ? Colors.green : Colors.red),
                      );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'healthy':
        return Colors.greenAccent;
      case 'warning':
        return Colors.orangeAccent;
      case 'danger':
        return Colors.redAccent;
      default:
        return Colors.grey;
    }
  }
}
