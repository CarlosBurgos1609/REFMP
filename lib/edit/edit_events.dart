// ignore_for_file: unused_local_variable

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/theme/theme_provider.dart';

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
  DateTime? selectedEndDateTime;
  List<String> selectedSedes = [];

  List<Map<String, dynamic>> sedes = [];

  @override
  void initState() {
    super.initState();
    nameController.text = widget.event['name'] ?? '';
    locationController.text = widget.event['location'] ?? '';
    selectedDateTime = DateTime.tryParse(widget.event['start_datetime'] ?? '');
    selectedEndDateTime = DateTime.tryParse(widget.event['end_datetime'] ?? '');
    fetchSedes();
  }

  Future<void> fetchSedes() async {
    final sedeResponse = await supabase.from('sedes').select();
    final sedeList = List<Map<String, dynamic>>.from(sedeResponse);

    final eventSedeResponse = await supabase
        .from('events_headquarters')
        .select('sede_id')
        .eq('event_id', widget.event['id']);

    List<String> preSelectedSedes = [];
    for (var eventSede in eventSedeResponse) {
      final sedeId = eventSede['sede_id'];
      final sede =
          sedeList.firstWhere((sede) => sede['id'] == sedeId, orElse: () => {});
      if (sede.isNotEmpty) {
        preSelectedSedes.add(sede['name']);
      }
    }

    setState(() {
      sedes = sedeList;
      selectedSedes = preSelectedSedes;
    });
  }

  Future<void> updateEvent() async {
    if (_formKey.currentState!.validate() &&
        selectedDateTime != null &&
        selectedEndDateTime != null &&
        selectedSedes.isNotEmpty) {
      final selectedSedeIds = selectedSedes.map((sedeName) {
        return sedes.firstWhere((sede) => sede['name'] == sedeName)['id']
            as int;
      }).toList();

      await supabase.from('events').update({
        'name': nameController.text,
        'date': selectedDateTime!.toIso8601String(),
        'time': DateFormat.Hm().format(selectedDateTime!),
        'time_fin': DateFormat.Hm().format(selectedEndDateTime!),
        'location': locationController.text,
        'month': selectedDateTime!.month,
        'year': selectedDateTime!.year,
        'start_datetime': selectedDateTime!.toIso8601String(),
        'end_datetime': selectedEndDateTime!.toIso8601String(),
      }).eq('id', widget.event['id']);

      await supabase
          .from('events_headquarters')
          .delete()
          .eq('event_id', widget.event['id']);

      for (var sedeId in selectedSedeIds) {
        await supabase.from('events_headquarters').insert({
          'event_id': widget.event['id'],
          'sede_id': sedeId,
        });
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
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
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
    final themeProvider = Provider.of<ThemeProvider>(context);
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
              MultiSelectDialogField(
                items: sedes
                    .map((sede) =>
                        MultiSelectItem<String>(sede['name'], sede['name']))
                    .toList(),
                initialValue: selectedSedes,
                title: const Text(
                  "Selecciona las sedes",
                  style: TextStyle(
                      color: Colors.blue, fontWeight: FontWeight.bold),
                ),
                selectedColor: Colors.blue,
                itemsTextStyle: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
                selectedItemsTextStyle: TextStyle(
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
                decoration: BoxDecoration(
                  color: themeProvider.isDarkMode
                      ? Colors.transparent
                      : Colors.transparent,
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: Colors.blue,
                    width: 1,
                  ),
                ),
                buttonIcon: const Icon(
                  Icons.location_city,
                  color: Colors.blue,
                ),
                buttonText: const Text(
                  "Selecciona las sedes",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                onConfirm: (values) {
                  setState(() {
                    selectedSedes = values.cast<String>();
                  });
                },
                validator: (values) {
                  if (values == null || values.isEmpty) {
                    return "Selecciona al menos una sede";
                  }
                  return null;
                },
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
                  style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.blue),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedDateTime ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: themeProvider.isDarkMode
                            ? ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.grey[900],
                              )
                            : ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.blue,
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
                      initialTime: TimeOfDay.fromDateTime(
                          selectedDateTime ?? DateTime.now()),
                      builder: (context, child) {
                        return Theme(
                          data: themeProvider.isDarkMode
                              ? ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.white,
                                  ),
                                  timePickerTheme: TimePickerThemeData(
                                    dayPeriodShape:
                                        const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                    ),
                                    dayPeriodColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.blueAccent;
                                      }
                                      return Colors.transparent;
                                    }),
                                    dayPeriodTextColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.white;
                                      }
                                      return Colors.grey;
                                    }),
                                    backgroundColor: Colors.grey[900],
                                  ),
                                )
                              : ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.blue,
                                  ),
                                  timePickerTheme: TimePickerThemeData(
                                    dayPeriodShape:
                                        const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                    ),
                                    dayPeriodColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.blueAccent;
                                      }
                                      return Colors.transparent;
                                    }),
                                    dayPeriodTextColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.white;
                                      }
                                      return Colors.grey;
                                    }),
                                    backgroundColor: Colors.white,
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
                leading: const Icon(Icons.access_time, color: Colors.blue),
                title: Text(
                  selectedEndDateTime != null
                      ? DateFormat('dd/MM/yyyy – hh:mm a')
                          .format(selectedEndDateTime!)
                      : 'Seleccionar fecha y hora de fin',
                  style: TextStyle(
                      color: themeProvider.isDarkMode
                          ? Colors.white
                          : Colors.blue),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: selectedEndDateTime ??
                        selectedDateTime ??
                        DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime(2100),
                    builder: (context, child) {
                      return Theme(
                        data: themeProvider.isDarkMode
                            ? ThemeData.dark().copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.white,
                                ),
                                dialogBackgroundColor: Colors.grey[900],
                              )
                            : ThemeData.light().copyWith(
                                colorScheme: const ColorScheme.light(
                                  primary: Colors.blue,
                                  onPrimary: Colors.white,
                                  onSurface: Colors.blue,
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
                      initialTime: TimeOfDay.fromDateTime(
                          selectedEndDateTime ?? DateTime.now()),
                      builder: (context, child) {
                        return Theme(
                          data: themeProvider.isDarkMode
                              ? ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.white,
                                  ),
                                  timePickerTheme: TimePickerThemeData(
                                    dayPeriodShape:
                                        const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                    ),
                                    dayPeriodColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.blueAccent;
                                      }
                                      return Colors.transparent;
                                    }),
                                    dayPeriodTextColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.white;
                                      }
                                      return Colors.grey;
                                    }),
                                    backgroundColor: Colors.grey[900],
                                  ),
                                )
                              : ThemeData.light().copyWith(
                                  colorScheme: const ColorScheme.light(
                                    primary: Colors.blue,
                                    onPrimary: Colors.white,
                                    onSurface: Colors.blue,
                                  ),
                                  timePickerTheme: TimePickerThemeData(
                                    dayPeriodShape:
                                        const RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                    ),
                                    dayPeriodColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.blueAccent;
                                      }
                                      return Colors.transparent;
                                    }),
                                    dayPeriodTextColor:
                                        MaterialStateColor.resolveWith(
                                            (states) {
                                      if (states
                                          .contains(MaterialState.selected)) {
                                        return Colors.white;
                                      }
                                      return Colors.grey;
                                    }),
                                    backgroundColor: Colors.white,
                                  ),
                                ),
                          child: child!,
                        );
                      },
                    );

                    if (time != null) {
                      setState(() {
                        selectedEndDateTime = DateTime(
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
