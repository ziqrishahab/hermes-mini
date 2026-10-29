class RegistryItem {
  final String id;
  final String name;
  final String description;
  final String type; // 'skill', 'mcp', 'agent'
  final String? author;
  final String? category;
  final List<String> tags;
  final String? path;
  final String? source;

  const RegistryItem({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.author,
    this.category,
    this.tags = const [],
    this.path,
    this.source,
  });

  factory RegistryItem.fromJson(Map<String, dynamic> json) {
    return RegistryItem(
      id: json['id'] as String? ?? json['name'] as String? ?? '',
      name: json['name'] as String? ?? json['id'] as String? ?? '',
      description: json['description'] as String? ?? '',
      type: json['type'] as String? ?? 'skill',
      author: json['author'] as String?,
      category: json['category'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      path: json['path'] as String?,
      source: json['source'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'type': type,
        'author': author,
        'category': category,
        'tags': tags,
        'path': path,
        'source': source,
      };
}
