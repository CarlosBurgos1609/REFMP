// ignore_for_file: unused_local_variable

import 'dart:io';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:provider/provider.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:refmp/widgets/location_picker.dart';
import 'package:refmp/services/notification_service.dart';

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
  TextEditingController ubicationUrlController = TextEditingController();
  DateTime? selectedDateTime;
  TimeOfDay? endTime;
  List<String> selectedSedes = [];
  File? imageFile;
  bool _isSaving = false; // Prevenir doble guardado

  List<Map<String, dynamic>> sedes = [];

  @override
  void initState() {
    super.initState();
    fetchSedes();
  }

  Future<void> fetchSedes() async {
    final response =
        await Supabase.instance.client.from('sedes').select('id, name');

    setState(() {
      sedes = response;
    });
  }

  Future<void> pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final tempDir = Directory.systemTemp;

      // Generar nombre con extensión .jpg siempre
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final compressedFilePath = '${tempDir.path}/compressed_$timestamp.jpg';

      final compressedImage = await FlutterImageCompress.compressAndGetFile(
        picked.path,
        compressedFilePath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
        format: CompressFormat.jpeg, // Asegurar formato JPEG
      );

      if (compressedImage != null) {
        setState(() {
          imageFile = File(compressedImage.path);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al comprimir la imagen')),
        );
      }
    }
  }

  Future<void> saveEvent() async {
    // Prevenir doble guardado
    if (_isSaving) {
      debugPrint('⚠️ Ya se está guardando el evento, ignorando doble clic');
      return;
    }

    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo obtener el usuario actual')),
      );
      return;
    }
    final userId = currentUser.id;

    if (!_formKey.currentState!.validate()) return;

    if (imageFile == null ||
        selectedDateTime == null ||
        endTime == null ||
        selectedSedes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Completa todos los campos requeridos')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final uuid = DateTime.now().millisecondsSinceEpoch;
    final cleanName =
        removeDiacritics(nameController.text.trim().replaceAll(" ", "_"));
    final filename = 'event_${uuid}_$cleanName.jpg';

    try {
      final storagePath = 'event_images/$filename';
      await supabase.storage.from('Events').upload(storagePath, imageFile!);

      final imageUrl =
          supabase.storage.from('Events').getPublicUrl(storagePath);

      final date = selectedDateTime!;
      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        endTime!.hour,
        endTime!.minute,
      );

      final response = await supabase
          .from('events')
          .insert({
            'name': nameController.text,
            'date': date.toIso8601String(),
            'time': DateFormat.Hm().format(date),
            'time_fin':
                '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
            'location': locationController.text,
            'ubication_url': ubicationUrlController.text,
            'image': imageUrl,
            'month': date.month,
            'year': date.year,
            'start_datetime': date.toIso8601String(),
            'end_datetime': endDateTime.toIso8601String(),
          })
          .select()
          .single();

      final eventId = response['id'];

      final selectedSedeIds = selectedSedes.map((sedeName) {
        final match = sedes.firstWhere((s) => s['name'] == sedeName);
        return match['id'];
      }).toList();

      for (var sedeId in selectedSedeIds) {
        await supabase.from('events_headquarters').insert({
          'event_id': eventId,
          'sede_id': sedeId,
        });
      }

      // Crear notificación para todos los usuarios
      try {
        final notifResponse = await supabase
            .from('notifications')
            .insert({
              'title': '🎉📅 Nuevo Evento ‼️: ${nameController.text}',
              'message':
                  'Se creó nuevo evento para el día ${DateFormat('dd/MM/yyyy').format(date)}. Da clic al evento para ver más detalles',
              'icon': 'event',
              'redirect_to': '/events?eventId=$eventId',
              'image': imageUrl,
            })
            .select()
            .single();

        debugPrint('📩 Notificación creada: ${notifResponse['id']}');

        // Enviar notificaciones push a todos los usuarios
        if (notifResponse['id'] != null) {
          final notifId = notifResponse['id'] is int
              ? notifResponse['id'] as int
              : int.tryParse(notifResponse['id'].toString()) ?? 0;

          if (notifId > 0) {
            await NotificationService.sendNotificationToAllUsers(notifId);
            debugPrint('✅ Notificaciones push enviadas');
          }
        }
      } catch (notifError) {
        debugPrint('⚠️ Error al enviar notificaciones: $notifError');
        // Continuar aunque falle la notificación
      }

      debugPrint('✅ Evento creado exitosamente: $eventId');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Evento guardado con éxito')),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => const EventsPage(title: 'Eventos'),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error al guardar evento: $e');

      if (mounted) {
        setState(() {
          _isSaving = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar el evento: $e')),
        );
      }
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

  // Método para abrir Google Maps y obtener el link
  Future<void> _openGoogleMaps() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const GoogleMapsWebViewScreen(),
      ),
    );

    if (result != null && result['url'] != null) {
      setState(() {
        ubicationUrlController.text = result['url'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: imageFile != null
                      ? LayoutBuilder(
                          builder: (context, constraints) {
                            return FutureBuilder<Size>(
                              future: _getImageSize(imageFile!),
                              builder: (context, snapshot) {
                                if (snapshot.hasData) {
                                  final imageSize = snapshot.data!;
                                  final containerWidth = constraints.maxWidth;
                                  final maxHeight =
                                      500.0; // Maximum height limit
                                  final imageAspectRatio =
                                      imageSize.width / imageSize.height;
                                  final containerAspectRatio =
                                      containerWidth / maxHeight;

                                  // Use BoxFit.cover if image is too large, else BoxFit.contain
                                  final fit = (imageSize.height > maxHeight ||
                                          imageSize.width > containerWidth ||
                                          imageAspectRatio >
                                              containerAspectRatio)
                                      ? BoxFit.cover
                                      : BoxFit.contain;

                                  return ConstrainedBox(
                                    constraints: BoxConstraints(
                                      maxHeight: maxHeight,
                                      maxWidth: containerWidth,
                                    ),
                                    child: AspectRatio(
                                      aspectRatio: imageAspectRatio,
                                      child: Image.file(
                                        imageFile!,
                                        fit: fit,
                                        width:
                                            containerWidth, // Match container width
                                      ),
                                    ),
                                  );
                                } else {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                            );
                          },
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
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: customInputDecoration(
                  'Nombre del evento',
                  Icons.event,
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa un nombre' : null,
              ),
              const SizedBox(height: 16),
              MultiSelectDialogField(
                items: sedes
                    .map((sede) =>
                        MultiSelectItem<String>(sede['name'], sede['name']))
                    .toList(),
                title: Text(
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
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                  border: Border.all(
                    color: Colors.blue,
                    width: 1,
                  ),
                ),
                buttonIcon: Icon(
                  Icons.location_city,
                  color: Colors.blue,
                ),
                buttonText: Text(
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
                textCapitalization: TextCapitalization.words,
                decoration: customInputDecoration(
                  'Ubicación del evento',
                  Icons.place,
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Ingresa una ubicación' : null,
              ),
              const SizedBox(height: 16),
              // Campo de ubicación con Google Maps
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blue, width: 1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.map, color: Colors.blue),
                      title: Text(
                        ubicationUrlController.text.isNotEmpty
                            ? 'Link de Google Maps configurado'
                            : 'Seleccionar ubicación en Google Maps',
                        style: TextStyle(
                          color: ubicationUrlController.text.isNotEmpty
                              ? Colors.white
                              : Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: ubicationUrlController.text.isNotEmpty
                          ? Text(
                              ubicationUrlController.text,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      trailing:
                          const Icon(Icons.chevron_right, color: Colors.blue),
                      onTap: _openGoogleMaps,
                    ),
                    Padding(
                      padding:
                          const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                      child: ElevatedButton.icon(
                        onPressed: _openGoogleMaps,
                        icon: const Icon(Icons.add_location_alt),
                        label: Text(
                          ubicationUrlController.text.isNotEmpty
                              ? 'Cambiar ubicación'
                              : 'Abrir Google Maps',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                  style: const TextStyle(color: Colors.blue),
                ),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
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
                leading: const Icon(
                  Icons.access_time,
                  color: Colors.blue,
                ),
                title: Text(
                  endTime != null
                      ? endTime!.format(context)
                      : 'Seleccionar hora de fin',
                  style: const TextStyle(color: Colors.blue),
                ),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.light().copyWith(
                          colorScheme: const ColorScheme.light(
                            primary: Colors.blue,
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
                                return Colors.blueAccent;
                              }
                              return Colors.transparent;
                            }),
                            dayPeriodTextColor:
                                MaterialStateColor.resolveWith((states) {
                              if (states.contains(MaterialState.selected)) {
                                return Colors.white;
                              }
                              return Colors.grey;
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
                        _isSaving ? 'Guardando...' : 'Guardar Evento',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _isSaving ? null : saveEvent,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      label: const Text(
                        'Cancelar',
                        style: TextStyle(color: Colors.red),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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

  // Helper method to get image size
  Future<Size> _getImageSize(File imageFile) async {
    final image = await decodeImageFromList(await imageFile.readAsBytes());
    return Size(image.width.toDouble(), image.height.toDouble());
  }
}
