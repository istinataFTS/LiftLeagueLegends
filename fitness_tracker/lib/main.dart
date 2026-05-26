import 'app/app.dart';
import 'app/bootstrap/app_bootstrapper.dart';
import 'package:flutter/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapper = AppBootstrapper();
  await bootstrapper.bootstrap();

  runApp(const AppHost());
}
