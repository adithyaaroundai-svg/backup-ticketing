import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ticketing_system/features/developer_crm/domain/entities/client.dart';
import 'package:ticketing_system/features/developer_crm/presentation/widgets/edit_client_dialog.dart';

void main() {
  group('EditClientDialog', () {
    testWidgets('renders initial client details correctly', (tester) async {
      final client = Client(
        id: 42,
        name: 'Acme Corp',
        contact: '+91 9876543210',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditClientDialog(
              client: client,
              onSave: (_, __) async {},
            ),
          ),
        ),
      );

      expect(find.text('Edit Client Details'), findsOneWidget);
      expect(find.text('Update name or contact info for client #42'), findsOneWidget);
      expect(find.text('Acme Corp'), findsOneWidget);
      expect(find.text('+91 9876543210'), findsOneWidget);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('validates required client name', (tester) async {
      final client = Client(id: 1, name: 'Old Name');
      bool saved = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditClientDialog(
              client: client,
              onSave: (_, __) async {
                saved = true;
              },
            ),
          ),
        ),
      );

      // Clear the name field
      await tester.enterText(find.widgetWithText(TextFormField, 'Old Name'), '');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(find.text('Client name is required.'), findsOneWidget);
      expect(saved, isFalse);
    });

    testWidgets('submits trimmed name and contact', (tester) async {
      final client = Client(id: 5, name: 'Sasco');
      String? savedName;
      String? savedContact;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EditClientDialog(
              client: client,
              onSave: (name, contact) async {
                savedName = name;
                savedContact = contact;
              },
            ),
          ),
        ),
      );

      await tester.enterText(find.widgetWithText(TextFormField, 'Sasco'), '  Sasco International  ');
      await tester.enterText(find.byType(TextFormField).at(1), '  info@sasco.com  ');
      await tester.tap(find.text('Save Changes'));
      await tester.pump();

      expect(savedName, equals('Sasco International'));
      expect(savedContact, equals('info@sasco.com'));
    });
  });
}

