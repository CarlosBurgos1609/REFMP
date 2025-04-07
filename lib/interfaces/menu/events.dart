import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:syncfusion_flutter_calendar/calendar.dart';
import 'package:intl/intl.dart';

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

  get rawDateT => null;

  @override
  void initState() {
    super.initState();

    fetchEvents();
  }

  Future<void> fetchEvents() async {
    final response = await supabase
        .from('events')
        .select('*, sedes(name)')
        .order('date', ascending: true)
        .order('name', ascending: true);

    List<Appointment> appointments = [];
    List<Map<String, dynamic>> eventDetails = [];

    for (var event in response) {
      try {
        final rawDate = event['date'];
        final rawTime = event['time'];

        DateTime startDateTime;

        if (rawDate.toString().contains('T')) {
          startDateTime = DateTime.parse(rawDate);
        } else {
          startDateTime = DateTime.parse('$rawDateT$rawTime');
        }

        DateTime endDateTime = startDateTime.add(const Duration(hours: 1));

        appointments.add(Appointment(
          startTime: startDateTime,

          endTime: endDateTime,
          subject: event['name'] ?? 'Evento sin nombre',
          notes: eventDetails.length.toString(), // índice
          color: Colors.blue,
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

  @override
  Widget build(BuildContext context) {
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
        floatingActionButton: FloatingActionButton(
          onPressed: () {},
          backgroundColor: Colors.blue,
          child: Icon(
            Icons.add,
            color: Colors.white,
          ),
        ),
        drawer: Menu.buildDrawer(context),
        body: RefreshIndicator(
          onRefresh: fetchEvents,
          child: SfCalendar(
            view: CalendarView.month,
            dataSource: EventDataSource(_appointments),
            minDate: DateTime(2025, 1, 1),
            monthViewSettings: const MonthViewSettings(
              appointmentDisplayMode: MonthAppointmentDisplayMode.appointment,
              showAgenda: true,
            ),
            onTap: (calendarTapDetails) {
              if (calendarTapDetails.appointments != null &&
                  calendarTapDetails.appointments!.isNotEmpty) {
                final tappedAppointment =
                    calendarTapDetails.appointments!.first as Appointment;
                final eventIndex = int.tryParse(tappedAppointment.notes ?? '');
                if (eventIndex != null && eventIndex < _eventDetails.length) {
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
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(20)),
                                  child: Image.network(event['image'],
                                      width: double.infinity,
                                      fit: BoxFit.cover),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(event['name'] ?? 'Evento sin nombre',
                                        style: const TextStyle(
                                            color: Colors.blue,
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 10),
                                    Text(
                                        "Fecha: ${DateFormat.yMMMMd('es_ES').format(DateTime.parse(event['date']))}",
                                        style: const TextStyle(fontSize: 16)),
                                    Text("Hora: ${event['time']}",
                                        style: const TextStyle(fontSize: 16)),
                                    Text("Ubicación: ${event['location']}",
                                        style: const TextStyle(fontSize: 16)),
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
      ),
    );
  }
}

class EventDataSource extends CalendarDataSource {
  EventDataSource(List<Appointment> appointments) {
    this.appointments = appointments;
  }
}
