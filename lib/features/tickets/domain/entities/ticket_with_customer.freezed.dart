// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'ticket_with_customer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$TicketWithCustomer {

 String get ticketId; String get customerId; String? get clientTicketUuid; String get title; String? get description; String? get category; String get status; String get priority; String get createdBy; String? get assignedTo; DateTime get createdAt; DateTime get updatedAt; DateTime? get slaDue;// Customer information
 Customer? get customer;
/// Create a copy of TicketWithCustomer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TicketWithCustomerCopyWith<TicketWithCustomer> get copyWith => _$TicketWithCustomerCopyWithImpl<TicketWithCustomer>(this as TicketWithCustomer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is TicketWithCustomer&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.clientTicketUuid, clientTicketUuid) || other.clientTicketUuid == clientTicketUuid)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.status, status) || other.status == status)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.slaDue, slaDue) || other.slaDue == slaDue)&&(identical(other.customer, customer) || other.customer == customer));
}


@override
int get hashCode => Object.hash(runtimeType,ticketId,customerId,clientTicketUuid,title,description,category,status,priority,createdBy,assignedTo,createdAt,updatedAt,slaDue,customer);

@override
String toString() {
  return 'TicketWithCustomer(ticketId: $ticketId, customerId: $customerId, clientTicketUuid: $clientTicketUuid, title: $title, description: $description, category: $category, status: $status, priority: $priority, createdBy: $createdBy, assignedTo: $assignedTo, createdAt: $createdAt, updatedAt: $updatedAt, slaDue: $slaDue, customer: $customer)';
}


}

/// @nodoc
abstract mixin class $TicketWithCustomerCopyWith<$Res>  {
  factory $TicketWithCustomerCopyWith(TicketWithCustomer value, $Res Function(TicketWithCustomer) _then) = _$TicketWithCustomerCopyWithImpl;
@useResult
$Res call({
 String ticketId, String customerId, String? clientTicketUuid, String title, String? description, String? category, String status, String priority, String createdBy, String? assignedTo, DateTime createdAt, DateTime updatedAt, DateTime? slaDue, Customer? customer
});


$CustomerCopyWith<$Res>? get customer;

}
/// @nodoc
class _$TicketWithCustomerCopyWithImpl<$Res>
    implements $TicketWithCustomerCopyWith<$Res> {
  _$TicketWithCustomerCopyWithImpl(this._self, this._then);

  final TicketWithCustomer _self;
  final $Res Function(TicketWithCustomer) _then;

/// Create a copy of TicketWithCustomer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? ticketId = null,Object? customerId = null,Object? clientTicketUuid = freezed,Object? title = null,Object? description = freezed,Object? category = freezed,Object? status = null,Object? priority = null,Object? createdBy = null,Object? assignedTo = freezed,Object? createdAt = null,Object? updatedAt = null,Object? slaDue = freezed,Object? customer = freezed,}) {
  return _then(_self.copyWith(
ticketId: null == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,clientTicketUuid: freezed == clientTicketUuid ? _self.clientTicketUuid : clientTicketUuid // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,slaDue: freezed == slaDue ? _self.slaDue : slaDue // ignore: cast_nullable_to_non_nullable
as DateTime?,customer: freezed == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as Customer?,
  ));
}
/// Create a copy of TicketWithCustomer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomerCopyWith<$Res>? get customer {
    if (_self.customer == null) {
    return null;
  }

  return $CustomerCopyWith<$Res>(_self.customer!, (value) {
    return _then(_self.copyWith(customer: value));
  });
}
}


/// Adds pattern-matching-related methods to [TicketWithCustomer].
extension TicketWithCustomerPatterns on TicketWithCustomer {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _TicketWithCustomer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _TicketWithCustomer() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _TicketWithCustomer value)  $default,){
final _that = this;
switch (_that) {
case _TicketWithCustomer():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _TicketWithCustomer value)?  $default,){
final _that = this;
switch (_that) {
case _TicketWithCustomer() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String ticketId,  String customerId,  String? clientTicketUuid,  String title,  String? description,  String? category,  String status,  String priority,  String createdBy,  String? assignedTo,  DateTime createdAt,  DateTime updatedAt,  DateTime? slaDue,  Customer? customer)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _TicketWithCustomer() when $default != null:
return $default(_that.ticketId,_that.customerId,_that.clientTicketUuid,_that.title,_that.description,_that.category,_that.status,_that.priority,_that.createdBy,_that.assignedTo,_that.createdAt,_that.updatedAt,_that.slaDue,_that.customer);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String ticketId,  String customerId,  String? clientTicketUuid,  String title,  String? description,  String? category,  String status,  String priority,  String createdBy,  String? assignedTo,  DateTime createdAt,  DateTime updatedAt,  DateTime? slaDue,  Customer? customer)  $default,) {final _that = this;
switch (_that) {
case _TicketWithCustomer():
return $default(_that.ticketId,_that.customerId,_that.clientTicketUuid,_that.title,_that.description,_that.category,_that.status,_that.priority,_that.createdBy,_that.assignedTo,_that.createdAt,_that.updatedAt,_that.slaDue,_that.customer);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String ticketId,  String customerId,  String? clientTicketUuid,  String title,  String? description,  String? category,  String status,  String priority,  String createdBy,  String? assignedTo,  DateTime createdAt,  DateTime updatedAt,  DateTime? slaDue,  Customer? customer)?  $default,) {final _that = this;
switch (_that) {
case _TicketWithCustomer() when $default != null:
return $default(_that.ticketId,_that.customerId,_that.clientTicketUuid,_that.title,_that.description,_that.category,_that.status,_that.priority,_that.createdBy,_that.assignedTo,_that.createdAt,_that.updatedAt,_that.slaDue,_that.customer);case _:
  return null;

}
}

}

