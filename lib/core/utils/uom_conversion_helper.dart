/// Helper for converting between user-facing units and the smallest stored
/// base unit.
///
/// All stock quantities are persisted in the database as the **smallest unit**
/// for each physical dimension:
///   - Weight  : Kilogram (Kg / kg) → grams  (g)   ×1000
///   - Volume  : Litre (L / l / Litre) → millilitres (ml) ×1000
///   - All other units (piece, dozen, pack, box, metre, etc.) → stored as-is (×1)
///
/// Usage:
///   final factor = UomConversionHelper.baseFactor('Kg');  // → 1000.0
///   final dbValue = userValue * factor;                   // store
///   final userValue = dbValue / factor;                   // display
class UomConversionHelper {
  UomConversionHelper._();

  /// Returns the multiplier from user-facing unit → smallest base unit.
  ///
  /// Examples:
  ///   'Kg' → 1000.0  (1 kg = 1000 g)
  ///   'kg' → 1000.0
  ///   'L'  → 1000.0  (1 litre = 1000 ml)
  ///   'l'  → 1000.0
  ///   'Litre' → 1000.0
  ///   'g'  → 1.0
  ///   'ml' → 1.0
  ///   'piece', 'pcs', 'box', etc. → 1.0
  static double baseFactor(String unitShortName) {
    switch (unitShortName.toLowerCase().trim()) {
      case 'kg':
      case 'kilogram':
      case 'l':
      case 'litre':
      case 'liter':
        return 1000.0;
      default:
        return 1.0;
    }
  }

  /// Returns the label for the smallest base unit corresponding to [unitShortName].
  ///
  /// Examples:
  ///   'Kg' → 'g'
  ///   'L'  → 'ml'
  ///   'ml' → 'ml'
  ///   'piece' → 'piece'
  static String baseUnitLabel(String unitShortName) {
    switch (unitShortName.toLowerCase().trim()) {
      case 'kg':
      case 'kilogram':
        return 'g';
      case 'l':
      case 'litre':
      case 'liter':
        return 'ml';
      default:
        return unitShortName;
    }
  }

  /// Converts a [userValue] (in user-facing units) to the DB base unit.
  static double toBase(double userValue, String unitShortName) =>
      userValue * baseFactor(unitShortName);

  /// Converts a [baseValue] (DB base unit) back to user-facing units.
  static double toUser(double baseValue, String unitShortName) =>
      baseValue / baseFactor(unitShortName);
}
