import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';

void showCongratulationsDialog(
  BuildContext context, {
  required int experiencePoints,
  required int totalScore,
  required int correctNotes,
  required int missedNotes,
  required VoidCallback onContinue,
}) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final themeProvider = Provider.of<ThemeProvider>(context);
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          constraints:
              const BoxConstraints(maxHeight: 500), // Limitar altura máxima
          padding: const EdgeInsets.all(16), // Reducido de 20 a 16
          decoration: BoxDecoration(
            color: themeProvider.isDarkMode
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SingleChildScrollView(
            // Permitir scroll si es necesario
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icono de check con animación (más pequeño)
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 60, // Reducido de 80 a 60
                        height: 60, // Reducido de 80 a 60
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30), // Ajustado
                          border: Border.all(color: Colors.green, width: 2),
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 30, // Reducido de 40 a 30
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16), // Reducido de 20 a 16

                // Título
                Text(
                  '¡Felicitaciones!',
                  style: TextStyle(
                    fontSize: 20, // Reducido de 22 a 20
                    fontWeight: FontWeight.bold,
                    color: themeProvider.isDarkMode
                        ? Colors.white
                        : Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6), // Reducido de 8 a 6

                Text(
                  'Has completado la canción',
                  style: TextStyle(
                    fontSize: 14, // Reducido de 16 a 14
                    color: themeProvider.isDarkMode
                        ? Colors.grey[300]
                        : Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16), // Reducido de 24 a 16

                // Estadísticas del juego en una sola fila
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: themeProvider.isDarkMode
                        ? Colors.grey[800]?.withOpacity(0.3)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: themeProvider.isDarkMode
                            ? Colors.grey[600]!.withOpacity(0.3)
                            : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      // Experiencia
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.star,
                          iconColor: Colors.purple,
                          title: 'XP',
                          value: '+$experiencePoints',
                          valueColor: Colors.purple,
                          themeProvider: themeProvider,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Puntos
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.score_rounded,
                          iconColor: Colors.blue,
                          title: 'Puntos',
                          value: '$totalScore',
                          valueColor: Colors.blue,
                          themeProvider: themeProvider,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Notas acertadas
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.check_rounded,
                          iconColor: Colors.green,
                          title: 'Aciertos',
                          value: '$correctNotes',
                          valueColor: Colors.green,
                          themeProvider: themeProvider,
                        ),
                      ),
                      const SizedBox(width: 6),

                      // Notas falladas
                      Expanded(
                        child: _buildStatCard(
                          icon: Icons.close_rounded,
                          iconColor: Colors.red,
                          title: 'Fallos',
                          value: '$missedNotes',
                          valueColor: Colors.red,
                          themeProvider: themeProvider,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16), // Reducido de 24 a 16

                // Botón Continuar (Verde)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    minimumSize:
                        const Size(double.infinity, 44), // Reducido de 48 a 44
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 2,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    onContinue();
                  },
                  child: const Text(
                    'Continuar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// Widget helper para crear cada tarjeta de estadística en fila
Widget _buildStatCard({
  required IconData icon,
  required Color iconColor,
  required String title,
  required String value,
  required Color valueColor,
  required dynamic themeProvider,
}) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
    decoration: BoxDecoration(
      color: iconColor.withOpacity(0.1),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: iconColor.withOpacity(0.3)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icono
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: iconColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 12,
          ),
        ),
        const SizedBox(height: 4),

        // Título
        Text(
          title,
          style: TextStyle(
            fontSize: 9,
            color:
                themeProvider.isDarkMode ? Colors.grey[400] : Colors.grey[600],
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),

        // Valor
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    ),
  );
}
