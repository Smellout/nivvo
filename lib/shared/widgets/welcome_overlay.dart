import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/utils/greeting.dart';
import '../../theme/app_colors.dart';
import '../services/core_providers.dart';
import 'aurora.dart';
import 'nivvo_logo.dart';

/// Saudação animada ao entrar no app ("Bom dia, Daniel!").
/// Fica por cima do app enquanto os dados do Início carregam por trás,
/// depois se dissolve. Um toque pula a animação.
class WelcomeOverlay extends ConsumerStatefulWidget {
  const WelcomeOverlay({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  ConsumerState<WelcomeOverlay> createState() => _WelcomeOverlayState();
}

class _WelcomeOverlayState extends ConsumerState<WelcomeOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final DateTime _now = DateTime.now();

  Animation<double> _curve(double begin, double end, [Curve curve = Curves.easeOutCubic]) => CurvedAnimation(
    parent: _controller,
    curve: Interval(begin, end, curve: curve),
  );

  late final _logoIn = _curve(0, 0.26, Curves.easeOutBack);
  late final _logoFade = _curve(0, 0.18);
  late final _greetingIn = _curve(0.14, 0.42);
  late final _nameIn = _curve(0.24, 0.52);
  late final _dateIn = _curve(0.34, 0.6);
  late final _exit = _curve(0.8, 1, Curves.easeInCubic);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Com "remover animações" ativado no aparelho, a saudação é bem curta.
      if (MediaQuery.disableAnimationsOf(context)) _controller.duration = const Duration(milliseconds: 900);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    if (_controller.value < 0.8) {
      _controller.animateTo(1, duration: const Duration(milliseconds: 280), curve: Curves.easeIn);
    }
  }

  Widget _rise(Animation<double> a, Widget child, {double offset = 18}) {
    return AnimatedBuilder(
      animation: a,
      builder: (_, child) => Opacity(
        opacity: a.value.clamp(0, 1),
        child: Transform.translate(offset: Offset(0, (1 - a.value) * offset), child: child),
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final firstName = ref.watch(userProfileProvider).name.trim().split(RegExp(r'\s+')).first;
    final greeting = Greeting.forTime(_now);
    final date = DateFormat("EEEE, d 'de' MMMM", 'pt_BR').format(_now);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _skip,
      child: AnimatedBuilder(
        animation: _exit,
        builder: (context, child) => Opacity(
          opacity: 1 - _exit.value,
          child: Transform.scale(scale: 1 + _exit.value * 0.04, child: child),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: Stack(
            fit: StackFit.expand,
            children: [
              const AuroraBackground(strength: 1),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _logoIn,
                        builder: (_, child) => Opacity(
                          opacity: _logoFade.value.clamp(0, 1),
                          child: Transform.scale(scale: 0.6 + 0.4 * _logoIn.value, child: child),
                        ),
                        child: const NivvoMark(size: 68),
                      ),
                      const SizedBox(height: 32),
                      if (firstName.isNotEmpty) ...[
                        _rise(
                          _greetingIn,
                          Text(
                            '$greeting,',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: c.text.withValues(alpha: 0.78),
                              letterSpacing: -0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        _rise(
                          _nameIn,
                          Text(
                            '$firstName!',
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                              letterSpacing: -1.6,
                              height: 1.1,
                            ),
                          ),
                          offset: 24,
                        ),
                      ] else
                        _rise(
                          _nameIn,
                          Text(
                            '$greeting!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                              letterSpacing: -1.4,
                            ),
                          ),
                          offset: 24,
                        ),
                      const SizedBox(height: 14),
                      _rise(
                        _dateIn,
                        Text(
                          date[0].toUpperCase() + date.substring(1),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: c.textSecondary),
                        ),
                        offset: 10,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
