import 'package:flutter/material.dart';
import 'package:refmp/interfaces/home.dart';
import 'package:refmp/interfaces/menu/graduates.dart';
import 'package:refmp/interfaces/menu/info.dart';
import 'package:refmp/interfaces/menu/learn.dart';
import 'package:refmp/interfaces/menu/settings.dart';
import 'package:refmp/interfaces/menu/contacts.dart';
import 'package:refmp/interfaces/menu/events.dart';
import 'package:refmp/interfaces/menu/headquarters.dart';
import 'package:refmp/interfaces/menu/instruments.dart';
import 'package:refmp/interfaces/menu/locations.dart';
import 'package:refmp/interfaces/menu/notification.dart';
import 'package:refmp/interfaces/menu/profile.dart';
import 'package:refmp/interfaces/menu/students.dart';
import 'package:refmp/interfaces/menu/teachers.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // Import url_launcher

class Menu {
  static const Map<int, String> _titles = {
    0: 'Inicio',
    1: 'Perfil',
    2: 'Sedes',
    3: 'Notificaciones',
    4: 'Instrumentos',
    5: 'Eventos',
    6: 'Contactos',
    7: 'Ubicaciones',
    8: 'Configuración',
    9: 'Estudiantes',
    10: 'Egresados',
    11: 'Información',
    12: 'Aprende',
    13: 'Profesores',
    14: 'Facebook',
    15: 'WhatsApp',
    16: 'TikTok',
    17: 'Instagram',
    18: 'Página Web',
    19: 'Youtube',
  };

