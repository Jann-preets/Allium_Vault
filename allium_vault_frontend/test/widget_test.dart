// This is an example Flutter widget test.
//
// To learn more about Flutter's testing capabilities, see the documentation at
// https://flutter.dev/docs/cookbook/testing/widget/introduction

import 'package:flutter_test/flutter_test.dart';
import 'package:allium_vault_app/main.dart'; // Make sure this is the correct name of your app folder

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    // This is a simple test to make sure the app starts without crashing.
    await tester.pumpWidget(const AlliumVaultApp());

    // Verify that the title of our app is displayed.
    // This is a simple but effective test to confirm the correct app is running.
    expect(find.text('Allium Vault Dashboard'), findsOneWidget);
  });
}
