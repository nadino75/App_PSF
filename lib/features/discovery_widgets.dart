import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/visual_theme.dart';
import 'neighborhood_art.dart';
import 'shared.dart';

class DiscoveryHero extends StatelessWidget {
  const DiscoveryHero({super.key, required this.onJoin});
  final VoidCallback onJoin;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 700;
      final compact = constraints.maxWidth < 400;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: clay,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 9),
              const Flexible(
                child: Text(
                  'GRANDES HALLAZGOS, MUY CERCA',
                  style: TextStyle(
                    fontSize: 9,
                    color: clay,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: wide ? 22 : 14),
          Text(
            'Descubre lo mejor\nde tu comunidad.',
            style: TextStyle(
              fontFamily: 'Fraunces',
              fontSize: wide
                  ? 49
                  : compact
                  ? 33
                  : 39,
              height: 1.07,
              fontWeight: FontWeight.w600,
              color: forest,
              letterSpacing: -1.2,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hay historias, sabores y talento\na la vuelta de la esquina.',
            style: TextStyle(fontSize: 13, color: muted, height: 1.65),
          ),
          SizedBox(height: wide ? 26 : 18),
          FilledButton.icon(
            onPressed: onJoin,
            icon: const Icon(Icons.add_business_outlined, size: 17),
            label: const Text('Publicar mi negocio'),
          ),
        ],
      );
      final art = ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: const NeighborhoodArt(),
      );
      return Container(
        margin: const EdgeInsets.only(bottom: 28),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F0E5),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(wide ? 32 : 23),
              child: wide
                  ? Row(
                      children: [
                        Expanded(flex: 6, child: copy),
                        const SizedBox(width: 22),
                        Expanded(
                          flex: 5,
                          child: SizedBox(height: 300, child: art),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        copy,
                        const SizedBox(height: 22),
                        SizedBox(
                          height: compact ? 136 : 190,
                          width: double.infinity,
                          child: art,
                        ),
                      ],
                    ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 13),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFDDE1D1))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border, size: 15, color: clay),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Elegir local hace grande a tu comunidad.',
                      style: TextStyle(
                        fontSize: 10,
                        color: forest,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (wide)
                    const Text(
                      'HECHO CERCA DE TI',
                      style: TextStyle(
                        fontSize: 9,
                        color: muted,
                        letterSpacing: 1.2,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class BusinessTile extends StatefulWidget {
  const BusinessTile({
    super.key,
    required this.business,
    required this.category,
    required this.onTap,
  });
  final Item business;
  final String category;
  final VoidCallback onTap;
  @override
  State<BusinessTile> createState() => _BusinessTileState();
}

class _BusinessTileState extends State<BusinessTile> {
  bool hovered = false;
  @override
  Widget build(BuildContext context) {
    final b = widget.business;
    return MouseRegion(
      onEnter: (_) => setState(() => hovered = true),
      onExit: (_) => setState(() => hovered = false),
      child: AnimatedContainer(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: hovered ? const Color(0xFF92A58B) : line),
          boxShadow: [
            BoxShadow(
              color: forest.withValues(alpha: hovered ? .08 : .025),
              blurRadius: hovered ? 22 : 8,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(22),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Stack(
                    children: [
                      imageOrArt(
                        b.images,
                        height: 184,
                        icon: b.text('categoria') == 'gastronomia'
                            ? Icons.local_cafe_outlined
                            : Icons.storefront_outlined,
                      ),
                      Positioned(
                        left: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: paper,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            widget.category,
                            style: const TextStyle(
                              fontSize: 10,
                              color: forest,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.text('nombre'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontSize: 25,
                          height: 1.15,
                          letterSpacing: -.4,
                          color: forest,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        b.text('descripcion'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: muted,
                          height: 1.6,
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 15),
                        child: Divider(height: 1),
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.place_outlined,
                            size: 15,
                            color: clay,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              b.text('zona'),
                              style: const TextStyle(
                                fontSize: 11,
                                color: muted,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEDF1E7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.arrow_outward,
                              size: 18,
                              color: forest,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EditorialTile extends StatelessWidget {
  const EditorialTile({
    super.key,
    required this.item,
    required this.ad,
    required this.onTap,
  });
  final Item item;
  final bool ad;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 54,
              decoration: BoxDecoration(
                color: ad ? const Color(0xFFF5E5C6) : const Color(0xFFE6EDD9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                ad ? Icons.campaign_outlined : Icons.auto_stories_outlined,
                color: ad ? clay : forest,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad ? 'EN LA VITRINA' : 'VIDA EN COMUNIDAD',
                    style: const TextStyle(
                      fontSize: 9,
                      color: clay,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.text('titulo'),
                    style: const TextStyle(
                      fontFamily: 'Fraunces',
                      fontSize: 23,
                      color: forest,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    item.text('descripcion'),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Text(
                        ad ? 'Ver anuncio' : 'Leer boletín',
                        style: const TextStyle(
                          fontSize: 11,
                          color: forest,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
