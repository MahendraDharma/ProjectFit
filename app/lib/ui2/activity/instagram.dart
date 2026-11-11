// Instagram Stories, straight in: the poster as the story's picture, or a
// transparent sticker of the numbers for the person to place over their own
// photo or video inside Instagram.
//
// Meta's documented route ("Sharing to Stories", developers.facebook.com):
//   iOS     — the pasteboard carries the images under the
//             com.instagram.sharedSticker.* keys, then
//             instagram-stories://share?source_application=<App ID> opens it
//             (InstagramBridge in AppDelegate.swift);
//   Android — the com.instagram.share.ADD_TO_STORY intent with
//             source_application, a background image and/or an
//             interactive_asset_uri sticker (NativeChannels.kt).
// Both REQUIRE a Facebook App ID since 2023; without one Instagram refuses.
// The ID is public (it travels in every share), so it lives in the code — but
// it is the owner's, made in their own Meta developer account, so until it is
// filled in the direct buttons stay hidden and the system share sheet (which
// lists Instagram too) is the only way out.
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../l10n/display_text.dart';
import '../screens/home_screen.dart' show unitsOf;
import '../theme.dart';
import 'poster.dart' show posterHero, posterStats, splitStatUnit;
import 'share.dart' show localizedExportCaption;
import 'summary.dart' show ActivityResult;

/// The owner's Facebook App ID. Paste it as the default value, or build with
/// `--dart-define=META_APP_ID=...`. Empty hides the direct Instagram buttons.
const kMetaAppId = String.fromEnvironment('META_APP_ID', defaultValue: '');

const _channel = MethodChannel('projectfit/instagram');

/// Whether a direct share can be offered: an App ID, a phone, and Instagram on
/// it. Never throws.
Future<bool> instagramStoriesAvailable() async {
  if (kMetaAppId.isEmpty || !(Platform.isIOS || Platform.isAndroid)) {
    return false;
  }
  try {
    return await _channel.invokeMethod<bool>('available') ?? false;
  } catch (_) {
    return false;
  }
}

/// Open Instagram's story editor with [background] (a full picture) and/or
/// [sticker] (a transparent PNG laid on top, movable there). [top] and
/// [bottom] colour the story behind a sticker that has no background. False
/// when Instagram could not be opened.
Future<bool> shareInstagramStory({
  Uint8List? background,
  Uint8List? sticker,
  required Color top,
  required Color bottom,
}) async {
  String hex(Color c) =>
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  try {
    return await _channel.invokeMethod<bool>('shareStory', {
          'appId': kMetaAppId,
          'background': background,
          'sticker': sticker,
          'top': hex(top),
          'bottom': hex(bottom),
        }) ??
        false;
  } catch (_) {
    return false;
  }
}

/// The session as a sticker: the app's name, the activity, the one big number,
/// up to three more and the route, on nothing — transparent, so it sits on the
/// person's own photo or video. A soft shadow under the type keeps it readable
/// over a bright picture without a panel around it.
class StoryStickerCard extends StatelessWidget {
  final ActivityResult r;

  /// Dark type, for a sticker going over a bright photo.
  final bool darkInk;
  const StoryStickerCard(this.r, {super.key, this.darkInk = false});

  static const width = 300.0;

