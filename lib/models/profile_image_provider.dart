import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileImageProvider extends ChangeNotifier {
  String? _profileImageUrl;
  String? _wallpaperUrl;
  final Box _box = Hive.box('offline_data');

  ProfileImageProvider() {
    _loadProfileImage();
    _loadWallpaper();
  }

  String? get profileImageUrl => _profileImageUrl;
  String? get wallpaperUrl => _wallpaperUrl;

  void _loadProfileImage() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _profileImageUrl = _box.get('user_profile_image_$userId',
          defaultValue: 'assets/images/refmmp.png');
    } else {
      _profileImageUrl = 'assets/images/refmmp.png';
    }
    debugPrint(
        'ProfileImageProvider initialized with profile image: $_profileImageUrl');
    notifyListeners();
  }

  void _loadWallpaper() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _wallpaperUrl = _box.get('user_wallpaper_$userId',
          defaultValue: 'assets/images/refmmp.png');
    } else {
      _wallpaperUrl = 'assets/images/refmmp.png';
    }
    debugPrint(
        'ProfileImageProvider initialized with wallpaper: $_wallpaperUrl');
    notifyListeners();
  }

  void updateProfileImage(String newImageUrl, {bool notify = true}) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _profileImageUrl = newImageUrl;
      _box.put('user_profile_image_$userId', newImageUrl);
      debugPrint('Profile image updated to: $newImageUrl, notify: $notify');
      if (notify) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
          debugPrint('notifyListeners called for profile image update');
        });
      }
    } else {
      debugPrint('No user ID, cannot update profile image');
    }
  }

  void updateWallpaper(String newWallpaperUrl, {bool notify = true}) {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      _wallpaperUrl = newWallpaperUrl;
      _box.put('user_wallpaper_$userId', newWallpaperUrl);
      debugPrint('Wallpaper updated to: $newWallpaperUrl, notify: $notify');
      if (notify) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
          debugPrint('notifyListeners called for wallpaper update');
        });
      }
    } else {
      debugPrint('No user ID, cannot update wallpaper');
    }
  }
}
