class GoogleAuthResult {
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiry;
  final String? email;
  final String? displayName;

  const GoogleAuthResult({
    this.accessToken,
    this.refreshToken,
    this.expiry,
    this.email,
    this.displayName,
  });
}

