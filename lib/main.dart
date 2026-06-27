import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/database/database_helper.dart';
import 'core/di/injection_container.dart' as di;
import 'core/l10n/app_localizations.dart';
import 'core/sync/data_access_mode_service.dart';
import 'core/theme/app_theme.dart';
import 'features/billing/presentation/bloc/billing_bloc.dart';
import 'features/billing/presentation/pages/held_bills_page.dart';
import 'features/expenses/presentation/bloc/expense_bloc.dart';
import 'features/license/presentation/bloc/license_bloc.dart';
import 'features/license/presentation/bloc/license_event.dart';
import 'features/masters/presentation/bloc/masters_bloc.dart';
import 'features/products/presentation/bloc/product_bloc.dart';
import 'features/purchase/domain/entities/purchase.dart';
import 'features/sales/presentation/bloc/sales_bloc.dart';
import 'features/auth/presentation/pages/login_screen.dart';
import 'features/setup/presentation/pages/setup_page.dart';
import 'features/users/domain/entities/app_user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.dark));

  await di.init();
  final mode = await DataAccessModeService.instance.resolveMode();
  if (mode == DataAccessMode.offlineSqlite) {
    await DatabaseHelper.instance.database;
  } else {
    // Online license: strictly block SQLite access for business data.
    DatabaseHelper.setOnlineMode();
  }
  await AppLocalizations.instance.load();

  final prefs = await SharedPreferences.getInstance();
  final bool isSetupDone = prefs.getBool('setup_done') ?? false;
  Widget startPage;
  if (!isSetupDone) {
    startPage = const SetupPage();
  } else {
    startPage = const LoginScreen();
  }
  runApp(ShopPOSApp(startPage: startPage));
}

class ShopPOSApp extends StatelessWidget {
  final Widget startPage;
  const ShopPOSApp({super.key, required this.startPage});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => di.sl<ProductBloc>()..add(LoadProducts())),
            BlocProvider(create: (_) => di.sl<BillingBloc>()),
            BlocProvider(create: (_) => di.sl<SalesBloc>()..add(LoadSalesData())),
            BlocProvider(create: (_) => di.sl<ExpenseBloc>()..add(LoadExpenses())),
            BlocProvider(create: (_) => di.sl<MastersBloc>()..add(LoadAllMasters())),
            BlocProvider(create: (_) => di.sl<PurchaseBloc>()..add(LoadPurchases())),
            BlocProvider(create: (_) => di.sl<HeldBillBloc>()..add(LoadHeldBills())),
            BlocProvider(create: (_) => di.sl<UserBloc>()),
            BlocProvider(create: (_) => di.sl<LicenseBloc>()..add(const CheckLicense())),
          ],
          child: ListenableBuilder(
            listenable: AppLocalizations.instance,
            builder: (context, _) => MaterialApp(
              title: 'Shop POS',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              home: startPage,
            ),
          ),
        );
      },
    );
  }
}
