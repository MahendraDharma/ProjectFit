// The share card for a lift or a calisthenics session.
//
// The route card has a map in the middle; a strength session has no route, so
// that card printed a big number over an empty gradient. What a lifter wants
// to show is what they DID — the exercises, the muscles, the best set — so
// this card offers three designs over the same frame, swiped through on the
// share screen (the pattern workout-log apps such as Hevy use):
//
//   · workout  — every exercise with its set count and best set
//   · muscles  — a front/back body map shaded by sets per muscle
//   · best     — the heaviest set, the estimated 1RM, the most reps
//
// Nothing on it is invented: a bodyweight session has no volume, so its big
// number is the reps it actually logged, and the "best" design leaves out the
// tiles that need a load when nothing had one. Sets per muscle use the same
// counting rule as the workout tab (`muscleVolume`: 1 per primary muscle, ½
// per secondary).
//
// [clear] draws the same content with no background, for the transparent
// sticker laid over a photo inside Instagram; [darkInk] sets it in dark type
// for a bright photo.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:projectfit_analytics/onehz.dart' show muscleVolume;

import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../../state/clock_format.dart' show formatClockOf;
import '../../state/units_controller.dart';
import '../body_map_data.dart';
import '../screens/home_screen.dart' show unitsOf;
import '../screens/muscle_recovery.dart' show kMuscleRegions;
import '../theme.dart';
import 'catalogue.dart' show exerciseByKey;
import 'muscle_sets.dart' show strengthSetInputs;
import 'poster.dart' show PosterFormat, kPosterW;
import 'summary.dart';

/// The three designs a strength session can be shared as.
enum StrengthDesign { workout, muscles, best }

String strengthDesignLabel(BuildContext c, StrengthDesign d) {
  final l = AppLocalizations.of(c);
  return switch (d) {
    StrengthDesign.workout => l?.strengthDesignWorkout ?? 'Workout',
    StrengthDesign.muscles => l?.strengthDesignMuscles ?? 'Muscles',
    StrengthDesign.best => l?.strengthDesignBest ?? 'Best sets',
  };
}

/// The sticker's height: a little taller than the post so a list fits.
const kStrengthStickerH = 400.0;

/// One exercise of the session: how many sets, how many reps, its best set.
class ExerciseLine {
  final String key;
  final int sets;
  final int reps;

  /// Heaviest set (ties: more reps); for an exercise with no load, the set
  /// with the most reps.
  final LoggedSet best;
  final double? volumeKg;
  const ExerciseLine(this.key, this.sets, this.reps, this.best, this.volumeKg);

  bool get loaded => best.loadKg != null;
}

/// The session per exercise, in the order it was first logged.
List<ExerciseLine> exerciseLines(StrengthLog log) {
  final order = <String>[];
  final by = <String, List<LoggedSet>>{};
  for (final s in log.sets) {
    (by[s.exerciseKey] ??= () {
      order.add(s.exerciseKey);
      return <LoggedSet>[];
    }()).add(s);
  }
  return [
    for (final k in order)
      () {
        final sets = by[k]!;
        LoggedSet best = sets.first;
        for (final s in sets.skip(1)) {
          final a = s.loadKg ?? -1, b = best.loadKg ?? -1;
          if (a > b || (a == b && s.reps > best.reps)) best = s;
        }
        double? vol;
        for (final s in sets) {
          final v = s.volume;
          if (v != null) vol = (vol ?? 0) + v;
        }
        return ExerciseLine(
          k,
          sets.length,
          sets.fold(0, (a, s) => a + s.reps),
          best,
          vol,
        );
      }(),
  ];
}

/// Sets per catalogue muscle for this one session (1 per primary, ½ per
/// secondary — the workout tab's rule).
Map<String, double> sessionMuscleSets(StrengthLog log) =>
    muscleVolume(strengthSetInputs(log)).value?.setsByMuscle ?? const {};

String _num(double x) =>
    x == x.roundToDouble() ? grouped(x.round()) : x.toStringAsFixed(1);

