import 'package:flutter/material.dart';

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
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      selectedItemColor: Colors.blue,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
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
          : const AssetImage('assets/images/default_profile.png')
              as ImageProvider,
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
