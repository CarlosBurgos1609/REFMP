import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RewardsFormPage extends StatefulWidget {
  const RewardsFormPage({super.key});

  @override
  State<RewardsFormPage> createState() => _RewardsFormPageState();
}

class _RewardsFormPageState extends State<RewardsFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController();

  DateTime? _weekStart;
  DateTime? _weekEnd;
  bool _isSaving = false;
  List<Map<String, dynamic>> _objects = <Map<String, dynamic>>[];
  int? _selectedObjectId;

  @override
  void initState() {
    super.initState();
    _prefillCurrentWeek();
    _loadObjects();
  }

  @override
  void dispose() {
    _positionController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  void _prefillCurrentWeek() {
    final now = DateTime.now();
    final monday = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));

    _weekStart = monday;
    _weekEnd = sunday;
  }

  Future<void> _loadObjects() async {
    try {
      final response = await _supabase
          .from('objets')
          .select('id, name, category')
          .order('name', ascending: true);

      if (!mounted) return;
      setState(() {
        _objects = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error loading objects for rewards form: $e');
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        color: Colors.blue,
        fontWeight: FontWeight.bold,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      prefixIcon: Icon(icon, color: Colors.blue),
    );
  }

  int? _toIntOrNull(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return int.tryParse(trimmed);
  }

  String _formatDate(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value);
  }

  Future<void> _pickWeekDate({required bool start}) async {
    final initial = start
        ? (_weekStart ?? DateTime.now())
        : (_weekEnd ??
            (_weekStart ?? DateTime.now()).add(const Duration(days: 6)));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2024),
      lastDate: DateTime(2100),
    );

    if (picked == null) return;

    setState(() {
      if (start) {
        _weekStart = DateTime(picked.year, picked.month, picked.day);
        if (_weekEnd == null || _weekEnd!.isBefore(_weekStart!)) {
          _weekEnd = _weekStart!.add(const Duration(days: 6));
        }
      } else {
        _weekEnd = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _saveReward() async {
    if (!_formKey.currentState!.validate()) return;

    final position = _toIntOrNull(_positionController.text);
    final coins = _toIntOrNull(_coinsController.text) ?? 0;

    if (position == null || position <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La posición debe ser mayor a 0.')),
      );
      return;
    }

    if (_weekStart == null || _weekEnd == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona semana de inicio y fin.')),
      );
      return;
    }

    if (_weekEnd!.isBefore(_weekStart!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('La fecha final no puede ser menor a la inicial.')),
      );
      return;
    }

    if (_selectedObjectId == null && coins <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debes seleccionar un objeto o asignar monedas.'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.from('rewards').insert({
        'user_game_id': null,
        'position': position,
        'object_id': _selectedObjectId,
        'coins_reward': coins,
        'claimed': false,
        'week_start': _formatDate(_weekStart!),
        'week_end': _formatDate(_weekEnd!),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensa creada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error creating reward: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al crear recompensa: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Agregar Recompensa',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _positionController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration('Posición', Icons.emoji_events),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ingresa la posición';
                  }
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed <= 0) {
                    return 'Debe ser un número mayor a 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _selectedObjectId,
                decoration:
                    _inputDecoration('Objeto (opcional)', Icons.card_giftcard),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin objeto'),
                  ),
                  ..._objects.map(
                    (item) => DropdownMenuItem<int?>(
                      value: item['id'] as int,
                      child: Text(
                          '${item['name']} (${item['category'] ?? 'sin categoría'})'),
                    ),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _selectedObjectId = value;
                        });
                      },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coinsController,
                keyboardType: TextInputType.number,
                decoration: _inputDecoration(
                    'Monedas (opcional)', Icons.monetization_on),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return null;
                  final parsed = int.tryParse(value.trim());
                  if (parsed == null || parsed < 0) {
                    return 'Ingresa un número válido (>= 0)';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: const Text('Semana de inicio',
                    style: TextStyle(color: Colors.blue)),
                subtitle: Text(_weekStart == null
                    ? 'Sin fecha'
                    : DateFormat('dd/MM/yyyy').format(_weekStart!)),
                onTap: _isSaving ? null : () => _pickWeekDate(start: true),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event_available, color: Colors.blue),
                title: const Text('Semana de fin',
                    style: TextStyle(color: Colors.blue)),
                subtitle: Text(_weekEnd == null
                    ? 'Sin fecha'
                    : DateFormat('dd/MM/yyyy').format(_weekEnd!)),
                onTap: _isSaving ? null : () => _pickWeekDate(start: false),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save, color: Colors.white),
                label: Text(
                  _isSaving ? 'Guardando...' : 'Guardar Recompensa',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _saveReward,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
