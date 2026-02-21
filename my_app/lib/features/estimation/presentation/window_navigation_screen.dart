import 'package:flutter/material.dart';

import '../models/window_type.dart';
import '../../settings/state/app_settings.dart';
import '../state/estimate_session_store.dart';
import '../../../core/theme/app_theme.dart';
import '../data/window_catalog.dart';
import 'input/input_registry.dart';
import '../widgets/window_navigation_card.dart';

class WindowNavigationScreen extends StatefulWidget {
  final List<WindowType> nodes;
  final List<String> path;
  final EstimateSessionStore session;

  const WindowNavigationScreen({
    super.key,
    required this.nodes,
    required this.path,
    required this.session,
  });

  factory WindowNavigationScreen.root({Key? key}) {
    return WindowNavigationScreen(
      key: key,
      nodes: WindowCatalog.root,
      path: const ['Add Windows'],
      session: EstimateSessionStore(
        numberingMode: AppSettings.instance.numberingMode,
      ),
    );
  }

  @override
  State<WindowNavigationScreen> createState() => _WindowNavigationScreenState();
}

class _WindowNavigationScreenState extends State<WindowNavigationScreen> {
  late final PageController _pageController;
  double _pageValue = 0;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.78);
    _pageController.addListener(_onPageScroll);
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  void _onPageScroll() {
    if (!_pageController.hasClients) {
      return;
    }

    final double nextPage = _pageController.page ?? 0;
    final int nextIndex = nextPage.round().clamp(0, widget.nodes.length - 1);

    if (nextPage == _pageValue && nextIndex == _currentIndex) {
      return;
    }

    setState(() {
      _pageValue = nextPage;
      _currentIndex = nextIndex;
    });
  }

  void _onNodeTap(WindowType node) {
    if (node.hasChildren) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => WindowNavigationScreen(
            nodes: node.children,
            path: [...widget.path, node.label],
            session: widget.session,
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => buildInputScreen(node: node, session: widget.session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentLabel = widget.nodes[_currentIndex].label;
    final double cardHeight = (MediaQuery.sizeOf(context).height * 0.74)
        .clamp(460.0, 700.0)
        .toDouble();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.mist, AppTheme.ice],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            const _GlowCircle(
              alignment: Alignment(-1.2, -1.15),
              size: 230,
              color: AppTheme.sky,
            ),
            const _GlowCircle(
              alignment: Alignment(1.2, -0.7),
              size: 190,
              color: AppTheme.violet,
            ),
            const _GlowCircle(
              alignment: Alignment(0.9, 1.1),
              size: 260,
              color: AppTheme.ice,
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 18, 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: AppTheme.deepTeal,
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimation',
                                key: const Key('navigation_estimation_heading'),
                                style: Theme.of(context).textTheme.headlineLarge
                                    ?.copyWith(fontSize: 30, height: 1),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${widget.path.join(' / ')} / $currentLabel',
                                key: const Key('navigation_context_label'),
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: AppTheme.deepTeal,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: PageView.builder(
                      key: const Key('window_page_view'),
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: widget.nodes.length,
                      onPageChanged: (int index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemBuilder: (BuildContext context, int index) {
                        final WindowType node = widget.nodes[index];
                        final double distance = (index - _pageValue).abs();
                        final double scale = (1 - (distance * 0.12)).clamp(
                          0.88,
                          1.0,
                        );
                        final double yOffset = (distance * 14).clamp(0, 14);
                        final double parallaxShift =
                            ((index - _pageValue) * -10).clamp(-12, 12);

                        return Transform.translate(
                          offset: Offset(0, yOffset),
                          child: Transform.scale(
                            scale: scale,
                            alignment: Alignment.center,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 18),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  height: cardHeight,
                                  child: WindowNavigationCard(
                                    node: node,
                                    isFocused: distance < 0.5,
                                    isSelected: false,
                                    parallaxShift: parallaxShift,
                                    onTap: () => _onNodeTap(node),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final Alignment alignment;
  final double size;
  final Color color;

  const _GlowCircle({
    required this.alignment,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.2),
        ),
      ),
    );
  }
}
