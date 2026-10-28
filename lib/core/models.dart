import 'audit.dart';

typedef Json = Map<String, dynamic>;

class Item {
  const Item(this.id, this.data);
  final String id;
  final Json data;
  String text(String key) => data[key]?.toString() ?? '';
  bool flag(String key) => data[key] == true;
  Json get proposal =>
      Map<String, dynamic>.from(data['propuesta'] as Map? ?? {});
  List<String> get images => List<String>.from(data['imagenes'] as List? ?? []);
}

class Account {
  const Account(this.uid, this.email, this.name, {this.admin = false});
  final String uid, email, name;
  final bool admin;
}

String? requiredText(String? value) =>
    value == null || value.trim().isEmpty ? 'Completa este campo.' : null;
String? validEmail(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Escribe un correo válido.';
String? validPhone(String? value) =>
    RegExp(r'^[+\d\s()-]{7,30}$').hasMatch(value?.trim() ?? '')
    ? null
    : 'Escribe un teléfono válido.';
bool activeAd(Item item, DateTime now) {
  final expires = DateTime.tryParse(item.text('vence'));
  return item.flag('publicado') && expires != null && expires.isAfter(now);
}

UserRole getUserRole(Account? account, {bool isOwner = false, List<String> ownedBusinesses = const []}) {
  if (account?.admin == true) return UserRole.admin;
  if (isOwner) return UserRole.owner;
  return UserRole.user;
}
