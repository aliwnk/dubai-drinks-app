import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'src/state/catalog_state.dart';
import 'src/state/cart_state.dart';
import 'src/ui/catalog_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DubaiDrinksApp());
}

class DubaiDrinksApp extends StatelessWidget {
  const DubaiDrinksApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CatalogState()..loadInitial()),
        ChangeNotifierProvider(create: (_) => CartState()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Dubai Drinks',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3A56FF)),
          fontFamily: 'CenturyGothic',
          fontFamilyFallback: const ['Roboto', 'Noto Sans', 'Arial Unicode MS'],
        ),
        home: const CatalogScreen(),
      ),
    );
  }
}

