import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:refmp/games/play.dart'; // Importar la página de play
import 'package:supabase_flutter/supabase_flutter.dart';

void showSongDialog(
  BuildContext context,
  Map<String, dynamic> song,
  int totalCoins,
  Future<void> Function(Map<String, dynamic>) playSong,
  Future<void> Function(Map<String, dynamic>) purchaseSong,
  Future<void> Function() refreshCoins,
) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final numberFormat = NumberFormat('#,##0', 'es_ES');

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: FutureBuilder<bool>(
          future: _checkUserOwnsSong(song['id']),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Container(
                height: 200,
                padding: const EdgeInsets.all(16),
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.blue),
                ),
              );
            }

            final isOwned = snapshot.data ?? false;
            final price = (song['coins'] ?? 0) as int;
            final imagePath = song['image'] ?? 'assets/images/refmmp.png';

            return Container(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Imagen de la canción como header (estilo card)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                    child: Container(
                      width: double.infinity,
                      height: 200,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Imagen de fondo
                          imagePath.isNotEmpty &&
                                  Uri.tryParse(imagePath)?.isAbsolute == true
                              ? CachedNetworkImage(
                                  imageUrl: imagePath,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                  placeholder: (context, url) => const Center(
                                    child: CircularProgressIndicator(
                                        color: Colors.blue),
                                  ),
                                  errorWidget: (context, url, error) {
                                    return Image.asset(
                                      'assets/images/refmmp.png',
                                      fit: BoxFit.cover,
                                    );
                                  },
                                )
                              : Image.asset(
                                  'assets/images/refmmp.png',
                                  fit: BoxFit.cover,
                                ),

                          // Overlay con información de monedas (solo si no es propietario)
                          if (!isOwned)
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withOpacity(0.7),
                                  ],
                                ),
                              ),
                            ),

                          // Información de monedas del usuario en la esquina superior
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/coin.png',
                                    width: 20,
                                    height: 20,
                                    fit: BoxFit.contain,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    numberFormat.format(totalCoins),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Indicador de propietario
                          if (isOwned)
                            Positioned(
                              top: 16,
                              left: 16,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle,
                                        color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Adquirida',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Contenido del diálogo
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Nombre de la canción
                        Text(
                          song['name'] ?? 'Sin nombre',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: themeProvider.isDarkMode
                                ? Colors.white
                                : Colors.blue,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),

                        // Artista
                        Text(
                          'Artista: ${song['artist'] ?? 'Sin artista'}',
                          style: TextStyle(
                            fontSize: 16,
                            color: themeProvider.isDarkMode
                                ? Colors.grey[300]
                                : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Dificultad
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: _getDifficultyColor(
                                song['difficulty'] ?? 'Desconocida'),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            song['difficulty'] ?? 'Desconocida',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Botones según si posee la canción o no
                        if (isOwned) ...[
                          // Ya posee la canción - Mostrar botón Tocar
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () {
                              Navigator.pop(context); // Cerrar el diálogo
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlayPage(
                                    songId: song['id'].toString(),
                                    songName: song['name'] ?? 'Sin nombre',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.music_note,
                                color: Colors.white),
                            label: const Text(
                              'Tocar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ] else ...[
                          // No posee la canción - Mostrar precio y botón comprar
                          Container(
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.amber, width: 2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/images/coin.png',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${numberFormat.format(price)} monedas',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: totalCoins >= price
                                  ? Colors.amber
                                  : Colors.grey,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: totalCoins >= price
                                ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        title: const Center(
                                          child: Text(
                                            'Confirmar compra',
                                            style: TextStyle(
                                              color: Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        content: Text(
                                          '¿Estás seguro de comprar "${song['name']}" por ${numberFormat.format(price)} monedas?',
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text(
                                              'Cancelar',
                                              style:
                                                  TextStyle(color: Colors.red),
                                            ),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text(
                                              'Comprar',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      try {
                                        await purchaseSong(song);
                                        Navigator.pop(context);

                                        // Mostrar diálogo de éxito
                                        showDialog(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(24),
                                            content: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                  width: 80,
                                                  height: 80,
                                                  decoration: BoxDecoration(
                                                    color: Colors.green,
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    color: Colors.white,
                                                    size: 50,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                const Text(
                                                  '¡Canción obtenida!',
                                                  textAlign: TextAlign.center,
                                                  style: TextStyle(
                                                    color: Colors.blue,
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 12),
                                                Text(
                                                  'Se ha agregado "${song['name']}" a tu biblioteca musical.',
                                                  style: const TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                            actions: [
                                              ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.blue,
                                                  minimumSize: const Size(
                                                      double.infinity, 48),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                                onPressed: () {
                                                  Navigator.pop(context);
                                                  refreshCoins();
                                                },
                                                child: const Text(
                                                  'Continuar',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                                'Error al comprar la canción: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                : () {
                                    // Mostrar diálogo de monedas insuficientes
                                    showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(16),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.all(24),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                color: Colors.red,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 50,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            const Text(
                                              'Monedas insuficientes',
                                              style: TextStyle(
                                                color: Colors.blue,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 20,
                                              ),
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              'Necesitas ${numberFormat.format(price)} monedas pero solo tienes ${numberFormat.format(totalCoins)}.',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w500,
                                                fontSize: 16,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              minimumSize: const Size(
                                                  double.infinity, 48),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.pop(context),
                                            child: const Text(
                                              'Entendido',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                            icon: Icon(
                              totalCoins >= price
                                  ? Icons.shopping_cart
                                  : Icons.lock,
                              color: Colors.white,
                            ),
                            label: Text(
                              totalCoins >= price ? 'Comprar' : 'Sin monedas',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Botón Cerrar
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            minimumSize: const Size(double.infinity, 48),
                            side: const BorderSide(color: Colors.red, width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Cerrar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
    },
  );
}

// Función para verificar si el usuario posee la canción
Future<bool> _checkUserOwnsSong(dynamic songId) async {
  try {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;

    if (userId == null) return false;

    final response = await supabase
        .from('user_songs')
        .select('user_id')
        .eq('user_id', userId)
        .eq('song_id', songId.toString())
        .maybeSingle();

    return response != null;
  } catch (e) {
    debugPrint('Error checking if user owns song: $e');
    return false;
  }
}

// Función auxiliar para obtener el color de la dificultad
Color _getDifficultyColor(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'fácil':
      return Colors.green;
    case 'medio':
      return Colors.orange;
    case 'difícil':
      return Colors.red;
    default:
      return Colors.grey;
  }
}
