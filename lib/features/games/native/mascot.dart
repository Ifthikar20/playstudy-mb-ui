import 'dart:math' as math;

import 'package:flutter/material.dart';

/// PlayStudy's mascot — **Pip**, an orange-and-white pup.
///
/// Pip is drawn procedurally with [Canvas] (no image assets) so he scales
/// crisply on every device, animates cheaply (ears, blink, head tilt, glancing
/// eyes) and stays consistent with the rest of the native games, which are all
/// vector-drawn. He is the star of both the Flappy ride and the Space Shooter,
/// so this module is shared by both.
///
/// To re-skin or rename the mascot you only need to touch this file.
class Mascot {
  Mascot._();

  /// Friendly name shown in game copy. Change once here to rename the mascot.
  static const String name = 'Pip';

  // Palette pulled from the reference art.
  static const Color orange = Color(0xFFF7941D);
  static const Color orangeDark = Color(0xFFE07A12);
  static const Color orangeLight = Color(0xFFFFB24D);
  static const Color cream = Color(0xFFFFFFFF);
  static const Color creamShade = Color(0xFFE9ECF0);
  static const Color paw = Color(0xFFDCE0E5);
  static const Color pawDark = Color(0xFFBFC5CC);
  static const Color ink = Color(0xFF1A1A1A);

  static Paint _stroke(double w) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..color = ink
    ..strokeJoin = StrokeJoin.round
    ..strokeCap = StrokeCap.round;

  /// Fill then outline a path in Pip's signature heavy ink line.
  static void _fs(Canvas c, Path p, Color fill, double sw) {
    c.drawPath(p, Paint()..color = fill);
    c.drawPath(p, _stroke(sw));
  }

