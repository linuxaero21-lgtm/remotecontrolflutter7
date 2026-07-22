import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remote_control/main.dart';

void main() {
  testWidgets('App should launch with login screen', (WidgetTester tester) async {
    // Inizializza il binding per il test
    TestWidgetsFlutterBinding.ensureInitialized();

    // Mock di SharedPreferences per evitare MissingPluginException
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(const RemoteControlApp());

    // Verifica che l'app parta con la schermata di login
    expect(find.text('Remote Control'), findsWidgets);
    expect(find.text('CONNETTI'), findsOneWidget);
  });
}
