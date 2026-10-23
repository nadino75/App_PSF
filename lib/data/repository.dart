import 'package:flutter/foundation.dart';

import '../core/models.dart';

abstract class AppRepository extends ChangeNotifier {
  Account? account;
  List<Item> businesses = [],
      categories = [],
      ads = [],
      bulletins = [],
      requests = [],
      owned = [],
      notices = [],
      news = [],
      history = [];
  Set<String> favorites = {}, readNews = {};
  String? error;
  bool loading = false;
  bool get demo => false;
  bool get isAdmin => account?.admin ?? false;
  String newId();
  Future<void> signIn(String email, String password);
  Future<void> register(String name, String email, String password);
  Future<void> signOut();
  Future<void> resetPassword(String email);
  Future<void> updateProfile(String name);
  Future<void> submit(Json data);
  Future<void> withdraw(String id);
  Future<void> resolve(String id, bool approve, String reason);
  Future<void> editorial(Json data);
  Future<void> toggleFavorite(String id);
  Future<void> markRead(String id, {bool global = false});
  Future<String> uploadImage(Uint8List bytes, String mime);
  Future<void> refresh();
  void clearError() {
    error = null;
    notifyListeners();
  }
}
