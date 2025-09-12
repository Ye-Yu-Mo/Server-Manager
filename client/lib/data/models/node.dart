class Node {
  final int id;
  final String nodeId;
  final String hostname;
  final String ipAddress;
  final String? osInfo;
  final String status;
  final DateTime? lastHeartbeat;
  final DateTime registeredAt;
  final DateTime updatedAt;

  Node({
    required this.id,
    required this.nodeId,
    required this.hostname,
    required this.ipAddress,
    this.osInfo,
    required this.status,
    this.lastHeartbeat,
    required this.registeredAt,
    required this.updatedAt,
  });

  factory Node.fromJson(Map<String, dynamic> json) {
    return Node(
      id: json['id'],
      nodeId: json['node_id'],
      hostname: json['hostname'],
      ipAddress: json['ip_address'],
      osInfo: json['os_info'],
      status: json['status'],
      lastHeartbeat: json['last_heartbeat'] != null 
          ? DateTime.parse(json['last_heartbeat'])
          : null,
      registeredAt: DateTime.parse(json['registered_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'node_id': nodeId,
      'hostname': hostname,
      'ip_address': ipAddress,
      'os_info': osInfo,
      'status': status,
      'last_heartbeat': lastHeartbeat?.toIso8601String(),
      'registered_at': registeredAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isOnline => status == 'online';

  String get lastHeartbeatFormatted {
    if (lastHeartbeat == null) return '从未心跳';
    final now = DateTime.now();
    final difference = now.difference(lastHeartbeat!);
    
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}秒前';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else {
      return '${difference.inDays}天前';
    }
  }

  Node copyWith({
    int? id,
    String? nodeId,
    String? hostname,
    String? ipAddress,
    String? osInfo,
    String? status,
    DateTime? lastHeartbeat,
    DateTime? registeredAt,
    DateTime? updatedAt,
  }) {
    return Node(
      id: id ?? this.id,
      nodeId: nodeId ?? this.nodeId,
      hostname: hostname ?? this.hostname,
      ipAddress: ipAddress ?? this.ipAddress,
      osInfo: osInfo ?? this.osInfo,
      status: status ?? this.status,
      lastHeartbeat: lastHeartbeat ?? this.lastHeartbeat,
      registeredAt: registeredAt ?? this.registeredAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