  @override
  Widget build(BuildContext c) {
    final u = unitsOf(c);
    final accent = r.activity.color;
    final hero = posterHero(r, u);
    final stats = posterStats(r, u).take(3).toList();
    final shade = [
      Shadow(
          color: (darkInk ? C.white : C.n900).withValues(alpha: .55),
          blurRadius: 8)
    ];
    // Named for the light case; it is the ink, whichever ink was asked for.
    final white = darkInk ? C.n900 : C.white;
    final caption = localizedExportCaption(c, r, hero.$3);
    return MediaQuery(
      data: MediaQuery.of(c).copyWith(textScaler: TextScaler.noScaling),
      // Transparent Material: the type styles resolve the same wherever the
      // sticker is drawn, and nothing is painted behind it.
      child: Material(
        type: MaterialType.transparency,
        child: SizedBox(
          width: width,
          child: Padding(
            padding: const EdgeInsets.all(S.x4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: S.x2,
                      height: S.x2,
                      decoration: BoxDecoration(
                        color: C.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: S.x2),
                    Text(
                      'ProjectFit',
                      style: F.cap.copyWith(
                        color: white.withValues(alpha: .85),
                        fontWeight: FontWeight.w700,
                        shadows: shade,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: S.x2),
                Text(
                  r.activity.displayName(c),
                  style: F.n17.copyWith(color: white, shadows: shade),
                  maxLines: 1,
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        hero.$1,
                        style: F.n48.copyWith(color: white, shadows: shade),
                      ),
                      if (hero.$2.isNotEmpty) ...[
                        const SizedBox(width: S.x2),
                        Text(
                          uiText(c, hero.$2),
                          style: F.body.copyWith(color: white, shadows: shade),
                        ),
                      ],
                    ],
                  ),
                ),
                // The caption, unless it only repeats the activity's name.
                if (caption != r.activity.displayName(c))
                  Text(
                    caption,
                    style: F.cap.copyWith(
                      color: white.withValues(alpha: .85),
                      shadows: shade,
                    ),
                  ),
                if (r.route.length >= 2) ...[
                  const SizedBox(height: S.x3),
                  SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: CustomPaint(
                        painter: StickerRoute(r.route, accent,
                            casing: darkInk ? C.white : C.n900)),
                  ),
                ],
                if (stats.isNotEmpty) ...[
                  const SizedBox(height: S.x3),
                  Row(
                    children: [
                      for (final s in stats)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                uiText(c, s.$1),
                                style: F.cap.copyWith(
                                  color: white.withValues(alpha: .85),
                                  shadows: shade,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(text: splitStatUnit(s.$2).$1),
                                      if (splitStatUnit(s.$2).$2
                                          case final unit?)
                                        TextSpan(
                                          text: ' ${uiText(c, unit)}',
                                          style: F.cap.copyWith(
                                            color: white,
                                            shadows: shade,
                                          ),
                                        ),
                                    ],
                                  ),
                                  style: F.head.copyWith(
                                    color: white,
                                    shadows: shade,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The route alone, fitted into its box with its shape kept, in the activity's
/// colour over a dark casing so it reads on a light photo too.
class StickerRoute extends CustomPainter {
  final List<Offset> route; // normalised 0…1
  final Color color;

  /// The outline under the line, so it reads on any photo.
  final Color casing;
  StickerRoute(this.route, this.color, {this.casing = C.n900});

  @override
  void paint(Canvas canvas, Size size) {
    if (route.length < 2) return;
    var minX = route.first.dx, maxX = minX, minY = route.first.dy, maxY = minY;
    for (final p in route) {
      minX = math.min(minX, p.dx);
      maxX = math.max(maxX, p.dx);
      minY = math.min(minY, p.dy);
      maxY = math.max(maxY, p.dy);
    }
    final w = math.max(maxX - minX, 1e-6), h = math.max(maxY - minY, 1e-6);
    final k = math.min(size.width / w, size.height / h);
    final path = Path();
    for (var i = 0; i < route.length; i++) {
      final o = Offset((route[i].dx - minX) * k, (route[i].dy - minY) * k);
      i == 0 ? path.moveTo(o.dx, o.dy) : path.lineTo(o.dx, o.dy);
    }
    Paint stroke(Color c, double width) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = c;
    canvas.drawPath(path, stroke(casing.withValues(alpha: .40), 7));
    canvas.drawPath(path, stroke(color, 3.5));
  }

  @override
  bool shouldRepaint(StickerRoute o) =>
      o.route != route || o.color != color || o.casing != casing;
}
