import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditRewardPage extends StatefulWidget {
  final Map<String, dynamic> reward;

  const EditRewardPage({super.key, required this.reward});

  @override
  State<EditRewardPage> createState() => _EditRewardPageState();
}

class _EditRewardPageState extends State<EditRewardPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final SupabaseClient _supabase = Supabase.instance.client;

  final TextEditingController _positionController = TextEditingController();
  final TextEditingController _coinsController = TextEditingController();

  DateTime? _weekStart;
  DateTime? _weekEnd;
  bool _isSaving = false;
  List<Map<String, dynamic>> _objects = <Map<String, dynamic>>[];
  int? _selectedObjectId;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    _loadInitialValues();
    _loadObjects();
  }

  @override
  void dispose() {
    _positionController.dispose();
    _coinsController.dispose();
    super.dispose();
  }

  int? _toInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  DateTime? _toDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  String _formatDate(DateTime value) {
    return DateFormat('yyyy-MM-dd').format(value);
  }

  void _loadInitialValues() {
    final reward = widget.reward;
    _positionController.text = (reward['position'] ?? '').toString();
    _coinsController.text = (reward['coins_reward'] ?? 0).toString();
    _selectedObjectId = _toInt(reward['object_id']);
    _weekStart = _toDate(reward['week_start']);
    _weekEnd = _toDate(reward['week_end']);
    _claimed = reward['claimed'] == true;
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
      debugPrint('Error loading objects for edit rewards: $e');
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
      } else {
        _weekEnd = DateTime(picked.year, picked.month, picked.day);
      }
    });
  }

  Future<void> _updateReward() async {
    if (!_formKey.currentState!.validate()) return;

    final rewardId = _toInt(widget.reward['id']);
    if (rewardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el id de la recompensa.')),
      );
      return;
    }

    final position = _toInt(_positionController.text.trim());
    final coins = _toInt(_coinsController.text.trim()) ?? 0;

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
      await _supabase.from('rewards').update({
        'position': position,
        'object_id': _selectedObjectId,
        'coins_reward': coins,
        'claimed': _claimed,
        'week_start': _formatDate(_weekStart!),
        'week_end': _formatDate(_weekEnd!),
      }).eq('id', rewardId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensa actualizada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error updating reward: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al editar recompensa: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deleteReward() async {
    final rewardId = _toInt(widget.reward['id']);
    if (rewardId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se encontró el id de la recompensa.')),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar recompensa'),
        content: const Text(
          '¿Estás seguro de eliminar esta recompensa? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await _supabase.from('rewards').delete().eq('id', rewardId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recompensa eliminada correctamente.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint('Error deleting reward: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al eliminar recompensa: $e')),
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
    final Map<int, Map<String, dynamic>> uniqueObjectsById =
        <int, Map<String, dynamic>>{};
    for (final item in _objects) {
      final id = _toInt(item['id']);
      if (id == null) continue;
      uniqueObjectsById[id] = item;
    }
    final uniqueObjects = uniqueObjectsById.values.toList();

    final hasSelectedObject = _selectedObjectId != null &&
        uniqueObjectsById.containsKey(_selectedObjectId);
    final int? dropdownValue = hasSelectedObject ? _selectedObjectId : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Editar Recompensa',
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
                value: dropdownValue,
                decoration:
                    _inputDecoration('Objeto (opcional)', Icons.card_giftcard),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin objeto'),
                  ),
                  ...uniqueObjects.map(
                    (item) => DropdownMenuItem<int?>(
                      value: _toInt(item['id']),
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
              const SizedBox(height: 8),
              SwitchListTile(
                value: _claimed,
                title: const Text('Marcar como reclamada'),
                activeColor: Colors.blue,
                onChanged: _isSaving
                    ? null
                    : (value) {
                        setState(() {
                          _claimed = value;
                        });
                      },
              ),
              const SizedBox(height: 8),
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
                  _isSaving ? 'Guardando...' : 'Guardar Cambios',
                  style: const TextStyle(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _updateReward,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(Icons.delete, color: Colors.red),
                label: const Text(
                  'Eliminar recompensa',
                  style: TextStyle(color: Colors.red),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isSaving ? null : _deleteReward,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
