import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart' show WebViewController, NavigationDelegate, JavaScriptMode, NavigationDecision, WebViewWidget;
import 'game_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
//  TraceMind — splash_screen.dart
//
//  Full cinematic splash / get-started screen:
//    • Animated particle field (floating dots)
//    • Animated logo with gradient shimmer
//    • Tagline reveal + pulse
//    • "START GAME" button with neon glow press effect
//    • "ABOUT" bottom sheet
//    • "PRIVACY POLICY" opens inline HTML webview sheet
//    • All dark-neon aesthetic matching game_screen
// ═══════════════════════════════════════════════════════════════════════════════

// ─── Particle for background ──────────────────────────────────────────────────

class _BgParticle {
  double x, y, vx, vy, size, opacity;
  Color color;
  _BgParticle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.size, required this.opacity,
    required this.color,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {

  // ── Controllers ──────────────────────────────────────────────────────────
  late final AnimationController _acLogo;
  late final AnimationController _acTagline;
  late final AnimationController _acButtons;
  late final AnimationController _acLogoShimmer;
  late final AnimationController _acGrid;
  late final AnimationController _acPulse;

  late final Animation<double> _aLogoScale;
  late final Animation<double> _aLogoFade;
  late final Animation<double> _aTaglineFade;
  late final Animation<double> _aTaglineSlide;
  late final Animation<double> _aButtonsFade;
  late final Animation<double> _aButtonsSlide;

  // ── Background particles ──────────────────────────────────────────────────
  List<_BgParticle> _particles = [];
  Timer? _particleTicker;
  final Random _rng = Random();

  // ── Button press state ────────────────────────────────────────────────────
  bool _startPressed = false;

  @override
  void initState() {
    super.initState();

    // Logo: scale up + fade in
    _acLogo = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _aLogoScale = Tween<double>(begin: 0.75, end: 1.0)
        .animate(CurvedAnimation(parent: _acLogo, curve: Curves.easeOutCubic));
    _aLogoFade = CurvedAnimation(parent: _acLogo, curve: Curves.easeOut);

    // Tagline: fade + slide up (delayed)
    _acTagline = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _aTaglineFade  = CurvedAnimation(parent: _acTagline, curve: Curves.easeOut);
    _aTaglineSlide = Tween<double>(begin: 18.0, end: 0.0)
        .animate(CurvedAnimation(parent: _acTagline, curve: Curves.easeOutCubic));

    // Buttons: fade + slide up (more delayed)
    _acButtons = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _aButtonsFade  = CurvedAnimation(parent: _acButtons, curve: Curves.easeOut);
    _aButtonsSlide = Tween<double>(begin: 24.0, end: 0.0)
        .animate(CurvedAnimation(parent: _acButtons, curve: Curves.easeOutCubic));

    // Logo shimmer repeat
    _acLogoShimmer = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))..repeat();

    // Grid bg rotation
    _acGrid = AnimationController(
        vsync: this, duration: const Duration(seconds: 40))..repeat();

