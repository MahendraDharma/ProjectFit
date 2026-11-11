// Sharing a workout to Instagram: a named Share button on the summary, a
// Sticker choice that exports a TRANSPARENT picture of the numbers, and the
// direct Instagram story button only when the owner's App ID is set.
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/ui2/activity/catalogue.dart';
import 'package:projectfit/ui2/activity/instagram.dart';
import 'package:projectfit/ui2/activity/share.dart';
import 'package:projectfit/ui2/activity/summary.dart';
import 'package:projectfit/ui2/ui2.dart';

final _run = ActivityResult(
  activityByName('Running')!,
  start: DateTime(2026, 8, 12, 7, 5),
  duration: const Duration(minutes: 45, seconds: 12),
  avgHr: 156,
  calories: 604,
  distanceKm: 8.02,
  route: [for (var i = 0; i < 40; i++) Offset(i / 40, (i % 10) / 10)],
);

Widget _host(Widget w) => MaterialApp(theme: buildTheme(Brightness.dark), home: w);

void main() {
  testWidgets('the summary names its Share button and it opens the sheet', (t) async {
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(ActivitySummary(_run)));
    await t.pump(const Duration(milliseconds: 300));
    final button = find.widgetWithText(BigButton, 'Share this running');
    expect(button, findsOneWidget);
    await t.tap(button);
    await t.pumpAndSettle();
    expect(find.byType(ShareSheet), findsOneWidget);
  });

  testWidgets('Sticker is a third choice, and it exports a clear background', (t) async {
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(ShareSheet(_run)));
    await t.pump(const Duration(milliseconds: 300));
    // No App ID in a test build: the direct button is not offered.
    expect(kMetaAppId, isEmpty);
    expect(find.text('Instagram story'), findsNothing);
    expect(find.text('Share'), findsWidgets);

    await t.tap(find.text('Sticker'));
    await t.pumpAndSettle();
    expect(find.byType(StoryStickerCard), findsOneWidget);
    expect(find.text('Your photo'), findsNothing, reason: 'no photo under a sticker');

    // The exported picture is the sticker alone: its corner pixel is clear.
    final boundary = t.renderObject<RenderRepaintBoundary>(find
        .ancestor(of: find.byType(StoryStickerCard), matching: find.byType(RepaintBoundary))
        .first);
    final bytes = await t.runAsync(() async {
      final img = await boundary.toImage(pixelRatio: 1);
      return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    });
    final alpha = Uint8List.view(bytes!.buffer)[3];
    expect(alpha, 0);
  });

  testWidgets('the sticker prints the hero, the route and the stats it has', (t) async {
    await t.pumpWidget(_host(Center(child: StoryStickerCard(_run))));
    expect(find.text('8.02'), findsOneWidget);
    expect(find.text('ProjectFit'), findsOneWidget);
    expect(find.byType(CustomPaint), findsWidgets);
    // A lift has no route and no distance: nothing invented for it.
    final lift = ActivityResult(activityByName('Weight training')!,
        start: DateTime(2026, 8, 11, 18), duration: const Duration(minutes: 50), calories: 300);
    await t.pumpWidget(_host(Center(child: StoryStickerCard(lift))));
    expect(find.text('8.02'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
  });
}
