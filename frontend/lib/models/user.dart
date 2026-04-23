class User {
  final String username;
  final String role;
  final String token;
  final int? farmId;
  final String? farmName;

  User({
    required this.username,
    required this.role,
    required this.token,
    this.farmId,
    this.farmName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      username: json['username'],
      role: json['role'],
      token: json['token'],
      farmId: json['farmId'],
      farmName: json['farmName'],
    );
  }
}