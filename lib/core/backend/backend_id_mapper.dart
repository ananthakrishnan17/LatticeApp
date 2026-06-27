import 'package:shared_preferences/shared_preferences.dart';

class BackendIdMapper {
  BackendIdMapper._();

  static final BackendIdMapper instance = BackendIdMapper._();

  SharedPreferences? _prefs;
  final Map<String, int> _uuidToIntCache = <String, int>{};
  final Map<String, String> _intToUuidCache = <String, String>{};

  Future<SharedPreferences> _preferences() async =>
      _prefs ??= await SharedPreferences.getInstance();

  String _uuidKey(String namespace, String uuid) =>
      'backend_id_map:$namespace:uuid:$uuid';

  String _intKey(String namespace, int id) =>
      'backend_id_map:$namespace:int:$id';

  Future<int> register({
    required String namespace,
    required String uuid,
  }) async {
    final normalizedUuid = uuid.trim();
    final uuidCacheKey = '$namespace::$normalizedUuid';
    final cachedInt = _uuidToIntCache[uuidCacheKey];
    if (cachedInt != null) {
      _intToUuidCache['$namespace::$cachedInt'] = normalizedUuid;
      return cachedInt;
    }

    final prefs = await _preferences();
    final storedInt = prefs.getInt(_uuidKey(namespace, normalizedUuid));
    if (storedInt != null) {
      _uuidToIntCache[uuidCacheKey] = storedInt;
      _intToUuidCache['$namespace::$storedInt'] = normalizedUuid;
      return storedInt;
    }

    var candidate = normalizedUuid.hashCode & 0x7fffffff;
    if (candidate == 0) {
      candidate = 1;
    }

    while (true) {
      final reverseKey = _intKey(namespace, candidate);
      final existingUuid =
          _intToUuidCache['$namespace::$candidate'] ?? prefs.getString(reverseKey);
      if (existingUuid == null || existingUuid == normalizedUuid) {
        await prefs.setInt(_uuidKey(namespace, normalizedUuid), candidate);
        await prefs.setString(reverseKey, normalizedUuid);
        _uuidToIntCache[uuidCacheKey] = candidate;
        _intToUuidCache['$namespace::$candidate'] = normalizedUuid;
        return candidate;
      }
      candidate += 1;
      if (candidate < 0) {
        candidate = 1;
      }
    }
  }

  Future<String?> lookupUuid({
    required String namespace,
    required int id,
  }) async {
    final cacheKey = '$namespace::$id';
    final cachedUuid = _intToUuidCache[cacheKey];
    if (cachedUuid != null) {
      return cachedUuid;
    }
    final prefs = await _preferences();
    final storedUuid = prefs.getString(_intKey(namespace, id));
    if (storedUuid != null) {
      _intToUuidCache[cacheKey] = storedUuid;
      _uuidToIntCache['$namespace::$storedUuid'] = id;
    }
    return storedUuid;
  }
}
