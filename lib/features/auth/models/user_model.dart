class UserModel {
  final String id;
  final String username;
  final String password;
  final String role;
  final String teamId;

  UserModel({
    required this.id,
    required this.username,
    required this.password,
    required this.role,
    required this.teamId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      username: json['username'],
      password: json['password'],
      role: json['role'],
      teamId: json['teamId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'role': role,
      'teamId': teamId,
    };
  }

  UserModel getUser(String username) {
    return UserModel(
      id: id,
      username: username,
      password: password,
      role: role,
      teamId: teamId,
    );
  }
}
