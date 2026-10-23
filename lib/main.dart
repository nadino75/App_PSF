import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'app.dart';
import 'data/demo_repository.dart';
import 'data/firebase_repository.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('DEMO_MODE')) {
    runApp(VitrinaApp(repository: DemoRepository()));
    return;
  }
  try {
    const emulator = bool.fromEnvironment('USE_EMULATORS');
    await Firebase.initializeApp(
      options: emulator
          ? const FirebaseOptions(
              apiKey: 'demo-vitrina-local',
              appId: '1:123:web:demo',
              messagingSenderId: '123',
              projectId: 'demo-vitrina-local',
              storageBucket: 'demo-vitrina-local.appspot.com',
            )
          : DefaultFirebaseOptions.currentPlatform,
    );
    if (emulator) {
      const host = String.fromEnvironment(
        'EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      await FirebaseAuth.instance.useAuthEmulator(host, 9099);
      FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
      FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
      await FirebaseStorage.instance.useStorageEmulator(host, 9199);
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: false,
      );
    }
    runApp(VitrinaApp(repository: FirebaseRepository()));
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 20),
                  const Text(
                    'No se pudo iniciar Firebase. Revisa la configuración y tu conexión.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: main,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
