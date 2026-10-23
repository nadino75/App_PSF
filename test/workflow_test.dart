import 'package:flutter_test/flutter_test.dart';
import 'package:psf_publinfo/data/demo_repository.dart';
import 'package:psf_publinfo/core/models.dart';

Json proposal(String name) => {
  'nombre': name,
  'categoria': 'gastronomia',
  'descripcion': 'Descripción',
  'zona': 'Centro',
  'direccion': 'Calle 1',
  'telefono': '+59170000000',
  'horarios': '09:00 a 18:00',
  'imagenes': <String>[],
};
void main() {
  test(
    'request is private until approval; changes preserve published version',
    () async {
      final r = DemoRepository();
      await r.signIn('dueno@vitrina.local', 'Demo123!');
      await r.submit({
        'id': 'nuevo',
        'tipo': 'negocio',
        'propuesta': proposal('Original'),
      });
      expect(r.businesses.any((b) => b.id == 'nuevo'), false);
      await r.signIn('admin@vitrina.local', 'Demo123!');
      await r.resolve('nuevo', true, '');
      expect(
        r.businesses.firstWhere((b) => b.id == 'nuevo').text('nombre'),
        'Original',
      );
      await expectLater(r.resolve('nuevo', true, ''), throwsStateError);
      await r.signIn('dueno@vitrina.local', 'Demo123!');
      expect(r.notices.length, 1);
      await r.submit({
        'id': 'cambio',
        'tipo': 'cambio',
        'negocioId': 'nuevo',
        'propuesta': proposal('Propuesto'),
      });
      expect(
        r.businesses.firstWhere((b) => b.id == 'nuevo').text('nombre'),
        'Original',
      );
      await expectLater(
        r.submit({
          'id': 'duplicado',
          'tipo': 'cambio',
          'negocioId': 'nuevo',
          'propuesta': proposal('Duplicado'),
        }),
        throwsStateError,
      );
      await r.signIn('admin@vitrina.local', 'Demo123!');
      await expectLater(r.resolve('cambio', false, ''), throwsStateError);
      await r.resolve('cambio', false, 'Revisa el nombre');
      expect(
        r.businesses.firstWhere((b) => b.id == 'nuevo').text('nombre'),
        'Original',
      );
      r.dispose();
    },
  );
  test(
    'another owner cannot modify a business; favorites are per account',
    () async {
      final r = DemoRepository();
      await r.signIn('dueno@vitrina.local', 'Demo123!');
      await expectLater(
        r.submit({
          'id': 'ataque',
          'tipo': 'cambio',
          'negocioId': 'taller',
          'propuesta': proposal('Ajeno'),
        }),
        throwsStateError,
      );
      await r.toggleFavorite('cafe');
      await r.signIn('admin@vitrina.local', 'Demo123!');
      expect(r.favorites, isEmpty);
      await r.signIn('dueno@vitrina.local', 'Demo123!');
      expect(r.favorites, contains('cafe'));
      r.dispose();
    },
  );
  test('expired advertisements are not shown', () {
    expect(
      activeAd(
        const Item('ad', {'publicado': true, 'vence': '2020-01-01T00:00:00Z'}),
        DateTime(2026),
      ),
      false,
    );
    expect(validEmail('incorrecto'), isNotNull);
    expect(validPhone('abc'), isNotNull);
  });
}