  /// Draw Pip's head centred at [center] with nominal head radius [r].
  ///
  /// All animation inputs are optional and safe to leave at 0:
  ///  * [earFlap]  -1..1  flutters the ears (e.g. when rising/boosting).
  ///  * [blink]     0..1  closes the eyes (1 = shut).
  ///  * [tilt]    radians  rotates the whole head.
  ///  * [look]    -1..1   slides the pupils left/right to glance.
  static void head(
    Canvas canvas,
    Offset center,
    double r, {
    double earFlap = 0,
    double blink = 0,
    double tilt = 0,
    double look = 0,
  }) {
    final sw = r * 0.13;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(tilt);

    // ---- Ears (drawn behind the face) -------------------------------------
    // Left ear: large, pointed, perked up and out.
    final lf = earFlap * r * 0.18;
    final leftEar = Path()
      ..moveTo(-r * 0.52, -r * 0.42)
      ..quadraticBezierTo(-r * 1.18, -r * 0.95 - lf, -r * 1.02, -r * 0.30 - lf)
      ..quadraticBezierTo(-r * 0.92, r * 0.02, -r * 0.46, r * 0.04)
      ..close();
    _fs(canvas, leftEar, orange, sw);
    canvas.drawPath(
      Path()
        ..moveTo(-r * 0.66, -r * 0.30)
        ..quadraticBezierTo(-r * 0.92, -r * 0.42 - lf, -r * 0.86, -r * 0.12 - lf),
      _stroke(sw * 0.7)..color = orangeDark,
    );

    // Right ear: folded over, droopy.
    final rf = earFlap * r * 0.12;
    final rightEar = Path()
      ..moveTo(r * 0.50, -r * 0.46)
      ..quadraticBezierTo(r * 1.22, -r * 0.60 + rf, r * 1.10, r * 0.06 + rf)
      ..quadraticBezierTo(r * 0.96, r * 0.30 + rf, r * 0.58, r * 0.10)
      ..close();
    _fs(canvas, rightEar, orange, sw);

    // ---- Face base (white) ------------------------------------------------
    final face = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: r * 1.92, height: r * 1.86),
        Radius.circular(r * 0.85),
      ));
    _fs(canvas, face, cream, sw);

    // ---- Orange mask over the left + top of the face ----------------------
    canvas.save();
    canvas.clipPath(face);
    final patch = Path()
      ..moveTo(-r * 0.98, -r)
      ..lineTo(r * 0.12, -r)
      // blaze: curve down the centre then back up, leaving a white stripe.
      ..quadraticBezierTo(-r * 0.10, -r * 0.30, r * 0.06, r * 0.10)
      ..quadraticBezierTo(r * 0.16, r * 0.42, -r * 0.10, r * 0.56)
      ..quadraticBezierTo(-r * 0.55, r * 0.66, -r * 0.98, r * 0.40)
      ..close();
    canvas.drawPath(patch, Paint()..color = orange);
    // soft shading where orange meets white.
    canvas.drawPath(
      patch,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw * 0.6
        ..color = orangeDark.withOpacity(0.5),
    );
    canvas.restore();

    // Re-stroke the face outline so the patch never bleeds over the ink line.
    canvas.drawPath(face, _stroke(sw));

    // ---- Eyes -------------------------------------------------------------
    final eyeR = r * 0.17;
    final open = (1 - blink).clamp(0.05, 1.0);
    for (final ex in [-r * 0.34, r * 0.34]) {
      final c = Offset(ex + look * r * 0.10, -r * 0.04);
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.scale(1, open);
      canvas.drawCircle(Offset.zero, eyeR, Paint()..color = ink);
      canvas.drawCircle(
          Offset(eyeR * 0.32, -eyeR * 0.34), eyeR * 0.34, Paint()..color = cream);
      canvas.restore();
      if (blink > 0.45) {
        canvas.drawLine(
          Offset(c.dx - eyeR, c.dy),
          Offset(c.dx + eyeR, c.dy),
          _stroke(sw * 0.8),
        );
      }
    }

    // ---- Nose + muzzle ----------------------------------------------------
    final nose = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(0, r * 0.34), width: r * 0.40, height: r * 0.30),
        Radius.circular(r * 0.14),
      ));
    _fs(canvas, nose, ink, sw * 0.5);
    canvas.drawCircle(
        Offset(-r * 0.06, r * 0.28), r * 0.05, Paint()..color = cream.withOpacity(0.7));

    // Smile: two little curves under the nose.
    final mouth = Path()
      ..moveTo(0, r * 0.50)
      ..quadraticBezierTo(-r * 0.20, r * 0.74, -r * 0.40, r * 0.52)
      ..moveTo(0, r * 0.50)
      ..quadraticBezierTo(r * 0.20, r * 0.74, r * 0.40, r * 0.52);
    canvas.drawPath(mouth, _stroke(sw * 0.8));
    canvas.drawLine(
        Offset(0, r * 0.46), Offset(0, r * 0.50), _stroke(sw * 0.8));

    canvas.restore();
  }

  /// Two front paw mitts gripping a horizontal bar/edge that passes through
  /// [center]. [spread] is the horizontal distance between paws, [r] their
  /// size. Used when Pip rides the bird or grips a cockpit rim.
  static void pawsGrip(Canvas canvas, Offset center, double r,
      {double spread = 1.0, double bob = 0}) {
    final sw = r * 0.26;
    for (final side in [-1.0, 1.0]) {
      final p = Offset(center.dx + side * r * spread, center.dy + bob);
      // little orange forearm
      final arm = Path()
        ..moveTo(p.dx - r * 0.22, p.dy - r * 0.9)
        ..lineTo(p.dx + r * 0.22, p.dy - r * 0.9)
        ..lineTo(p.dx + r * 0.26, p.dy)
        ..lineTo(p.dx - r * 0.26, p.dy)
        ..close();
      _fs(canvas, arm, orange, sw);
      // grey paw mitt
      final mitt = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromCenter(center: p, width: r * 0.7, height: r * 0.6),
          Radius.circular(r * 0.3),
        ));
      _fs(canvas, mitt, paw, sw);
      canvas.drawLine(Offset(p.dx, p.dy - r * 0.18),
          Offset(p.dx, p.dy + r * 0.22), _stroke(sw * 0.7)..color = pawDark);
    }
  }

  /// A small rider torso (orange shoulders + cream chest) sized to sit beneath
  /// a head of radius [r], centred at [center]. Gives Pip a body when he rides.
  static void riderTorso(Canvas canvas, Offset center, double r) {
    final sw = r * 0.13;
    final torso = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center, width: r * 1.5, height: r * 1.2),
        Radius.circular(r * 0.5),
      ));
    _fs(canvas, torso, orange, sw);
    final chest = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(center.dx, center.dy + r * 0.05),
            width: r * 0.8,
            height: r * 0.95),
        Radius.circular(r * 0.4),
      ));
    canvas.drawPath(chest, Paint()..color = cream);
  }

  /// Convenience: a complete riding Pip (torso + head + gripping paws) facing
  /// right, centred at [center]. [r] is the head radius. Animation knobs match
  /// [head]. [gripY] is where the paws grab (relative to center).
  static void rider(
    Canvas canvas,
    Offset center,
    double r, {
    double earFlap = 0,
    double blink = 0,
    double tilt = 0,
    double look = 0,
    double gripY = 1.1,
  }) {
    riderTorso(canvas, Offset(center.dx, center.dy + r * 0.95), r);
    pawsGrip(canvas, Offset(center.dx + r * 0.1, center.dy + r * gripY), r * 0.6,
        spread: 1.3);
    head(canvas, center, r,
        earFlap: earFlap, blink: blink, tilt: tilt, look: look);
  }

  /// A complete **side-view running Pip**, centred at [center] with body scale
  /// [r] (roughly the head radius). Used by Super Dash.
  ///  * [runPhase] advances the gallop cycle (legs, tail wag, body bob).
  ///  * [airborne]  0..1 tucks the legs in for a jump.
  ///  * [earFlap]  -1..1 flutters the ears (e.g. on take-off).
  static void runner(
    Canvas canvas,
    Offset center,
    double r, {
    double runPhase = 0,
    double airborne = 0,
    double earFlap = 0,
  }) {
    final sw = r * 0.13;
    final double tuck = airborne.clamp(0.0, 1.0).toDouble();
    final bob = math.sin(runPhase * 2) * r * 0.07 * (1 - tuck);
    final bodyC = Offset(center.dx, center.dy + bob);

    final hipBack = Offset(bodyC.dx - r * 0.6, bodyC.dy + r * 0.42);
    final hipFront = Offset(bodyC.dx + r * 0.5, bodyC.dy + r * 0.42);

    // ---- Tail (behind body, wagging) --------------------------------------
    final wag = math.sin(runPhase * 1.6) * 0.6;
    final tail = Path()
      ..moveTo(bodyC.dx - r * 0.95, bodyC.dy - r * 0.05)
      ..quadraticBezierTo(bodyC.dx - r * 1.5, bodyC.dy - r * (0.55 + wag),
          bodyC.dx - r * 1.15, bodyC.dy - r * (1.0 + wag))
      ..quadraticBezierTo(
          bodyC.dx - r * 1.0, bodyC.dy - r * 0.45, bodyC.dx - r * 0.7, bodyC.dy)
      ..close();
    _fs(canvas, tail, orange, sw);

    // ---- Far legs (diagonal gait, drawn darker behind the body) -----------
    _leg(canvas, hipBack, r, runPhase + math.pi, tuck, orangeDark, sw);
    _leg(canvas, hipFront, r, runPhase, tuck, orangeDark, sw);

    // ---- Body + cream belly -----------------------------------------------
    final body = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: bodyC, width: r * 2.05, height: r * 1.35),
        Radius.circular(r * 0.62),
      ));
    _fs(canvas, body, orange, sw);
    canvas.save();
    canvas.clipPath(body);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(bodyC.dx + r * 0.15, bodyC.dy + r * 0.5),
            width: r * 1.6,
            height: r * 0.95),
        Radius.circular(r * 0.5),
      ),
      Paint()..color = cream,
    );
    canvas.restore();
    canvas.drawPath(body, _stroke(sw));

    // ---- Near legs --------------------------------------------------------
    _leg(canvas, hipBack, r, runPhase, tuck, orange, sw);
    _leg(canvas, hipFront, r, runPhase + math.pi, tuck, orange, sw);

    // ---- Head at the front, looking ahead ---------------------------------
    head(canvas, Offset(bodyC.dx + r * 1.02, bodyC.dy - r * 0.5), r * 0.8,
        earFlap: earFlap, look: 0.35, tilt: -0.04);
  }

  /// One bent (thigh + shin) leg used by [runner], swinging with [phase].
  static void _leg(Canvas canvas, Offset hip, double r, double phase,
      double tuck, Color color, double sw) {
    final swing = math.sin(phase) * (1 - tuck) * 0.9;
    final reach = math.cos(phase);
    final knee =
        Offset(hip.dx + swing * r * 0.35, hip.dy + r * 0.5 - tuck * r * 0.3);
    final lift = math.max(0.0, reach) * (1 - tuck) * r * 0.45;
    final foot = Offset(
        knee.dx + swing * r * 0.4, knee.dy + r * 0.5 - lift - tuck * r * 0.5);
    final legPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = sw * 2.2
      ..color = color;
    final path = Path()
      ..moveTo(hip.dx, hip.dy)
      ..lineTo(knee.dx, knee.dy)
      ..lineTo(foot.dx, foot.dy);
    canvas.drawPath(path, legPaint);
    canvas.drawCircle(foot, r * 0.17, Paint()..color = color);
    canvas.drawCircle(foot, r * 0.17, _stroke(sw * 0.7));
  }
}

/// Small deterministic helper for a gentle idle wobble from a time value.
double mascotWobble(double t, {double speed = 1, double amp = 1}) =>
    math.sin(t * speed) * amp;
