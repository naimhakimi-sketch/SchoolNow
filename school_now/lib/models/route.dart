class RoutePlan {
  final String id;
  final String name;

  const RoutePlan({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
      };

  factory RoutePlan.fromJson(String id, Map<String, dynamic> json) => RoutePlan(
        id: id,
        name: json['name'] as String,
      );
}
