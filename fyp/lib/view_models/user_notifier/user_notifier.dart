import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fyp/views/links/image_link/image_link.dart';
import '../../models/user_data/user_data.dart';

// M-2 FOR MANAGING USER DATA IN THE APP STATE
class UserNotifier extends StateNotifier<UserData> {
  UserNotifier()
      : super(UserData(
            id: '',
            fName: '',
            lName: '',
            email: '',
            number: '',
            gender: 'Male',
            password: '',
            dob: DateTime.now().toIso8601String(),
            imageUrl: image,
            address: '',
            bloodGroup: '',
            profileType: 'patient'));

  void updateFName(String n) {
    state = state.copyWith(fName: n);
  }

  void updateLName(String n) {
    state = state.copyWith(lName: n);
  }

  void updateName(String fName, String lName) {
    state = state.copyWith(fName: fName, lName: lName);
  }

  void updateEmail(String e) {
    state = state.copyWith(email: e);
  }

  void updateNumber(String n) {
    state = state.copyWith(number: n);
  }

  void updateGender(String g) {
    state = state.copyWith(gender: g);
  }

  void updatePassword(String p) {
    state = state.copyWith(password: p);
  }

  void updateDob(DateTime d) {
    state = state.copyWith(dob: d.toIso8601String());
  }

  void updateAddress(String a) {
    state = state.copyWith(address: a);
  }

  void updateBloodType(String b) {
    state = state.copyWith(bloodGroup: b);
  }

  void updateImageUrl(String url) {
    state = state.copyWith(imageUrl: url);
  }

  void loadUserFromSession(UserData userData) {
    state = userData;
  }
}
