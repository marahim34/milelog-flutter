import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileData {
  const ProfileData({
    this.name = '',
    this.companyName = '',
    this.address = '',
    this.phone = '',
    this.email,
  });

  final String name;
  final String companyName;
  final String address;
  final String phone;
  // null = no auth session yet; will be set from FirebaseAuth.instance.currentUser?.email
  final String? email;
}

class ProfileNotifier extends StateNotifier<ProfileData> {
  ProfileNotifier() : super(const ProfileData()) {
    _load();
  }

  static const _kName = 'profile_name';
  static const _kCompanyName = 'profile_company_name';
  static const _kAddress = 'profile_address';
  static const _kPhone = 'profile_phone';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProfileData(
      name: prefs.getString(_kName) ?? '',
      companyName: prefs.getString(_kCompanyName) ?? '',
      address: prefs.getString(_kAddress) ?? '',
      phone: prefs.getString(_kPhone) ?? '',
      email: null, // TODO: FirebaseAuth.instance.currentUser?.email
    );
  }

  Future<void> update(ProfileData data) async {
    state = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, data.name);
    await prefs.setString(_kCompanyName, data.companyName);
    await prefs.setString(_kAddress, data.address);
    await prefs.setString(_kPhone, data.phone);
    // email is not persisted — it comes from the auth session
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileData>(
        (ref) => ProfileNotifier());
