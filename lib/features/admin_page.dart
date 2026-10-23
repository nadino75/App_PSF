import 'package:flutter/material.dart';

import '../core/models.dart';
import '../data/repository.dart';
import 'shared.dart';
import 'account_pages.dart';
import 'public_pages.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String section = 'Solicitudes';
  Future<void> category([Item? item]) async {
    final name = await askText(
      context,
      'Nombre de la categoría',
      initial: item?.text('nombre') ?? '',
    );
    if (name == null || !mounted) return;
    await perform(
      context,
      () => widget.repository.editorial({
        'tipo': 'categoria',
        'id': item?.id ?? widget.repository.newId(),
        'nombre': name,
        'activa': item?.flag('activa') ?? true,
      }),
      success: 'Categoría guardada.',
    );
  }

  Future<void> bulletin([Item? item]) async {
    final title = await askText(
      context,
      'Título del boletín',
      initial: item?.text('titulo') ?? '',
    );
    if (title == null || !mounted) return;
    final body = await askText(
      context,
      'Contenido del boletín',
      initial: item?.text('descripcion') ?? '',
    );
    if (body == null || !mounted) return;
    await perform(
      context,
      () => widget.repository.editorial({
        'tipo': 'boletin',
        'id': item?.id ?? widget.repository.newId(),
        'titulo': title,
        'descripcion': body,
        'publicado': true,
      }),
      success: 'Boletín publicado.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.repository;
    if (!r.isAdmin) {
      return const EmptyState(
        'Acceso restringido',
        'Se requiere una cuenta de administrador.',
      );
    }
    final pending = r.requests
        .where((s) => s.text('estado') == 'pendiente')
        .toList();
    return PageBody(
      children: [
        SectionTitle(
          'Cuidemos nuestra vitrina',
          '${pending.length} solicitudes pendientes · ${r.businesses.where((b) => b.flag('publicado')).length} negocios publicados',
        ),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final label in [
              'Solicitudes',
              'Negocios',
              'Categorías',
              'Anuncios',
              'Boletines',
              'Historial',
            ])
              ChoiceChip(
                label: Text(label),
                selected: section == label,
                onSelected: (_) => setState(() => section = label),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (section == 'Solicitudes') ...[
          if (pending.isEmpty)
            const EmptyState(
              'No hay revisiones pendientes',
              'Las nuevas solicitudes aparecerán aquí.',
              icon: Icons.task_alt,
            ),
          for (final s in pending)
            RequestCard(
              repository: r,
              request: s,
              onReview: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ReviewPage(repository: r, requestId: s.id),
                ),
              ),
            ),
        ],
        if (section == 'Categorías') ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: category,
              icon: const Icon(Icons.add),
              label: const Text('Nueva categoría'),
            ),
          ),
          const SizedBox(height: 20),
          for (final c in r.categories)
            Card(
              child: ListTile(
                title: Text(c.text('nombre')),
                subtitle: Text(c.flag('activa') ? 'Activa' : 'Inactiva'),
                leading: IconButton(
                  tooltip: 'Editar categoría',
                  onPressed: () => category(c),
                  icon: const Icon(Icons.edit_outlined),
                ),
                trailing: Switch(
                  value: c.flag('activa'),
                  onChanged: (v) => perform(
                    context,
                    () => r.editorial({
                      'tipo': 'categoria',
                      'id': c.id,
                      'nombre': c.text('nombre'),
                      'activa': v,
                    }),
                  ),
                ),
              ),
            ),
        ],
        if (section == 'Negocios') ...[
          if (r.businesses.isEmpty)
            const EmptyState(
              'No hay negocios',
              'Se agregarán cuando apruebes una solicitud.',
            ),
          for (final b in r.businesses)
            Card(
              child: ListTile(
                title: Text(b.text('nombre')),
                subtitle: Text(
                  b.flag('publicado') ? 'Publicado' : 'Despublicado',
                ),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => BusinessDetail(repository: r, business: b),
                  ),
                ),
                trailing: Switch(
                  value: b.flag('publicado'),
                  onChanged: (v) => perform(
                    context,
                    () => r.editorial({
                      'tipo': 'negocio',
                      'id': b.id,
                      'publicado': v,
                    }),
                  ),
                ),
              ),
            ),
        ],
        if (section == 'Anuncios') ...[
          if (r.ads.isEmpty)
            const EmptyState(
              'No hay anuncios',
              'Aprueba una solicitud de anuncio para publicarlo.',
            ),
          for (final a in r.ads)
            Card(
              child: ListTile(
                title: Text(a.text('titulo')),
                subtitle: Text(
                  activeAd(a, DateTime.now())
                      ? 'Vigente'
                      : 'Inactivo o vencido',
                ),
                trailing: a.flag('publicado')
                    ? IconButton(
                        tooltip: 'Despublicar anuncio',
                        icon: const Icon(Icons.visibility_off_outlined),
                        onPressed: () => perform(
                          context,
                          () => r.editorial({'tipo': 'anuncio', 'id': a.id}),
                        ),
                      )
                    : null,
              ),
            ),
        ],
        if (section == 'Boletines') ...[
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: bulletin,
              icon: const Icon(Icons.add),
              label: const Text('Publicar boletín'),
            ),
          ),
          const SizedBox(height: 20),
          for (final b in r.bulletins)
            Card(
              child: ListTile(
                title: Text(b.text('titulo')),
                subtitle: Text(
                  b.flag('publicado') ? 'Publicado' : 'Despublicado',
                ),
                leading: IconButton(
                  tooltip: 'Editar boletín',
                  onPressed: () => bulletin(b),
                  icon: const Icon(Icons.edit_outlined),
                ),
                trailing: Switch(
                  value: b.flag('publicado'),
                  onChanged: (v) => perform(
                    context,
                    () => r.editorial({
                      'tipo': 'boletin',
                      'id': b.id,
                      'titulo': b.text('titulo'),
                      'descripcion': b.text('descripcion'),
                      'publicado': v,
                    }),
                  ),
                ),
              ),
            ),
        ],
        if (section == 'Historial') ...[
          if (r.history.isEmpty)
            const EmptyState(
              'Todavía no hay decisiones',
              'Cada resolución quedará registrada aquí.',
            ),
          for (final h in r.history)
            Card(
              child: ListTile(
                title: Text('Solicitud ${h.id}'),
                subtitle: Text(
                  '${h.text('motivo')}\nResponsable: ${h.text('revisorId')}\nFecha: ${h.text('creado')}',
                ),
                trailing: StatusChip(h.text('estado')),
              ),
            ),
        ],
      ],
    );
  }
}

