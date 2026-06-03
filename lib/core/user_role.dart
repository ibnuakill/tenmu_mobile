enum UserRole { user, owner, superadmin }

extension UserRoleX on UserRole {
  String get value {
    switch (this) {
      case UserRole.user:
        return 'user';
      case UserRole.owner:
        return 'owner';
      case UserRole.superadmin:
        return 'superadmin';
    }
  }

  String get label {
    switch (this) {
      case UserRole.user:
        return 'User Biasa';
      case UserRole.owner:
        return 'Pemilik UMKM';
      case UserRole.superadmin:
        return 'Superadmin';
    }
  }
}

UserRole parseUserRole(dynamic rawRole) {
  final role = rawRole?.toString().trim().toLowerCase();

  switch (role) {
    case 'owner':
      return UserRole.owner;
    case 'superadmin':
    case 'admin':
      return UserRole.superadmin;
    case 'user':
    default:
      return UserRole.user;
  }
}
