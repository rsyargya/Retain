import 'package:flutter/material.dart';

import 'models/churn_result.dart';
import 'screens/action_center_screen.dart';

import 'screens/dashboard_screen.dart';
import 'screens/simulation_screen.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const RetainApp());
}

class RetainApp extends StatelessWidget {
  const RetainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Retain Enterprise',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _fadeController;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;

  @override
  void initState() {
    super.initState();

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _logoScale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );

    _startAnimations();
  }

  Future<void> _startAnimations() async {
    await Future.delayed(const Duration(milliseconds: 300));
    _logoController.forward();
    await Future.delayed(const Duration(milliseconds: 600));
    _fadeController.forward();
    await Future.delayed(const Duration(milliseconds: 1800));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (context, animation, secondaryAnimation) {
            return const MobileAppContainer();
          },
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _logoController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Slate 900 Solid Obsidian
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            // Animated logo
            ListenableBuilder(
              listenable: _logoController,
              builder: (context, child) {
                return Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.scale(
                    scale: _logoScale.value,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 36,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Image.asset(
                          'assets/splash/splash_logo.png',
                          width: 110,
                          height: 110,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            // Animated text
            ListenableBuilder(
              listenable: _fadeController,
              builder: (context, child) {
                return SlideTransition(
                  position: _textSlide,
                  child: Opacity(
                    opacity: _textOpacity.value,
                    child: Column(
                      children: [
                        const Text(
                          'RETAIN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 8,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enterprise Customer Retention',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            const Spacer(flex: 3),
            // Loading indicator
            ListenableBuilder(
              listenable: _fadeController,
              builder: (context, child) {
                return Opacity(
                  opacity: _textOpacity.value,
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class MobileAppContainer extends StatefulWidget {
  const MobileAppContainer({super.key});

  @override
  State<MobileAppContainer> createState() => _MobileAppContainerState();
}

class _MobileAppContainerState extends State<MobileAppContainer> {
  int _currentIndex = 0;
  ChurnResult? _selectedCustomer;
  final GlobalKey<DashboardScreenState> _dashboardKey = GlobalKey<DashboardScreenState>();
  final GlobalKey<ActionCenterScreenState> _actionCenterKey = GlobalKey<ActionCenterScreenState>();

  void _onSelectCustomer(ChurnResult customer) {
    setState(() {
      _selectedCustomer = customer;
      _currentIndex = 2; // Navigasikan ke tab Simulasi (Index 2)
    });
  }

  void _onClearSelectedCustomer() {
    setState(() {
      _selectedCustomer = null;
    });
  }

  void _navigateToActions() {
    setState(() {
      _currentIndex = 1;
    });
    _actionCenterKey.currentState?.refresh();
  }

  void _onBottomNavTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
    if (index == 0) {
      _dashboardKey.currentState?.refresh();
    } else if (index == 1) {
      _actionCenterKey.currentState?.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    final appContent = Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: IndexedStack(
          index: _currentIndex,
          children: [
            DashboardScreen(
              key: _dashboardKey,
              onSelectCustomer: _onSelectCustomer,
              onNavigateToActionCenter: _navigateToActions,
              onActionCreated: () {
                _actionCenterKey.currentState?.refresh();
                _dashboardKey.currentState?.refresh();
              },
            ),
            ActionCenterScreen(
              key: _actionCenterKey,
              onStatusChanged: () => _dashboardKey.currentState?.refresh(),
            ),
            SimulationScreen(
              initialCustomer: _selectedCustomer,
              onClearCustomer: _onClearSelectedCustomer,
              onCustomerChanged: (customer) {
                setState(() {
                  _selectedCustomer = customer;
                });
              },
              onActionCreated: () {
                _actionCenterKey.currentState?.refresh();
                _dashboardKey.currentState?.refresh();
              },
              onNavigateToActionCenter: _navigateToActions,
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildCustomBottomNav(),
    );


    if (!isDesktop) {
      return appContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 20),
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: bgPrimary,
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: const Color(0xFF334155), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 50,
                spreadRadius: 2,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              // Sleek device status bar
              Container(
                height: 28,
                color: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '09:41',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    Container(
                      width: 68,
                      height: 12,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.signal_cellular_alt_rounded, size: 12, color: textPrimary),
                        SizedBox(width: 4),
                        Icon(Icons.wifi_rounded, size: 12, color: textPrimary),
                        SizedBox(width: 4),
                        Icon(Icons.battery_full_rounded, size: 13, color: textPrimary),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(child: appContent),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomBottomNav() {
    final navItems = [
      {'icon': Icons.grid_view_rounded, 'label': 'Dashboard'},
      {'icon': Icons.bolt_rounded, 'label': 'Pusat Aksi'},
      {'icon': Icons.tune_rounded, 'label': 'Simulasi'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(navItems.length, (index) {
            final isSelected = _currentIndex == index;
            final item = navItems[index];

            return InkWell(
              onTap: () => _onBottomNavTapped(index),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? bluePastelBg : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'] as IconData,
                      color: isSelected ? navyPrimary : textTertiary,
                      size: 20,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isSelected ? navyPrimary : textSecondary,
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

