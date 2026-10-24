import 'dart:async';

import 'package:flutter/material.dart';

import 'data/repository.dart';
import 'core/visual_theme.dart';
import 'features/shared.dart';
import 'features/public_pages.dart';
import 'features/account_pages.dart';
import 'features/admin_page.dart';

class VitrinaApp extends StatelessWidget {
  const VitrinaApp({super.key, required this.repository});
  final AppRepository repository;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Vitrina Local',
    debugShowCheckedModeBanner: false,
    theme: vitrinaTheme(),
    home: HomeShell(repository: repository),
  );
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int selected = 0;
  Timer? timer;
  @override
  void initState() {
    super.initState();
    timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final r = widget.repository;
      final labels = [
        'Descubrir',
        'Anuncios',
        'Boletines',
        'Mi cuenta',
        if (r.isAdmin) 'Administrar',
      ];
      final icons = [
        Icons.explore_outlined,
        Icons.campaign_outlined,
        Icons.article_outlined,
        Icons.person_outline,
        if (r.isAdmin) Icons.admin_panel_settings_outlined,
      ];
      final index = selected < labels.length ? selected : 0;
      final wide = MediaQuery.sizeOf(context).width >= 900;
      final content = switch (index) {
        0 => CatalogPage(repository: r),
        1 => PublicationsPage(repository: r, ads: true),
        2 => PublicationsPage(repository: r, ads: false),
        3 => AccountPage(repository: r),
        _ => AdminPage(repository: r),
      };
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: ink,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 23,
                  color: cream,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Vitrina Local',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: ink,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            if (wide)
              const Padding(
                padding: EdgeInsets.only(right: 24),
                child: Text(
                  'DESCUBRE. CONECTA. COMPRA LOCAL.',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.4,
                    color: muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            if (r.account != null)
              IconButton(
                tooltip: 'Notificaciones',
                icon: Badge(
                  isLabelVisible:
                      r.notices.any((n) => !n.flag('leida')) ||
                      r.news.any((n) => !r.readNews.contains(n.id)),
                  child: const Icon(Icons.notifications_none),
                ),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => NotificationsPage(repository: r),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: r.refresh,
              icon: const Icon(Icons.refresh),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            if (r.demo)
              Container(
                width: double.infinity,
                color: const Color(0xFFF6E8C4),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 7,
                ),
                child: const Text(
                  'DEMOSTRACIÓN · Datos ficticios, guardados solo durante esta sesión.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12),
                ),
              ),
            if (r.error != null)
              MaterialBanner(
                content: Text(r.error!),
                actions: [
                  TextButton(
                    onPressed: r.refresh,
                    child: const Text('Reintentar'),
                  ),
                  TextButton(
                    onPressed: r.clearError,
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            if (r.loading) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: Row(
                children: [
                  if (wide)
                    Container(
                      decoration: const BoxDecoration(
                        border: Border(right: BorderSide(color: line)),
                      ),
                      child: NavigationRail(
                        extended: true,
                        backgroundColor: cream,
                        indicatorColor: const Color(0xFFE6EDDD),
                        selectedLabelTextStyle: const TextStyle(
                          fontFamily: 'Manrope',
                          color: forest,
                          fontWeight: FontWeight.w800,
                        ),
                        unselectedLabelTextStyle: const TextStyle(
                          fontFamily: 'Manrope',
                          color: muted,
                        ),
                        selectedIconTheme: const IconThemeData(color: forest),
                        unselectedIconTheme: const IconThemeData(color: muted),
                        minExtendedWidth: 208,
                        leading: const Padding(
                          padding: EdgeInsets.fromLTRB(24, 22, 24, 22),
                          child: Text(
                            'EXPLORA TU COMUNIDAD',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: muted,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        selectedIndex: index,
                        onDestinationSelected: (i) =>
                            setState(() => selected = i),
                        destinations: [
                          for (var i = 0; i < labels.length; i++)
                            NavigationRailDestination(
                              icon: Icon(icons[i]),
                              label: Text(labels[i]),
                            ),
                        ],
                      ),
                    ),
                  Expanded(child: content),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: index,
                labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                onDestinationSelected: (i) => setState(() => selected = i),
                destinations: [
                  for (var i = 0; i < labels.length; i++)
                    NavigationDestination(
                      icon: Icon(icons[i]),
                      label: labels[i],
                    ),
                ],
              ),
      );
    },
  );
}
