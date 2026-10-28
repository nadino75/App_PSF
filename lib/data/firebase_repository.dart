import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../core/models.dart';
import '../core/audit.dart';
import 'repository.dart';

class FirebaseRepository extends AppRepository {
  FirebaseRepository() {
    _authSub = auth.idTokenChanges().listen((_) => refresh());
  }
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final functions = FirebaseFunctions.instance;
  late final StreamSubscription<User?> _authSub;
  final List<StreamSubscription<QuerySnapshot<Json>>> _subscriptions = [];
  StreamSubscription<DocumentSnapshot<Json>>? _profileSub;
  int _generation = 0;
  final Map<String, Item> _public = {}, _private = {};

  @override
  String newId() => db.collection('solicitudes').doc().id;
  void watch(
    Query<Json> query,
    void Function(List<Item>) assign,
    int generation,
  ) {
    _subscriptions.add(
      query.snapshots().listen(
        (snapshot) {
          if (generation != _generation) return;
          assign(snapshot.docs.map((doc) => Item(doc.id, doc.data())).toList());
          loading = false;
          notifyListeners();
        },
        onError: (Object e) {
          if (generation != _generation) return;
          error = 'No se pudieron cargar los datos. Comprueba la conexión y la configuración de Firebase.';
          loading = false;
          notifyListeners();
        },
      ),
    );
  }

  void _mergeBusinesses() {
    businesses = {..._private, ..._public}.values.toList();
  }

  Future<void> _loadOwned(List<Item> items, int generation) async {
    try {
      final docs = await Future.wait(
        items.map((s) => db.collection('catalogo').doc(s.id).get()),
      );
      if (generation != _generation) return;
      _private.clear();
      for (final doc in docs) {
        if (doc.exists) _private[doc.id] = Item(doc.id, doc.data()!);
      }
      _mergeBusinesses();
      notifyListeners();
    } catch (_) {
      if (generation == _generation) {
        error = 'No se pudieron cargar tus negocios.';
        notifyListeners();
      }
    }
  }

