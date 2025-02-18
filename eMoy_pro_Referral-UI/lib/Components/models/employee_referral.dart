class EmployeeReferral {
  final int referralInfoId;
  final int referralEventId;
  final int branchId;
  final String userId;
  final String customerName;
  final String address;
  final int functionName;
  final DateTime? dateOfFunction;
  final String customerMobileNumber;
  final String customerWhatsappNumber;
  final int noOfTable;
  final String selfProposal;
  final String? eventPhoto;
  final String description;
  final String isReferralBooked;
  final int noOfPoints;
  final int totalPoints;
  final String? createdBy;
  final DateTime? createdDate;
  final String? updatedBy;
  final DateTime? updatedDate;
  final bool isActive;

  EmployeeReferral({
    required this.referralInfoId,
    required this.referralEventId,
    required this.branchId,
    required this.userId,
    required this.customerName,
    required this.address,
    required this.functionName,
    required this.dateOfFunction,
    required this.customerMobileNumber,
    required this.customerWhatsappNumber,
    required this.noOfTable,
    required this.selfProposal,
    this.eventPhoto,
    required this.description,
    required this.isReferralBooked,
    required this.noOfPoints,
    required this.totalPoints,
    this.createdBy,
    this.createdDate,
    this.updatedBy,
    this.updatedDate,
    required this.isActive,
  });

  factory EmployeeReferral.fromJson(Map<String, dynamic> json) {
    return EmployeeReferral(
      referralInfoId: json['referral_info_id'] as int,
      referralEventId: json['referral_event_id'] as int,
      branchId: json['branch_id'] as int,
      functionName: json['event_id'] as int,
      userId: json['user_id'] as String,
      customerName: json['customer_name'] ?? '',
      address: json['address'] ?? '',
      dateOfFunction: _parseDate(json['date_of_function']),
      customerMobileNumber: json['customer_mobile_number']?.toString() ?? '',
      customerWhatsappNumber: json['customer_whatsapp_number']?.toString() ?? '',
      noOfTable: int.tryParse(json['no_of_table']?.toString() ?? '0') ?? 0,
      selfProposal: json['self_proposal'] ?? '',
      description: json['description'] ?? '',
      eventPhoto: json['event_photo'] as String?,
      isReferralBooked: json['is_referral_booked'] ?? '',
      noOfPoints: json['no_of_points'] ?? 0,
      totalPoints: json['total_sum_amount'] ?? 0,
      createdBy: json['created_by'] as String?,
      createdDate: _parseDate(json['created_date']),
      updatedBy: json['updated_by'] as String?,
      updatedDate: _parseDate(json['updated_date']),
      isActive: json['is_active'] == "Y",
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is int) {
      return DateTime.fromMillisecondsSinceEpoch(date);
    }
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class UserProfile {
  final int userProfileId;
  final String userId;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime? dateOfBirth;
  final String email;
  final String address;
  final String mobileNumber;
  final String whatsappNumber;
  final int branchId;
  final String? profilePicture;
  final String? identityProof;

  UserProfile({
    required this.userProfileId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.dateOfBirth,
    required this.email,
    required this.address,
    required this.mobileNumber,
    required this.whatsappNumber,
    required this.branchId,
    this.profilePicture,
    this.identityProof,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userProfileId: json['userprofile_id'] as int,
      userId: json['user_id'] as String,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      gender: json['gender'] ?? '',
      dateOfBirth: _parseDate(json['date_of_birth']),
      email: json['email'] ?? '',
      address: json['address'] ?? '',
      mobileNumber: json['mobile_number']?.toString() ?? '',
      whatsappNumber: json['whatsapp_number']?.toString() ?? '',
      branchId: json['branch_id'] as int,
      profilePicture: json['profile_picture'] as String?,
      identityProof: json['identity_Proof'] as String?,
    );
  }

  static DateTime? _parseDate(dynamic date) {
    if (date == null) return null;
    if (date is String) {
      try {
        return DateTime.parse(date);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}

class ReferralAndProfile {
  final EmployeeReferral referral;
  final UserProfile profile;

  ReferralAndProfile({
    required this.referral,
    required this.profile,
  });

  factory ReferralAndProfile.fromJson(Map<String, dynamic> json) {
    return ReferralAndProfile(
      referral: EmployeeReferral.fromJson(json['referal_Info']),
      profile: UserProfile.fromJson(json['user_Profiles']),
    );
  }

  get userProfiles => null;

  get totalPoints => null;
}
