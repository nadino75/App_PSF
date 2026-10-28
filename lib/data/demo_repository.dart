import 'dart:typed_data';

import '../core/models.dart';
import '../core/audit.dart';
import 'repository.dart';

class DemoRepository extends AppRepository {
  DemoRepository() {
    categories = [
      const Item('gastronomia', {'nombre': 'Gastronomía', 'activa': true}),
      const Item('artesania', {'nombre': 'Artesanía', 'activa': true}),
      const Item('servicios', {'nombre': 'Servicios', 'activa': true}),
    ];
    businesses = [
      Item('cafe', {
        'nombre': 'Café de la esquina',
        'descripcion': 'Café de altura y pan recién horneado. Un espacio para conversar y descubrir sabores locales.',
        'categoria': 'gastronomia',
        'direccion': 'Av. del Prado 120',
        'zona': 'Centro',
        'telefono': '+59170000001',
        'horarios': 'Lunes a sábado · 08:00 a 20:00',
        'imagenes': <String>[],
        'publicado': true,
      }),
      Item('taller', {
        'nombre': 'Manos de nuestra tierra',
        'descripcion':
            'Cerámica y tejidos hechos a mano por artesanos locales.',
        'categoria': 'artesania',
        'direccion': 'Calle Los Andes 45',
        'zona': 'Miraflores',
        'telefono': '+59170000002',
        'horarios': 'Lunes a viernes · 09:00 a 18:00',
        'imagenes': <String>[],
        'publicado': true,
      }),
    ];
    _owners.addAll([
      const Item('cafe', {'duenoId': 'demo-owner', 'publicado': true}),
      const Item('taller', {'duenoId': 'otro', 'publicado': true}),
    ]);
    ads = [
      Item('promo', {
        'titulo': 'Una pausa con sabor local',
        'descripcion': 'Conoce nuestra selección de café de altura.',
        'negocioId': 'cafe',
        'vence': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'publicado': true,
      }),
    ];
    bulletins = [
      const Item('bienvenida', {
        'titulo': 'Tu barrio tiene mucho por descubrir',
        'descripcion': 'Vitrina Local conecta a nuestra comunidad con sus negocios. Explora el catálogo, guarda tus favoritos y encuentra nuevas propuestas cerca de ti.\n\nEstos son datos ficticios para demostrar el proyecto.',
        'publicado': true,
      }),
    ];
  }
  final List<Item> _owners = [], _requests = [], _notices = [], _history = [];
  final Map<String, Set<String>> _favorites = {}, _reads = {};
  final Map<String, (Account, String)> _accounts = {
    'admin@vitrina.local': (
      const Account(
        'demo-admin',
        'admin@vitrina.local',
        'Administración',
        admin: true,
      ),
      'Demo123!',
    ),
    'dueno@vitrina.local': (
      const Account('demo-owner', 'dueno@vitrina.local', 'Emprendedor local'),
      'Demo123!',
    ),
    'otro@vitrina.local': (
      const Account('otro', 'otro@vitrina.local', 'Otra cuenta'),
      'Demo123!',
    ),
  };
  int _counter = 0;
  @override
  bool get demo => true;
  @override
  String newId() =>
      'demo-${DateTime.now().microsecondsSinceEpoch}-${_counter++}';
  void requireAccount() {
    if (account == null) throw StateError('Inicia sesión.');
  }

  void requireAdmin() {
    if (!isAdmin) {
      throw StateError('Solo un administrador puede realizar esta acción.');
    }
  }

  @override
  Future<void> refresh() async {
    requests = _requests
        .where((r) => isAdmin || r.text('solicitanteId') == account?.uid)
        .toList()
        .reversed
        .toList();
    owned = _owners
        .where((r) => isAdmin || r.text('duenoId') == account?.uid)
        .toList();
    notices = _notices.where((r) => r.text('uid') == account?.uid).toList();
    history = _history
        .where((r) => isAdmin || r.text('solicitanteId') == account?.uid)
        .toList();
    favorites = _favorites.putIfAbsent(account?.uid ?? '', () => {});
    readNews = _reads.putIfAbsent(account?.uid ?? '', () => {});
    notifyListeners();
  }

  @override
  Future<void> signIn(String email, String password) async {
    final saved = _accounts[email.trim().toLowerCase()];
    if (saved == null || saved.$2 != password) {
      throw StateError(
        'Cuenta o contraseña incorrecta. Las cuentas de ejemplo usan Demo123!',
      );
    }
    account = saved.$1;
    await refresh();
  }

  @override
  Future<void> register(String name, String email, String password) async {
    final key = email.trim().toLowerCase();
    if (_accounts.containsKey(key)) {
      throw StateError('Este correo ya tiene una cuenta.');
    }
    account = Account(newId(), key, name.trim());
    _accounts[key] = (account!, password);
    await refresh();
  }

  @override
  Future<void> signOut() async {
    account = null;
    await refresh();
  }

  @override
  Future<void> resetPassword(String email) async {
    throw StateError('La demostración no envía correos. Usa Demo123!');
  }

