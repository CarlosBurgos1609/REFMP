import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ProfileImageProvider extends ChangeNotifier {
  String? _profileImageUrl;
  String? _wallpaperUrl;
  String? _userTable;
  final SupabaseClient supabase = Supabase.instance.client;

  ProfileImageProvider() {
    _initialize();
  }

  String? get profileImageUrl => _profileImageUrl;
  String? get wallpaperUrl => _wallpaperUrl;
  String? get userTable => _userTable;

  Future<void> _initialize() async {
    await _loadFromCache();
    await fetchUserTable();
  }

  Future<void> _loadFromCache() async {
    // Check if box is open before accessing
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Opened offline_data box in ProfileImageProvider');
    }
    final box = Hive.box('offline_data');
    final userId = supabase.auth.currentUser?.id;
    if (userId != null) {
      _profileImageUrl =
          box.get('user_profile_image_$userId', defaultValue: null);
      _wallpaperUrl = box.get('user_wallpaper_$userId', defaultValue: null);
      _userTable = box.get('user_table_$userId', defaultValue: null);
      debugPrint(
          'Loaded from cache: profileImageUrl=$_profileImageUrl, wallpaperUrl=$_wallpaperUrl, userTable=$_userTable');
      notifyListeners();
    }
  }

  Future<void> fetchUserTable() async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('No user ID found, cannot fetch user table');
      return;
    }

    // Check if box is open
    if (!Hive.isBoxOpen('offline_data')) {
      await Hive.openBox('offline_data');
      debugPrint('Opened offline_data box in fetchUserTable');
    }
    final box = Hive.box('offline_data');
    final cacheKey = 'user_table_$userId';

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOnline = connectivityResult != ConnectivityResult.none;

      if (!isOnline) {
        _userTable = box.get(cacheKey, defaultValue: null);
        debugPrint('Loaded user table offline: $_userTable');
        notifyListeners();
        return;
      }

      List<String> tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents',
        'directors'
      ];
      String? foundTable;
      for (String table in tables) {
        final response = await supabase
            .from(table)
            .select('user_id')
            .eq('user_id', userId)
            .maybeSingle();
        if (response != null) {
          foundTable = table;
          break;
        }
      }

      if (foundTable != null) {
        _userTable = foundTable;
        await box.put(cacheKey, foundTable);
        debugPrint('Fetched user table online: $foundTable');
        notifyListeners();
      } else {
        debugPrint('No user table found for user: $userId');
      }
    } catch (e) {
      debugPrint('Error fetching user table: $e');
      _userTable = box.get(cacheKey, defaultValue: null);
      notifyListeners();
    }
  }

  String? getUserTable() {
    if (_userTable == null) {
      debugPrint('User table is null, attempting to fetch');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        fetchUserTable();
      });
    }
    return _userTable;
  }

  void updateProfileImage(String imageUrl,
      {required bool notify, bool isOnline = true, String? userTable}) {
    _profileImageUrl = imageUrl;
    if (userTable != null) {
      _userTable = userTable;
      final userId = supabase.auth.currentUser?.id;
      if (userId != null) {
        if (!Hive.isBoxOpen('offline_data')) {
          Hive.openBox('offline_data').then((box) {
            box.put('user_table_$userId', userTable);
            debugPrint('Saved user table to Hive: $userTable');
          });
        } else {
          Hive.box('offline_data').put('user_table_$userId', userTable);
          debugPrint('Saved user table to Hive: $userTable');
        }
      }
    }
    if (notify) {
      debugPrint('Updating profile image: $imageUrl, notify=$notify');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void updateWallpaper(String imageUrl,
      {required bool notify, bool isOnline = true}) {
    _wallpaperUrl = imageUrl;
    if (notify) {
      debugPrint('Updating wallpaper: $imageUrl, notify=$notify');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }
}
