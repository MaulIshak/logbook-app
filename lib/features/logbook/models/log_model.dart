class LogModel {
  final String title;
  final String date;
  final String description;
  final String username;

  LogModel({
    required this.title,
    required this.date,
    required this.description,
    required this.username,
  });

  // Untuk Tugas HOTS: Konversi Map (JSON) ke Object
  factory LogModel.fromMap(Map<String, dynamic> map) {
    return LogModel(
      title: map['title'],
      date: map['date'],
      description: map['description'],
      username: map['username'],
    );
  }

  // Konversi Object ke Map (JSON) untuk disimpan
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'date': date,
      'description': description,
      'username': username,
    };
  }
}