  @override
  Future<void> updateProfile(String name) async {
    requireAccount();
    account = Account(account!.uid, account!.email, name, admin: isAdmin);
    _accounts[account!.email] = (account!, _accounts[account!.email]!.$2);
    notifyListeners();
  }

  @override
  Future<void> submit(Json data) async {
    requireAccount();
    final existing = _requests.where((r) => r.id == data['id']).firstOrNull;
    if (existing != null && existing.text('estado') != 'borrador') return;
    final tipo = data['tipo'];
    final businessId = tipo == 'negocio' ? data['id'] : data['negocioId'];
    if (tipo != 'negocio' &&
        !_owners.any(
          (r) => r.id == businessId && r.text('duenoId') == account!.uid,
        )) {
      throw StateError('El negocio pertenece a otra cuenta.');
    }
    if (_requests.any(
      (r) =>
          r.text('negocioId') == businessId &&
          r.text('tipo') == tipo &&
          r.text('estado') == 'pendiente',
    )) {
      throw StateError('Ya existe una solicitud pendiente.');
    }
    _requests.removeWhere((r) => r.id == data['id']);
    _requests.add(
      Item(data['id'], {
        ...data,
        'negocioId': businessId,
        'solicitanteId': account!.uid,
        'estado': data['borrador'] == true ? 'borrador' : 'pendiente',
      }),
    );
    await refresh();
  }

  @override
  Future<void> withdraw(String id) async {
    requireAccount();
    final r = _requests.firstWhere((r) => r.id == id);
    if (r.text('solicitanteId') != account!.uid ||
        r.text('estado') != 'pendiente') {
      throw StateError('No se puede retirar.');
    }
    r.data['estado'] = 'retirada';
    await refresh();
  }

  @override
  Future<void> resolve(String id, bool approve, String reason) async {
    requireAdmin();
    final r = _requests.firstWhere((r) => r.id == id);
    if (r.text('estado') != 'pendiente') {
      throw StateError('Esta solicitud ya fue resuelta.');
    }
    if (!approve && reason.trim().isEmpty) {
      throw StateError('Escribe el motivo del rechazo.');
    }
    if (approve) {
      if (r.text('tipo') == 'anuncio') {
        ads.add(Item(id, {...r.proposal, 'publicado': true}));
      } else {
        businesses.removeWhere((b) => b.id == r.text('negocioId'));
        businesses.add(
          Item(r.text('negocioId'), {...r.proposal, 'publicado': true}),
        );
        _owners.removeWhere((b) => b.id == r.text('negocioId'));
        _owners.add(
          Item(r.text('negocioId'), {
            'duenoId': r.text('solicitanteId'),
            'publicado': true,
          }),
        );
      }
      news.add(
        Item(id, {
          'titulo': r.proposal['nombre'] ?? r.proposal['titulo'],
          'mensaje': 'Nuevo contenido publicado',
        }),
      );
    }
    r.data.addAll({
      'estado': approve ? 'aprobada' : 'rechazada',
      'motivo': reason.trim(),
      'revisorId': account!.uid,
    });
    _history.add(Item(id, {...r.data}));
    _notices.add(
      Item(id, {
        'uid': r.text('solicitanteId'),
        'titulo': 'Solicitud ${r.text('estado')}',
        'mensaje': reason.isEmpty ? 'Tu contenido ya está publicado.' : reason,
        'leida': false,
      }),
    );
    await refresh();
  }

  @override
  Future<void> editorial(Json data) async {
    requireAdmin();
    final id = data['id'] as String;
    if (data['tipo'] == 'categoria') {
      categories.removeWhere((x) => x.id == id);
      categories.add(Item(id, data));
    }
    if (data['tipo'] == 'boletin') {
      bulletins.removeWhere((x) => x.id == id);
      bulletins.add(Item(id, data));
      if (data['publicado'] == true) {
        news.add(
          Item(id, {
            'titulo': data['titulo'],
            'mensaje': 'Nuevo boletín disponible',
          }),
        );
      }
    }
    if (data['tipo'] == 'negocio') {
      businesses.firstWhere((x) => x.id == id).data['publicado'] =
          data['publicado'];
      for (final ad in ads.where((x) => x.text('negocioId') == id)) {
        ad.data['publicado'] = false;
      }
    }
    if (data['tipo'] == 'anuncio') {
      ads.firstWhere((x) => x.id == id).data['publicado'] = false;
    }
    await refresh();
  }

  @override
  Future<void> toggleFavorite(String id) async {
    requireAccount();
    if (!favorites.remove(id)) favorites.add(id);
    notifyListeners();
  }

  @override
  Future<void> markRead(String id, {bool global = false}) async {
    if (global) {
      readNews.add(id);
    } else {
      notices.firstWhere((x) => x.id == id).data['leida'] = true;
    }
    notifyListeners();
  }

  @override
  Future<String> uploadImage(Uint8List bytes, String mime) async {
    throw StateError(
      'La carga de archivos requiere Firebase. En la demo puedes añadir una dirección HTTPS.',
    );
  }

  @override
  Future<List<AuditLog>> fetchAuditLogs() async {
    return [];
  }

  @override
  Future<List<AuditLog>> fetchMyAuditLogs() async {
    return [];
  }
}
