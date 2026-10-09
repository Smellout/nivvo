import 'dart:ui' show ImageFilter;

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';

/// Fundo da marca: manchas de luz azul/violeta/ciano desfocadas no topo,
/// dissolvendo no fundo escuro. Pintado com gradientes radiais (barato, sem blur em tempo real).
class AuroraBackground extends StatelessWidget {
  const AuroraBackground({super.key, this.strength = 1});

  /// 1 = intenso (Início, login); ~0.5 = discreto (listas e formulários).
  final double strength;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final k = strength * c.auroraStrength;
    return RepaintBoundary(
      child: ColoredBox(
        color: c.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            return Stack(
              clipBehavior: Clip.hardEdge,
              children: [
                _Blob(left: -w * 0.4, top: -w * 0.6, size: w * 1.4, color: c.aurora[0], alpha: 1.0 * k),
                _Blob(left: w * 0.3, top: -w * 0.5, size: w * 1.1, color: c.aurora[1], alpha: 0.7 * k),
                _Blob(left: -w * 0.05, top: w * 0.18, size: w * 0.85, color: c.aurora[2], alpha: 0.28 * k),
                // Funde a aurora no fundo, deixando o conteúdo de baixo limpo.
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.32, 0.62],
                        colors: [c.background.withValues(alpha: 0), c.background.withValues(alpha: 0.35), c.background],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({required this.left, required this.top, required this.size, required this.color, required this.alpha});

  final double left;
  final double top;
  final double size;
  final Color color;
  final double alpha;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      width: size,
      height: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color.withValues(alpha: alpha.clamp(0, 1)),
              color.withValues(alpha: (alpha * 0.35).clamp(0, 1)),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ),
        ),
      ),
    );
  }
}

/// Scaffold com o fundo aurora. AppBar transparente por cima do brilho.
class NivvoScaffold extends StatelessWidget {
  const NivvoScaffold({
    super.key,
    this.appBar,
    required this.body,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.aurora = 0.55,
    this.extendBody = false,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final double aurora;
  final bool extendBody;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: AuroraBackground(strength: aurora)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          extendBody: extendBody,
          floatingActionButton: floatingActionButton,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

/// Vidro fosco de verdade (desfoca o que está atrás). Use com moderação:
/// é mais caro que um cartão translúcido comum.
class FrostedGlass extends StatelessWidget {
  const FrostedGlass({super.key, required this.child, this.radius = 24, this.blur = 22, this.padding, this.tint});

  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry? padding;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: tint ?? c.surface,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: c.border),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Botão de ação circular com legenda (estilo app de banco moderno).
class RoundAction extends StatelessWidget {
  const RoundAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.badge = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = primary ? c.brand : (isDark ? const Color(0x1FFFFFFF) : const Color(0xB3FFFFFF));
    final fg = primary || isDark ? Colors.white : c.text;
    return SizedBox(
      width: 76,
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Material(
                color: bg,
                shape: CircleBorder(side: primary ? BorderSide.none : BorderSide(color: c.border)),
                clipBehavior: Clip.antiAlias,
                elevation: primary ? 8 : 0,
                shadowColor: c.brand.withValues(alpha: 0.6),
                child: InkWell(
                  onTap: onTap,
                  child: SizedBox(width: 56, height: 56, child: Icon(icon, color: fg, size: 25)),
                ),
              ),
              if (badge)
                Positioned(
                  right: 2,
                  top: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: c.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: c.background, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text),
          ),
        ],
      ),
    );
  }
}

/// Valor em destaque com centavos menores: "R$ 9.992" + ",50".
class BigAmount extends StatelessWidget {
  const BigAmount(this.formatted, {super.key, this.size = 46, this.color});

  /// Valor já formatado, ex.: "R$ 9.992,50".
  final String formatted;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.colors.text;
    final comma = formatted.lastIndexOf(',');
    final main = comma < 0 ? formatted : formatted.substring(0, comma);
    final cents = comma < 0 ? '' : formatted.substring(comma);
    final symbolEnd = main.indexOf(' ');
    final symbol = symbolEnd < 0 ? '' : main.substring(0, symbolEnd + 1);
    final integer = main.substring(symbol.length);
    final base = TextStyle(
      color: c,
      fontWeight: FontWeight.w800,
      letterSpacing: -size * 0.04,
      fontFeatures: const [FontFeature.tabularFigures()],
      height: 1.05,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: symbol,
              style: base.copyWith(fontSize: size * 0.5, letterSpacing: 0),
            ),
            TextSpan(
              text: integer,
              style: base.copyWith(fontSize: size),
            ),
            TextSpan(
              text: cents,
              style: base.copyWith(fontSize: size * 0.55, letterSpacing: 0),
            ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}
