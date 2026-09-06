import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'design/tokens.dart';
import 'glass/liquid_glass.dart';
import 'screens/home_screen.dart';
import 'widgets/chrome.dart';
import 'widgets/glass_tab_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Шейдер компилируется один раз и заранее: если тянуть до первого кадра
  // со стеклом, этот кадр успеет отрисоваться запасным путём и будет
  // видна подмена.
  await GlassProgram.load();
  SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle.dark);
  runApp(const SproutApp());
}

class SproutApp extends StatelessWidget {
  const SproutApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const CupertinoApp(
      title: 'Sprout',
      debugShowCheckedModeBanner: false,
      theme: CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: SproutColors.accent,
        scaffoldBackgroundColor: SproutColors.background,
      ),
      // Приложение целиком русское, поэтому и системные элементы — меню
      // выделения текста в поиске, подписи в диалогах — должны быть
      // русскими. Без этого списка они остаются английскими.
      locale: Locale('ru'),
      supportedLocales: [Locale('ru')],
      localizationsDelegates: [
        DefaultCupertinoLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
      ],
      home: SproutShell(),
    );
  }
}

/// Оболочка приложения.
///
/// Нижняя панель и плашка под чёлкой лежат над вложенным Navigator, а не
/// внутри экранов. Из-за этого при переходе на растение уезжает только
/// содержимое, а стекло панели остаётся на месте и продолжает преломлять
/// то, что под ним проезжает, — как в iOS.
class SproutShell extends StatefulWidget {
  const SproutShell({super.key});

  @override
  State<SproutShell> createState() => _SproutShellState();
}

class _SproutShellState extends State<SproutShell> {
  final _navigator = GlobalKey<NavigatorState>();
  final _query = ValueNotifier<String>('');

  int _tab = 0;
  bool _searchOpen = false;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _onTab(int i) {
    // Разделов кроме главного в макете нет. Переключение оставлено
    // живым — на нём и видно, как подложка перетекает между вкладками.
    setState(() => _tab = i);
    _navigator.currentState?.popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_searchOpen) {
          setState(() => _searchOpen = false);
          return;
        }
        _navigator.currentState?.maybePop();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: Navigator(
              key: _navigator,
              onGenerateRoute: (settings) => CupertinoPageRoute<void>(
                settings: settings,
                builder: (_) => HomeScreen(query: _query),
              ),
            ),
          ),
          const Positioned(
            top: 19,
            left: 0,
            right: 0,
            child: Center(child: SproutBadge()),
          ),
          Positioned(
            left: SproutMetrics.barMargin,
            right: SproutMetrics.barMargin,
            // В макете панель отстоит от низа экрана на 21 pt и заходит
            // на область домашней полосы — ровно как системный таб-бар.
            bottom: 21,
            child: GlassTabBar(
              index: _tab,
              onIndexChanged: _onTab,
              searchOpen: _searchOpen,
              onSearchOpenChanged: (v) => setState(() => _searchOpen = v),
              onQueryChanged: (q) => _query.value = q,
            ),
          ),
        ],
      ),
    );
  }
}
