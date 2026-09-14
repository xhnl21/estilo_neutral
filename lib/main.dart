import 'package:flutter/material.dart';
import 'app/di/injection.dart';
import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  ServiceLocator().init();
  runApp(const EstiloNeutralApp());
}
