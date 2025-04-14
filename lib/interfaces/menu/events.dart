import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';

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

  @override
  void initState() {
    super.initState();
    _calendarController = CalendarController();
    _calendarController.view = _calendarView;
    initializeDateFormatting('es_ES', null).then((_) {
      setState(() {});
    });
    fetchEvents();
  }

  Future<void> fetchEvents() async {
    final response = await supabase
        .from('events')
        .select('*, sedes(name)')
        .order('date', ascending: true)
        .order('name', ascending: true);

    debugPrint('Eventos obtenidos: ${response.length}');

    List<Appointment> appointments = [];
    List<Map<String, dynamic>> eventDetails = [];

    for (var event in response) {
      try {
        final rawDate = event['date']; // ya es timestamp con hora
        final rawTimeFin = event['time_fin'];

        debugPrint('Procesando evento: $event');

        if (rawDate == null) continue;

        DateTime startDateTime = DateTime.parse(rawDate);
        DateTime endDateTime;

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
          notes: eventDetails.length.toString(),
          color: Colors.green,
        ));

        eventDetails.add(event);
      } catch (e) {
        debugPrint("Error procesando evento: $e");
      }
    }

    if (!mounted) return;
    setState(() {
      _appointments = appointments;
      _eventDetails = eventDetails;
    });
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
                              borderRadius: BorderRadius.circular(12),
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
                        MonthAppointmentDisplayMode.appointment,
                    showAgenda: true,
                  ),
                  scheduleViewSettings: const ScheduleViewSettings(
                    appointmentItemHeight: 70,
                  ),
                  onTap: (calendarTapDetails) {
                    if (calendarTapDetails.appointments != null &&
                        calendarTapDetails.appointments!.isNotEmpty) {
                      final tappedAppointment =
                          calendarTapDetails.appointments!.first as Appointment;
                      final eventIndex =
                          int.tryParse(tappedAppointment.notes ?? '');
                      if (eventIndex != null &&
                          eventIndex < _eventDetails.length) {
                        final event = _eventDetails[eventIndex];
                        final sedeName =
                            event['sedes']['name'] ?? 'Sede no encontrada';

                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (context) {
                            return SingleChildScrollView(
                              child: Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (event['image'] != null)
                                      ClipRRect(
                                        borderRadius:
                                            const BorderRadius.vertical(
                                                top: Radius.circular(20)),
                                        child: Image.network(event['image'],
                                            width: double.infinity,
                                            fit: BoxFit.cover),
                                      ),
                                    Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              event['name'] ??
                                                  'Evento sin nombre',
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.bold)),
                                          const SizedBox(height: 10),
                                          Text(
                                              "Fecha: ${DateFormat.yMMMMd('es_ES').format(DateTime.parse(event['date']))}",
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          Text(
                                            "Hora: ${event['time']} - ${event['time_fin'] ?? 'No especificada'}",
                                            style:
                                                const TextStyle(fontSize: 16),
                                          ),
                                          Text(
                                              "Ubicación: ${event['location']}",
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          Text("Sede: $sedeName",
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: Colors.blue)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<Appointment> appointments) {
    this.appointments = appointments;
  }
}
