import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileData {
  const ProfileData({
    this.name = '',
    this.address = '',
    this.phone = '',
    this.email = '',
  });

  final String name;
  final String address;
  final String phone;
  final String email;
}

class ProfileNotifier extends StateNotifier<ProfileData> {
  ProfileNotifier() : super(const ProfileData()) {
    _load();
  }

  static const _kName = 'profile_name';
  static const _kAddress = 'profile_address';
  static const _kPhone = 'profile_phone';
  static const _kEmail = 'profile_email';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = ProfileData(
      name: prefs.getString(_kName) ?? '',
      address: prefs.getString(_kAddress) ?? '',
      phone: prefs.getString(_kPhone) ?? '',
      email: prefs.getString(_kEmail) ?? '',
    );
  }

  Future<void> update(ProfileData data) async {
    state = data;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kName, data.name);
    await prefs.setString(_kAddress, data.address);
    await prefs.setString(_kPhone, data.phone);
    await prefs.setString(_kEmail, data.email);
  }
}

final profileProvider =
    StateNotifierProvider<ProfileNotifier, ProfileData>(
        (ref) => ProfileNotifier());
