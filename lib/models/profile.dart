class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.colorIndex,
  });

  final String id;
  final String displayName;
  final int colorIndex;

  String get firstName => displayName.split(RegExp(r'\s+')).first;

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        id: map['id'] as String,
        displayName: map['display_name'] as String? ?? 'Locmate user',
        colorIndex: (map['color_index'] as num?)?.toInt() ?? 0,
      );
}
