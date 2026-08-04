import 'package:freezed_annotation/freezed_annotation.dart';

part 'user.freezed.dart';
part 'user.g.dart';

enum UserRole {
  admin,
  @JsonValue('Support Head')
  supportHead,
  client,
}

@freezed
abstract class User with _$User {
  const factory User({
    required String uid,
    required UserRole role,
    @Default('') String companyName,
    @Default('') String tallySerialNo,
    DateTime? amcExpiryDate,
    @Default('') String phone,
    String? fcmToken,
  }) = _User;

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
}
