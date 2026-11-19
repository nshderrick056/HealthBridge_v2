import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/settings/settings.dart';
import 'data/db.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android reads the project (healthbridge-rwanda) from android/app/google-services.json.
  await Firebase.initializeApp();
  // Records live in the encrypted local database (SQLCipher); Firestore's own cache would be a second,
  // unencrypted copy of patient data on the phone, so it is off. Sync only writes while online.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  final db = await openAppDatabase();
  final prefs = await SharedPreferences.getInstance();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const HealthBridgeApp(),
    ),
  );
}
