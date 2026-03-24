import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/operator_model.dart';
import '../providers/operator_provider.dart';
import 'calendar_screen.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _surnameCtrl = TextEditingController();
  final _coopCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _serverUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-compila se operatore già esistente (modifica profilo)
    final operator = ref.read(operatorProvider);
    if (operator != null) {
      _nameCtrl.text = operator.name;
      _surnameCtrl.text = operator.surname;
      _coopCtrl.text = operator.cooperative;
      _emailCtrl.text = operator.email;
      _serverUrlCtrl.text = operator.serverUrl;
      _apiKeyCtrl.text = operator.apiKey;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _surnameCtrl.dispose();
    _coopCtrl.dispose();
    _emailCtrl.dispose();
    _serverUrlCtrl.dispose();
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanQrCode() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _QrScannerScreen()),
    );
    if (result == null) return;
    try {
      final data = jsonDecode(result) as Map<String, dynamic>;
      if (data['url'] != null) _serverUrlCtrl.text = data['url'] as String;
      if (data['api_key'] != null) _apiKeyCtrl.text = data['api_key'] as String;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('QR non valido')),
        );
      }
    }
  }

  void _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(operatorProvider.notifier).save(
          OperatorModel(
            name: _nameCtrl.text.trim(),
            surname: _surnameCtrl.text.trim(),
            cooperative: _coopCtrl.text.trim(),
            email: _emailCtrl.text.trim(),
            serverUrl: _serverUrlCtrl.text.trim(),
            apiKey: _apiKeyCtrl.text.trim(),
          ),
        );
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CalendarScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = ref.watch(operatorProvider) != null;

    return Scaffold(
      backgroundColor: const Color(0xFF1565C0),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Logo / Titolo
                const Icon(Icons.work_history, size: 72, color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  'Registro Ore',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Cooperativa Oltre i Sogni',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 40),
                // Card form
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            isEdit ? 'Modifica Profilo' : 'Benvenuto!',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1565C0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            isEdit
                                ? 'Aggiorna i tuoi dati'
                                : 'Inserisci i tuoi dati per iniziare',
                            style: theme.textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _buildField(
                            controller: _nameCtrl,
                            label: 'Nome',
                            icon: Icons.person,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Inserisci il nome'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _surnameCtrl,
                            label: 'Cognome',
                            icon: Icons.person_outline,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Inserisci il cognome'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _coopCtrl,
                            label: 'Cooperativa Sociale',
                            icon: Icons.business,
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Inserisci la cooperativa'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _emailCtrl,
                            label: 'Email (per ricevere il report)',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            capitalization: TextCapitalization.none,
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final re = RegExp(r'^[\w\.\+\-]+@[\w\-]+\.\w+$');
                              return re.hasMatch(v.trim()) ? null : 'Email non valida';
                            },
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Sincronizzazione web (opzionale)',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _scanQrCode,
                            icon: const Icon(Icons.qr_code_scanner),
                            label: const Text('Scansiona QR Code'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF1565C0),
                              side: const BorderSide(color: Color(0xFF1565C0)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildField(
                            controller: _serverUrlCtrl,
                            label: 'URL server (es. http://mioserver.com:8000)',
                            icon: Icons.cloud_outlined,
                            keyboardType: TextInputType.url,
                            capitalization: TextCapitalization.none,
                          ),
                          const SizedBox(height: 16),
                          _buildField(
                            controller: _apiKeyCtrl,
                            label: 'API Key (fornita dall\'amministratore)',
                            icon: Icons.key_outlined,
                            capitalization: TextCapitalization.none,
                          ),
                          const SizedBox(height: 28),
                          FilledButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.check),
                            label: Text(
                                isEdit ? 'Salva modifiche' : 'Inizia ora'),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF1565C0),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization capitalization = TextCapitalization.words,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF1565C0)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1565C0), width: 2),
        ),
      ),
    );
  }
}

// ── Schermata scanner QR ────────────────────────────────────────────────────

class _QrScannerScreen extends StatefulWidget {
  const _QrScannerScreen();

  @override
  State<_QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<_QrScannerScreen> {
  bool _scanned = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scansiona QR Code'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) {
              if (_scanned) return;
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) {
                _scanned = true;
                Navigator.of(context).pop(barcode!.rawValue);
              }
            },
          ),
          // Cornice guida
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: Text(
              'Inquadra il QR Code mostrato\nnella dashboard web',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black)]),
            ),
          ),
        ],
      ),
    );
  }
}
