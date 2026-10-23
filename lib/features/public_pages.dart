import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/models.dart';
import '../data/repository.dart';
import 'shared.dart';
import 'account_pages.dart';
import 'discovery_widgets.dart';
import '../core/visual_theme.dart';

String categoryName(AppRepository r, String id) =>
    r.categories.where((c) => c.id == id).firstOrNull?.text('nombre') ?? id;

class CatalogPage extends StatefulWidget {
  const CatalogPage({
    super.key,
    required this.repository,
    this.favoritesOnly = false,
  });
  final AppRepository repository;
  final bool favoritesOnly;
  @override
  State<CatalogPage> createState() => _CatalogPageState();
}

class _CatalogPageState extends State<CatalogPage> {
  String search = '', category = '';
  @override
  Widget build(BuildContext context) {
    final r = widget.repository;
    final visible = r.businesses
        .where(
          (b) =>
              b.flag('publicado') &&
              (!widget.favoritesOnly || r.favorites.contains(b.id)) &&
              (category.isEmpty || b.text('categoria') == category) &&
              '${b.text('nombre')} ${b.text('zona')} ${b.text('descripcion')}'
                  .toLowerCase()
                  .contains(search.toLowerCase()),
        )
        .toList();
    return PageBody(
      children: [
        if (!widget.favoritesOnly)
          DiscoveryHero(onJoin: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Tu espacio en Vitrina Local')), body: AccountPage(repository: r))))),
        SectionTitle(
          widget.favoritesOnly ? 'Tus favoritos' : 'Elige tu próxima parada',
          widget.favoritesOnly
              ? 'Los negocios que quieres volver a visitar.'
              : 'Explora el talento y los servicios de tu zona.',
        ),
        TextField(
          onChanged: (value) => setState(() => search = value.trim()),
          decoration: const InputDecoration(
            hintText: 'Buscar un negocio, producto o zona',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: const Text('Todos'),
              selected: category.isEmpty,
              onSelected: (_) => setState(() => category = ''),
            ),
            for (final c in r.categories.where((c) => c.flag('activa')))
              ChoiceChip(
                label: Text(c.text('nombre')),
                selected: category == c.id,
                onSelected: (_) => setState(() => category = c.id),
              ),
          ],
        ),
        const SizedBox(height: 22),
        Text(
          '${visible.length} negocios para descubrir',
          style: const TextStyle(color: Color(0xFF67746C)),
        ),
        const SizedBox(height: 14),
        if (visible.isEmpty && !r.loading)
          const EmptyState(
            'No encontramos negocios',
            'Prueba otra búsqueda o vuelve pronto para ver nuevas publicaciones.',
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 850
                ? 3
                : constraints.maxWidth > 560
                ? 2
                : 1;
            final width = (constraints.maxWidth - 18 * (columns - 1)) / columns;
            return Wrap(
              spacing: 18,
              runSpacing: 4,
              children: [
                for (final b in visible)
                  SizedBox(
                    width: width,
                    child: BusinessCard(repository: r, business: b),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'Vitrina Local · Un punto de encuentro para los negocios de nuestra comunidad.',
          style: TextStyle(color: Color(0xFF67746C), fontSize: 12),
        ),
      ],
    );
  }
}

class BusinessCard extends StatelessWidget {
  const BusinessCard({
    super.key,
    required this.repository,
    required this.business,
  });
  final AppRepository repository;
  final Item business;
  @override
  Widget build(BuildContext context) => BusinessTile(
    business: business,
    category: categoryName(repository, business.text('categoria')),
    onTap: () => Navigator.push(context, MaterialPageRoute<void>(builder: (_) => BusinessDetail(repository: repository, business: business))),
  );
}

class BusinessDetail extends StatelessWidget {
  const BusinessDetail({
    super.key,
    required this.repository,
    required this.business,
    this.preview = false,
  });
  final AppRepository repository;
  final Item business;
  final bool preview;
  Future<void> open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('No se pudo abrir la aplicación de contacto.');
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) {
      final b = preview
          ? business
          : repository.businesses.where((x) => x.id == business.id).firstOrNull;
      if (b == null ||
          (!preview &&
              !b.flag('publicado') &&
              !repository.isAdmin &&
              !repository.owned.any((o) => o.id == b.id))) {
        return Scaffold(
          appBar: AppBar(title: const Text('Negocio')),
          body: const EmptyState(
            'Negocio no disponible',
            'Esta ficha ya no está publicada.',
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(
          title: Text(preview ? 'Vista previa' : 'Conoce el negocio'),
        ),
        body: PageBody(
          children: [
            imageOrArt(b.images, height: 260),
            const SizedBox(height: 24),
            SectionTitle(
              b.text('nombre'),
              '${categoryName(repository, b.text('categoria'))} · ${b.text('zona')}',
            ),
            Text(
              b.text('descripcion'),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Planea tu visita',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.place_outlined),
                      title: Text(b.text('direccion')),
                      subtitle: Text(b.text('zona')),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.schedule),
                      title: Text(b.text('horarios')),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.phone_outlined),
                      title: Text(b.text('telefono')),
                    ),
                  ],
                ),
              ),
            ),
            if (!preview)
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  ActionButton(
                    label: 'Llamar',
                    icon: Icons.phone_outlined,
                    action: () => open(
                      Uri(
                        scheme: 'tel',
                        path: b
                            .text('telefono')
                            .replaceAll(RegExp(r'[^+\d]'), ''),
                      ),
                    ),
                  ),
                  ActionButton(
                    label: 'WhatsApp',
                    icon: Icons.chat_bubble_outline,
                    action: () => open(
                      Uri.https(
                        'wa.me',
                        '/${b.text('telefono').replaceAll(RegExp(r'\D'), '')}',
                      ),
                    ),
                  ),
                  ActionButton(
                    label: 'Ver ubicación',
                    icon: Icons.map_outlined,
                    action: () => open(
                      Uri.https('www.google.com', '/maps/search/', {
                        'api': '1',
                        'query':
                            '${b.text('direccion')}, ${b.text('zona')}, Bolivia',
                      }),
                    ),
                  ),
                  ActionButton(
                    label: 'Copiar ficha',
                    icon: Icons.ios_share,
                    action: () => Clipboard.setData(
                      ClipboardData(
                        text:
                            '${b.text('nombre')}\n${b.text('descripcion')}\n${b.text('direccion')} · ${b.text('zona')}\n${b.text('telefono')}',
                      ),
                    ),
                    success: 'Información copiada para compartir.',
                  ),
                  ActionButton(
                    label: repository.favorites.contains(b.id)
                        ? 'Quitar favorito'
                        : 'Guardar favorito',
                    icon: repository.favorites.contains(b.id)
                        ? Icons.favorite
                        : Icons.favorite_border,
                    action: () async {
                      if (repository.account == null) {
                        await Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => AuthPage(repository: repository),
                          ),
                        );
                      } else {
                        await repository.toggleFavorite(b.id);
                      }
                    },
                  ),
                ],
              ),
            if (b.images.length > 1) ...[
              const SizedBox(height: 24),
              const SectionTitle('Galería', 'Más detalles de este negocio.'),
              for (final url in b.images.skip(1))
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: imageOrArt([url], height: 260),
                ),
            ],
            if (!preview) ...[
              const SizedBox(height: 28),
              const SectionTitle(
                'Novedades del negocio',
                'Promociones y anuncios vigentes.',
              ),
              for (final ad in repository.ads.where(
                (a) =>
                    a.text('negocioId') == b.id && activeAd(a, DateTime.now()),
              ))
                PublicationCard(item: ad, ad: true),
            ],
          ],
        ),
      );
    },
  );
}

