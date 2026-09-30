/// Supported user roles across Alpha X Gym
/// Strictly restricted to Admin and Client roles.
enum UserRole {
  admin,
  client;

  String get value {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.client:
        return 'client';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Admin';
      case UserRole.client:
        return 'Client';
    }
  }

  bool get isAdmin => this == UserRole.admin;
  bool get isClient => this == UserRole.client;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.client;
    final normalized = role.trim().toLowerCase();
    if (normalized == 'admin' || normalized == 'super_admin') {
      return UserRole.admin;
    }
    return UserRole.client;
  }
}