  static IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home;
      case 1:
        return Icons.account_circle_rounded;
      case 2:
        return Icons.business_rounded;
      case 3:
        return Icons.circle_notifications;
      case 4:
        return Icons.piano_rounded;
      case 5:
        return Icons.calendar_month_rounded;
      case 6:
        return Icons.contacts_rounded;
      case 7:
        return Icons.map_outlined;
      case 8:
        return Icons.settings;
      case 9:
        return Icons.supervised_user_circle;
      case 10:
        return Icons.school_rounded;
      case 11:
        return Icons.info_outline_rounded;
      case 12:
        return Icons.sports_esports_rounded;
      case 13:
        return Icons.badge;
      case 14:
        return FontAwesomeIcons.facebook;
      case 15:
        return FontAwesomeIcons.whatsapp;
      case 16:
        return FontAwesomeIcons.tiktok;
      case 17:
        return FontAwesomeIcons.instagram;
      case 18:
        return FontAwesomeIcons.globe; // Icon for website
      case 19:
        return FontAwesomeIcons.youtube; // Icon for website
      default:
        return Icons.error;
    }
  }

  static ValueNotifier<int> currentIndexNotifier = ValueNotifier<int>(0);

  static Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }

  static void _navigateToPage(BuildContext context, int index) {
    // Social media and website URLs
    const Map<int, String> socialMediaUrls = {
      14: 'https://www.facebook.com/redescuelasfm',
      15: 'https://chat.whatsapp.com/BQsO6B9GkAvKOw7r11RjLg',
      16: 'https://www.tiktok.com/@sempasto',
      17: 'https://www.instagram.com/red.escuelas.pasto/',
      18: 'https://www.pasto.gov.co/index.php/component/content/category/189-red-de-escuelas-de-formacion-musical?Itemid=101',
      19: 'https://www.youtube.com/@reddeescuelasdeformacionmu8424/videos',
    };

    // Check if the index corresponds to a social media link
    if (socialMediaUrls.containsKey(index)) {
      _launchURL(socialMediaUrls[index]!);
      return;
    }

    // Internal app navigation for other pages
    final routes = {
      0: MaterialPageRoute(
          settings: const RouteSettings(name: 'Inicio'),
          builder: (context) => const HomePage(title: "Inicio")),
      1: MaterialPageRoute(
          settings: const RouteSettings(name: 'Perfil'),
          builder: (context) => const ProfilePage(title: "Perfil")),
      2: MaterialPageRoute(
          settings: const RouteSettings(name: 'Sedes'),
          builder: (context) => const HeadquartersPage(title: "Sedes")),
      3: MaterialPageRoute(
          settings: const RouteSettings(name: 'Notificaciones'),
          builder: (context) =>
              const NotificationPage(title: "Notificaciones")),
      4: MaterialPageRoute(
          settings: const RouteSettings(name: 'Instrumentos'),
          builder: (context) => const InstrumentsPage(
                title: "Instrumentos",
              )),
      5: MaterialPageRoute(
          settings: const RouteSettings(name: 'Eventos'),
          builder: (context) => const EventsPage(title: "Eventos")),
      6: MaterialPageRoute(
          settings: const RouteSettings(name: 'Contactos'),
          builder: (context) => const ContactsPage(title: "Contactos")),
      7: MaterialPageRoute(
          settings: const RouteSettings(name: 'Ubicaciones'),
          builder: (context) => const LocationsPage(title: "Ubicaciones")),
      8: MaterialPageRoute(
          settings: const RouteSettings(name: 'Configuración'),
          builder: (context) => const SettingsPage(title: "Configuración")),
      9: MaterialPageRoute(
          settings: const RouteSettings(name: 'Estudiantes'),
          builder: (context) => const StudentsPage(title: "Estudiantes")),
      10: MaterialPageRoute(
          settings: const RouteSettings(name: 'Egresados'),
          builder: (context) => const GraduatesPage(title: "Egresados")),
      11: MaterialPageRoute(
          settings: const RouteSettings(name: 'Información'),
          builder: (context) => const InfoPage(title: "Información")),
      12: MaterialPageRoute(
          settings: const RouteSettings(name: 'Aprende y Juega'),
          builder: (context) => const LearnPage(title: "Aprende y Juega")),
      13: MaterialPageRoute(
          settings: const RouteSettings(name: 'Profesores'),
          builder: (context) => const TeachersPage(title: "Profesores")),
    };

    // Update the current page index
    currentIndexNotifier.value = index;

    Navigator.pushReplacement(context, routes[index]!);
  }

  static Future<Map<String, dynamic>?> _loadUserProfile() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user != null) {
      final tables = [
        'users',
        'students',
        'graduates',
        'teachers',
        'advisors',
        'parents',
        'guests'
      ];
      for (final table in tables) {
        final response = await supabase
            .from(table)
            .select()
            .eq('user_id', user.id)
            .maybeSingle();
        if (response != null) {
          return response;
        }
      }
    }
    return null;
  }

  static Future<bool> _canSeeTeachersMenu() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    // Pueden ver: teachers, users (admin), advisors
    final tables = ['teachers', 'users', 'advisors'];
    for (final table in tables) {
      final response = await supabase
          .from(table)
          .select()
          .eq('user_id', user.id)
          .maybeSingle();
      if (response != null) return true;
    }
    return false;
  }

  static Future<bool>? _canSeeTeachersMenuFuture;

  static Future<bool> _getCanSeeTeachersMenuFuture() {
    _canSeeTeachersMenuFuture ??= _canSeeTeachersMenu();
    return _canSeeTeachersMenuFuture!;
  }

  static Future<bool> _isStudentOrParent() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final isStudent = await supabase
        .from('students')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    if (isStudent != null) return true;

    final isParent = await supabase
        .from('parents')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return isParent != null;
  }

  static Future<bool> _isGuest() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) return false;

    final isGuest = await supabase
        .from('guests')
        .select()
        .eq('user_id', user.id)
        .maybeSingle();
    return isGuest != null;
  }

  static Future<bool>? _isStudentOrParentFuture;
  // ignore: unused_element
  static Future<bool> _getIsStudentOrParentFuture() {
    _isStudentOrParentFuture ??= _isStudentOrParent();
    return _isStudentOrParentFuture!;
  }

  static Future<bool>? _isGuestFuture;
  static Future<bool> _getIsGuestFuture() {
    _isGuestFuture ??= _isGuest();
    return _isGuestFuture!;
  }

  static void clearRoleCache() {
    _isStudentOrParentFuture = null;
    _canSeeTeachersMenuFuture = null;
    _isGuestFuture = null;
  }

  static ValueListenableBuilder<int> buildDrawer(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: currentIndexNotifier,
      builder: (context, currentIndex, _) {
        return Drawer(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              DrawerHeader(
                padding: const EdgeInsets.all(0),
                decoration: BoxDecoration(color: Colors.blue),
                child: Container(
                  decoration: const BoxDecoration(
                    image: DecorationImage(
                      fit: BoxFit.fill,
                      image: AssetImage("assets/images/pasto.png"),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FutureBuilder(
                      future: _loadUserProfile(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          // return const Center(
                          //     child: CircularProgressIndicator(
                          //   color: Colors.blue,
                          // ));
                        }
                        if (snapshot.hasError || snapshot.data == null) {
                          return UserAccountsDrawerHeader(
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            accountName: Text(
                              "Sin Conexion a internet",
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 15,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            currentAccountPicture: GestureDetector(
                              onTap: () {
                                currentIndexNotifier.value = 1;
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const ProfilePage(title: "Perfil"),
                                  ),
                                );
                              },
                              child: CircleAvatar(
                                backgroundColor: Colors.blue,
                                backgroundImage: const AssetImage(
                                    "assets/images/refmmp.png"),
                              ),
                            ),
                            accountEmail: null,
                          );
                        }

                        final userProfile =
                            snapshot.data as Map<String, dynamic>;

                        return UserAccountsDrawerHeader(
                          decoration: BoxDecoration(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          accountName: Text(
                            "${userProfile['first_name'] ?? 'Usuario'} ${userProfile['last_name'] ?? ''}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          accountEmail: Text(
                            userProfile['charge'] ?? "No tiene Cargo",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          currentAccountPicture: GestureDetector(
                            onTap: () {
                              currentIndexNotifier.value = 1;
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfilePage(title: "Perfil"),
                                ),
                              );
                            },
                            child: CircleAvatar(
                              backgroundColor: Colors.blue,
                              backgroundImage: userProfile['profile_image'] !=
                                          null &&
                                      userProfile['profile_image'].isNotEmpty
                                  ? NetworkImage(userProfile['profile_image'])
                                      as ImageProvider
                                  : const AssetImage(
                                      "assets/images/refmmp.png"),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              // Main menu items - hide 'Aprende' (12) for guests
              FutureBuilder<bool>(
                future: Menu._getIsGuestFuture(),
                builder: (context, snapshot) {
                  final isGuest = snapshot.hasData && snapshot.data == true;
                  final menuItems = isGuest
                      ? [0, 1, 2, 4, 5] // Sin 'Aprende' para invitados
                      : [0, 1, 2, 4, 5, 12]; // Con 'Aprende' para otros

                  return Column(
                    children: menuItems.map((index) {
                      return ListTile(
                        leading: Icon(Menu._getIcon(index),
                            color: currentIndex == index
                                ? Colors.blue
                                : Colors.grey),
                        title: Text(
                          _titles[index]!,
                          style: TextStyle(
                            color: currentIndex == index
                                ? Colors.blue
                                : Colors.grey,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          Menu._navigateToPage(context, index);
                        },
                      );
                    }).toList(),
                  );
                },
              ),

              // User-related items solo para teachers, users (admin) y advisors
              FutureBuilder<bool>(
                future: Menu._getCanSeeTeachersMenuFuture(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const SizedBox.shrink();
                  }
                  if (snapshot.hasData && snapshot.data == true) {
                    // Mostrar sección de usuarios para teachers, users (admin) y advisors
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Divider(),
                        const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                          child: Text(
                            "Usuarios",
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Estudiantes y Egresados
                        ...[9, 10].map((index) {
                          return ListTile(
                            leading: Icon(Menu._getIcon(index),
                                color: currentIndex == index
                                    ? Colors.blue
                                    : Colors.grey),
                            title: Text(
                              _titles[index]!,
                              style: TextStyle(
                                color: currentIndex == index
                                    ? Colors.blue
                                    : Colors.grey,
                              ),
                            ),
                            onTap: () {
                              Navigator.pop(context);
                              Menu._navigateToPage(context, index);
                            },
                          );
                        }),
                        // Profesores
                        ListTile(
                          leading: Icon(Menu._getIcon(13),
                              color: currentIndex == 13
                                  ? Colors.blue
                                  : Colors.grey),
                          title: Text(
                            _titles[13]!,
                            style: TextStyle(
                              color: currentIndex == 13
                                  ? Colors.blue
                                  : Colors.grey,
                            ),
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            Menu._navigateToPage(context, 13);
                          },
                        ),
                      ],
                    );
                  }
                  // Si no tiene permiso, no muestra nada
                  return const SizedBox.shrink();
                },
              ),

              const Divider(),
              // Notifications, contacts, settings, and info
              ...[3, 6, 8, 11].map((index) {
                return ListTile(
                  leading: Icon(Menu._getIcon(index),
                      color: currentIndex == index ? Colors.blue : Colors.grey),
                  title: Text(
                    _titles[index]!,
                    style: TextStyle(
                      color: currentIndex == index ? Colors.blue : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Menu._navigateToPage(context, index);
                  },
                );
              }),
              const Divider(),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 18, vertical: 5),
                child: Text(
                  "Redes Sociales",
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Social media and website links
              ...[14, 15, 16, 17, 19, 18].map((index) {
                return ListTile(
                  leading: Icon(Menu._getIcon(index),
                      color: currentIndex == index ? Colors.blue : Colors.grey),
                  title: Text(
                    _titles[index]!,
                    style: TextStyle(
                      color: currentIndex == index ? Colors.blue : Colors.grey,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Menu._navigateToPage(context, index);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class RoleAwareDrawer extends StatefulWidget {
  final int currentIndex;
  const RoleAwareDrawer({super.key, required this.currentIndex});

  @override
  State<RoleAwareDrawer> createState() => _RoleAwareDrawerState();
}

class _RoleAwareDrawerState extends State<RoleAwareDrawer> {
  bool? isStudentOrParent;
  bool? canSeeTeachers;
  bool? isGuest;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    final isSP = await Menu._isStudentOrParent();
    final canSeeT = await Menu._canSeeTeachersMenu();
    final isG = await Menu._isGuest();
    if (mounted) {
      setState(() {
        isStudentOrParent = isSP;
        canSeeTeachers = canSeeT;
        isGuest = isG;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isStudentOrParent == null ||
        canSeeTeachers == null ||
        isGuest == null) {
      // Loader solo mientras se consulta el rol
      return const Drawer(
        child: Center(child: CircularProgressIndicator(color: Colors.blue)),
      );
    }
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            padding: const EdgeInsets.all(0),
            decoration: BoxDecoration(color: Colors.blue),
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  fit: BoxFit.fill,
                  image: AssetImage("assets/images/pasto.png"),
                ),
              ),
              child: Align(
                alignment: Alignment.bottomLeft,
                child: FutureBuilder(
                  future: Menu._loadUserProfile(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // return const Center(
                      //     child: CircularProgressIndicator(
                      //   color: Colors.blue,
                      // ));
                    }
                    if (snapshot.hasError || snapshot.data == null) {
                      return UserAccountsDrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        accountName: Text(
                          "Sin Conexion a internet",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        currentAccountPicture: GestureDetector(
                          onTap: () {
                            Menu.currentIndexNotifier.value = 1;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const ProfilePage(title: "Perfil"),
                              ),
                            );
                          },
                          child: CircleAvatar(
                            backgroundColor: Colors.blue,
                            backgroundImage:
                                const AssetImage("assets/images/refmmp.png"),
                          ),
                        ),
                        accountEmail: null,
                      );
                    }

                    final userProfile = snapshot.data as Map<String, dynamic>;

                    return UserAccountsDrawerHeader(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      accountName: Text(
                        "${userProfile['first_name'] ?? 'Usuario'} ${userProfile['last_name'] ?? ''}",
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      accountEmail: Text(
                        userProfile['charge'] ?? "No tiene Cargo",
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.blue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      currentAccountPicture: GestureDetector(
                        onTap: () {
                          Menu.currentIndexNotifier.value = 1;
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ProfilePage(title: "Perfil"),
                            ),
                          );
                        },
                        child: CircleAvatar(
                          backgroundColor: Colors.blue,
                          backgroundImage: userProfile['profile_image'] !=
                                      null &&
                                  userProfile['profile_image'].isNotEmpty
                              ? NetworkImage(userProfile['profile_image'])
                                  as ImageProvider
                              : const AssetImage("assets/images/refmmp.png"),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
          // Main menu items - hide 'Aprende' (12) for guests
          FutureBuilder<bool>(
            future: Menu._getIsGuestFuture(),
            builder: (context, snapshot) {
              final isGuest = snapshot.hasData && snapshot.data == true;
              final menuItems = isGuest
                  ? [0, 1, 2, 4, 5] // Sin 'Aprende' para invitados
                  : [0, 1, 2, 4, 5, 12]; // Con 'Aprende' para otros

              return Column(
                children: menuItems.map((index) {
                  return ListTile(
                    leading: Icon(Menu._getIcon(index),
                        color: widget.currentIndex == index
                            ? Colors.blue
                            : Colors.grey),
                    title: Text(
                      Menu._titles[index]!,
                      style: TextStyle(
                        color: widget.currentIndex == index
                            ? Colors.blue
                            : Colors.grey,
                      ),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      Menu._navigateToPage(context, index);
                    },
                  );
                }).toList(),
              );
            },
          ),
          const Divider(),
          if (canSeeTeachers == true) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Text(
                "Usuarios",
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...[9, 10].map((index) {
              return ListTile(
                leading: Icon(Menu._getIcon(index),
                    color: widget.currentIndex == index
                        ? Colors.blue
                        : Colors.grey),
                title: Text(
                  Menu._titles[index]!,
                  style: TextStyle(
                    color: widget.currentIndex == index
                        ? Colors.blue
                        : Colors.grey,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  Menu._navigateToPage(context, index);
                },
              );
            }),
            ListTile(
              leading: Icon(Menu._getIcon(13),
                  color: widget.currentIndex == 13 ? Colors.blue : Colors.grey),
              title: Text(
                Menu._titles[13]!,
                style: TextStyle(
                  color: widget.currentIndex == 13 ? Colors.blue : Colors.grey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Menu._navigateToPage(context, 13);
              },
            ),
          ],
          // Notifications, contacts, settings, and info
          ...[3, 6, 8, 11].map((index) {
            return ListTile(
              leading: Icon(Menu._getIcon(index),
                  color:
                      widget.currentIndex == index ? Colors.blue : Colors.grey),
              title: Text(
                Menu._titles[index]!,
                style: TextStyle(
                  color:
                      widget.currentIndex == index ? Colors.blue : Colors.grey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Menu._navigateToPage(context, index);
              },
            );
          }),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 18, vertical: 5),
            child: Text(
              "Redes Sociales",
              style: TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // Social media and website links
          ...[14, 15, 16, 17, 19, 18].map((index) {
            return ListTile(
              leading: Icon(Menu._getIcon(index),
                  color:
                      widget.currentIndex == index ? Colors.blue : Colors.grey),
              title: Text(
                Menu._titles[index]!,
                style: TextStyle(
                  color:
                      widget.currentIndex == index ? Colors.blue : Colors.grey,
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                Menu._navigateToPage(context, index);
              },
            );
          }),
        ],
      ),
    );
  }
}
