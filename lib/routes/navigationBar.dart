import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:provider/provider.dart';
import 'package:refmp/models/profile_image_provider.dart';
import 'package:refmp/theme/theme_provider.dart';

class CustomCacheManager {
  static const key = 'customCacheKey';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 200,
    ),
  );
}

class CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const CustomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final profileImageProvider = Provider.of<ProfileImageProvider>(context);
    debugPrint(
        'CustomNavigationBar: profileImageUrl=${profileImageProvider.profileImageUrl}, wallpaperUrl=${profileImageProvider.wallpaperUrl}');

    return Container(
      decoration: BoxDecoration(
          image: profileImageProvider.wallpaperUrl != null &&
                  profileImageProvider.wallpaperUrl!.isNotEmpty &&
                  _isValidImageUrl(profileImageProvider.wallpaperUrl!)
              ? DecorationImage(
                  image:
                      _buildImageProvider(profileImageProvider.wallpaperUrl!),
                  fit: BoxFit.cover,
                  opacity: 0.3,
                  onError: (exception, stackTrace) {
                    debugPrint('Error loading wallpaper: $exception');
                  },
                )
              : null,
          color: themeProvider.isDarkMode
              ? const Color.fromARGB(255, 2, 2, 2)
              : const Color.fromARGB(255, 2, 2, 2)),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onItemTapped,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.transparent,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        items: [
          _buildNavItem(
            icon: Icons.book_outlined,
            selectedIcon: Icons.book_rounded,
            index: 0,
            label: 'Aprende',
          ),
          _buildNavItem(
            icon: Icons.music_note_outlined,
            selectedIcon: Icons.music_note_rounded,
            index: 1,
            label: 'Música',
          ),
          _buildNavItem(
            icon: Icons.emoji_events_outlined,
            selectedIcon: Icons.emoji_events_rounded,
            index: 2,
            label: 'Torneo',
          ),
          _buildNavItem(
            icon: Icons.card_giftcard_outlined,
            selectedIcon: Icons.card_giftcard_rounded,
            index: 3,
            label: 'Objetos',
          ),
          BottomNavigationBarItem(
            icon: _buildProfileIcon(4, profileImageProvider.profileImageUrl),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) {
      debugPrint('Invalid image URL: Empty URL');
      return false;
    }
    if (!url.startsWith('http') && !File(url).existsSync()) {
      debugPrint('Invalid image URL: File does not exist at $url');
      return false;
    }
    if (url.startsWith('http') && Uri.tryParse(url)?.isAbsolute != true) {
      debugPrint('Invalid image URL: Invalid network URL $url');
      return false;
    }
    return true;
  }

  ImageProvider _buildImageProvider(String imageUrl) {
    debugPrint('Building ImageProvider for URL: $imageUrl');
    if (!imageUrl.startsWith('http') && File(imageUrl).existsSync()) {
      debugPrint('Using local image: $imageUrl');
      return FileImage(File(imageUrl));
    } else if (Uri.tryParse(imageUrl)?.isAbsolute == true) {
      debugPrint('Using network image: $imageUrl');
      return NetworkImage(imageUrl);
    }
    debugPrint('Using default image for: $imageUrl');
    return const AssetImage('assets/images/refmmp.png');
  }

  BottomNavigationBarItem _buildNavItem({
    required IconData icon,
    required IconData selectedIcon,
    required int index,
    required String label,
  }) {
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: selectedIndex == index
            ? BoxDecoration(
                color: Colors.blue.withOpacity(0.15),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    spreadRadius: 2,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              )
            : null,
        child: Icon(
          selectedIndex == index ? selectedIcon : icon,
          color: selectedIndex == index ? Colors.blue : Colors.grey,
          shadows: [
            Shadow(
              color: Colors.black,
              offset: Offset(2, 1),
              blurRadius: 8,
            ),
          ],
        ),
      ),
      label: label,
    );
  }

  Widget _buildProfileIcon(int index, String? profileImageUrl) {
    debugPrint('Building profile icon with URL: $profileImageUrl');
    Widget avatar;

    if (profileImageUrl != null &&
        profileImageUrl.isNotEmpty &&
        !profileImageUrl.startsWith('http') &&
        File(profileImageUrl).existsSync()) {
      debugPrint('Using local profile image: $profileImageUrl');
      avatar = Image.file(
        File(profileImageUrl),
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          debugPrint(
              'Error loading local profile image: $error, path: $profileImageUrl');
          return Image.asset(
            'assets/images/refmmp.png',
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          );
        },
      );
    } else if (profileImageUrl != null &&
        profileImageUrl.isNotEmpty &&
        Uri.tryParse(profileImageUrl)?.isAbsolute == true) {
      debugPrint('Using network profile image: $profileImageUrl');
      avatar = CachedNetworkImage(
        imageUrl: profileImageUrl,
        cacheManager: CustomCacheManager.instance,
        width: 28,
        height: 28,
        fit: BoxFit.cover,
        placeholder: (context, url) => const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
        ),
        errorWidget: (context, url, error) {
          debugPrint('Error loading network profile image: $error, url: $url');
          return Image.asset(
            'assets/images/refmmp.png',
            width: 28,
            height: 28,
            fit: BoxFit.cover,
          );
        },
      );
    } else {
      debugPrint('Using default profile image for: $profileImageUrl');
      avatar = Image.asset(
        'assets/images/refmmp.png',
        width: 28,
        height: 28,
        fit: BoxFit.cover,
      );
    }

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: selectedIndex == index
          ? BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              shape: BoxShape.circle,
            )
          : null,
      child: CircleAvatar(
        radius: 14,
        backgroundColor: Colors.transparent,
        child: ClipOval(
          child: avatar,
        ),
      ),
    );
  }
}