/// @nodoc


class _TicketWithCustomer implements TicketWithCustomer {
  const _TicketWithCustomer({required this.ticketId, required this.customerId, this.clientTicketUuid, required this.title, this.description, this.category, required this.status, required this.priority, required this.createdBy, this.assignedTo, required this.createdAt, required this.updatedAt, this.slaDue, this.customer});
  

@override final  String ticketId;
@override final  String customerId;
@override final  String? clientTicketUuid;
@override final  String title;
@override final  String? description;
@override final  String? category;
@override final  String status;
@override final  String priority;
@override final  String createdBy;
@override final  String? assignedTo;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  DateTime? slaDue;
// Customer information
@override final  Customer? customer;

/// Create a copy of TicketWithCustomer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TicketWithCustomerCopyWith<_TicketWithCustomer> get copyWith => __$TicketWithCustomerCopyWithImpl<_TicketWithCustomer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _TicketWithCustomer&&(identical(other.ticketId, ticketId) || other.ticketId == ticketId)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.clientTicketUuid, clientTicketUuid) || other.clientTicketUuid == clientTicketUuid)&&(identical(other.title, title) || other.title == title)&&(identical(other.description, description) || other.description == description)&&(identical(other.category, category) || other.category == category)&&(identical(other.status, status) || other.status == status)&&(identical(other.priority, priority) || other.priority == priority)&&(identical(other.createdBy, createdBy) || other.createdBy == createdBy)&&(identical(other.assignedTo, assignedTo) || other.assignedTo == assignedTo)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.slaDue, slaDue) || other.slaDue == slaDue)&&(identical(other.customer, customer) || other.customer == customer));
}


@override
int get hashCode => Object.hash(runtimeType,ticketId,customerId,clientTicketUuid,title,description,category,status,priority,createdBy,assignedTo,createdAt,updatedAt,slaDue,customer);

@override
String toString() {
  return 'TicketWithCustomer(ticketId: $ticketId, customerId: $customerId, clientTicketUuid: $clientTicketUuid, title: $title, description: $description, category: $category, status: $status, priority: $priority, createdBy: $createdBy, assignedTo: $assignedTo, createdAt: $createdAt, updatedAt: $updatedAt, slaDue: $slaDue, customer: $customer)';
}


}

/// @nodoc
abstract mixin class _$TicketWithCustomerCopyWith<$Res> implements $TicketWithCustomerCopyWith<$Res> {
  factory _$TicketWithCustomerCopyWith(_TicketWithCustomer value, $Res Function(_TicketWithCustomer) _then) = __$TicketWithCustomerCopyWithImpl;
@override @useResult
$Res call({
 String ticketId, String customerId, String? clientTicketUuid, String title, String? description, String? category, String status, String priority, String createdBy, String? assignedTo, DateTime createdAt, DateTime updatedAt, DateTime? slaDue, Customer? customer
});


@override $CustomerCopyWith<$Res>? get customer;

}
/// @nodoc
class __$TicketWithCustomerCopyWithImpl<$Res>
    implements _$TicketWithCustomerCopyWith<$Res> {
  __$TicketWithCustomerCopyWithImpl(this._self, this._then);

  final _TicketWithCustomer _self;
  final $Res Function(_TicketWithCustomer) _then;

/// Create a copy of TicketWithCustomer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? ticketId = null,Object? customerId = null,Object? clientTicketUuid = freezed,Object? title = null,Object? description = freezed,Object? category = freezed,Object? status = null,Object? priority = null,Object? createdBy = null,Object? assignedTo = freezed,Object? createdAt = null,Object? updatedAt = null,Object? slaDue = freezed,Object? customer = freezed,}) {
  return _then(_TicketWithCustomer(
ticketId: null == ticketId ? _self.ticketId : ticketId // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,clientTicketUuid: freezed == clientTicketUuid ? _self.clientTicketUuid : clientTicketUuid // ignore: cast_nullable_to_non_nullable
as String?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,category: freezed == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,priority: null == priority ? _self.priority : priority // ignore: cast_nullable_to_non_nullable
as String,createdBy: null == createdBy ? _self.createdBy : createdBy // ignore: cast_nullable_to_non_nullable
as String,assignedTo: freezed == assignedTo ? _self.assignedTo : assignedTo // ignore: cast_nullable_to_non_nullable
as String?,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,slaDue: freezed == slaDue ? _self.slaDue : slaDue // ignore: cast_nullable_to_non_nullable
as DateTime?,customer: freezed == customer ? _self.customer : customer // ignore: cast_nullable_to_non_nullable
as Customer?,
  ));
}

/// Create a copy of TicketWithCustomer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CustomerCopyWith<$Res>? get customer {
    if (_self.customer == null) {
    return null;
  }

  return $CustomerCopyWith<$Res>(_self.customer!, (value) {
    return _then(_self.copyWith(customer: value));
  });
}
}

// dart format on
