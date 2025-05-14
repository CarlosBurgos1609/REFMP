import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:refmp/theme/theme_provider.dart';

class CustomNavigationBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;
  final String? profileImageUrl;

  const CustomNavigationBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.profileImageUrl,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      backgroundColor: themeProvider.isDarkMode
          ? Color.fromARGB(255, 2, 2, 2)
          : Color.fromARGB(255, 255, 255, 255),
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
          label: 'Recompensas',
        ),
        BottomNavigationBarItem(
          icon: _buildProfileIcon(4),
          label: 'Perfil',
        ),
      ],
    );
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
                color: Colors.blue.withOpacity(0.15), // fondo azul transparente
                shape: BoxShape.circle,
              )
            : null,
        child: Icon(
          selectedIndex == index ? selectedIcon : icon,
          color: selectedIndex == index ? Colors.blue : Colors.grey,
        ),
      ),
      label: label,
    );
  }

  Widget _buildProfileIcon(int index) {
    final avatar = CircleAvatar(
      radius: 14,
      backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
          ? NetworkImage(profileImageUrl!)
          : const AssetImage('assets/images/logo1.png') as ImageProvider,
      backgroundColor: Colors.transparent,
    );

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: selectedIndex == index
          ? BoxDecoration(
              color: Colors.blue.withOpacity(0.15),
              shape: BoxShape.circle,
            )
          : null,
      child: avatar,
    );
  }
}
