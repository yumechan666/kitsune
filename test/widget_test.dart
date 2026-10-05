// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:kitsune/game/atlas.dart';
import 'package:kitsune/game/renderer.dart';
import 'package:kitsune/main.dart';

void main() {
  testWidgets('Kitsune opens the game screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.byType(GameScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  test('portrait viewport fits the screen width', () {
    final renderer = Renderer(AssetLibrary());
    renderer.resize(390, 844);

    expect(renderer.viewWidth * 844 / 540, closeTo(390, 0.01));
  });
}
