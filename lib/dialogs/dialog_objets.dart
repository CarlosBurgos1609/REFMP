import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:refmp/games/game/escenas/profile.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'dart:io';

void showObjectDialog(
  BuildContext context,
  Map<String, dynamic> item,
  String category,
  int totalCoins,
  Future<void> Function(Map<String, dynamic>, String) useObject,
  Future<void> Function(Map<String, dynamic>) purchaseObject,
) {
  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final numberFormat = NumberFormat('#,##0', 'es_ES');
  final isObtained = item['objet_id'] != null || item['id'] != null;
  final price = (item['price'] ?? 0) as int;
  final imagePath = item['local_image_path'] ??
      item['image'] ??
      item['image_url'] ??
      'assets/images/refmmp.png';

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Mis monedas',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/coin.png',
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    numberFormat.format(totalCoins),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                width: category == 'avatares' ? 150 : double.infinity,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(category == 'avatares' ? 75 : 8),
                  border: Border.all(
                    color: isObtained ? Colors.green : Colors.blue,
                    width: 2,
                  ),
                ),
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(category == 'avatares' ? 75 : 8),
                  child: imagePath.isNotEmpty &&
                          !imagePath.startsWith('http') &&
                          File(imagePath).existsSync()
                      ? Image.file(
                          File(imagePath),
                          fit: category == 'trompetas'
                              ? BoxFit.contain
                              : BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            debugPrint(
                                'Error loading local image: $error, path: $imagePath');
                            return Image.asset(
                              'assets/images/refmmp.png',
                              fit: BoxFit.cover,
                            );
                          },
                        )
                      : imagePath.isNotEmpty &&
                              Uri.tryParse(imagePath)?.isAbsolute == true
                          ? CachedNetworkImage(
                              imageUrl: imagePath,
                              cacheManager: CustomCacheManager.instance,
                              fit: category == 'trompetas'
                                  ? BoxFit.contain
                                  : BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(
                                    color: Colors.blue),
                              ),
                              errorWidget: (context, url, error) {
                                debugPrint(
                                    'Error loading network image: $error, url: $url');
                                return Image.asset(
                                  'assets/images/refmmp.png',
                                  fit: BoxFit.cover,
                                );
                              },
                              memCacheWidth: 200,
                              memCacheHeight: 200,
                              fadeInDuration: const Duration(milliseconds: 200),
                            )
                          : Image.asset(
                              'assets/images/refmmp.png',
                              fit: BoxFit.cover,
                            ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item['name'] ?? '',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.isDarkMode ? Colors.white : Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                item['description'] ?? 'Sin descripción',
                style: TextStyle(
                  fontSize: 14,
                  color: themeProvider.isDarkMode
                      ? Colors.grey[300]
                      : Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              if (isObtained) ...[
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    await useObject(item, category);
                    Navigator.pop(context);
                  },
                  child: Text(
                    'Usar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ] else ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/coin.png',
                      width: 20,
                      height: 20,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      numberFormat.format(price),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        totalCoins >= price ? Colors.green : Colors.grey,
                    minimumSize: Size(double.infinity, 48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    if (totalCoins < price) {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          contentPadding: EdgeInsets.all(16),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.close_rounded,
                                color: Colors.red,
                                size: MediaQuery.of(context).size.width * 0.3,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Monedas insuficientes',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'No tienes suficientes monedas. Tienes: ($totalCoins) monedas y son menores que el precio del objeto que es: ($price) monedas.',
                                style: TextStyle(fontWeight: FontWeight.bold),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                          actions: [
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                minimumSize: Size(double.infinity, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text(
                                'OK',
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
                    } else {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Center(
                            child: Text(
                              'Confirmar compra',
                              style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                          content: Text(
                            '¿Estás seguro de comprar ${item['name']} por ${numberFormat.format(price)} monedas?',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(
                                'Cancelar',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(
                                'Sí',
                                style: TextStyle(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await purchaseObject(item);
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            contentPadding: EdgeInsets.all(16),
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: Colors.green,
                                  size: MediaQuery.of(context).size.width * 0.3,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '¡Objeto obtenido!',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.blue,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Se ha obtenido ${item['name']} con éxito.',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                            actions: [
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  minimumSize: Size(double.infinity, 48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pop(context);
                                  showObjectDialog(
                                    context,
                                    item,
                                    category,
                                    totalCoins - price,
                                    useObject,
                                    purchaseObject,
                                  );
                                },
                                child: Text(
                                  'OK',
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
                      }
                    }
                  },
                  child: Text(
                    'Comprar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  minimumSize: Size(double.infinity, 48),
                  side: BorderSide(color: Colors.red, width: 2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
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
      );
    },
  );
}
