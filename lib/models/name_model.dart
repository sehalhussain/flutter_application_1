class AsmaName {
  final int number;
  final String name;
  final String transliteration;
  final String meaning;

  AsmaName({
    required this.number,
    required this.name,
    required this.transliteration,
    required this.meaning,
  });

  factory AsmaName.fromJson(Map<String, dynamic> json) {
    return AsmaName(
      number: json['number'] ?? 0,
      name: json['name'] ?? '',
      transliteration: json['transliteration'] ?? '',
      // Digging into the 'en' object for the meaning
      meaning: json['en'] != null ? json['en']['meaning'] : '',
    );
  }
}