    // Pulse for start button
    _acPulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);

    // Staggered entry
    _acLogo.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _acTagline.forward();
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _acButtons.forward();
    });

    // Background particles
    WidgetsBinding.instance.addPostFrameCallback((_) => _initParticles());
  }

  void _initParticles() {
    final sz = MediaQuery.of(context).size;
    final colors = [
      const Color(0xFF00D4FF),
      const Color(0xFFBB55FF),
      const Color(0xFF00FFB0),
      const Color(0xFFFFCC00),
    ];
    _particles = List.generate(38, (_) => _BgParticle(
      x: _rng.nextDouble() * sz.width,
      y: _rng.nextDouble() * sz.height,
      vx: (_rng.nextDouble() - 0.5) * 0.4,
      vy: -0.2 - _rng.nextDouble() * 0.4,
      size: 1.5 + _rng.nextDouble() * 3.0,
      opacity: 0.15 + _rng.nextDouble() * 0.35,
      color: colors[_rng.nextInt(colors.length)],
    ));

    _particleTicker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (!mounted) return;
      final sz2 = MediaQuery.of(context).size;
      setState(() {
        for (final p in _particles) {
          p.x += p.vx;
          p.y += p.vy;
          if (p.y < -10) { p.y = sz2.height + 10; p.x = _rng.nextDouble() * sz2.width; }
          if (p.x < -10) { p.x = sz2.width + 10; }
          if (p.x > sz2.width + 10) { p.x = -10; }
        }
      });
    });
  }

  @override
  void dispose() {
    _acLogo.dispose(); _acTagline.dispose(); _acButtons.dispose();
    _acLogoShimmer.dispose(); _acGrid.dispose(); _acPulse.dispose();
    _particleTicker?.cancel();
    super.dispose();
  }

  // ── Navigate to game ─────────────────────────────────────────────────────

  void _startGame() async {
    HapticFeedback.mediumImpact();
    setState(() => _startPressed = true);
    await Future.delayed(const Duration(milliseconds: 180));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => const GameScreen(),
        transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  // ── About sheet ───────────────────────────────────────────────────────────

  void _showAbout() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _AboutSheet(),
    );
  }

  // ── Privacy policy sheet ──────────────────────────────────────────────────

  void _showPrivacyPolicy() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    final sz  = MediaQuery.of(context).size;
    final sw  = sz.width;
    final sh  = sz.height;

    return Scaffold(
      backgroundColor: const Color(0xFF02020A),
      body: Stack(
        children: [
          // ── Animated dark bg gradient ──
          AnimatedBuilder(
            animation: _acGrid,
            builder: (_, __) => CustomPaint(
              size: sz,
              painter: _SplashBgPainter(t: _acGrid.value),
            ),
          ),

          // ── Floating particles ──
          ..._particles.map((p) => Positioned(
            left: p.x - p.size / 2,
            top:  p.y - p.size / 2,
            child: Container(
              width: p.size, height: p.size,
              decoration: BoxDecoration(
                color: p.color.withOpacity(p.opacity),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: p.color.withOpacity(p.opacity * 0.6), blurRadius: 6)],
              ),
            ),
          )),

          // ── Scanline + vignette overlay ──
          Positioned.fill(child: IgnorePointer(child: CustomPaint(painter: _VignettePainter()))),

          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),

                // ── Logo block ──
                ScaleTransition(
                  scale: _aLogoScale,
                  child: FadeTransition(
                    opacity: _aLogoFade,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Icon mark
                        _buildLogoMark(sw),
                        const SizedBox(height: 20),
                        // Word mark
                        _buildWordMark(),
                        const SizedBox(height: 10),
                        // Tagline
                        FadeTransition(
                          opacity: _aTaglineFade,
                          child: AnimatedBuilder(
                            animation: _aTaglineSlide,
                            builder: (_, child) => Transform.translate(
                              offset: Offset(0, _aTaglineSlide.value),
                              child: child,
                            ),
                            child: _buildTagline(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 2),

                // ── Buttons ──
                FadeTransition(
                  opacity: _aButtonsFade,
                  child: AnimatedBuilder(
                    animation: _aButtonsSlide,
                    builder: (_, child) => Transform.translate(
                      offset: Offset(0, _aButtonsSlide.value),
                      child: child,
                    ),
                    child: _buildButtons(sw),
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Logo mark — animated mirror grid icon ────────────────────────────────

  Widget _buildLogoMark(double sw) {
    return AnimatedBuilder(
      animation: _acPulse,
      builder: (_, __) {
        final p = _acPulse.value;
        return Container(
          width: 82, height: 82,
          decoration: BoxDecoration(
            color: const Color(0xFF07071C),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Color.lerp(
                const Color(0xFF00D4FF).withOpacity(0.40),
                const Color(0xFFBB55FF).withOpacity(0.60),
                p,
              )!,
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D4FF).withOpacity(0.18 + 0.12 * p),
                blurRadius: 24 + 12 * p, spreadRadius: 2,
              ),
              BoxShadow(
                color: const Color(0xFFBB55FF).withOpacity(0.10 + 0.10 * p),
                blurRadius: 40 + 20 * p, spreadRadius: 4,
              ),
            ],
          ),
          child: Center(
            child: CustomPaint(
              size: const Size(52, 52),
              painter: _LogoIconPainter(pulse: p),
            ),
          ),
        );
      },
    );
  }

  // ─── Word mark ────────────────────────────────────────────────────────────

  Widget _buildWordMark() {
    return AnimatedBuilder(
      animation: _acLogoShimmer,
      builder: (_, __) {
        final t = _acLogoShimmer.value;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment(-1.5 + t * 3.5, 0),
            end: Alignment(-0.5 + t * 3.5, 0),
            colors: const [
              Color(0xFF00D4FF),
              Color(0xFFFFFFFF),
              Color(0xFFBB55FF),
              Color(0xFF00FFB0),
              Color(0xFF00D4FF),
            ],
            stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
          ).createShader(bounds),
          child: const Text(
            'TRACEMIND',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
          decoration: BoxDecoration(
            border: Border(
              left:  BorderSide(color: const Color(0xFF00D4FF).withOpacity(0.4), width: 1.5),
              right: BorderSide(color: const Color(0xFFBB55FF).withOpacity(0.4), width: 1.5),
            ),
          ),
          child: const Text(
            'ESCAPE  YOUR  REFLECTION',
            style: TextStyle(
              color: Color(0xFF4A5A7A),
              fontSize: 10,
              letterSpacing: 4,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Buttons ──────────────────────────────────────────────────────────────

  Widget _buildButtons(double sw) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // START GAME
          _buildStartBtn(sw),
          const SizedBox(height: 14),
          // ABOUT + PRIVACY in a row
          Row(
            children: [
              Expanded(child: _buildSecondaryBtn('ABOUT', Icons.info_outline_rounded, _showAbout)),
              const SizedBox(width: 10),
              Expanded(child: _buildSecondaryBtn('PRIVACY', Icons.shield_outlined, _showPrivacyPolicy)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStartBtn(double sw) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _startPressed = true),
      onTapCancel: () => setState(() => _startPressed = false),
      onTapUp: (_) => _startGame(),
      child: AnimatedBuilder(
        animation: _acPulse,
        builder: (_, __) {
          final p = _acPulse.value;
          return AnimatedScale(
            scale: _startPressed ? 0.95 : 1.0,
            duration: const Duration(milliseconds: 80),
            child: Container(
              width: double.infinity,
              height: 62,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.lerp(const Color(0xFF00A8CC), const Color(0xFF0088FF), p)!,
                    Color.lerp(const Color(0xFF0088FF), const Color(0xFF7700CC), p)!,
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D4FF).withOpacity(0.35 + 0.20 * p),
                    blurRadius: 20 + 14 * p, spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: const Color(0xFF7700CC).withOpacity(0.20 + 0.15 * p),
                    blurRadius: 32 + 10 * p, spreadRadius: 2,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 26,
                    shadows: [Shadow(color: Colors.white.withOpacity(0.6), blurRadius: 10)],
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'START GAME',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.5,
                      shadows: [Shadow(color: Colors.white38, blurRadius: 8)],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSecondaryBtn(String label, IconData icon, VoidCallback fn) {
    return GestureDetector(
      onTap: fn,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF07071C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF1A1A3E), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: const Color(0xFF4A5A7A), size: 15),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(
              color: Color(0xFF4A5A7A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 2,
            )),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  About Sheet
// ═══════════════════════════════════════════════════════════════════════════════

class _AboutSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF00D4FF);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 20),
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF07071C),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withOpacity(0.25), width: 1.2),
        boxShadow: [BoxShadow(color: accent.withOpacity(0.08), blurRadius: 48)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A3E),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Logo text
          ShaderMask(
            shaderCallback: (b) => const LinearGradient(
              colors: [Color(0xFF00D4FF), Color(0xFFBB55FF), Color(0xFF00FFB0)],
            ).createShader(b),
            child: const Text('TRACEMIND', style: TextStyle(
              color: Colors.white, fontSize: 22,
              fontWeight: FontWeight.w900, letterSpacing: 6,
            )),
          ),
          const SizedBox(height: 6),
          const Text('ESCAPE YOUR REFLECTION', style: TextStyle(
            color: Color(0xFF2A3A4A), fontSize: 9, letterSpacing: 3.5, fontWeight: FontWeight.w700,
          )),

          const SizedBox(height: 24),

          // Description
          const Text(
            'TraceMind is a mind-bending puzzle game where you navigate a maze while your clone shadows your every move — with a delay.\n\nOutthink your reflection. Escape before your past catches you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF4A5A7A), fontSize: 13, height: 1.75,
            ),
          ),

          const SizedBox(height: 24),

          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _statPill('20', 'LEVELS'),
              _statPill('5', 'TIERS'),
              _statPill('∞', 'REPLAYS'),
            ],
          ),

          const SizedBox(height: 24),
          Container(height: 1, color: const Color(0xFF1A1A3E)),
          const SizedBox(height: 16),

          const Text('Developed by', style: TextStyle(
            color: Color(0xFF2A3A4A), fontSize: 9, letterSpacing: 2,
          )),
          const SizedBox(height: 4),
          const Text('PATRICIA LN SAGALE LLC', style: TextStyle(
            color: Color(0xFF4A5A7A), fontSize: 11,
            fontWeight: FontWeight.w800, letterSpacing: 2,
          )),
          const SizedBox(height: 4),
          const Text('blomnik74@gmail.com', style: TextStyle(
            color: Color(0xFF00D4FF), fontSize: 11, letterSpacing: 1,
          )),

          const SizedBox(height: 20),

          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: double.infinity, height: 46,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.30), width: 1),
              ),
              child: const Center(
                child: Text('CLOSE', style: TextStyle(
                  color: accent, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 3,
                )),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statPill(String val, String label) {
    return Column(children: [
      Text(val, style: const TextStyle(
        color: Color(0xFF00D4FF), fontSize: 20, fontWeight: FontWeight.w900,
        shadows: [Shadow(color: Color(0xFF00D4FF), blurRadius: 12)],
      )),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
        color: Color(0xFF2A3A4A), fontSize: 8, letterSpacing: 2, fontWeight: FontWeight.w700,
      )),
    ]);
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Privacy Policy Sheet — loads local HTML asset
// ═══════════════════════════════════════════════════════════════════════════════



class PrivacyPolicyScreen extends StatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  State<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends State<PrivacyPolicyScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => setState(() => _isLoading = false),
          onNavigationRequest: (request) {
            if (request.url.startsWith('http') ||
                request.url.startsWith('https')) {
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      );
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    final html = await rootBundle.loadString('assets/privacy_policy.html');
    await _controller.loadHtmlString(html, baseUrl: 'about:blank');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FF),
      appBar: AppBar(
        title: const Text(
          'Privacy Policy',
          style: TextStyle(
            fontFamily: 'DM Sans',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2979FF)),
                  SizedBox(height: 12),
                  Text(
                    'Loading privacy policy…',
                    style: TextStyle(color: Color(0xFF8898AA), fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
//  Custom Painters
// ═══════════════════════════════════════════════════════════════════════════════

class _SplashBgPainter extends CustomPainter {
  final double t;
  const _SplashBgPainter({required this.t});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Base fill
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h),
        Paint()..color = const Color(0xFF02020A));

    // Animated radial glow 1
    final cx1 = w * (0.3 + sin(t * 2 * pi) * 0.15);
    final cy1 = h * (0.4 + cos(t * 2 * pi) * 0.10);
    canvas.drawCircle(
      Offset(cx1, cy1),
      w * 0.55,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF00D4FF).withOpacity(0.06),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx1, cy1), radius: w * 0.55)),
    );

    // Animated radial glow 2
    final cx2 = w * (0.70 - sin(t * 2 * pi) * 0.12);
    final cy2 = h * (0.6 + cos(t * 2 * pi + 1.0) * 0.08);
    canvas.drawCircle(
      Offset(cx2, cy2),
      w * 0.45,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFBB55FF).withOpacity(0.05),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: w * 0.45)),
    );

    // Subtle dot grid
    final dotPaint = Paint()..color = const Color(0xFF0D0D28);
    const spacing = 28.0;
    for (double x = 0; x < w + spacing; x += spacing) {
      for (double y = 0; y < h + spacing; y += spacing) {
        canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
      }
    }
  }

  @override bool shouldRepaint(_SplashBgPainter o) => o.t != t;
}

