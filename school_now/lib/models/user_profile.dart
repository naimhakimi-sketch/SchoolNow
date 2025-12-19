class UserProfile {
  final String id;
  final String name;
  final String email;
  final String role;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'role': role,
      };
}
