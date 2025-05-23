import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubnivelesPage extends StatefulWidget {
  final String levelId;
  final String levelTitle;

  const SubnivelesPage(
      {super.key, required this.levelId, required this.levelTitle});

  @override
  State<SubnivelesPage> createState() => _SubnivelesPageState();
}

class _SubnivelesPageState extends State<SubnivelesPage> {
  final supabase = Supabase.instance.client;
  List<dynamic> subniveles = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSubniveles();
  }

  Future<void> fetchSubniveles() async {
    try {
      final response = await supabase
          .from('sublevels')
          .select()
          .eq('level_id', widget.levelId)
          .order('order_number', ascending: true)
          .limit(50);

      setState(() {
        subniveles = response;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error al obtener subniveles: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _canAddEvent() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return false;

    final user = await supabase
        .from('users')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    if (user != null) return true;

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        title: Text(
          widget.levelTitle,
          style: TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      floatingActionButton: FutureBuilder<bool>(
        future: _canAddEvent(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(); // o un indicador de carga pequeño
          }

          if (snapshot.hasData && snapshot.data == true) {
            return FloatingActionButton(
              backgroundColor: Colors.blue,
              onPressed: () {
                // Navigator.push(
                //   context,
                //   MaterialPageRoute(builder: (context) => SongsFormPage()),
                // );
              },
              child: const Icon(Icons.add, color: Colors.white),
            );
          } else {
            return const SizedBox(); // no mostrar nada si no tiene permiso
          }
        },
      ),
      body: RefreshIndicator(
        color: Colors.blue, // Indicador azul
        onRefresh: fetchSubniveles, // Método de recarga
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                color: Colors.blue,
              ))
            : ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                itemCount: subniveles.length,
                itemBuilder: (context, index) {
                  final subnivel = subniveles[index];
                  return Card(
                    margin: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subnivel['image'] != null &&
                            subnivel['image'].toString().isNotEmpty)
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(12)),
                            child: Image.network(
                              subnivel['image'],
                              width: double.infinity,
                              height: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(
                                height: 180,
                                child: Center(child: Icon(Icons.broken_image)),
                              ),
                            ),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subnivel['title'] ?? 'Sin título',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                subnivel['description'] ?? '',
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(height: 8),
                              Chip(
                                label: Text(
                                  'Tipo: ${subnivel['type'] ?? 'N/A'}',
                                  style: TextStyle(color: Colors.white),
                                ),
                                backgroundColor: Colors.blue.shade100,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}
