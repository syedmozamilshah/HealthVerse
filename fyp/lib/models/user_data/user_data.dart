class UserData {
  final String id;
  final String fName;
  final String lName;
  final String email;
  final String number;
  final String gender;
  final String password;
  final String dob;
  final String imageUrl;
  final String address;
  final String bloodGroup;
  final String profileType;

  const UserData(
      {required this.id,
      required this.fName,
      required this.lName,
      required this.email,
      required this.number,
      required this.gender,
      required this.password,
      required this.dob,
      required this.imageUrl,
      required this.address,
      required this.bloodGroup,
      required this.profileType});

  UserData copyWith({
    String? id,
    String? fName,
    String? lName,
    String? email,
    String? number,
    String? gender,
    String? password,
    String? dob,
    String? imageUrl,
    String? address,
    String? bloodGroup,
    String? patientType,
  }) {
    return UserData(
        id: id ?? this.id,
        fName: fName ?? this.fName,
        lName: lName ?? this.lName,
        email: email ?? this.email,
        number: number ?? this.number,
        gender: gender ?? this.gender,
        password: password ?? this.password,
        dob: dob ?? this.dob,
        imageUrl: imageUrl ?? this.imageUrl,
        address: address ?? this.address,
        bloodGroup: bloodGroup ?? this.bloodGroup,
        profileType: patientType ?? this.profileType);
  }

  factory UserData.fromJson(Map<String, dynamic> json) {
    return UserData(
        id: json['id'] ?? '',
        fName: json['firstName'] ?? '',
        lName: json['lastName'] ?? '',
        email: json['email'] ?? '',
        gender: json['gender'] ?? '',
        password: json['password'] ?? '',
        bloodGroup: json['bloodGroup'] ?? '',
        number: json['whatsappNo'] ?? '',
        dob: (json['dob'] ?? '') ?? DateTime.now().toUtc().toIso8601String(),
        imageUrl: json['profileImage'] ?? '',
        profileType: json['profileType'] ?? '',
        address: json['address'] ?? '');
  }

  factory UserData.fromSessionJson(Map<String, dynamic> json) {
    return UserData(
        id: json['id'] ?? '',
        fName: json['first_name'] ?? '',
        lName: json['last_name'] ?? '',
        email: json['email'] ?? '',
        gender: json['gender'] ?? '',
        password: json['password'] ?? '',
        bloodGroup: json['blood_group'] ?? '',
        number: json['whatsapp_no'] ?? '',
        dob: (json['dob'] ?? '') ?? DateTime.now().toUtc().toIso8601String(),
        imageUrl: json['image_url'] ?? '',
        profileType: json['patient_type'] ?? '',
        address: json['address'] ?? '');
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'first_name': fName,
      'last_name': lName,
      'email': email,
      'whatsapp_no': number,
      'gender': gender,
      'password': password,
      'dob': dob,
      'image_url': imageUrl,
      'address': address,
      'blood_group': bloodGroup,
      'patient_type': profileType
    };
  }
}
