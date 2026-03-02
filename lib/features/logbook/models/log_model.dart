class LogModel {
  final String title;
  final String date;
  final String description;
  final String username;
  final String category;

  LogModel({
    required this.title,
    required this.date,
    required this.description,
    required this.username,
    required this.category,
  });

  // Untuk Tugas HOTS: Konversi Map (JSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      title: map['title'],
      date: map['date'],
      description: map['description'],
      username: map['username'],
      category: map['category'] ?? 'Other',
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': date,
      'description': description,
      'username': username,
      'category': category,
    };
  }
}
