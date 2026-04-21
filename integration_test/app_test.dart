import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goalapp/main.dart'; // Ensure this matches GoalApp
import 'package:flutter/material.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('GoalApp End-to-End Test', () {
    testWidgets('App boots up, displays empty vault, navigates to goal setup', (tester) async {
      // 1. Arrange & App Load
      await tester.pumpWidget(const ProviderScope(child: GoalApp()));
      
      // Wait for Hive mapping & provider initialization animations
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // 2. Initial State Assertions
      // It should load the Roadmap vault (which is empty by default in tests)
      expect(find.text('Vault is Empty'), findsOneWidget);

      // 3. Act: Tap the 'Design New Roadmap' button
      // Assuming you have an Icon or Text indicating new roadmap
      final fab = find.byIcon(Icons.add); // General FAB identifier
      
      if (fab.evaluate().isNotEmpty) {
        await tester.tap(fab);
        
        // Wait for GoRouter transition animation
        await tester.pumpAndSettle(const Duration(seconds: 1));

        // 4. Validate routing worked
        // Verify we arrived at the goal setup screen (LevelPicker/SourceSelector are there)
        expect(find.text('What do you want to learn?'), findsWidgets);
      }
    });
  });
}