class PublicationsPage extends StatelessWidget {
  const PublicationsPage({
    super.key,
    required this.repository,
    required this.ads,
  });
  final AppRepository repository;
  final bool ads;
  @override
  Widget build(BuildContext context) {
    final items = ads
        ? repository.ads.where((x) => activeAd(x, DateTime.now()))
        : repository.bulletins.where((x) => x.flag('publicado'));
    return PageBody(
      children: [
        SectionTitle(
          ads ? 'Algo nuevo en tu barrio' : 'Historias y noticias locales',
          ads
              ? 'Promociones, eventos y novedades de los negocios.'
              : 'Información para nuestra comunidad.',
        ),
        if (items.isEmpty)
          const EmptyState(
            'Pronto habrá novedades',
            'Las publicaciones aparecerán aquí cuando estén aprobadas.',
            icon: Icons.article_outlined,
          ),
        for (final item in items) PublicationCard(item: item, ad: ads),
      ],
    );
  }
}

class PublicationCard extends StatelessWidget {
  const PublicationCard({super.key, required this.item, required this.ad});
  final Item item;
  final bool ad;
  @override
  Widget build(BuildContext context) => EditorialTile(
    item: item,
    ad: ad,
    onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text(ad ? 'Anuncio' : 'Boletín')),
            body: PageBody(
              children: [
                SectionTitle(
                  item.text('titulo'),
                  ad
                      ? 'Vigente hasta ${item.text('vence').split('T').first}'
                      : 'Vitrina Local · Comunidad',
                ),
                SelectableText(
                  item.text('descripcion'),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
  );
}
