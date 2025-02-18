class EmployeeProfile {
  final int userProfileId;
  final String userId;
  final String firstName;
  final String lastName;
  final String gender;
  final DateTime? dateOfBirth;
  final String mobileNumber;
  final String whatsappNumber;
  final String email;
  final String address;
  final String? identityProof;
  final String? profileImageUrl;
  final int branchId;
  final String createdBy;
  final DateTime? createdDate;
  final String updatedBy;
  final DateTime? updatedDate;

  EmployeeProfile({
    required this.userProfileId,
    required this.userId,
    required this.firstName,
    required this.lastName,
    required this.gender,
    this.dateOfBirth,
    required this.mobileNumber,
    required this.whatsappNumber,
    required this.email,
    required this.address,
    this.identityProof,
    this.profileImageUrl,
    required this.branchId,
    required this.createdBy,
    this.createdDate,
    required this.updatedBy,
    this.updatedDate,
  });

  factory EmployeeProfile.fromJson(Map<String, dynamic> json) {
    return EmployeeProfile(
      userProfileId: json['userprofile_id'] as int,
      userId: json['user_id'] as String,
      firstName: json['first_name'] as String,
      lastName: json['last_name'] as String,
      gender: json['gender'] as String,
      dateOfBirth: _parseDate(json['date_of_birth']),
      mobileNumber: json['mobile_number']?.toString() ?? '',
      whatsappNumber: json['whatsapp_number']?.toString() ?? '',
      email: json['email'] as String? ?? '',
      address: json['address'] as String? ?? '',
      identityProof: json['identityproof'] as String?,
      profileImageUrl: json['profile_picture'] as String?,
      branchId: json['branch_id'] as int,
      createdBy: json['created_by'] as String,
      createdDate: _parseDate(json['created_date']),
      updatedBy: json['updated_by'] as String,
      updatedDate: _parseDate(json['updated_date']),
    );
  }

  get isNotEmpty => null;

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
