// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEventForm extends StatefulWidget {
  const AddEventForm({Key? key}) : super(key: key);

  @override
  _AddEventFormState createState() => _AddEventFormState();
}

class _AddEventFormState extends State<AddEventForm> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  TextEditingController nameController = TextEditingController();
  TextEditingController locationController = TextEditingController();
  DateTime? selectedDateTime;
  TimeOfDay? endTime;
  String? selectedSede;
  File? imageFile;

  List<Map<String, dynamic>> sedes = [];

  @override
  void initState() {
    super.initState();
    fetchSedes();
  }

  Future<void> fetchSedes() async {
    final response = await supabase.from('sedes').select();
    setState(() {
      sedes = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<void> saveEvent() async {
    if (_formKey.currentState!.validate() &&
        selectedDateTime != null &&
        endTime != null &&
        selectedSede != null &&
        imageFile != null) {
      final filename = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      final storageResponse = await supabase.storage
          .from('Events')
          .upload('event_images/$filename', imageFile!);

      final imageUrl = supabase.storage
          .from('Events')
          .getPublicUrl('event_images/$filename');

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

      await supabase.from('events').insert({
        'name': nameController.text,
        'date': date.toIso8601String(),
        'time': DateFormat.Hm().format(date),
        'time_fin':
            '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
        'location': locationController.text,
        'image': imageUrl,
        'month': date.month,
        'year': date.year,
        'sede_id': selectedSedeId,
        'start_datetime': date.toIso8601String(),
        'end_datetime': endDateTime.toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento guardado con éxito')),
        );
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const EventsPage(
                  title: 'Eventos',
                )),
      );
    }
  }

  void cancelEvent() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => const EventsPage(
                title: 'Eventos',
              )),
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
          onPressed: cancelEvent,
        ),
        title: const Text(
          'Agregar Evento',
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
              GestureDetector(
                onTap: pickImage,
                child: imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(imageFile!,
                            height: 200, fit: BoxFit.cover),
                      )
                    : Container(
                        height: 200,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text(
                            'Seleccionar Imagen',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: customInputDecoration(
                  'Nombre del evento',
                  Icons.event, // ícono dinámico
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedSede,
                decoration: customInputDecoration(
                  'Selecciona la sede',
                  Icons.location_city, // ícono dinámico
                ),
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
                decoration: customInputDecoration(
                  'Ubicación del evento',
                  Icons.place, // ícono dinámico
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una ubicación' : null,
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(
                  Icons.calendar_month,
                  color: Colors.blue,
                ),
                title: Text(
                  selectedDateTime != null
                      ? DateFormat('dd/MM/yyyy – hh:mm a')
                          .format(selectedDateTime!)
                      : 'Seleccionar fecha y hora de inicio',
                  style: const TextStyle(color: Colors.blue), // ← texto azul
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors
                                .blue, // ← color de encabezado, botón "OK"
                            onPrimary: Colors.white, // ← texto sobre fondo azul
                            onSurface: Colors.blue, // ← texto del calendario
                          ),
                          dialogBackgroundColor: Colors.white,
                        ),
                        child: child!,
                      );
                    },
                  );

                  if (date != null) {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                      builder: (context, child) {
                        return Theme(
                          data: ThemeData.light().copyWith(
                            colorScheme: const ColorScheme.light(
                              primary:
                                  Colors.blue, // color del reloj y botón OK
                              onPrimary: Colors.white,
                              onSurface: Colors.blue,
                            ),
                            timePickerTheme: TimePickerThemeData(
                              dayPeriodShape: const RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.all(Radius.circular(8)),
                              ),
                              dayPeriodColor:
                                  MaterialStateColor.resolveWith((states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors
                                      .greenAccent; // fondo AM/PM seleccionado
                                }
                                return Colors
                                    .transparent; // fondo AM/PM no seleccionado
                              }),
                              dayPeriodTextColor:
                                  MaterialStateColor.resolveWith((states) {
                                if (states.contains(MaterialState.selected)) {
                                  return Colors
                                      .white; // texto AM/PM seleccionado
                                }
                                return Colors
                                    .grey; // texto AM/PM no seleccionado
                              }),
                            ),
                          ),
                          child: child!,
                        );
                      },
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
                leading: const Icon(
                  Icons.access_time,
                  color: Colors.blue,
                ),
                title: Text(
                  endTime != null
                      ? endTime!.format(context)
                      : 'Seleccionar hora de fin',
                  style: const TextStyle(color: Colors.blue), // ← texto azul
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.blue, // color del reloj y botón OK
                            onPrimary: Colors.white,
                            onSurface: Colors.blue,
                          ),
                          timePickerTheme: TimePickerThemeData(
                            dayPeriodShape: const RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.all(Radius.circular(8)),
                            ),
                            dayPeriodColor:
                                MaterialStateColor.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors
                                    .greenAccent; // fondo AM/PM seleccionado
                              }
                              return Colors
                                  .transparent; // fondo AM/PM no seleccionado
                            }),
                            dayPeriodTextColor:
                                MaterialStateColor.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.white; // texto AM/PM seleccionado
                              }
                              return Colors.grey; // texto AM/PM no seleccionado
                            }),
                          ),
                        ),
                        child: child!,
                      );
                    },
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
                      icon: const Icon(
                        Icons.save,
                        color: Colors.blue,
                      ),
                      label: const Text(
                        'Guardar Evento',
                        style: TextStyle(color: Colors.blue),
                      ),
                      onPressed: saveEvent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.cancel,
                        color: Colors.red,
                      ),
                      label: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.red),
                      ),
                      onPressed: cancelEvent,
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
