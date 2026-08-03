import 'auth_user.dart';

class AuthSessionResult {
  final AuthUser user;
  final String token;
  final DateTime? expiresAt;

  /// True when the backend reports this account has no workshop details saved
  /// yet, so the app routes it into the workshop onboarding screen before the
  /// home screen. Persisted so it survives an app restart mid-onboarding.
  final bool needsWorkshopSetup;

  const AuthSessionResult({
    required this.user,
    required this.token,
    required this.expiresAt,
    this.needsWorkshopSetup = false,
  });

  factory AuthSessionResult.fromJson(Map<String, dynamic> json) {
    return AuthSessionResult(
      user: AuthUser.fromJson(
        (json['user'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
      ),
      token: json['token'] as String? ?? '',
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? ''),
      needsWorkshopSetup: json['needsWorkshopSetup'] == true,
    );
  }

  AuthSessionResult copyWith({bool? needsWorkshopSetup}) {
    return AuthSessionResult(
      user: user,
      token: token,
      expiresAt: expiresAt,
      needsWorkshopSetup: needsWorkshopSetup ?? this.needsWorkshopSetup,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'user': user.toJson(),
      'token': token,
      'expiresAt': expiresAt?.toIso8601String(),
      'needsWorkshopSetup': needsWorkshopSetup,
    };
  }
}
