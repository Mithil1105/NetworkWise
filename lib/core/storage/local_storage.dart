/// Abstract local storage contract.
///
/// A concrete implementation (SharedPreferences / Hive / file) will be
/// bound in Phase 9 when Settings are wired up. Keeping the interface
/// here lets providers depend on the abstraction today.
abstract class ILocalStorage {
  Future<void> init();

  Future<String?> readString(String key);
  Future<void> writeString(String key, String value);

  Future<int?> readInt(String key);
  Future<void> writeInt(String key, int value);

  Future<double?> readDouble(String key);
  Future<void> writeDouble(String key, double value);

  Future<bool?> readBool(String key);
  Future<void> writeBool(String key, bool value);

  Future<void> remove(String key);
  Future<void> clear();
}
