enum UserRole { customer, tech }

class UserProfile {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String gender;
  final UserRole role;
  final String avatarUrl;
  final double walletBalance;
  final String bio;
  final double hourlyRate;
  final int experienceYears;
  final List<String> selectedServices;

  const UserProfile({
    this.id = '',
    this.firstName = '',
    this.lastName = '',
    this.email = '',
    this.phone = '',
    this.gender = '',
    this.role = UserRole.customer,
    this.avatarUrl = '',
    this.walletBalance = 0.0,
    this.bio = '',
    this.hourlyRate = 0.0,
    this.experienceYears = 0,
    this.selectedServices = const [],
  });

  String get fullName => '$firstName $lastName'.trim();

  UserProfile copyWith({
    String? id,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? gender,
    UserRole? role,
    String? avatarUrl,
    double? walletBalance,
    String? bio,
    double? hourlyRate,
    int? experienceYears,
    List<String>? selectedServices,
  }) {
    return UserProfile(
      id: id ?? this.id,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      gender: gender ?? this.gender,
      role: role ?? this.role,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      walletBalance: walletBalance ?? this.walletBalance,
      bio: bio ?? this.bio,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      experienceYears: experienceYears ?? this.experienceYears,
      selectedServices: selectedServices ?? this.selectedServices,
    );
  }
}
