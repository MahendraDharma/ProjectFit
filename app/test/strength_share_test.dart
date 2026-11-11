// Sharing a lift or a calisthenics session: three designs (workout list,
// muscles, best sets) swiped through on the share screen, a reps hero when
// nothing had a load, and every design fitting both formats and the sticker.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projectfit/l10n/app_localizations.dart';
import 'package:projectfit/ui2/activity/catalogue.dart';
import 'package:projectfit/ui2/activity/poster.dart';
import 'package:projectfit/ui2/activity/share.dart';
import 'package:projectfit/ui2/activity/strength_share.dart';
import 'package:projectfit/ui2/activity/summary.dart';
import 'package:projectfit/ui2/ui2.dart';

final _t0 = DateTime(2026, 11, 11, 17, 30);
LoggedSet _s(String k, int reps, int min, [double? kg]) => LoggedSet(
  k,
  reps,
  loadKg: kg,
  at: _t0.add(Duration(minutes: min)),
);

final _gym = ActivityResult(
  activityByName('Weight training')!,
  start: _t0,
  duration: const Duration(minutes: 58, seconds: 40),
  avgHr: 118,
  strength: StrengthLog([
    _s('back_squat', 8, 2, 80),
    _s('back_squat', 6, 5, 90),
    _s('bench_press', 8, 10, 60),
    _s('bench_press', 8, 13, 62.5),
    _s('deadlift', 5, 20, 110),
  ]),
);

final _cali = ActivityResult(
  activityByName('Calisthenics')!,
  start: _t0,
  duration: const Duration(minutes: 42, seconds: 5),
  avgHr: 124,
  strength: StrengthLog([
    for (var i = 0; i < 3; i++) _s('pull_up', 10 - i, i * 3),
    for (var i = 0; i < 3; i++) _s('chin_up', 9 - i, 10 + i * 3),
    for (var i = 0; i < 3; i++) _s('dip', 15 - i, 20 + i * 3),
    for (var i = 0; i < 3; i++) _s('push_up', 25 - i, 30 + i * 2),
    _s('pike_push_up', 12, 38),
    _s('hanging_leg_raise', 12, 39),
    _s('pistol_squat', 6, 41),
    _s('plank', 1, 42),
  ]),
);

Widget _host(Widget w, {Locale? locale}) => MaterialApp(
  theme: buildTheme(Brightness.dark),
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: w,
);

