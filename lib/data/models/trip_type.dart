/// Mirrors the TripType enum from the Kotlin source.
/// Stored as its [value] string ('PERSONAL' / 'BUSINESS') in the database.
enum TripType {
  personal('PERSONAL'),
  business('BUSINESS');

  const TripType(this.value);
  final String value;

  static TripType fromString(String s) =>
      values.firstWhere((e) => e.value == s, orElse: () => TripType.personal);
}
