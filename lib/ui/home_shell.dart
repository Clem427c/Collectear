import 'package:flutter/material.dart';

import '../app_data.dart';
import 'tabs/bestiary_tab.dart';
import 'tabs/play_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/shop_tab.dart';
import 'tabs/social_tab.dart';
import 'theme.dart';

/// Écran principal : onglets en bas, « Jouer » au centre (style jeu mobile).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.data});
  final AppData data;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _Tab {
  const _Tab(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _HomeShellState extends State<HomeShell> {
  static const _tabs = [
    _Tab('Profil', Icons.person),
    _Tab('Boutique', Icons.storefront),
    _Tab('Jouer', Icons.explore),
    _Tab('Bestiaire', Icons.style),
    _Tab('Social', Icons.groups),
  ];
  static const _playIndex = 2;

  int _index = _playIndex;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final pages = [
      ProfileTab(data: data),
      const ShopTab(),
      PlayTab(data: data, onChanged: _refresh),
      BestiaryTab(data: data, onChanged: _refresh),
      SocialTab(data: data),
    ];
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF2E2370), AppColors.ink],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _TopBar(data: data),
              Expanded(child: IndexedStack(index: _index, children: pages)),
            ],
          ),
        ),
      ),
      bottomNavigationBar: _BottomBar(
        tabs: _tabs,
        index: _index,
        playIndex: _playIndex,
        onTap: (i) => setState(() => _index = i),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.data});
  final AppData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(
        children: [
          const Text('Collectear', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const Spacer(),
          const _Currency(icon: Icons.monetization_on, color: AppColors.gold, value: 0),
          const SizedBox(width: 8),
          const _Currency(icon: Icons.diamond, color: Color(0xFF4DD6FF), value: 0),
        ],
      ),
    );
  }
}

class _Currency extends StatelessWidget {
  const _Currency({required this.icon, required this.color, required this.value});
  final IconData icon;
  final Color color;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 12, 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 6),
        Text('$value', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ]),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.tabs, required this.index, required this.playIndex, required this.onTap});
  final List<_Tab> tabs;
  final int index;
  final int playIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF140F33),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < tabs.length; i++)
                Expanded(
                  flex: i == playIndex ? 13 : 10,
                  child: _TabButton(
                    tab: tabs[i],
                    selected: i == index,
                    highlight: i == playIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.tab, required this.selected, required this.highlight, required this.onTap});
  final _Tab tab;
  final bool selected;
  final bool highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.gold : Colors.white54;
    return InkWell(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withValues(alpha: 0.10) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: selected ? Border.all(color: AppColors.gold.withValues(alpha: 0.6), width: 1.5) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(tab.icon, color: color, size: highlight ? 32 : (selected ? 28 : 24)),
            const SizedBox(height: 2),
            Text(tab.label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}