void main() {
  group('exerciseLines', () {
    test('one line per exercise, in the order it was first logged', () {
      final lines = exerciseLines(_gym.strength);
      expect(lines.map((e) => e.key), [
        'back_squat',
        'bench_press',
        'deadlift',
      ]);
      expect(lines.first.sets, 2);
      expect(lines.first.reps, 14);
      expect(lines.first.volumeKg, 80 * 8 + 90 * 6);
    });

    test('the best set is the heaviest, ties broken by reps', () {
      final best = exerciseLines(
        StrengthLog([
          _s('bench_press', 10, 0, 60),
          _s('bench_press', 6, 1, 70),
          _s('bench_press', 8, 2, 70),
        ]),
      ).single.best;
      expect((best.loadKg, best.reps), (70.0, 8));
    });

    test('with no load, the best set is the one with the most reps', () {
      final e = exerciseLines(_cali.strength).first;
      expect(e.loaded, isFalse);
      expect(e.best.reps, 10);
      expect(e.volumeKg, isNull);
    });
  });

  test('sets per muscle use the workout tab rule (1 primary, ½ secondary)', () {
    final m = sessionMuscleSets(StrengthLog([_s('bench_press', 8, 0, 60)]));
    expect(m['Chest'], 1);
    expect(m['Triceps'], .5);
  });

  testWidgets('muscle names are translated, spaces and all', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(
      _host(
        Builder(
          builder: (c) {
            ctx = c;
            return const SizedBox();
          },
        ),
        locale: const Locale('id'),
      ),
    );
    expect(muscleName(ctx, 'Quads'), 'Paha depan');
    expect(muscleName(ctx, 'Lower back'), 'Punggung bawah');
    expect(
      muscleName(ctx, 'Something new'),
      'Something new',
      reason: 'an unknown muscle comes back as itself',
    );
  });

  for (final (name, r) in [('gym', _gym), ('calisthenics', _cali)]) {
    for (final d in StrengthDesign.values) {
      for (final (f, clear) in [
        (PosterFormat.post, false),
        (PosterFormat.story, false),
        (PosterFormat.post, true),
      ]) {
        testWidgets(
          '$name · ${d.name} · ${clear ? 'sticker' : f.name} fits its card',
          (t) async {
            await t.pumpWidget(
              _host(
                Center(
                  child: StrengthShareCard(
                    r,
                    design: d,
                    format: f,
                    clear: clear,
                  ),
                ),
              ),
            );
            await t.pump();
            expect(t.takeException(), isNull);
            final size = t.getSize(find.byType(StrengthShareCard));
            expect(size.width, kPosterW);
            expect(size.height, clear ? kStrengthStickerH : f.height);
          },
        );
      }
    }
  }

  testWidgets('a bodyweight session leads with its reps, not a volume', (
    t,
  ) async {
    await t.pumpWidget(_host(Center(child: StrengthShareCard(_cali))));
    await t.pump();
    expect(find.text('${_cali.strength.repCount}'), findsOneWidget);
    expect(find.text('reps'), findsOneWidget);
    expect(find.text('kg'), findsNothing);
  });

  testWidgets('the workout design says how many exercises did not fit', (
    t,
  ) async {
    await t.pumpWidget(_host(Center(child: StrengthShareCard(_cali))));
    await t.pump();
    expect(find.textContaining(RegExp(r'^\+\d+ more$')), findsOneWidget);
  });

  testWidgets('the best design shows the heaviest set and an estimated 1RM', (
    t,
  ) async {
    await t.pumpWidget(
      _host(
        Center(
          child: StrengthShareCard(
            _gym,
            design: StrengthDesign.best,
            format: PosterFormat.story,
          ),
        ),
      ),
    );
    await t.pump();
    expect(find.text('Heaviest set'), findsOneWidget);
    expect(find.text('110 kg × 5'), findsOneWidget);
    expect(find.text('Est. 1RM'), findsOneWidget);
  });

  testWidgets('the share screen swaps a lift onto the strength designs', (
    t,
  ) async {
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(ShareSheet(_gym)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.byType(PosterCard), findsNothing);
    expect(find.byType(StrengthShareCard), findsWidgets);
    expect(find.text('Workout'), findsOneWidget);

    await t.tap(find.text('Muscles'));
    await t.pumpAndSettle();
    final shown = t.widget<StrengthShareCard>(
      find
          .descendant(
            of: find.byWidgetPredicate(
              (w) => w is RepaintBoundary && w.key != null,
            ),
            matching: find.byType(StrengthShareCard),
          )
          .first,
    );
    expect(
      shown.design,
      StrengthDesign.muscles,
      reason: 'the exported picture is the design on screen',
    );

    await t.tap(find.text('Sticker'));
    await t.pumpAndSettle();
    expect(find.text('Text colour'), findsOneWidget);
    await t.tap(find.text('Dark'));
    await t.pumpAndSettle();
    expect(
      t
          .widgetList<StrengthShareCard>(find.byType(StrengthShareCard))
          .every((c) => c.clear && c.darkInk),
      isTrue,
    );
  });

  testWidgets('a bodyweight summary does not warn about missing loads', (
    t,
  ) async {
    t.view.physicalSize = const Size(1170, 5000);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(_host(ActivitySummary(_cali)));
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('Some sets had no load'), findsNothing);
    expect(
      find.text('${_cali.strength.repCount} reps · bodyweight'),
      findsOneWidget,
    );
  });
}
