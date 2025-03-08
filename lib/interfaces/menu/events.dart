import 'package:flutter/material.dart';
import 'package:refmp/controllers/exit.dart';
import 'package:refmp/routes/menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

class EventsPage extends StatefulWidget {
  const EventsPage({super.key, required this.title});
  final String title;

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  final SupabaseClient supabase = Supabase.instance.client;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, List<Map<String, dynamic>>> _eventsByDay = {};
  List<Map<String, dynamic>> _events = [];

  Future<void> fetchEvents() async {
    final response = await supabase
        .from('events')
        .select('*, sedes(name)')
        .order('date', ascending: true)
        .order('name', ascending: true);

    Map<DateTime, List<Map<String, dynamic>>> eventsMap = {};
    List<Map<String, dynamic>> eventsList = [];
    for (var event in response) {
      DateTime eventDate = DateTime.parse(event['date']);
      DateTime normalizedDate =
          DateTime(eventDate.year, eventDate.month, eventDate.day);
      if (!eventsMap.containsKey(normalizedDate)) {
        eventsMap[normalizedDate] = [];
      }
      eventsMap[normalizedDate]!.add(event);
      eventsList.add(event);
    }

    setState(() {
      _eventsByDay = eventsMap;
      _events = eventsList
          .where((e) => DateTime.parse(e['date']).month == _focusedDay.month)
          .toList();
    });
  }

  @override
  void initState() {
    super.initState();
    initializeDateFormatting();
    fetchEvents();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => showExitConfirmationDialog(context),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title,
              style: const TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              )),
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
          child: SingleChildScrollView(
            child: Column(
              children: [
                TableCalendar(
                  locale: 'es_ES',
                  firstDay: DateTime.utc(2025, 1, 1),
                  lastDay: DateTime.utc(2100, 12, 31),
                  focusedDay: _focusedDay,
                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  // onDaySelected: (selectedDay, focusedDay) {
                  //   setState(() {
                  //     _selectedDay = selectedDay;
                  //     _focusedDay = focusedDay;
                  //     _events = _eventsByDay[selectedDay] ?? [];
                  //   });
                  // },
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                      _events = _eventsByDay.entries
                          .where((e) => e.key.month == focusedDay.month)
                          .expand((e) => e.value)
                          .toList();
                    });
                  },
                  calendarFormat: CalendarFormat.month,
                  headerStyle: const HeaderStyle(
                      formatButtonVisible: false, titleCentered: true),
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (_eventsByDay.containsKey(date)) {
                        return Positioned(
                          bottom: 5,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green,
                              shape: BoxShape.circle,
                            ),
                          ),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 10),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _events.length,
                  itemBuilder: (context, index) {
                    final event = _events[index];
                    final sedeName =
                        event['sedes']['name'] ?? 'Sede No Encontrada';
                    return GestureDetector(
                      onTap: () {
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
                                  children: [
                                    if (event['image'] != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.vertical(
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
                                          Text("Fecha: ${event['date']}",
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          Text("Hora: ${event['time']}",
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          Text(
                                              "Ubicación: ${event['location']}",
                                              style: const TextStyle(
                                                  fontSize: 16)),
                                          Text("Sede: $sedeName",
                                              style: const TextStyle(
                                                  color: Colors.blue,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                      child: Card(
                        margin: const EdgeInsets.all(10),
                        child: Column(
                          children: [
                            if (event['image'] != null)
                              ClipRRect(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(10)),
                                child: Image.network(event['image'],
                                    width: double.infinity,
                                    height: 150,
                                    fit: BoxFit.cover),
                              ),
                            ListTile(
                              title: Text(event['name'] ?? 'Evento sin nombre',
                                  style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(
                                  "${event['date']} - ${event['location']} - Sede: $sedeName"),
                              trailing: Text(
                                "${event['time']} ",
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.blue),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