String _weight(UnitsController? u, double kg) =>
    '${_num(u == null ? kg : u.weightValue(kg))} ${u?.weightUnit ?? 'kg'}';

String exerciseName(BuildContext c, String key) =>
    exerciseByKey(key)?.labelFor(Localizations.localeOf(c).languageCode) ?? key;

/// A catalogue muscle in the reader's language. The select keys cannot hold
/// spaces, so 'Lower back' is asked for as 'Lower_back'; a muscle the select
/// does not know comes back as itself.
String muscleName(BuildContext c, String muscle) {
  final key = muscle.replaceAll(' ', '_');
  final out = AppLocalizations.of(c)?.muscleName(key) ?? key;
  return out == key ? muscle : out;
}

/// The card itself. A fixed-size picture, like [PosterCard]: authored at
/// [kPosterW] and exported at 3×, and it never inherits the reader's text
/// scale.
class StrengthShareCard extends StatelessWidget {
  final ActivityResult r;
  final StrengthDesign design;
  final PosterFormat format;
  final ImageProvider? photo;

  /// No background at all: the transparent sticker.
  final bool clear;

  /// Dark type, for a sticker going over a bright photo.
  final bool darkInk;

  const StrengthShareCard(
    this.r, {
    super.key,
    this.design = StrengthDesign.workout,
    this.format = PosterFormat.post,
    this.photo,
    this.clear = false,
    this.darkInk = false,
  });

  double get _height => clear ? kStrengthStickerH : format.height;
  bool get _compact => _height < 360;

