import 'package:NammaNanban/features/settings/data/repositories/admin_setup_repository.dart';
import 'package:NammaNanban/features/settings/domain/entities/admin_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('allowed business types include reselling, manufacturing and service',
      () {
    expect(
      AdminSetupConfig.allowedBusinessTypes,
      ['reselling', 'manufacturing', 'service'],
    );
  });

  test('load maps legacy restaurant business type to service', () async {
    SharedPreferences.setMockInitialValues({'business_type': 'restaurant'});

    final config = await AdminSetupRepository.instance.load();

    expect(config.businessType, 'service');
  });

  test('load falls back to reselling for unknown business type', () async {
    SharedPreferences.setMockInitialValues({'business_type': 'invalid'});

    final config = await AdminSetupRepository.instance.load();

    expect(config.businessType, 'reselling');
  });
}
