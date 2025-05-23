import 'package:flutter/material.dart';

class SongsFormPage extends StatefulWidget {
  const SongsFormPage({super.key});

  @override
  _SongsFormPageState createState() => _SongsFormPageState();
}

class _SongsFormPageState extends State<SongsFormPage> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController artistController = TextEditingController();
  final TextEditingController imageController = TextEditingController();
  String? selectedDifficulty;
  int? selectedInstrumentId;

  final List<String> difficulties = ['Fácil', 'Medio', 'Difícil'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Agregar canción',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryBlue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            const SizedBox(height: 16),
            CustomInputField(
              label: 'Nombre de la canción',
              icon: Icons.music_note,
              controller: nameController,
            ),
            const SizedBox(height: 16),
            CustomInputField(
              label: 'Artista',
              icon: Icons.person,
              controller: artistController,
            ),
            const SizedBox(height: 16),
            CustomInputField(
              label: 'Link imagen (Spotify)',
              icon: Icons.image,
              controller: imageController,
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              decoration: InputDecoration(
                labelText: 'Dificultad',
                labelStyle: const TextStyle(color: AppColors.primaryBlue),
                prefixIcon:
                    const Icon(Icons.bar_chart, color: AppColors.primaryBlue),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
              ),
              value: selectedDifficulty,
              items: difficulties.map((level) {
                return DropdownMenuItem(
                  value: level,
                  child: Text(level),
                );
              }).toList(),
              onChanged: (value) => setState(() => selectedDifficulty = value),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Instrumento',
                labelStyle: TextStyle(color: AppColors.primaryBlue),
                prefixIcon:
                    Icon(Icons.music_video, color: AppColors.primaryBlue),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryBlue),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 1, child: Text("Trompeta")),
                // Aquí puedes cargar dinámicamente desde Supabase
              ],
              onChanged: (value) =>
                  setState(() => selectedInstrumentId = value),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isEmpty ||
                    artistController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Por favor completa todos los campos')),
                  );
                  return;
                }
                // Navegar a la siguiente pantalla (SongCreationPage aún por crear)
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SongCreationPage(
                      songData: {
                        'name': nameController.text,
                        'artist': artistController.text,
                        'image': imageController.text,
                        'difficulty': selectedDifficulty,
                        'instrument_id': selectedInstrumentId,
                      },
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Siguiente',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class AppColors {
  static const Color primaryBlue = Colors.blue;
}

class CustomInputField extends StatelessWidget {
  final String label;
  final IconData icon;
  final TextEditingController controller;
  final TextInputType keyboardType;

  const CustomInputField({
    super.key,
    required this.label,
    required this.icon,
    required this.controller,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style:
          const TextStyle(color: AppColors.primaryBlue), // Texto ingresado azul
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.primaryBlue), // Label azul
        prefixIcon: Icon(icon, color: AppColors.primaryBlue), // Ícono azul
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryBlue),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: AppColors.primaryBlue),
        ),
      ),
    );
  }
}

// ⚠️ Página ficticia de ejemplo, debes implementarla después:
class SongCreationPage extends StatelessWidget {
  final Map<String, dynamic> songData;

  const SongCreationPage({super.key, required this.songData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear melodía'),
        backgroundColor: AppColors.primaryBlue,
      ),
      body: const Center(
        child:
            Text('Aquí irá el editor de melodía con partitura e imágenes 🎵'),
      ),
    );
  }
}
