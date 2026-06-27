import 'package:NammaNanban/core/sync/data_access_mode_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    DataAccessModeService.instance.clearCache();
  });

  test('resolveMode returns online mode when license type is online', () async {
    SharedPreferences.setMockInitialValues({'license_type': 'online'});
    DataAccessModeService.instance.clearCache();

    final mode = await DataAccessModeService.instance.resolveMode();

    expect(mode, DataAccessMode.onlineApi);
  });

  test('resolveMode returns offline mode by default', () async {
    final mode = await DataAccessModeService.instance.resolveMode();

    expect(mode, DataAccessMode.offlineSqlite);
  });

  test('resolveMode treats non-online license values as offline', () async {
    SharedPreferences.setMockInitialValues({'license_type': 'unknown'});
    DataAccessModeService.instance.clearCache();

    final mode = await DataAccessModeService.instance.resolveMode();

    expect(mode, DataAccessMode.offlineSqlite);
  });
}
