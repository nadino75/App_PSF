import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:cloud_functions/cloud_functions.dart'; // Spark: no Cloud Functions
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
  // final functions = FirebaseFunctions.instance; // Spark: no Cloud Functions
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

  // Spark: invoke() removed - no Cloud Functions
  // Future<void> invoke(String name, Json data) async {
  //   await functions.httpsCallable(name).call<dynamic>(data);
  // }

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
    // Spark: Crear usuario directamente sin Cloud Function
    final uid = result.user!.uid;
    await db.collection('usuarios').doc(uid).set({
      'nombre': name.trim(),
      'email': email.trim(),
      'creado': FieldValue.serverTimestamp(),
    });
    // Log audit from client
    await _logAuditFromClient(uid, 'register', null, 'usuario');
  }

  Future<void> _logAuditFromClient(
    String userId,
    String action,
    String? targetId,
    String targetType,
  ) async {
    final auditId = db.collection('auditoria').doc().id;
    await db.collection('auditoria').doc(auditId).set({
      'userId': userId,
      'action': action,
      'targetId': targetId,
      'targetType': targetType,
      'result': 'success',
      'creado': FieldValue.serverTimestamp(),
    });
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
  Future<void> submit(Json data) async {
    // Spark: Crear solicitud directamente sin Cloud Function
    final uid = account!.uid;
    final tipo = data['tipo'] as String;
    final id = data['id'] as String;
    final negocioId = data['negocioId'] as String?;
    final propuesta = data['propuesta'] as Json?;

    await db.collection('solicitudes').doc(id).set({
      'tipo': tipo,
      'negocioId': negocioId ?? id,
      'propuesta': propuesta,
      'estado': 'pendiente',
      'solicitanteId': uid,
      'creado': FieldValue.serverTimestamp(),
      'actualizado': FieldValue.serverTimestamp(),
    });

    await _logAuditFromClient(uid, 'submitRequest', id, 'request');
  }

  @override
  Future<void> withdraw(String id) async {
    await db.collection('solicitudes').doc(id).update({
      'estado': 'retirada',
      'actualizado': FieldValue.serverTimestamp(),
    });
    await _logAuditFromClient(account!.uid, 'withdrawRequest', id, 'request');
  }

  @override
  Future<void> resolve(String id, bool approve, String reason) async {
    if (!isAdmin) throw StateError('Solo un administrador puede resolver solicitudes.');
    final motivo = reason.trim();
    if (!approve && motivo.isEmpty) {
      throw StateError('Indica el motivo del rechazo.');
    }
    final reviewer = account!.uid;
    final ref = db.collection('solicitudes').doc(id);
    await db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) throw StateError('Solicitud inexistente.');
      final request = snap.data()!;
      if (request['estado'] != 'pendiente') {
        throw StateError('Esta solicitud ya no está pendiente.');
      }
      final tipo = request['tipo'] as String;
      final negocioId = request['negocioId'] as String;
      final solicitanteId = request['solicitanteId'] as String;
      final propuesta = Map<String, dynamic>.from(request['propuesta'] as Map);
      final business = db.collection('negocios').doc(negocioId);
      final current = await tx.get(business);
      DocumentSnapshot<Json>? category;
      if (approve) {
        if (tipo == 'anuncio') {
          if (!current.exists || current.data()!['duenoId'] != solicitanteId) {
            throw StateError('El negocio ya no pertenece al solicitante.');
          }
          if (current.data()!['publicado'] != true) {
            throw StateError('El negocio no está publicado.');
          }
        } else {
          if (tipo != 'negocio' &&
              (!current.exists || current.data()!['duenoId'] != solicitanteId)) {
            throw StateError('El negocio ya no pertenece al solicitante.');
          }
          category = await tx.get(
            db.collection('categorias').doc(propuesta['categoria'] as String),
          );
          if (!category.exists || category.data()!['activa'] != true) {
            throw StateError('La categoría ya no está activa.');
          }
        }
      }
      final now = FieldValue.serverTimestamp();
      if (approve) {
        if (tipo == 'anuncio') {
          tx.set(db.collection('anuncios').doc(id), {
            ...propuesta,
            'publicado': true,
            'creado': now,
          });
        } else {
          tx.set(business, {
            'duenoId': solicitanteId,
            'publicado': true,
            'versionId': id,
            'actualizado': now,
          });
          tx.set(db.collection('catalogo').doc(negocioId), {
            ...propuesta,
            'publicado': true,
            'actualizado': now,
          });
          tx.set(business.collection('versiones').doc(id), {
            ...propuesta,
            'creado': now,
          });
          tx.set(db.collection('usuarios').doc(solicitanteId), {
            'dueno': true,
          }, SetOptions(merge: true));
        }
        tx.set(db.collection('novedades').doc(id), {
          'titulo': propuesta['nombre'] ?? propuesta['titulo'],
          'mensaje': tipo == 'anuncio'
              ? 'Nuevo anuncio publicado'
              : 'Novedades en el catálogo',
          'creado': now,
        });
      }
      final estado = approve ? 'aprobada' : 'rechazada';
      tx.update(ref, {
        'estado': estado,
        'motivo': motivo,
        'revisorId': reviewer,
        'resuelto': now,
        'actualizado': now,
      });
      tx.set(db.collection('historial').doc(id), {
        'solicitudId': id,
        'solicitanteId': solicitanteId,
        'revisorId': reviewer,
        'estado': estado,
        'motivo': motivo,
        'creado': now,
      });
      tx.set(
        db
            .collection('usuarios')
            .doc(solicitanteId)
            .collection('notificaciones')
            .doc(id),
        {
          'titulo': 'Solicitud $estado',
          'mensaje': motivo.isEmpty ? 'Tu contenido ya está publicado.' : motivo,
          'solicitudId': id,
          'leida': false,
          'creado': now,
        },
      );
    });
    await _logAuditFromClient(reviewer, 'resolveRequest', id, 'request');
  }

  @override
  Future<void> editorial(Json data) async {
    if (!isAdmin) throw StateError('Solo un administrador puede hacer esto.');
    final tipo = data['tipo'] as String;
    final id = data['id'] as String;
    final now = FieldValue.serverTimestamp();
    String action;
    if (tipo == 'categoria') {
      action = 'editorialCategory';
      await db.collection('categorias').doc(id).set({
        'nombre': (data['nombre'] as String).trim(),
        'activa': data['activa'] == true,
      });
    } else if (tipo == 'boletin') {
      action = 'editorialBulletin';
      final publicado = data['publicado'] == true;
      final titulo = (data['titulo'] as String).trim();
      final batch = db.batch();
      batch.set(db.collection('boletines').doc(id), {
        'titulo': titulo,
        'descripcion': (data['descripcion'] as String).trim(),
        'publicado': publicado,
        'actualizado': now,
      });
      if (publicado) {
        batch.set(db.collection('novedades').doc('boletin_$id'), {
          'titulo': titulo,
          'mensaje': 'Nuevo boletín disponible',
          'creado': now,
        });
      }
      await batch.commit();
    } else if (tipo == 'negocio') {
      action = 'editorialBusiness';
      final publicado = data['publicado'] == true;
      final ads = await db
          .collection('anuncios')
          .where('negocioId', isEqualTo: id)
          .get();
      final batch = db.batch();
      batch.update(db.collection('negocios').doc(id), {'publicado': publicado});
      batch.update(db.collection('catalogo').doc(id), {'publicado': publicado});
      if (!publicado) {
        for (final ad in ads.docs) {
          batch.update(ad.reference, {'publicado': false});
        }
      }
      await batch.commit();
    } else if (tipo == 'anuncio') {
      action = 'editorialAd';
      await db.collection('anuncios').doc(id).update({'publicado': false});
    } else {
      throw StateError('Operación desconocida.');
    }
    await _logAuditFromClient(account!.uid, action, id, tipo);
  }
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