  @override
  Widget build(BuildContext c) {
    final accent = r.activity.color;
    final ink = darkInk ? C.n900 : C.white;
    final shade = clear
        ? [
            Shadow(
              color: (darkInk ? C.white : C.n900).withValues(alpha: .55),
              blurRadius: 8,
            ),
          ]
        : const <Shadow>[];
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        S.x5,
        _compact ? S.x3 : S.x4,
        S.x4,
        _compact ? S.x3 : S.x4,
      ),
      child: _Content(
        r: r,
        design: design,
        compact: _compact,
        ink: ink,
        accent: clear && !darkInk ? ink : accent,
        dot: accent,
        shade: shade,
      ),
    );
    return MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.noScaling),
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: kPosterW,
          height: _height,
          child: clear
              ? content
              : ClipRRect(
                  borderRadius: R.rXl,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (photo != null)
                        Image(image: photo!, fit: BoxFit.cover)
                      else
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Color.lerp(C.n900, accent, .14)!,
                                Color.lerp(C.n900, accent, .46)!,
                              ],
                            ),
                          ),
                        ),
                      // The shadow that keeps the type readable over a photo.
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: C.n900.withValues(
                            alpha: photo == null ? .20 : .58,
                          ),
                        ),
                      ),
                      content,
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  final ActivityResult r;
  final StrengthDesign design;
  final bool compact;
  final Color ink, accent, dot;
  final List<Shadow> shade;
  const _Content({
    required this.r,
    required this.design,
    required this.compact,
    required this.ink,
    required this.accent,
    required this.dot,
    required this.shade,
  });

  TextStyle _t(TextStyle s, {double alpha = 1, Color? color}) => s.copyWith(
    color: (color ?? ink).withValues(alpha: alpha),
    shadows: shade,
  );

  @override
  Widget build(BuildContext c) {
    final l = AppLocalizations.of(c);
    final u = unitsOf(c);
    final log = r.strength;
    final vol = log.volumeKg;
    final reps = log.repCount;
    // The hero: volume when anything had a load, otherwise the reps — never
    // a volume of zero for a session that did real work.
    final (heroV, heroU) = vol != null
        ? (_num(u == null ? vol : u.weightValue(vol)), u?.weightUnit ?? 'kg')
        : (grouped(reps), l?.strengthShareRepsUnit ?? 'reps');
    final stats = <(String, String)>[
      (l?.strengthShareTime ?? 'Time', hms(r.duration)),
      (l?.strengthShareSets ?? 'Sets', '${log.setCount}'),
      if (vol != null) (l?.strengthShareRepsLabel ?? 'Reps', grouped(reps)),
      if (r.avgHr != null)
        (l?.strengthShareHeartRate ?? 'Heart rate', '${r.avgHr}'),
    ].take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: S.x2,
              height: S.x2,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: S.x2),
            Text(
              'ProjectFit',
              style: _t(
                F.over,
                alpha: .8,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(width: S.x3),
            // The date shrinks rather than pushing the name off the card.
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  '${displayDate(c, r.start)} · ${formatClockOf(r.start)}',
                  style: _t(F.over, alpha: .7).copyWith(letterSpacing: 0),
                  maxLines: 1,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? S.x2 : S.x3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            r.activity.displayName(c).toUpperCase(),
            style: _t(F.n17, color: accent).copyWith(letterSpacing: .6),
            maxLines: 1,
          ),
        ),
        SizedBox(
          height: compact ? 38 : 46,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(heroV, style: _t(F.n48)),
                const SizedBox(width: S.x2),
                Text(heroU, style: _t(F.cap, alpha: .75)),
              ],
            ),
          ),
        ),
        SizedBox(height: compact ? S.x2 : S.x3),
        Row(
          children: [
            for (final (i, s) in stats.indexed) ...[
              if (i > 0) const SizedBox(width: S.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.$1.toUpperCase(),
                        style: _t(F.over, alpha: .7).copyWith(letterSpacing: 1),
                        maxLines: 1,
                      ),
                    ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        s.$2,
                        style: _t(compact ? F.n17 : F.n24),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: compact ? S.x2 : S.x4),
        Container(height: 1, color: ink.withValues(alpha: .18)),
        SizedBox(height: compact ? S.x2 : S.x3),
        Expanded(
          child: switch (design) {
            StrengthDesign.workout => _workout(c, u),
            StrengthDesign.muscles => _muscles(c),
            StrengthDesign.best => _best(c, u),
          },
        ),
      ],
    );
  }

  // ─────────── workout: the exercise list ───────────
  Widget _workout(BuildContext c, UnitsController? u) {
    final l = AppLocalizations.of(c);
    final lines = exerciseLines(r.strength);
    // On a story there is room for every set under its exercise, the way a
    // workout log prints it; a post keeps one line per exercise.
    final detail = !compact;
    final rowH = compact ? 22.0 : 44.0;
    String setText(LoggedSet s) => s.loadKg == null
        ? '${s.reps}'
        : '${_num(u == null ? s.loadKg! : u.weightValue(s.loadKg!))}×${s.reps}';
    return LayoutBuilder(
      builder: (c, box) {
        final fit = math.max(1, (box.maxHeight / rowH).floor());
        final shown = lines.length <= fit
            ? lines
            : lines.take(fit - 1).toList();
        final more = lines.length - shown.length;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final e in shown)
              SizedBox(
                height: rowH,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: 28,
                          child: Text(
                            '${e.sets}×',
                            style: _t(
                              F.cap,
                              color: accent,
                            ).copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            exerciseName(c, e.key),
                            style: _t(compact ? F.cap : F.body),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: S.x2),
                        Text(
                          e.loaded
                              ? '${_weight(u, e.best.loadKg!)} × ${e.best.reps}'
                              : (l?.strengthShareRepsCount(e.best.reps) ??
                                    '${e.best.reps} reps'),
                          style: _t(
                            F.cap,
                            alpha: .8,
                          ).copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    if (detail)
                      Padding(
                        padding: const EdgeInsets.only(left: 28, top: 2),
                        child: Text(
                          [
                            for (final s in r.strength.sets)
                              if (s.exerciseKey == e.key) setText(s),
                          ].join('  ·  '),
                          style: _t(
                            F.over,
                            alpha: .6,
                          ).copyWith(letterSpacing: 0),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            if (more > 0)
              SizedBox(
                height: rowH,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l?.strengthShareMore(more) ?? '+$more more',
                    style: _t(F.cap, alpha: .6),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  // ─────────── muscles: the body map ───────────
  Widget _muscles(BuildContext c) {
    final l = AppLocalizations.of(c);
    final sets = sessionMuscleSets(r.strength);
    final rows = sets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = rows.isEmpty ? 1.0 : rows.first.value;
    final fill = <String, double>{};
    for (final e in sets.entries) {
      for (final region in kMuscleRegions[e.key] ?? const <String>[]) {
        fill[region] = math.max(fill[region] ?? 0, e.value / top);
      }
    }
    String fmt(double x) =>
        x == x.roundToDouble() ? '${x.toInt()}' : x.toStringAsFixed(1);
    // Untrained regions: faint on the card's own surface, stronger on the
    // sticker, which has to read over somebody's photo.
    final rest = shade.isEmpty ? .13 : .32;
    Widget body() => Row(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: ShareBodyPainter(
              kBodyFront,
              fill,
              accent,
              ink,
              rest: rest,
            ),
          ),
        ),
        const SizedBox(width: S.x1),
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: ShareBodyPainter(kBodyBack, fill, accent, ink, rest: rest),
          ),
        ),
      ],
    );
    Widget entry(MapEntry<String, double> e) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          muscleName(c, e.key),
          style: _t(F.cap).copyWith(fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        Text(
          l?.strengthShareSetsCount(fmt(e.value)) ?? '${fmt(e.value)} sets',
          style: _t(F.over, alpha: .7).copyWith(letterSpacing: 0),
        ),
      ],
    );
    const entryH = 34.0;
    if (compact) {
      // A post: the map beside as many muscles as fit under it.
      return Row(
        children: [
          Expanded(flex: 5, child: body()),
          const SizedBox(width: S.x3),
          Expanded(
            flex: 4,
            child: LayoutBuilder(
              builder: (c, box) {
                final n = math.max(1, (box.maxHeight / entryH).floor());
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final e in rows.take(n))
                      SizedBox(height: entryH, child: entry(e)),
                  ],
                );
              },
            ),
          ),
        ],
      );
    }
    // A story: the map large, the muscles two to a line under it.
    final list = rows.take(6).toList();
    return Column(
      children: [
        Expanded(child: body()),
        const SizedBox(height: S.x3),
        for (var i = 0; i < list.length; i += 2)
          SizedBox(
            height: entryH + S.x1,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: entry(list[i])),
                const SizedBox(width: S.x3),
                Expanded(
                  child: i + 1 < list.length
                      ? entry(list[i + 1])
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ─────────── best: the highlights ───────────
  Widget _best(BuildContext c, UnitsController? u) {
    final l = AppLocalizations.of(c);
    final log = r.strength;
    final lines = exerciseLines(log);
    final tiles = <(IconData, String, String, String)>[];
    final top = log.topSet;
    if (top != null && top.loadKg != null) {
      tiles.add((
        LucideIcons.trophy,
        l?.strengthShareHeaviest ?? 'Heaviest set',
        exerciseName(c, top.exerciseKey),
        '${_weight(u, top.loadKg!)} × ${top.reps}',
      ));
      final rm = oneRepMax(top);
      if (rm != null) {
        tiles.add((
          LucideIcons.medal,
          l?.strengthShareOneRm ?? 'Est. 1RM',
          exerciseName(c, top.exerciseKey),
          _weight(u, rm.roundToDouble()),
        ));
      }
    }
    if (log.sets.isNotEmpty) {
      final most = log.sets.reduce((a, b) => b.reps > a.reps ? b : a);
      tiles.add((
        LucideIcons.repeat,
        l?.strengthShareMostReps ?? 'Most reps in a set',
        exerciseName(c, most.exerciseKey),
        l?.strengthShareRepsCount(most.reps) ?? '${most.reps} reps',
      ));
    }
    final byVol = lines.where((e) => e.volumeKg != null).toList()
      ..sort((a, b) => b.volumeKg!.compareTo(a.volumeKg!));
    if (byVol.isNotEmpty) {
      tiles.add((
        LucideIcons.dumbbell,
        l?.strengthShareMostVolume ?? 'Most volume',
        exerciseName(c, byVol.first.key),
        _weight(u, byVol.first.volumeKg!),
      ));
    } else if (lines.isNotEmpty) {
      final busiest = [...lines]..sort((a, b) => b.reps.compareTo(a.reps));
      tiles.add((
        LucideIcons.flame,
        l?.strengthShareMostTotalReps ?? 'Most reps overall',
        exerciseName(c, busiest.first.key),
        l?.strengthShareRepsCount(busiest.first.reps) ??
            '${busiest.first.reps} reps',
      ));
    }
    if (tiles.length < 4 && log.setCount > 0 && log.volumeKg == null) {
      tiles.add((
        LucideIcons.chartNoAxesColumn,
        l?.strengthShareAvgReps ?? 'Avg reps per set',
        '',
        (log.repCount / log.setCount).toStringAsFixed(1),
      ));
    }
    if (tiles.length < 4 && lines.isNotEmpty) {
      tiles.add((
        LucideIcons.listChecks,
        l?.strengthShareExercises ?? 'Exercises',
        '',
        '${lines.length}',
      ));
    }
    Widget tile((IconData, String, String, String) t) => Container(
      padding: EdgeInsets.all(compact ? S.x2 : S.x3),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: .08),
        borderRadius: R.rMd,
        border: Border.all(color: ink.withValues(alpha: .14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(t.$1, size: compact ? 11 : 13, color: accent),
              const SizedBox(width: S.x1),
              Expanded(
                child: Text(
                  t.$2,
                  style: _t(
                    F.over,
                    alpha: .75,
                  ).copyWith(letterSpacing: 0, height: 1.15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : S.x1),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(t.$4, style: _t(compact ? F.n17 : F.n24), maxLines: 1),
          ),
          if (t.$3.isNotEmpty)
            Text(
              t.$3,
              style: _t(F.over, alpha: .7).copyWith(letterSpacing: 0),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
    );
    final shown = tiles.take(4).toList();
    final gap = compact ? S.x2 : S.x3;
    return LayoutBuilder(
      builder: (c, box) {
        // A story has room to spare, so a tile keeps a tile's height instead
        // of stretching; a post and the sticker share out what there is.
        final rowsN = math.max(1, (shown.length + 1) ~/ 2);
        final fitH = (box.maxHeight - gap * (rowsN - 1)) / rowsN;
        final tileH = compact ? fitH : math.min(96.0, fitH);
        Widget row(Widget child) => SizedBox(height: tileH, child: child);
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < shown.length; i += 2) ...[
              if (i > 0) SizedBox(height: gap),
              row(
                Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: tile(shown[i])),
                    SizedBox(width: gap),
                    Expanded(
                      child: i + 1 < shown.length
                          ? tile(shown[i + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// The body map for a share card: each region in the accent, as strong as the
/// share of the session's sets that went to it; untrained regions a faint
/// outline of the card's ink.
class ShareBodyPainter extends CustomPainter {
  final List<(String, List<List<double>>)> shapes;
  final Map<String, double> fill; // region → 0…1
  final Color accent, ink;

  /// The opacity of an untrained region.
  final double rest;
  ShareBodyPainter(
    this.shapes,
    this.fill,
    this.accent,
    this.ink, {
    this.rest = .13,
  });

  @override
  void paint(Canvas c, Size s) {
    final k = math.min(s.width / 100, s.height / 200);
    final dx = (s.width - 100 * k) / 2, dy = (s.height - 200 * k) / 2;
    for (final (key, polys) in shapes) {
      final f = fill[key];
      final col = f == null
          ? ink.withValues(alpha: rest)
          : Color.lerp(ink.withValues(alpha: rest), accent, .35 + .65 * f)!;
      for (final pts in polys) {
        if (pts.length < 6) continue;
        final path = Path()..moveTo(dx + pts[0] * k, dy + pts[1] * k);
        for (var i = 2; i + 1 < pts.length; i += 2) {
          path.lineTo(dx + pts[i] * k, dy + pts[i + 1] * k);
        }
        path.close();
        c.drawPath(path, Paint()..color = col);
      }
    }
  }

  @override
  bool shouldRepaint(ShareBodyPainter o) =>
      o.fill != fill || o.accent != accent || o.ink != ink || o.rest != rest;
}
