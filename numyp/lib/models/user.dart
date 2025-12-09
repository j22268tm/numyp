class AppUser {
  AppUser({
    required this.id,
    required this.username,
    required this.accessToken,
    this.iconUrl,
    this.coins = 0,
    this.currentSkinName,
    this.currentSkinImageUrl,
  });

  final String id;
  final String username;
  final String accessToken;
  final String? iconUrl;
  final int coins;
  final String? currentSkinName;
  final String? currentSkinImageUrl;

  factory AppUser.fromApi(Map<String, dynamic> json, String token) {
    final wallet = json['wallet'] as Map<String, dynamic>?;
    final skin = json['current_skin'] as Map<String, dynamic>?;

    return AppUser(
      id: json['id'] as String,
      username: json['username'] as String,
      accessToken: token,
      iconUrl: json['icon_url'] as String?,
      coins: (wallet?['coins'] as num?)?.toInt() ?? 0,
      currentSkinName: skin?['name'] as String?,
      currentSkinImageUrl: skin?['image_url'] as String?,
    );
  }
}
