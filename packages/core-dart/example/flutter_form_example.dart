// ignore_for_file: use_key_in_widget_constructors

/// Flutter Widget address form validation example using bluewhale_core.
///
/// Demonstrates how to wire [extractRoutingSync] into a [TextFormField]
/// validator for real-time address validation, and how to surface warning
/// badges when the input is non-canonical (e.g. a numeric MEMO_TEXT or a
/// routing ID with leading zeros).
///
/// Run with:
///   flutter run -d <device>
library;

import 'package:flutter/material.dart';
import 'package:bluewhale_core/bluewhale_core.dart';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

void main() {
  runApp(const BluewhaleFormExampleApp());
}

// ---------------------------------------------------------------------------
// App shell
// ---------------------------------------------------------------------------

class BluewhaleFormExampleApp extends StatelessWidget {
  const BluewhaleFormExampleApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bluewhale Address Form',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3E1BDB)),
        useMaterial3: true,
      ),
      home: const AddressFormPage(),
    );
  }
}

// ---------------------------------------------------------------------------
// Form page
// ---------------------------------------------------------------------------

class AddressFormPage extends StatefulWidget {
  const AddressFormPage();

  @override
  State<AddressFormPage> createState() => _AddressFormPageState();
}

class _AddressFormPageState extends State<AddressFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _memoValueController = TextEditingController();

  String _memoType = 'none';
  RoutingResult? _result;
  List<RoutingWarning> _warnings = [];

  // Memo type options shown in the dropdown.
  static const _memoTypes = ['none', 'id', 'text', 'hash', 'return'];

  @override
  void dispose() {
    _addressController.dispose();
    _memoValueController.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Validation helpers
  // -------------------------------------------------------------------------

  /// Inline validator used by the address [TextFormField].
  ///
  /// Returns a human-readable error message when the address is unparseable
  /// (unknown prefix, malformed checksum, etc.). Returns `null` on success so
  /// the form field shows no error decoration.
  String? _validateAddress(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) {
      return 'Address is required.';
    }

    final prefix = trimmed[0].toUpperCase();
    if (prefix != 'G' && prefix != 'M') {
      return 'Expected a G-address or M-address. '
          'C-addresses cannot be used as payment destinations.';
    }

    // Run the full routing extraction to catch checksum / format errors.
    try {
      final result = extractRoutingSync(RoutingInput(
        destination: trimmed,
        memoType: _memoType,
        memoValue: _memoValueController.text.isEmpty
            ? null
            : _memoValueController.text,
      ));

      if (result.destinationError != null) {
        return result.destinationError!.message;
      }
    } on ExtractRoutingException catch (e) {
      return e.message;
    }

    return null;
  }

  // -------------------------------------------------------------------------
  // Submit handler
  // -------------------------------------------------------------------------

  void _onSubmit() {
    // Clear stale state before re-validation.
    setState(() {
      _result = null;
      _warnings = [];
    });

    if (!_formKey.currentState!.validate()) return;

    try {
      final result = extractRoutingSync(RoutingInput(
        destination: _addressController.text.trim(),
        memoType: _memoType,
        memoValue:
            _memoValueController.text.isEmpty ? null : _memoValueController.text,
      ));

      setState(() {
        _result = result;
        _warnings = result.warnings;
      });
    } on ExtractRoutingException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stellar Address Validator'),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Address field ------------------------------------------
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Stellar Address (G or M)',
                  hintText:
                      'GABC… or MABC…',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                validator: _validateAddress,
                // Re-validate on every keystroke so the error clears in
                // real-time as the user corrects their input.
                onChanged: (_) {
                  if (_formKey.currentState != null) {
                    _formKey.currentState!.validate();
                  }
                  // Clear previous results when user starts editing.
                  setState(() {
                    _result = null;
                    _warnings = [];
                  });
                },
                autocorrect: false,
                keyboardType: TextInputType.text,
              ),

              const SizedBox(height: 16),

              // -- Memo type dropdown ------------------------------------
              DropdownButtonFormField<String>(
                value: _memoType,
                decoration: const InputDecoration(
                  labelText: 'Memo Type',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.label_outline),
                ),
                items: _memoTypes
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _memoType = value ?? 'none';
                    _result = null;
                    _warnings = [];
                  });
                },
              ),

              const SizedBox(height: 16),

              // -- Memo value field (only active when memo type != none) --
              TextFormField(
                controller: _memoValueController,
                enabled: _memoType != 'none',
                decoration: InputDecoration(
                  labelText: 'Memo Value',
                  hintText:
                      _memoType == 'id' ? 'Numeric ID (e.g. 12345)' : 'Memo text',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.notes_outlined),
                ),
                onChanged: (_) {
                  setState(() {
                    _result = null;
                    _warnings = [];
                  });
                },
                autocorrect: false,
              ),

              const SizedBox(height: 24),

              // -- Submit button -----------------------------------------
              FilledButton.icon(
                onPressed: _onSubmit,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Extract Routing'),
              ),

              const SizedBox(height: 24),

              // -- Result card ------------------------------------------
              if (_result != null) ...[
                _RoutingResultCard(result: _result!),
                const SizedBox(height: 12),
              ],

              // -- Warning badges ----------------------------------------
              if (_warnings.isNotEmpty) ...[
                const Text(
                  'Warnings',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ..._warnings.map((w) => _WarningBadge(warning: w)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Routing result card
// ---------------------------------------------------------------------------

class _RoutingResultCard extends StatelessWidget {
  final RoutingResult result;

  const _RoutingResultCard({required this.result});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasRouting = result.id != null;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasRouting ? Icons.check_circle : Icons.info_outline,
                  color: hasRouting
                      ? theme.colorScheme.primary
                      : theme.colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Routing Result',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _ResultRow(
              label: 'Source',
              value: result.source.name.toUpperCase(),
            ),
            if (result.destinationBaseAccount != null)
              _ResultRow(
                label: 'Base Account (G)',
                value: result.destinationBaseAccount!,
                monospace: true,
              ),
            if (result.id != null)
              _ResultRow(
                label: 'Routing ID',
                // Use idString for web-safe output (avoids JS Number truncation).
                value: result.idString!,
                monospace: true,
              ),
          ],
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;

  const _ResultRow({
    required this.label,
    required this.value,
    this.monospace = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: monospace
                  ? theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    )
                  : theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Warning badge
// ---------------------------------------------------------------------------

class _WarningBadge extends StatelessWidget {
  final RoutingWarning warning;

  const _WarningBadge({required this.warning});

  Color _badgeColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (warning.severity) {
      case 'error':
        return cs.errorContainer;
      case 'warn':
        return const Color(0xFFFFF3CD); // amber-100 equivalent
      case 'info':
      default:
        return cs.secondaryContainer;
    }
  }

  Color _badgeTextColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (warning.severity) {
      case 'error':
        return cs.onErrorContainer;
      case 'warn':
        return const Color(0xFF856404); // amber-900 equivalent
      case 'info':
      default:
        return cs.onSecondaryContainer;
    }
  }

  IconData _badgeIcon() {
    switch (warning.severity) {
      case 'error':
        return Icons.error_outline;
      case 'warn':
        return Icons.warning_amber_outlined;
      case 'info':
      default:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _badgeColor(context);
    final textColor = _badgeTextColor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_badgeIcon(), color: textColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  warning.code,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  warning.message,
                  style: TextStyle(fontSize: 12, color: textColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
