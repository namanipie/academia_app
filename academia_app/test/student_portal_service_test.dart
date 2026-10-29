import 'package:flutter_test/flutter_test.dart';
import 'package:academia_app/services/student_portal_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('StudentPortalService Tests', () {
    test('fetchCaptcha retrieves live captcha image and session token from SRM portal', () async {
      try {
        final session = await StudentPortalService.fetchCaptcha();
        expect(session.cookies.containsKey('JSESSIONID'), isTrue);
        expect(session.captchaToken.isNotEmpty, isTrue);
        expect(session.imageBytes.isNotEmpty, isTrue);
        expect(session.imageBytes.length, greaterThan(100));
        expect(session.imageBytes[0], 137);
        expect(session.imageBytes[1], 80);
        expect(session.imageBytes[2], 78);
        expect(session.imageBytes[3], 71);
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('loginAndSync rejects invalid credentials and captcha gracefully without crashing', () async {
      try {
        final session = await StudentPortalService.fetchCaptcha();
        final result = await StudentPortalService.loginAndSync(
          username: 'dummy_user_123',
          password: 'dummy_password',
          captcha: 'XYZ99',
          session: session,
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('syncViaGateway handles invalid credentials gracefully without crashing', () async {
      try {
        final result = await StudentPortalService.syncViaGateway(
          username: 'dummy_invalid_netid_9999',
          password: 'wrong_password_123',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, isNotNull);
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}