class _VignettePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Scanlines
    final lp = Paint()..color = Colors.black.withOpacity(0.035)..strokeWidth = 1;
    for (double y = 0; y < size.height; y += 3) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), lp);
    }
    // Vignette
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, Colors.black.withOpacity(0.45)],
          radius: 0.80,
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
  }
  @override bool shouldRepaint(_) => false;
}

// Logo icon painter — a stylised trace/mirror glyph
class _LogoIconPainter extends CustomPainter {
  final double pulse;
  const _LogoIconPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2, cy = h / 2;

    final paintLine = Paint()
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw a stylised "T" trace path — player path glyph
    // Outer diamond
    final outerPaint = Paint()
      ..color = const Color(0xFF00D4FF).withOpacity(0.65 + 0.25 * pulse)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 1.5 + pulse * 2);

    final path = Path();
    path.moveTo(cx, cy - h * 0.38);
    path.lineTo(cx + w * 0.38, cy);
    path.lineTo(cx, cy + h * 0.38);
    path.lineTo(cx - w * 0.38, cy);
    path.close();
    canvas.drawPath(path, outerPaint);

    // Center cross (the "trace" icon)
    paintLine
      ..color = const Color(0xFF00D4FF).withOpacity(0.90)
      ..strokeWidth = 2.2
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + pulse * 3);

    canvas.drawLine(Offset(cx - w * 0.20, cy), Offset(cx + w * 0.20, cy), paintLine);
    canvas.drawLine(Offset(cx, cy - h * 0.20), Offset(cx, cy + h * 0.20), paintLine);

    // Inner dot
    canvas.drawCircle(
      Offset(cx, cy),
      3.5 + pulse * 1.5,
      Paint()
        ..color = Colors.white.withOpacity(0.90)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 + pulse * 4),
    );

    // Ghost position dot (mirrored)
    canvas.drawCircle(
      Offset(cx + w * 0.20, cy - h * 0.20),
      2.5,
      Paint()
        ..color = const Color(0xFFBB55FF).withOpacity(0.55 + 0.40 * pulse)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + pulse * 3),
    );
  }

  @override bool shouldRepaint(_LogoIconPainter o) => o.pulse != pulse;
}