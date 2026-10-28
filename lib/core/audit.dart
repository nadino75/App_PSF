enum UserRole { user, owner, admin }

enum AuditAction {
  signIn,
  register,
  updateProfile,
  submitRequest,
  withdrawRequest,
  resolveRequest,
  editorialCategory,
  editorialBulletin,
  editorialBusiness,
  editorialAd,
  toggleFavorite,
  markReadNotification,
  uploadImage,
}

class AuditLog {
  final String id;
  final String userId;
  final String? userName;
  final AuditAction action;
  final String? targetId;
  final String? targetType;
  final Map<String, dynamic>? changes;
  final String? result;
  final String? reason;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.userId,
    this.userName,
    required this.action,
    this.targetId,
    this.targetType,
    this.changes,
    this.result,
    this.reason,
    required this.timestamp,
  });
}
