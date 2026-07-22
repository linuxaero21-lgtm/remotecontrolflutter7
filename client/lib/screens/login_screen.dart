/**
 * login_screen.dart — Schermata di connessione
 *
 * Permette di inserire indirizzo (IP locale o URL Ngrok) e password.
 * Rileva automaticamente se è TCP o HTTP.
 */

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/connection_service.dart';
import 'touchpad_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _connectionService = ConnectionService();

  bool _connecting = false;
  bool _obscurePassword = true;
  String? _statusMessage;
  Color _statusColor = Colors.grey;

  // Storico indirizzi recenti
  List<String> _recentAddresses = [];

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _addressController.text = prefs.getString('last_address') ?? '';
      _passwordController.text = prefs.getString('last_password') ?? '';
      _recentAddresses = prefs.getStringList('recent_addresses') ?? [];
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_address', _addressController.text.trim());
    await prefs.setString('last_password', _passwordController.text);

    // Aggiorna storico
    final addr = _addressController.text.trim();
    if (addr.isNotEmpty) {
      _recentAddresses.remove(addr);
      _recentAddresses.insert(0, addr);
      if (_recentAddresses.length > 5) {
        _recentAddresses = _recentAddresses.sublist(0, 5);
      }
      await prefs.setStringList('recent_addresses', _recentAddresses);
    }
  }

  Future<void> _connect() async {
    final address = _addressController.text.trim();
    final password = _passwordController.text;

    if (address.isEmpty) {
      _setStatus('Inserisci un indirizzo (IP o URL Ngrok)', Colors.red);
      return;
    }
    if (password.isEmpty) {
      _setStatus('Inserisci la password di sicurezza', Colors.red);
      return;
    }

    setState(() {
      _connecting = true;
      _statusMessage = 'Connessione in corso...';
      _statusColor = Colors.blue;
    });

    final result = await _connectionService.connect(
      address: address,
      password: password,
    );

    if (!mounted) return;

    if (result.success) {
      await _saveData();
      _setStatus(result.message, Colors.green);

      // Vai alla schermata touchpad
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => TouchpadScreen(
            connectionService: _connectionService,
          ),
        ),
      );
    } else {
      _setStatus(result.message, Colors.red);
      setState(() => _connecting = false);
    }
  }

  void _setStatus(String msg, Color color) {
    setState(() {
      _statusMessage = msg;
      _statusColor = color;
    });
  }

  ConnectionMode? _detectMode() {
    final addr = _addressController.text.trim();
    if (addr.isEmpty) return null;
    return ConnectionService.detectMode(addr);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mode = _detectMode();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icona
                Icon(
                  Icons.computer_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  'Remote Control',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Controlla il tuo PC da smartphone',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey,
                      ),
                ),
                const SizedBox(height: 40),

                // Campo indirizzo
                Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) {
                      return _recentAddresses;
                    }
                    return _recentAddresses.where((addr) =>
                        addr.toLowerCase().contains(
                            textEditingValue.text.toLowerCase()));
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onSubmitted) {
                    // Sincronizza controller esterno
                    _addressController.text = controller.text;

                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        labelText: 'Indirizzo',
                        hintText: '192.168.1.57:5555 o URL Ngrok',
                        prefixIcon: const Icon(Icons.link),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (mode != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: mode == ConnectionMode.http
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : Colors.blue.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  mode == ConnectionMode.http
                                      ? 'HTTP'
                                      : 'TCP',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: mode == ConnectionMode.http
                                        ? Colors.orange
                                        : Colors.blue,
                                  ),
                                ),
                              ),
                            if (controller.text.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () {
                                  controller.clear();
                                  _addressController.clear();
                                },
                              ),
                          ],
                        ),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => onSubmitted(),
                    );
                  },
                  onSelected: (selection) {
                    _addressController.text = selection;
                    setState(() {});
                  },
                ),
                const SizedBox(height: 16),

                // Campo password
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Inserisci la password del server',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off
                            : Icons.visibility,
                      ),
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _connect(),
                ),
                const SizedBox(height: 24),

                // Pulsante connetti
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: _connecting ? null : _connect,
                    icon: _connecting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.power_settings_new),
                    label: Text(
                      _connecting ? 'Connessione...' : 'CONNETTI',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Messaggio di stato
                if (_statusMessage != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _statusColor == Colors.green
                              ? Icons.check_circle
                              : _statusColor == Colors.red
                                  ? Icons.error
                                  : Icons.info,
                          color: _statusColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _statusMessage!,
                            style: TextStyle(
                              color: _statusColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Info modalità
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey.withValues(alpha: 0.2)
                        : Colors.grey.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '💡 Come connettersi:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _infoRow(Icons.wifi, 'Wi-Fi locale: IP:porta del server'),
                      const SizedBox(height: 4),
                      _infoRow(
                          Icons.cloud, 'Remoto: URL Ngrok dall\'app del PC'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
