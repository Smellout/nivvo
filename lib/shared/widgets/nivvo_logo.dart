import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';

/// Marca Nivvo: um "N" em traço contínuo (fluxo) terminando num nó (conexão/resultado).
/// Mesma geometria do ícone Android (`ic_launcher_foreground.xml`).
class NivvoMark extends StatelessWidget {
  const NivvoMark({super.key, this.size = 40, this.boxed = true});

  final double size;

  /// `true`: ícone com fundo em gradiente. `false`: apenas o traço na cor do texto.
  final bool boxed;

  @override
  Widget build(BuildContext context) {
    final glyph = CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(color: boxed ? Colors.white : context.colors.text),
    );
    if (!boxed) return glyph;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(gradient: NivvoPalette.brandGradient, borderRadius: BorderRadius.circular(size * 0.3)),
      child: glyph,
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    // Geometria em uma grade 24×24, como o vetor Android.
    final s = size.width / 24;
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * s * 0.85
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // Mantém a marca dentro de ~60% do quadro.
    canvas.translate(size.width * 0.12, size.height * 0.12);
    canvas.scale(0.76);

    final path = Path()
      ..moveTo(6 * s, 18 * s)
      ..lineTo(6 * s, 6 * s)
      ..lineTo(18 * s, 18 * s)
      ..lineTo(18 * s, 10.5 * s);
    canvas.drawPath(path, stroke);
    canvas.drawCircle(Offset(18 * s, 6 * s), 1.9 * s, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.color != color;
}

/// Logotipo completo: marca + "nivvo".
class NivvoWordmark extends StatelessWidget {
  const NivvoWordmark({super.key, this.height = 36, this.showTagline = false});

  final double height;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final word = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        NivvoMark(size: height),
        SizedBox(width: height * 0.32),
        Text(
          'nivvo',
          style: TextStyle(
            fontSize: height * 0.82,
            fontWeight: FontWeight.w800,
            letterSpacing: -height * 0.045,
            color: c.text,
            height: 1,
          ),
        ),
      ],
    );
    if (!showTagline) return word;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        word,
        const SizedBox(height: 12),
        Text(
          'Controle financeiro simplificado.',
          style: TextStyle(color: c.textSecondary, fontSize: 14, letterSpacing: 0.1),
        ),
      ],
    );
  }
}
