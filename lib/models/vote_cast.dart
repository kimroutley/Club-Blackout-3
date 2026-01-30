class VoteCast {
  final int day;
  final String voterId;
  final String? targetId;
  final DateTime timestamp;
  final int sequence;

  const VoteCast({
    required this.day,
    required this.voterId,
    required this.targetId,
    required this.timestamp,
    required this.sequence,
  });

  Map<String, dynamic> toJson() => {
        'day': day,
        'voterId': voterId,
        'targetId': targetId,
        'timestamp': timestamp.toIso8601String(),
        'sequence': sequence,
      };

  factory VoteCast.fromJson(Map<String, dynamic> json) {
    return VoteCast(
      day: (json['day'] as num?)?.toInt() ?? 0,
      voterId: json['voterId'] as String,
      targetId: json['targetId'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      sequence: (json['sequence'] as num?)?.toInt() ?? 0,
    );
  }
}