  @override
  Future<void> refresh() async {
    final generation = ++_generation;
    final old = List<StreamSubscription<QuerySnapshot<Json>>>.from(
      _subscriptions,
    );
    _subscriptions.clear();
    await Future.wait(old.map((s) => s.cancel()));
    await _profileSub?.cancel();
    if (generation != _generation) return;
    requests = [];
    owned = [];
    notices = [];
    news = [];
    history = [];
    favorites = {};
    readNews = {};
    businesses = [];
    ads = [];
    bulletins = [];
    _public.clear();
    _private.clear();
    error = null;
    loading = true;
    account = null;
    final user = auth.currentUser;
    try {
      if (user != null && !user.isAnonymous) {
        final token = await user.getIdTokenResult();
        if (generation != _generation) return;
        account = Account(
          user.uid,
          user.email ?? '',
          user.displayName ?? '',
          admin: token.claims?['admin'] == true,
        );
        _profileSub = db
            .collection('usuarios')
            .doc(user.uid)
            .snapshots()
            .listen(
              (snap) {
                if (generation != _generation) return;
                account = Account(
                  user.uid,
                  user.email ?? '',
                  snap.data()?['nombre'] as String? ?? user.displayName ?? '',
                  admin: account?.admin ?? false,
                );
                notifyListeners();
              },
              onError: (Object _) {
                if (generation == _generation) {
                  error = 'No se pudo cargar tu perfil.';
                  notifyListeners();
                }
              },
            );
      }
      Query<Json> publicQuery(String name) => isAdmin
          ? db.collection(name)
          : db.collection(name).where('publicado', isEqualTo: true);
      watch(publicQuery('catalogo'), (v) {
        _public.clear();
        for (final item in v) {
          _public[item.id] = item;
        }
        _mergeBusinesses();
      }, generation);
      watch(db.collection('categorias'), (v) => categories = v, generation);
      watch(publicQuery('anuncios'), (v) => ads = v, generation);
      watch(publicQuery('boletines'), (v) => bulletins = v, generation);
      if (account != null) {
        final uid = account!.uid;
        watch(
          isAdmin
              ? db.collection('solicitudes')
              : db
                    .collection('solicitudes')
                    .where('solicitanteId', isEqualTo: uid),
          (v) {
            requests = v
              ..sort(
                (a, b) =>
                    ((b.data['creado'] as Timestamp?)?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                          (a.data['creado'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0,
                        ),
              );
          },
          generation,
        );
        watch(
          isAdmin
              ? db.collection('negocios')
              : db.collection('negocios').where('duenoId', isEqualTo: uid),
          (v) {
            owned = v;
            if (!isAdmin) unawaited(_loadOwned(v, generation));
          },
          generation,
        );
        final profile = db.collection('usuarios').doc(uid);
        watch(
          profile.collection('favoritos'),
          (v) => favorites = v.map((x) => x.id).toSet(),
          generation,
        );
        watch(
          profile.collection('notificaciones'),
          (v) => notices = v,
          generation,
        );
        watch(
          profile.collection('lecturas'),
          (v) => readNews = v.map((x) => x.id).toSet(),
          generation,
        );
        watch(
          db
              .collection('novedades')
              .orderBy('creado', descending: true)
              .limit(100),
          (v) => news = v,
          generation,
        );
        watch(
          isAdmin
              ? db.collection('historial')
              : db
                    .collection('historial')
                    .where('solicitanteId', isEqualTo: uid),
          (v) => history = v,
          generation,
        );
      }
    } catch (_) {
      error =
          'No fue posible recuperar la sesión. Intenta ingresar nuevamente.';
      loading = false;
    }
    notifyListeners();
  }

  Future<void> invoke(String name, Json data) async {
    await functions.httpsCallable(name).call<dynamic>(data);
  }

  @override
  Future<void> signIn(String email, String password) async {
    await auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<void> register(String name, String email, String password) async {
    final result = await auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user!.updateDisplayName(name.trim());
    await db.collection('usuarios').doc(result.user!.uid).set({
      'nombre': name.trim(),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> signOut() => auth.signOut();
  @override
  Future<void> resetPassword(String email) =>
      auth.sendPasswordResetEmail(email: email.trim());
  @override
  Future<void> updateProfile(String name) => db
      .collection('usuarios')
      .doc(account!.uid)
      .set({'nombre': name.trim()}, SetOptions(merge: true));
  @override
  Future<void> submit(Json data) => invoke('enviarSolicitud', data);
  @override
  Future<void> withdraw(String id) => invoke('retirarSolicitud', {'id': id});
  @override
  Future<void> resolve(String id, bool approve, String reason) => invoke(
    'resolverSolicitud',
    {'id': id, 'aprobar': approve, 'motivo': reason},
  );
  @override
  Future<void> editorial(Json data) => invoke('gestionEditorial', data);
  @override
  Future<void> toggleFavorite(String id) async {
    final ref = db
        .collection('usuarios')
        .doc(account!.uid)
        .collection('favoritos')
        .doc(id);
    if (favorites.contains(id)) {
      await ref.delete();
    } else {
      await ref.set({'creado': FieldValue.serverTimestamp()});
    }
  }

  @override
  Future<void> markRead(String id, {bool global = false}) async {
    final ref = db
        .collection('usuarios')
        .doc(account!.uid)
        .collection(global ? 'lecturas' : 'notificaciones')
        .doc(id);
    if (global) {
      await ref.set({'leida': true});
    } else {
      await ref.update({'leida': true});
    }
  }

  @override
  Future<String> uploadImage(Uint8List bytes, String mime) async {
    if (bytes.length > 5 * 1024 * 1024) {
      throw StateError('La imagen supera 5 MB.');
    }
    final ref = FirebaseStorage.instance.ref(
      'usuarios/${account!.uid}/${newId()}',
    );
    await ref.putData(bytes, SettableMetadata(contentType: mime));
    return ref.getDownloadURL();
  }

  @override
  Future<List<AuditLog>> fetchAuditLogs() async {
    if (!isAdmin) throw Exception('Acceso denegado');
    try {
      loading = true;
      error = null;
      notifyListeners();
      final snapshot = await db
          .collection('auditoria')
          .orderBy('creado', descending: true)
          .limit(100)
          .get();
      auditLogs = snapshot.docs.map((doc) {
        final data = doc.data();
        return AuditLog(
          id: doc.id,
          userId: data['userId'] ?? '',
          userName: data['userName'],
          action: _parseAuditAction(data['action'] ?? ''),
          targetId: data['targetId'],
          targetType: data['targetType'],
          changes: data['changes'],
          result: data['result'],
          reason: data['reason'],
          timestamp: (data['creado'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      notifyListeners();
      return auditLogs;
    } catch (e) {
      error = 'Error cargando auditoría: $e';
      notifyListeners();
      rethrow;
    } finally {
      loading = false;
    }
  }

  @override
  Future<List<AuditLog>> fetchMyAuditLogs() async {
    if (account == null) throw Exception('No autenticado');
    try {
      loading = true;
      error = null;
      notifyListeners();
      final snapshot = await db
          .collection('auditoria')
          .where('userId', isEqualTo: account!.uid)
          .orderBy('creado', descending: true)
          .limit(50)
          .get();
      myAuditLogs = snapshot.docs.map((doc) {
        final data = doc.data();
        return AuditLog(
          id: doc.id,
          userId: data['userId'] ?? '',
          userName: data['userName'],
          action: _parseAuditAction(data['action'] ?? ''),
          targetId: data['targetId'],
          targetType: data['targetType'],
          changes: data['changes'],
          result: data['result'],
          reason: data['reason'],
          timestamp: (data['creado'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
      notifyListeners();
      return myAuditLogs;
    } catch (e) {
      error = 'Error cargando actividad: $e';
      notifyListeners();
      rethrow;
    } finally {
      loading = false;
    }
  }

  AuditAction _parseAuditAction(String action) {
    try {
      return AuditAction.values.firstWhere(
        (e) => e.toString().split('.').last == action,
      );
    } catch (_) {
      return AuditAction.signIn;
    }
  }

  @override
  void dispose() {
    _generation++;
    _authSub.cancel();
    _profileSub?.cancel();
    for (final sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }
}
