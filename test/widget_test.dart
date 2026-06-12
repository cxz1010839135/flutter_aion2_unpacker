import 'package:aion2_unpacker/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches', (tester) async {
    await tester.pumpWidget(const Aion2UnpackerApp());
    await tester.pump();
    expect(find.text('AION2'), findsOneWidget);
  });
}
