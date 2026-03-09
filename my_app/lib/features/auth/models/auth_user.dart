class AuthUser {
  final String id;
  final String fullName;
  final String email;

  const AuthUser({
    required this.id,
    required this.fullName,
    required this.email,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'] as String? ?? '',
      fullName: json['fullName'] as String? ?? '',
      email: json['email'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{'id': id, 'fullName': fullName, 'email': email};
  }
}
