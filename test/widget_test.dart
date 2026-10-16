import 'package:flutter_test/flutter_test.dart';
import 'package:reapiroo/main.dart';
import 'package:reapiroo/screens/onboarding_screen.dart';

void main() {
  testWidgets('App renders onboarding screen when not logged in', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp(isLoggedIn: false, userRole: ''));
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });
}
