class ReportDescriptor {
  final String reportName;
  final String label;
  final String description;
  final List<String> allowedRoles;
  final List<String> params;

  const ReportDescriptor({
    required this.reportName,
    required this.label,
    required this.description,
    required this.allowedRoles,
    required this.params,
  });

  factory ReportDescriptor.fromJson(Map<String, dynamic> json) {
    List<String> parseStringList(dynamic value) {
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      return const <String>[];
    }

    return ReportDescriptor(
      reportName: json['reportName']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      allowedRoles: parseStringList(json['allowedRoles']),
      params: parseStringList(json['params']),
    );
  }
}
