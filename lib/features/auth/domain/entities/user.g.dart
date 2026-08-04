// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_User _$UserFromJson(Map<String, dynamic> json) => _User(
  uid: json['uid'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  companyName: json['companyName'] as String? ?? '',
  tallySerialNo: json['tallySerialNo'] as String? ?? '',
  amcExpiryDate: json['amcExpiryDate'] == null
      ? null
      : DateTime.parse(json['amcExpiryDate'] as String),
  phone: json['phone'] as String? ?? '',
  fcmToken: json['fcmToken'] as String?,
);

Map<String, dynamic> _$UserToJson(_User instance) => <String, dynamic>{
  'uid': instance.uid,
  'role': _$UserRoleEnumMap[instance.role]!,
  'companyName': instance.companyName,
  'tallySerialNo': instance.tallySerialNo,
  'amcExpiryDate': instance.amcExpiryDate?.toIso8601String(),
  'phone': instance.phone,
  'fcmToken': instance.fcmToken,
};

const _$UserRoleEnumMap = {
  UserRole.admin: 'admin',
  UserRole.supportHead: 'Support Head',
  UserRole.client: 'client',
};
