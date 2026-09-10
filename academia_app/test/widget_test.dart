import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/main.dart';
import 'package:academia_app/services/theme_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.instance.init();
  });

  testWidgets('App root initializes and loads without crashing', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false));
    expect(find.byType(MyApp), findsOneWidget);
  });
}
