import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:psf_publinfo/app.dart';
import 'package:psf_publinfo/data/demo_repository.dart';

void main() {
  testWidgets('visitor can explore and access account on a narrow screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = DemoRepository();
    final originalErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      debugPrint(details.toString());
      originalErrorHandler?.call(details);
    };
    addTearDown(() => FlutterError.onError = originalErrorHandler);
    await tester.pumpWidget(VitrinaApp(repository: repository));
    await tester.pumpAndSettle();
    expect(find.text('Vitrina Local'), findsOneWidget);
    expect(find.textContaining('Descubre lo mejor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    expect(find.text('Ingresar o registrarme'), findsOneWidget);
    await tester.tap(find.text('Ingresar o registrarme'));
    await tester.pumpAndSettle();
    expect(find.text('Usar dueño'), findsOneWidget);
    await tester.tap(find.text('Usar dueño'));
    await tester.tap(find.text('Ingresar'));
    await tester.pumpAndSettle();
    expect(find.text('Mis negocios'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    repository.dispose();
  });
}
