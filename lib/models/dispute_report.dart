class DisputeReport {
  final int id;
  final String description;
  final int filedById;
  final String filedByUsername;
  final int filedAgainstId;
  final String filedAgainstUsername;
  final bool attendedTo;
  final DateTime createdAt;

  const DisputeReport({
    required this.id,
    required this.description,
    required this.filedById,
    required this.filedByUsername,
    required this.filedAgainstId,
    required this.filedAgainstUsername,
    required this.attendedTo,
    required this.createdAt,
  });

  factory DisputeReport.fromJson(Map<String, dynamic> json) {
    return DisputeReport(
      id: json['id'] ?? 0,
      description: json['description'] ?? '',
      filedById: json['filedById'] ?? json['filedBy'] ?? 0,
      filedByUsername: json['filedByUsername'] ?? '',
      filedAgainstId: json['filedAgainstId'] ?? json['filedAgainst'] ?? 0,
      filedAgainstUsername: json['filedAgainstUsername'] ?? '',
      attendedTo: json['attendedTo'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
