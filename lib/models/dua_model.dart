class Dua {
  final String title;
  final String arabic;
  final String? latin;
  final String translation;
  final String? notes;
  final String? benefits;
  final String? source;

  Dua({
    required this.title,
    required this.arabic,
    this.latin,
    required this.translation,
    this.notes,
    this.benefits,
    this.source,
  });

  factory Dua.fromJson(Map<String, dynamic> json) {
    return Dua(
      title: json['title'] ?? '',
      arabic: json['arabic'] ?? '',
      latin: json['latin'],
      translation: json['translation'] ?? '',
      notes: json['notes'],
      benefits: json['benefits'] ?? json['fawaid'],
      source: json['source'],
    );
  }
}
