import 'package:flutter/material.dart';

import '../data/repository.dart';
import 'shared.dart';
import '../core/models.dart';
import 'editor_page.dart';
import 'public_pages.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key, required this.repository});
  final AppRepository repository;
  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final keyForm = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      name = TextEditingController();
  bool registration = false, recovery = false, busy = false;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    name.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!keyForm.currentState!.validate()) return;
    setState(() => busy = true);
    final r = widget.repository;
    final ok = await perform(
      context,
      () async {
        if (recovery) {
          await r.resetPassword(email.text);
        } else if (registration) {
          await r.register(name.text, email.text, password.text);
        } else {
          await r.signIn(email.text, password.text);
        }
      },
      success: recovery
          ? 'Si existe una cuenta, recibirás instrucciones de recuperación.'
          : null,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok && !recovery) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Tu cuenta')),
    body: PageBody(
      maxWidth: 560,
      children: [
        SectionTitle(
          recovery
              ? 'Recupera tu acceso'
              : registration
              ? 'Únete a la comunidad'
              : 'Qué bueno verte de nuevo',
          'Guarda tus favoritos y administra tu presencia en Vitrina Local.',
        ),
        if (widget.repository.demo)
          Card(
            color: const Color(0xFFF6E8C4),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Acceso de demostración · Contraseña: Demo123!'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          email.text = 'dueno@vitrina.local';
                          password.text = 'Demo123!';
                        },
                        child: const Text('Usar dueño'),
                      ),
                      TextButton(
                        onPressed: () {
                          email.text = 'admin@vitrina.local';
                          password.text = 'Demo123!';
                        },
                        child: const Text('Usar administrador'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Form(
          key: keyForm,
          child: Column(
            children: [
              if (registration && !recovery)
                InputField(name, 'Nombre', max: 100),
              InputField(
                email,
                'Correo electrónico',
                keyboard: TextInputType.emailAddress,
                max: 254,
                validator: validEmail,
              ),
              if (!recovery)
                InputField(
                  password,
                  'Contraseña',
                  obscure: true,
                  max: 128,
                  validator: (v) => (v?.length ?? 0) < (registration ? 8 : 1)
                      ? 'Usa al menos ${registration ? 8 : 1} caracteres.'
                      : null,
                ),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'Un momento…'
                        : recovery
                        ? 'Enviar instrucciones'
                        : registration
                        ? 'Crear cuenta'
                        : 'Ingresar',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: busy
              ? null
              : () => setState(() {
                  registration = !registration;
                  recovery = false;
                }),
          child: Text(
            registration ? 'Ya tengo una cuenta' : 'Crear una cuenta',
          ),
        ),
        TextButton(
          onPressed: busy
              ? null
              : () => setState(() {
                  recovery = !recovery;
                  registration = false;
                }),
          child: Text(recovery ? 'Volver al acceso' : 'Olvidé mi contraseña'),
        ),
      ],
    ),
  );
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.repository});
  final AppRepository repository;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) {
      final r = repository;
      if (r.account == null) {
        return PageBody(
          children: [
            const SectionTitle(
              'Tu lugar en la comunidad',
              'Crea una cuenta para guardar negocios y dar a conocer el tuyo.',
            ),
            const EmptyState(
              'Todo empieza con una conexión',
              'Explora libremente. Inicia sesión cuando quieras participar.',
              icon: Icons.people_outline,
            ),
            FilledButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => AuthPage(repository: r),
                ),
              ),
              icon: const Icon(Icons.login),
              label: const Text('Ingresar o registrarme'),
            ),
          ],
        );
      }
      final account = r.account!;
      final ownBusinesses = r.owned
          .where((b) => b.text('duenoId') == account.uid)
          .toList();
      final requests = r.requests
          .where((s) => s.text('solicitanteId') == account.uid)
          .toList();
      return PageBody(
        children: [
          SectionTitle(
            'Hola, ${account.name.isEmpty ? 'vecino' : account.name}',
            '${account.email} · ${r.isAdmin
                ? 'Administrador'
                : ownBusinesses.isEmpty
                ? 'Usuario'
                : 'Dueño de negocio'}',
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => EditorPage(repository: r, kind: 'negocio'),
                  ),
                ),
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Solicitar un negocio'),
              ),
              OutlinedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ListenableBuilder(
                      listenable: r,
                      builder: (context, _) => Scaffold(
                        appBar: AppBar(title: const Text('Favoritos')),
                        body: CatalogPage(repository: r, favoritesOnly: true),
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.favorite_outline),
                label: const Text('Mis favoritos'),
              ),
              OutlinedButton.icon(
                onPressed: () async {
                  final name = await askText(
                    context,
                    'Editar nombre',
                    initial: account.name,
                  );
                  if (name != null && context.mounted) {
                    await perform(
                      context,
                      () => r.updateProfile(name),
                      success: 'Perfil actualizado.',
                    );
                  }
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar perfil'),
              ),
              ActionButton(
                label: 'Cerrar sesión',
                icon: Icons.logout,
                action: r.signOut,
              ),
            ],
          ),
          const SizedBox(height: 32),
          const SectionTitle(
            'Mis negocios',
            'Las modificaciones se publican después de una revisión.',
          ),
          if (ownBusinesses.isEmpty)
            const Text(
              'Cuando aprueben tu primera solicitud, podrás administrar el negocio aquí.',
            ),
          for (final own in ownBusinesses)
            Builder(
              builder: (context) {
                final b = r.businesses.where((b) => b.id == own.id).firstOrNull;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          b?.text('nombre') ?? 'Cargando negocio…',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          b?.flag('publicado') == true
                              ? 'Publicado'
                              : 'Despublicado',
                        ),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          children: [
                            if (b != null)
                              OutlinedButton.icon(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) => EditorPage(
                                      repository: r,
                                      kind: 'cambio',
                                      business: b,
                                    ),
                                  ),
                                ),
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('Proponer cambios'),
                              ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) => EditorPage(
                                    repository: r,
                                    kind: 'anuncio',
                                    business: b ?? own,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.campaign_outlined),
                              label: const Text('Solicitar anuncio'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 32),
          const SectionTitle(
            'Mis solicitudes',
            'Consulta decisiones, retira pendientes o envía una corrección.',
          ),
          if (requests.isEmpty)
            const EmptyState(
              'Todavía no hay solicitudes',
              'Puedes guardar un borrador o enviar tu primer negocio.',
            ),
          for (final s in requests) RequestCard(repository: r, request: s),
        ],
      );
    },
  );
}

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.repository,
    required this.request,
    this.onReview,
  });
  final AppRepository repository;
  final Item request;
  final VoidCallback? onReview;
  @override
  Widget build(BuildContext context) {
    final s = request;
    final editable = [
      'borrador',
      'rechazada',
      'retirada',
    ].contains(s.text('estado'));
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  s.proposal['nombre'] as String? ??
                      s.proposal['titulo'] as String? ??
                      'Solicitud',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                StatusChip(s.text('estado')),
              ],
            ),
            Text('Tipo: ${s.text('tipo')}'),
            if (s.text('motivo').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text('Motivo: ${s.text('motivo')}'),
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                if (onReview != null)
                  FilledButton(
                    onPressed: onReview,
                    child: const Text('Revisar solicitud'),
                  ),
                if (editable &&
                    s.text('solicitanteId') == repository.account?.uid)
                  TextButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => EditorPage(
                          repository: repository,
                          kind: s.text('tipo'),
                          previous: s,
                          business: repository.businesses
                              .where((b) => b.id == s.text('negocioId'))
                              .firstOrNull,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
                    label: Text(
                      s.text('estado') == 'borrador'
                          ? 'Continuar borrador'
                          : 'Corregir y reenviar',
                    ),
                  ),
                if (s.text('estado') == 'pendiente' &&
                    s.text('solicitanteId') == repository.account?.uid)
                  TextButton(
                    onPressed: () => perform(
                      context,
                      () => repository.withdraw(s.id),
                      success: 'Solicitud retirada. Puedes corregirla y crear un nuevo envío.',
                    ),
                    child: const Text('Retirar solicitud'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key, required this.repository});
  final AppRepository repository;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: repository,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: PageBody(
        children: [
          const SectionTitle(
            'Lo que está pasando',
            'Decisiones sobre tus solicitudes y novedades de la comunidad.',
          ),
          if (repository.notices.isEmpty && repository.news.isEmpty)
            const EmptyState(
              'Estás al día',
              'Aquí aparecerán las nuevas notificaciones.',
              icon: Icons.notifications_none,
            ),
          for (final n in repository.notices) _notice(context, n, false),
          for (final n in repository.news) _notice(context, n, true),
        ],
      ),
    ),
  );
  Widget _notice(BuildContext context, Item n, bool global) {
    final read = global ? repository.readNews.contains(n.id) : n.flag('leida');
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(18),
        leading: Icon(
          read
              ? Icons.mark_email_read_outlined
              : Icons.mark_email_unread_outlined,
        ),
        title: Text(n.text('titulo')),
        subtitle: Text(n.text('mensaje')),
        trailing: read
            ? null
            : IconButton(
                tooltip: 'Marcar como leída',
                onPressed: () => perform(
                  context,
                  () => repository.markRead(n.id, global: global),
                ),
                icon: const Icon(Icons.done),
              ),
      ),
    );
  }
}
