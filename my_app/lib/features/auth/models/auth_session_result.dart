import 'auth_user.dart';

class AuthSessionResult {
  final AuthUser user;
  final String token;
  final DateTime? expiresAt;

  const AuthSessionResult({
    required this.user,
    required this.token,
    required this.expiresAt,
  });

  factory AuthSessionResult.fromJson(Map<String, dynamic> json) {
    return AuthSessionResult(
      user: AuthUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      token: json['token'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user.toJson(),
      'token': token,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }
}
