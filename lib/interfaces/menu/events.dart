import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/edit/edit_events.dart';
import 'package:refmp/forms/eventsForm.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:url_launcher/url_launcher.dart';

// Custom cache manager for images
final customCacheManager = CacheManager(
  Config(
    'eventsImageCache',
    stalePeriod: const Duration(days: 30),
    maxNrOfCacheObjects: 100,
  ),
);

// Map of month names to image paths
const Map<String, String> monthImages = {
  'enero': 'assets/images/enero.png',
  'febrero': 'assets/images/febrero.png',
  'marzo': 'assets/images/marzo.png',
  'abril': 'assets/images/abril.png',
  'mayo': 'assets/images/mayo.png',
  'junio': 'assets/images/junio.png',
  'julio': 'assets/images/julio.png',
  'agosto': 'assets/images/agosto.png',
  'septiembre': 'assets/images/septiembre.png',
  'octubre': 'assets/images/octubre.png',
  'noviembre': 'assets/images/noviembre.png',
  'diciembre': 'assets/images/diciembre.png',
};

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.title});
  final String title;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  List<Appointment> _appointments = [];
  List<Map<String, dynamic>> _eventDetails = [];
  late CalendarController _calendarController;
  DateTime _focusedDate = DateTime.now();
  CalendarView _calendarView = CalendarView.month;
  File? eventImage;
  bool _isOnline = false;
  late Box _hiveBox;

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _calendarController.view = _calendarView;
    initializeDateFormatting('es_ES', null).then((_) {
      setState(() {});
    });
    Hive.openBox('offline_data').then((box) {
      _hiveBox = box;
      fetchEvents();
    });
  }

  @override
  void dispose() {
    _calendarController.dispose();
    super.dispose();
  }

  Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      return false;
    }
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      debugPrint('Error en verificación de internet: $e');
      return false;
    }
  }

  Future<String?> uploadImage(File imageFile) async {
    try {
      final fileName =
          'events_images/event_${DateTime.now().millisecondsSinceEpoch}.png';
      await supabase.storage.from('Events').upload(fileName, imageFile);
      final imageUrl = supabase.storage.from('Events').getPublicUrl(fileName);
      return imageUrl;
    } catch (error) {
      debugPrint('Error al subir la imagen: $error');
      return null;
    }
  }

  Future<void> fetchEvents() async {
    const cacheKey = 'events_data';

    _isOnline = await isOnline();

    List<dynamic> response;

    if (_isOnline) {
      try {
        response = await supabase
            .from('events')
            .select(
                '*, events_headquarters(*, sedes(id,name, photo)),ubication_url')
            .order('date', ascending: false);

        await _hiveBox.put(cacheKey, response);
        debugPrint('Eventos obtenidos ONLINE: ${response.length}');
      } catch (e) {
        debugPrint('Error al obtener eventos desde Supabase: $e');
        response = _hiveBox.get(cacheKey, defaultValue: []) ?? [];
        debugPrint('Cargados ${response.length} eventos desde cache');
      }
    } else {
      debugPrint('Sin conexión, usando cache');
      response = _hiveBox.get(cacheKey, defaultValue: []) ?? [];
      debugPrint('Cargados ${response.length} eventos desde cache');
    }

    List<Appointment> appointments = [];
    List<Map<String, dynamic>> eventDetails = [];

    await Future.wait(response.asMap().entries.map((entry) async {
      final i = entry.key;
      final event = entry.value;
      try {
        final rawDate = event['date'];
        if (rawDate == null) return;

        DateTime startDateTime = DateTime.parse(rawDate);
        DateTime endDateTime;
        final rawTimeFin = event['time_fin'];

        if (rawTimeFin != null && rawTimeFin.toString().isNotEmpty) {
          final dateOnly = DateTime(
              startDateTime.year, startDateTime.month, startDateTime.day);
          final parts = rawTimeFin.toString().split(":");
          endDateTime = DateTime(
            dateOnly.year,
            dateOnly.month,
            dateOnly.day,
            int.parse(parts[0]),
            int.parse(parts[1]),
          );
        } else {
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }

        if (endDateTime.isBefore(startDateTime)) {
          endDateTime = startDateTime.add(const Duration(hours: 1));
        }

        appointments.add(Appointment(
          startTime: startDateTime,
          endTime: endDateTime,
          subject: event['name'] ?? 'Evento sin nombre',
          notes: i.toString(),
          color: Colors.green,
        ));

        eventDetails.add({
          'id': event['id'],
          'name': event['name'] ?? 'Evento sin nombre',
          'date': event['date'],
          'time': event['time'] ?? 'No especificada',
          'time_fin': event['time_fin'] ?? 'No especificada',
          'location': event['location'] ?? 'No especificada',
          'ubication_url': event['ubication_url'] ?? '', // Added ubication_url
          'image': event['image'],
          'events_headquarters': event['events_headquarters'] ?? [],
        });
      } catch (e) {
        debugPrint("Error procesando evento: $e");
      }
    }));

    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _eventDetails = eventDetails;
    });
  }

  Future<bool> _canAddEvent() async {
    if (!_isOnline) return false;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final futures = await Future.wait([
      supabase.from('users').select().eq('user_id', userId).maybeSingle(),
      supabase.from('teachers').select().eq('user_id', userId).maybeSingle(),
      supabase.from('advisors').select().eq('user_id', userId).maybeSingle(),
    ]);

    return futures.any((result) => result != null);
  }

  Future<bool> _canDeleteEvent(int eventId) async {
    if (!_isOnline) return false;

    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return false;

    final futures = await Future.wait([
      supabase.from('users').select().eq('user_id', userId).maybeSingle(),
      supabase.from('teachers').select().eq('user_id', userId).maybeSingle(),
      supabase.from('advisors').select().eq('user_id', userId).maybeSingle(),
    ]);

    return futures.any((result) => result != null);
  }

  Future<void> _deleteEvent(
      Map<String, dynamic> event, BuildContext context) async {
    try {
      await supabase.from('events').delete().eq('id', event['id']);

      final imageUrl = event['image'];
      if (imageUrl != null && imageUrl.isNotEmpty) {
        final imageName = imageUrl.split('/').last;
        await supabase.storage
            .from('Events')
            .remove(['events_images/$imageName']);
        await customCacheManager.removeFile(imageUrl);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Evento eliminado correctamente'),
            backgroundColor: Colors.green,
          ),
        );

        await fetchEvents();
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error eliminando evento: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al eliminar el evento: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _goToPreviousMonth() {
    final newDate =
        DateTime(_focusedDate.year, _focusedDate.month - 1, _focusedDate.day);
    if (newDate.isBefore(DateTime(2025, 1, 1))) return;
    _calendarController.displayDate = newDate;
    setState(() {
      _focusedDate = newDate;
    });
  }

  void _launchGoogleMaps(String? ubication) async {
    if (ubication == null || ubication.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación no disponible')),
      );
      return;
    }
    final uri = Uri.parse(ubication);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir Google Maps')),
      );
    }
  }

  void _goToNextMonth() {
    final newDate =
        DateTime(_focusedDate.year, _focusedDate.month + 1, _focusedDate.day);
    _calendarController.displayDate = newDate;
    setState(() {
      _focusedDate = newDate;
    });
  }

  void _toggleCalendarView() {
    setState(() {
      _calendarView = _calendarView == CalendarView.month
          ? CalendarView.schedule
          : CalendarView.month;
      _calendarController.view = _calendarView;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final monthName = DateFormat.yMMMM('es_ES').format(_focusedDate);

    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 22,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: Colors.blue,
          leading: Builder(
            builder: (context) {
              return IconButton(
                icon: const Icon(Icons.menu, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
          centerTitle: true,
        ),
        drawer: Menu.buildDrawer(context),
        body: RefreshIndicator(
          onRefresh: fetchEvents,
          color: Colors.blue,
          child: Column(
            children: [
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      monthName[0].toUpperCase() + monthName.substring(1),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.isDarkMode
                            ? const Color.fromARGB(255, 255, 255, 255)
                            : const Color.fromARGB(255, 33, 150, 243),
                      ),
                    ),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _goToPreviousMonth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Icon(Icons.arrow_back_ios_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _goToNextMonth,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Icon(Icons.arrow_forward_ios_rounded,
                              color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _toggleCalendarView,
                    icon: const Icon(Icons.swap_horiz, color: Colors.white),
                    label: Text(
                      _calendarView == CalendarView.month
                          ? 'Cambiar a Agenda'
                          : 'Cambiar a Calendario',
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SfCalendar(
                  controller: _calendarController,
                  view: _calendarView,
                  dataSource: EventDataSource(_appointments),
                  minDate: DateTime(2025, 1, 1),
                  todayHighlightColor: Colors.blue,
                  selectionDecoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(6),
                    color: Colors.transparent,
                  ),
                  monthViewSettings: MonthViewSettings(
                    appointmentDisplayMode:
                        MonthAppointmentDisplayMode.indicator,
                    showAgenda: true,
                    monthCellStyle: MonthCellStyle(
                      textStyle: TextStyle(
                        color: themeProvider.isDarkMode
                            ? const Color.fromARGB(255, 236, 234, 234)
                            : Colors.black,
                      ),
                    ),
                    navigationDirection: MonthNavigationDirection.horizontal,
                  ),
                  scheduleViewSettings: ScheduleViewSettings(
                    appointmentItemHeight: 50,
                    monthHeaderSettings: const MonthHeaderSettings(
                      monthFormat: 'MMMM yyyy',
                      height: 200,
                      textAlign: TextAlign.center,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  scheduleViewMonthHeaderBuilder: (BuildContext context,
                      ScheduleViewMonthHeaderDetails details) {
                    final monthName = DateFormat.MMMM('es_ES')
                        .format(details.date)
                        .toLowerCase();
                    final imagePath =
                        monthImages[monthName] ?? 'assets/images/refmmp.png';

                    return Stack(
                      children: [
                        Container(
                          height: 250,
                          decoration: BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage(imagePath),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 10,
                          left: 16,
                          child: Text(
                            DateFormat('MMMM yyyy', 'es_ES')
                                .format(details.date)
                                .toUpperCase(),
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.black,
                                  offset: Offset(2, 2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                  onViewChanged: (ViewChangedDetails details) {
                    if (_calendarView == CalendarView.month) {
                      final newDate = details
                          .visibleDates[details.visibleDates.length ~/ 2];
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _focusedDate = newDate;
                          });
                        }
                      });
                    }
                  },
                  onTap: (calendarTapDetails) async {
                    if (calendarTapDetails.appointments != null &&
                        calendarTapDetails.appointments!.isNotEmpty) {
                      final tappedAppointment =
                          calendarTapDetails.appointments!.first as Appointment;
                      final eventIndex =
                          int.tryParse(tappedAppointment.notes ?? '');
                      if (eventIndex != null &&
                          eventIndex >= 0 &&
                          eventIndex < _eventDetails.length) {
                        final event = _eventDetails[eventIndex];

                        bool canEditDelete = false;
                        if (_isOnline) {
                          canEditDelete = await _canDeleteEvent(event['id']);
                        }

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          isDismissible: true,
                          enableDrag: true,
                          constraints: BoxConstraints(
                            maxHeight: MediaQuery.of(context).size.height * 0.9,
                          ),
                          builder: (context) {
                            return DraggableScrollableSheet(
                              initialChildSize: 0.9,
                              minChildSize: 0.5,
                              maxChildSize: 0.9,
                              expand: false,
                              builder: (context, scrollController) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(25.0),
                                  child: Container(
                                    color: themeProvider.isDarkMode
                                        ? const Color.fromARGB(255, 34, 34, 34)
                                        : Colors.white,
                                    child: SingleChildScrollView(
                                      controller: scrollController,
                                      child: Card(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(40),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Stack(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                  child: event['image'] !=
                                                              null &&
                                                          event['image']
                                                              .isNotEmpty
                                                      ? CachedNetworkImage(
                                                          imageUrl:
                                                              event['image'],
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                          cacheManager:
                                                              customCacheManager,
                                                          placeholder: (context,
                                                                  url) =>
                                                              const CircularProgressIndicator(
                                                                  color: Colors
                                                                      .blue),
                                                          errorWidget: (context,
                                                                  url, error) =>
                                                              Image.asset(
                                                            'assets/images/refmmp.png',
                                                            width:
                                                                double.infinity,
                                                            fit: BoxFit.cover,
                                                          ),
                                                        )
                                                      : Image.asset(
                                                          'assets/images/refmmp.png',
                                                          width:
                                                              double.infinity,
                                                          fit: BoxFit.cover,
                                                        ),
                                                ),
                                                Positioned(
                                                  top: 8,
                                                  right: 8,
                                                  child: IconButton(
                                                    icon: const Icon(
                                                      Icons.close,
                                                      color: Colors.white,
                                                      size: 30,
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.pop(context),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.all(16.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .spaceBetween,
                                                    children: [
                                                      Expanded(
                                                        child: Text(
                                                          event['name'],
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.blue,
                                                            fontSize: 22,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () =>
                                                            Navigator.pop(
                                                                context),
                                                        child: const Icon(
                                                          Icons.close,
                                                          color: Colors.white,
                                                          size: 24,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  const SizedBox(height: 10),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "Fecha: ",
                                                        style: TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        DateFormat.yMMMMd(
                                                                'es_ES')
                                                            .format(DateTime
                                                                .parse(event[
                                                                    'date'])),
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Row(
                                                    children: [
                                                      Text(
                                                        "Hora: ",
                                                        style: TextStyle(
                                                          color: Colors.blue,
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      Text(
                                                        "${event['time']} - ${event['time_fin']}",
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    "Ubicación: ",
                                                    style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  if (event['ubication_url'] !=
                                                          null &&
                                                      event['ubication_url']
                                                          .isNotEmpty)
                                                    GestureDetector(
                                                      onTap: () =>
                                                          _launchGoogleMaps(event[
                                                              'ubication_url']),
                                                      child: Row(
                                                        children: [
                                                          const Icon(
                                                              Icons.location_on,
                                                              color:
                                                                  Colors.blue,
                                                              size: 20),
                                                          const SizedBox(
                                                              width: 4),
                                                          Expanded(
                                                            child: Text(
                                                              event['location'],
                                                              style:
                                                                  const TextStyle(
                                                                color:
                                                                    Colors.blue,
                                                                decoration:
                                                                    TextDecoration
                                                                        .underline,
                                                                decorationColor:
                                                                    Colors.blue,
                                                                fontSize: 16,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    )
                                                  else
                                                    Text(
                                                      event['location'],
                                                      style: const TextStyle(
                                                          fontSize: 16),
                                                    ),
                                                  const SizedBox(height: 8),
                                                  Text(
                                                    "Sedes: ",
                                                    style: TextStyle(
                                                      color: Colors.blue,
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                  ClipRRect(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            50.0),
                                                    child: Container(
                                                      color: Colors.transparent,
                                                      child:
                                                          SingleChildScrollView(
                                                        scrollDirection:
                                                            Axis.horizontal,
                                                        child: Row(
                                                          children: (event['events_headquarters']
                                                                          as List<
                                                                              dynamic>?)
                                                                      ?.isEmpty ??
                                                                  true
                                                              ? [
                                                                  const Padding(
                                                                    padding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8.0),
                                                                    child: Text(
                                                                        'No hay sedes asociadas'),
                                                                  ),
                                                                ]
                                                              : (event['events_headquarters']
                                                                      as List<
                                                                          dynamic>)
                                                                  .map((hq) {
                                                                  final sedeName =
                                                                      hq?['sedes']
                                                                              ?[
                                                                              'name'] ??
                                                                          'Sede desconocida';
                                                                  final sedeImage = hq?[
                                                                              'sedes']
                                                                          ?[
                                                                          'local_photo_path'] ??
                                                                      hq?['sedes']
                                                                          ?[
                                                                          'photo'] ??
                                                                      '';

                                                                  return Padding(
                                                                    padding: const EdgeInsets
                                                                        .symmetric(
                                                                        horizontal:
                                                                            4.0),
                                                                    child: Chip(
                                                                      avatar: sedeImage
                                                                              .isNotEmpty
                                                                          ? CircleAvatar(
                                                                              backgroundImage: File(sedeImage).existsSync()
                                                                                  ? FileImage(File(sedeImage))
                                                                                  : CachedNetworkImageProvider(
                                                                                      sedeImage,
                                                                                      cacheManager: customCacheManager,
                                                                                    ),
                                                                              radius: 12,
                                                                              backgroundColor: Colors.white,
                                                                            )
                                                                          : null,
                                                                      label:
                                                                          Text(
                                                                        sedeName,
                                                                        style:
                                                                            const TextStyle(
                                                                          fontSize:
                                                                              12,
                                                                          color:
                                                                              Colors.white,
                                                                        ),
                                                                      ),
                                                                      backgroundColor: Colors
                                                                          .blue
                                                                          .shade300,
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(50),
                                                                      ),
                                                                      padding: const EdgeInsets
                                                                          .symmetric(
                                                                          horizontal:
                                                                              8.0),
                                                                    ),
                                                                  );
                                                                }).toList(),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  if (canEditDelete &&
                                                      _isOnline)
                                                    Align(
                                                      alignment:
                                                          Alignment.centerRight,
                                                      child: Row(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets
                                                                    .all(10.0),
                                                            child:
                                                                ElevatedButton
                                                                    .icon(
                                                              style:
                                                                  ElevatedButton
                                                                      .styleFrom(
                                                                backgroundColor:
                                                                    Colors.blue,
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                              onPressed:
                                                                  () async {
                                                                final result =
                                                                    await Navigator
                                                                        .push(
                                                                  context,
                                                                  MaterialPageRoute(
                                                                    builder: (context) =>
                                                                        EditEventForm(
                                                                            event:
                                                                                event),
                                                                  ),
                                                                );
                                                                if (result ==
                                                                    true) {
                                                                  await fetchEvents();
                                                                }
                                                              },
                                                              icon: const Icon(
                                                                  Icons.edit),
                                                              label: const Text(
                                                                  'Editar'),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                              width: 10),
                                                          ElevatedButton.icon(
                                                            onPressed:
                                                                () async {
                                                              final confirm =
                                                                  await showDialog<
                                                                      bool>(
                                                                context:
                                                                    context,
                                                                builder:
                                                                    (context) =>
                                                                        AlertDialog(
                                                                  title:
                                                                      const Text(
                                                                    '¿Eliminar evento?',
                                                                    style: TextStyle(
                                                                        color: Colors
                                                                            .blue),
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  content:
                                                                      const Text(
                                                                    '¿Estás seguro de que deseas eliminar este evento?',
                                                                    textAlign:
                                                                        TextAlign
                                                                            .center,
                                                                  ),
                                                                  actions: [
                                                                    TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.of(context).pop(false),
                                                                      child:
                                                                          const Text(
                                                                        'Cancelar',
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.blue),
                                                                        textAlign:
                                                                            TextAlign.center,
                                                                      ),
                                                                    ),
                                                                    TextButton(
                                                                      onPressed:
                                                                          () =>
                                                                              Navigator.of(context).pop(true),
                                                                      child:
                                                                          const Text(
                                                                        'Eliminar',
                                                                        style: TextStyle(
                                                                            color:
                                                                                Colors.red),
                                                                      ),
                                                                    ),
                                                                  ],
                                                                ),
                                                              );

                                                              if (confirm ==
                                                                  true) {
                                                                await _deleteEvent(
                                                                    event,
                                                                    context);
                                                              }
                                                            },
                                                            icon: const Icon(
                                                                Icons.delete),
                                                            label: const Text(
                                                                'Eliminar'),
                                                            style:
                                                                ElevatedButton
                                                                    .styleFrom(
                                                              backgroundColor:
                                                                  Colors.red,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: FutureBuilder<bool>(
          future: _canAddEvent(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox();
            }

            if (snapshot.hasData && snapshot.data == true) {
              return FloatingActionButton(
                backgroundColor: Colors.blue,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AddEventForm()),
                  );
                },
                child: const Icon(Icons.add, color: Colors.white),
              );
            } else {
              return const SizedBox();
            }
          },
        ),
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<Appointment> appointments) {
    this.appointments = appointments;
  }
}
