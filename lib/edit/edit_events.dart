// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refmp/interfaces/menu/events.dart';

class EditEventForm extends StatefulWidget {
  final Map<String, dynamic> event;
  const EditEventForm({Key? key, required this.event}) : super(key: key);

  @override
  _EditEventFormState createState() => _EditEventFormState();
}

class _EditEventFormState extends State<EditEventForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  TextEditingController nameController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  DateTime? selectedDateTime;
  TimeOfDay? endTime;
  String? selectedSede;

  List<Map<String, dynamic>> sedes = [];

  @override
  void initState() {
    super.initState();
    nameController.text = widget.event['name'] ?? '';
    locationController.text = widget.event['location'] ?? '';
    selectedDateTime = DateTime.tryParse(widget.event['date'] ?? '');

    // Obtener la hora de fin (asegurándonos de que esté en el formato correcto)
    final timeFin = widget.event['time_fin'];
    if (timeFin != null && timeFin is String) {
      final parts = timeFin.split(":");
      if (parts.length == 2) {
        setState(() {
          endTime = TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 0,
            minute: int.tryParse(parts[1]) ?? 0,
          );
        });
      }
    }
    fetchSedes();
  }

  Future<void> fetchSedes() async {
    final sedeResponse = await supabase.from('sedes').select();
    final sedeList = List<Map<String, dynamic>>.from(sedeResponse);

    final eventSedeResponse = await supabase
        .from('events_headquarters')
        .select('sede_id')
        .eq('event_id', widget.event['id']);

    int? sedeId = eventSedeResponse.isNotEmpty
        ? eventSedeResponse.first['sede_id']
        : null;

    setState(() {
      sedes = sedeList;
      selectedSede = sedeList.firstWhere((sede) => sede['id'] == sedeId,
          orElse: () => {})['name'];
    });
  }

  Future<void> updateEvent() async {
    if (_formKey.currentState!.validate() &&
        selectedDateTime != null &&
        endTime != null &&
        selectedSede != null) {
      final selectedSedeId =
          sedes.firstWhere((sede) => sede['name'] == selectedSede)['id'] as int;

      final date = selectedDateTime!;
      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        endTime!.hour,
        endTime!.minute,
      );

      await supabase.from('events').update({
        'name': nameController.text,
        'date': date.toIso8601String(),
        'time': DateFormat.Hm().format(date),
        'time_fin':
            '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
        'location': locationController.text,
        'month': date.month,
        'year': date.year,
        'start_datetime': date.toIso8601String(),
        'end_datetime': endDateTime.toIso8601String(),
      }).eq('id', widget.event['id']);

      // Actualizar relación en events_headquarters
      final existingRelation = await supabase
          .from('events_headquarters')
          .select()
          .eq('event_id', widget.event['id']);

      if (existingRelation.isEmpty) {
        await supabase.from('events_headquarters').insert({
          'event_id': widget.event['id'],
          'sede_id': selectedSedeId,
        });
      } else {
        await supabase.from('events_headquarters').update(
            {'sede_id': selectedSedeId}).eq('event_id', widget.event['id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento actualizado con éxito')),
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const EventsPage(title: 'Eventos')),
      );
    }
  }

  void cancelEdit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const EventsPage(title: 'Eventos')),
    );
  }

  InputDecoration customInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle:
          const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
      enabledBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: Colors.blue, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
      prefixIcon: Icon(
        icon,
        color: Colors.blue,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: cancelEdit,
        ),
        title: const Text(
          'Editar Evento',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const SizedBox(height: 10),
              widget.event['image'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        children: [
                          Image.network(
                            widget.event['image'],
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              color: Colors.black54,
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: const Text(
                                'La imagen no se puede editar',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          )
                        ],
                      ),
                    )
                  : Container(
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'No hay imagen disponible',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration:
                    customInputDecoration('Nombre del evento', Icons.event),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSede,
                decoration: customInputDecoration(
                    'Selecciona la sede', Icons.location_city),
                items: sedes.map((sede) {
                  return DropdownMenuItem<String>(
                    value: sede['name'],
                    child: Text(sede['name']),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedSede = value;
                  });
                },
                validator: (value) =>
                    value == null ? 'Selecciona una sede' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: locationController,
                decoration:
                    customInputDecoration('Ubicación del evento', Icons.place),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una ubicación' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.calendar_month, color: Colors.blue),
                title: Text(
                  selectedDateTime != null
                      ? DateFormat('dd/MM/yyyy – hh:mm a')
                          .format(selectedDateTime!)
                      : 'Seleccionar fecha y hora de inicio',
                  style: const TextStyle(color: Colors.blue),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                  );

                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.fromDateTime(
                          selectedDateTime ?? DateTime.now()),
                    );

                    if (time != null) {
                      setState(() {
                        selectedDateTime = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        );
                      });
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: Text(
                  endTime != null
                      ? '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}'
                      : 'Seleccionar hora de fin',
                  style: const TextStyle(color: Colors.blue),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: endTime ?? TimeOfDay.now(),
                  );

                  if (picked != null) {
                    setState(() {
                      endTime = picked;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.save, color: Colors.blue),
                      label: const Text('Guardar Cambios',
                          style: TextStyle(color: Colors.blue)),
                      onPressed: updateEvent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text('Cancelar',
                          style: TextStyle(color: Colors.red)),
                      onPressed: cancelEdit,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