class ReviewPage extends StatefulWidget {
  const ReviewPage({
    super.key,
    required this.repository,
    required this.requestId,
  });
  final AppRepository repository;
  final String requestId;
  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  bool busy = false;
  Future<void> decide(bool approve) async {
    final reason = await askText(
      context,
      approve
          ? 'Aprobar solicitud · comentario opcional'
          : 'Motivo del rechazo',
      required: !approve,
    );
    if (reason == null || !mounted) return;
    setState(() => busy = true);
    final ok = await perform(
      context,
      () => widget.repository.resolve(widget.requestId, approve, reason),
      success: approve
          ? 'Solicitud aprobada y contenido publicado.'
          : 'Solicitud rechazada. Se notificó el motivo al solicitante.',
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.repository,
    builder: (context, _) {
      final r = widget.repository;
      final s = r.requests.where((s) => s.id == widget.requestId).firstOrNull;
      if (!r.isAdmin || s == null) {
        return Scaffold(
          appBar: AppBar(),
          body: const EmptyState(
            'Solicitud no disponible',
            'Comprueba tus permisos.',
          ),
        );
      }
      final current = r.businesses
          .where((b) => b.id == s.text('negocioId'))
          .firstOrNull;
      return Scaffold(
        appBar: AppBar(title: const Text('Revisar solicitud')),
        body: PageBody(
          children: [
            SectionTitle(
              s.proposal['nombre'] as String? ??
                  s.proposal['titulo'] as String? ??
                  'Solicitud',
              'Tipo: ${s.text('tipo')} · Solicitante: ${s.text('solicitanteId')}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: StatusChip(s.text('estado')),
            ),
            const SizedBox(height: 18),
            for (final entry in s.proposal.entries.where(
              (e) => e.key != 'imagenes',
            ))
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF67746C),
                        ),
                      ),
                      if (current != null &&
                          s.text('tipo') == 'cambio' &&
                          current.data[entry.key] != entry.value) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Publicado: ${current.data[entry.key] ?? '—'}',
                          style: const TextStyle(color: Color(0xFF8D342A)),
                        ),
                      ],
                      const SizedBox(height: 8),
                      SelectableText('Propuesta: ${entry.value}'),
                    ],
                  ),
                ),
              ),
            for (final url in List<String>.from(
              s.proposal['imagenes'] as List? ?? [],
            ))
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: imageOrArt([url], height: 240),
              ),
            if (s.text('estado') == 'pendiente')
              Wrap(
                spacing: 12,
                runSpacing: 10,
                children: [
                  FilledButton.icon(
                    onPressed: busy ? null : () => decide(true),
                    icon: const Icon(Icons.check),
                    label: Text(busy ? 'Guardando…' : 'Aprobar y publicar'),
                  ),
                  OutlinedButton.icon(
                    onPressed: busy ? null : () => decide(false),
                    icon: const Icon(Icons.close),
                    label: const Text('Rechazar con motivo'),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}
