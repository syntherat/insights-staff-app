class StaffAccess {
  final bool canGate;
  final bool canGame;
  final bool canPrize;
  final bool canStaffCheckin;
  final bool canManageCheckinDays;
  final String? staffRegNo;

  const StaffAccess({
    required this.canGate,
    required this.canGame,
    required this.canPrize,
    required this.canStaffCheckin,
    required this.canManageCheckinDays,
    this.staffRegNo,
  });

  factory StaffAccess.fromJson(Map<String, dynamic>? json) {
    final data = json ?? <String, dynamic>{};
    return StaffAccess(
      canGate: data['can_gate'] == true,
      canGame: data['can_game'] == true,
      canPrize: data['can_prize'] == true,
      canStaffCheckin: data['can_staff_checkin'] == true,
      canManageCheckinDays: data['can_manage_checkin_days'] == true,
      staffRegNo: data['staff_reg_no']?.toString(),
    );
  }
}

class StaffUser {
  final String id;
  final String username;
  final String role;
  final String? fullName;
  final String? email;
  final StaffAccess access;

  const StaffUser({
    required this.id,
    required this.username,
    required this.role,
    required this.access,
    this.fullName,
    this.email,
  });

  factory StaffUser.fromJson(Map<String, dynamic> json) {
    return StaffUser(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? '',
      role: json['role']?.toString() ?? 'STAFF',
      fullName: json['full_name']?.toString(),
      email: json['email']?.toString(),
      access: StaffAccess.fromJson(json['access'] as Map<String, dynamic>?),
    );
  }
}

class StaffSession {
  final String token;
  final StaffUser staff;

  const StaffSession({required this.token, required this.staff});
}
