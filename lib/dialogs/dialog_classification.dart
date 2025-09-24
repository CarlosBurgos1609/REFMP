import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:refmp/theme/theme_provider.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'dart:async';

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 3),
      maxNrOfCacheObjects: 200,
    ),
  );
}

void showUserProfileDialog(
  BuildContext context,
  Map<String, dynamic> userData,
  bool isOnline,
) {
  if (!isOnline) {
    // No hacer nada si está offline
    return;
  }

  final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
  final userId = userData['user_id'] ?? '';
  final nickname = userData['nickname'] ?? 'Usuario';
  final points = userData['points_xp_weekend'] ?? 0;

  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor:
          themeProvider.isDarkMode ? Colors.grey[900] : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      child: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserProfileData(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              height: 300,
              padding: const EdgeInsets.all(16),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.blue),
              ),
            );
          }

          final profileData = snapshot.data ?? {};
          final wallpaperUrl =
              profileData['wallpaper'] ?? 'assets/images/refmmp.png';
          final profileImageUrl =
              profileData['profile_image'] ?? 'assets/images/refmmp.png';

          return Container(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Fondo con imagen de perfil superpuesta
                Container(
                  height: 200,
                  width: double.infinity,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo de pantalla
                      ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: _buildWallpaperImage(wallpaperUrl),
                      ),
                      // Imagen de perfil superpuesta en el centro
                      Positioned(
                        bottom: 0,
                        left: (MediaQuery.of(context).size.width - 120) / 2,
                        child: CircleAvatar(
                          radius: 60.0,
                          backgroundColor: Colors.transparent,
                          child: ClipOval(
                            child: _buildProfileImage(profileImageUrl),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido inferior
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 8),
                      // Nombre del usuario
                      Text(
                        nickname,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: themeProvider.isDarkMode
                              ? Colors.white
                              : Colors.blue,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),

                      // Puntos XP
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.blue.shade50,
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.bolt,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '$points XP Semanal',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.blue.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Botón cerrar
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          minimumSize: const Size(double.infinity, 48),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'Cerrar',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
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
    ),
  );
}

Widget _buildWallpaperImage(String wallpaperUrl) {
  if (wallpaperUrl.startsWith('assets/')) {
    return Image.asset(
      wallpaperUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/refmmp.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  } else if (Uri.tryParse(wallpaperUrl)?.isAbsolute == true) {
    return CachedNetworkImage(
      imageUrl: wallpaperUrl,
      cacheManager: CustomCacheManager.instance,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
      errorWidget: (context, url, error) {
        return Image.asset(
          'assets/images/refmmp.png',
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      },
    );
  } else {
    return Image.asset(
      'assets/images/refmmp.png',
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
    );
  }
}

Widget _buildProfileImage(String profileImageUrl) {
  if (profileImageUrl.startsWith('assets/')) {
    return Image.asset(
      profileImageUrl,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      errorBuilder: (context, error, stackTrace) {
        return Image.asset(
          'assets/images/refmmp.png',
          fit: BoxFit.cover,
          width: 120,
          height: 120,
        );
      },
    );
  } else if (Uri.tryParse(profileImageUrl)?.isAbsolute == true) {
    return CachedNetworkImage(
      imageUrl: profileImageUrl,
      cacheManager: CustomCacheManager.instance,
      fit: BoxFit.cover,
      width: 120,
      height: 120,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(color: Colors.blue),
      ),
      errorWidget: (context, url, error) {
        return Image.asset(
          'assets/images/refmmp.png',
          fit: BoxFit.cover,
          width: 120,
          height: 120,
        );
      },
    );
  } else {
    return Image.asset(
      'assets/images/refmmp.png',
      fit: BoxFit.cover,
      width: 120,
      height: 120,
    );
  }
}

Future<Map<String, dynamic>> _fetchUserProfileData(String userId) async {
  final supabase = Supabase.instance.client;
  Map<String, dynamic> result = {};

  try {
    // Buscar imagen de perfil en todas las tablas
    final tables = [
      'users',
      'students',
      'graduates',
      'teachers',
      'advisors',
      'parents',
      'directors'
    ];

    String? profileImage;
    for (String table in tables) {
      final response = await supabase
          .from(table)
          .select('profile_image')
          .eq('user_id', userId)
          .maybeSingle();

      if (response != null && response['profile_image'] != null) {
        profileImage = response['profile_image'];
        break;
      }
    }

    // Buscar wallpaper en users_games
    final wallpaperResponse = await supabase
        .from('users_games')
        .select('wallpapers')
        .eq('user_id', userId)
        .maybeSingle();

    String? wallpaper;
    if (wallpaperResponse != null && wallpaperResponse['wallpapers'] != null) {
      wallpaper = wallpaperResponse['wallpapers'];
    }

    result = {
      'profile_image': profileImage ?? 'assets/images/refmmp.png',
      'wallpaper': wallpaper ?? 'assets/images/refmmp.png',
    };

    debugPrint('Fetched profile data for user $userId: $result');
  } catch (e) {
    debugPrint('Error fetching user profile data: $e');
    result = {
      'profile_image': 'assets/images/refmmp.png',
      'wallpaper': 'assets/images/refmmp.png',
    };
  }

  return result;
}
