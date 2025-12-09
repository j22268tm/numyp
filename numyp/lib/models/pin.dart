class Pin {
  Pin({
    required this.id,
    required this.title,
    this.description,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final String id;
  final String title;
  final String? description;
  final DateTime createdAt;

  Pin copyWith({String? title, String? description}) {
    return Pin(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      createdAt: createdAt,
    );
  }
}
