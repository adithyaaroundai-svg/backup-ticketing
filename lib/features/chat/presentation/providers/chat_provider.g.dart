// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(globalMessageSearch)
const globalMessageSearchProvider = GlobalMessageSearchFamily._();

final class GlobalMessageSearchProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          FutureOr<List<ChatMessage>>
        >
    with
        $FutureModifier<List<ChatMessage>>,
        $FutureProvider<List<ChatMessage>> {
  const GlobalMessageSearchProvider._({
    required GlobalMessageSearchFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'globalMessageSearchProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$globalMessageSearchHash();

  @override
  String toString() {
    return r'globalMessageSearchProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<List<ChatMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<ChatMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return globalMessageSearch(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is GlobalMessageSearchProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$globalMessageSearchHash() =>
    r'0c082f074036c21a8c7b30c00638e25e629b1d00';

final class GlobalMessageSearchFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<List<ChatMessage>>, String> {
  const GlobalMessageSearchFamily._()
    : super(
        retry: null,
        name: r'globalMessageSearchProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  GlobalMessageSearchProvider call(String query) =>
      GlobalMessageSearchProvider._(argument: query, from: this);

  @override
  String toString() => r'globalMessageSearchProvider';
}

@ProviderFor(ChatStream)
const chatStreamProvider = ChatStreamFamily._();

final class ChatStreamProvider
    extends $AsyncNotifierProvider<ChatStream, List<ChatMessage>> {
  const ChatStreamProvider._({
    required ChatStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'chatStreamProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$chatStreamHash();

  @override
  String toString() {
    return r'chatStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatStream create() => ChatStream();

  @override
  bool operator ==(Object other) {
    return other is ChatStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatStreamHash() => r'9a7d91ed9f2ce58de14b58623c1670c6d08263c8';

final class ChatStreamFamily extends $Family
    with
        $ClassFamilyOverride<
          ChatStream,
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          FutureOr<List<ChatMessage>>,
          String
        > {
  const ChatStreamFamily._()
    : super(
        retry: null,
        name: r'chatStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  ChatStreamProvider call(String channel) =>
      ChatStreamProvider._(argument: channel, from: this);

  @override
  String toString() => r'chatStreamProvider';
}

abstract class _$ChatStream extends $AsyncNotifier<List<ChatMessage>> {
  late final _$args = ref.$arg as String;
  String get channel => _$args;

  FutureOr<List<ChatMessage>> build(String channel);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<List<ChatMessage>>, List<ChatMessage>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ChatMessage>>, List<ChatMessage>>,
              AsyncValue<List<ChatMessage>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(DmStream)
const dmStreamProvider = DmStreamFamily._();

final class DmStreamProvider
    extends $AsyncNotifierProvider<DmStream, List<ChatMessage>> {
  const DmStreamProvider._({
    required DmStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'dmStreamProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$dmStreamHash();

  @override
  String toString() {
    return r'dmStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  DmStream create() => DmStream();

  @override
  bool operator ==(Object other) {
    return other is DmStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$dmStreamHash() => r'80771dc2ac27f5df2ee6c391085667bd8850d2fb';

final class DmStreamFamily extends $Family
    with
        $ClassFamilyOverride<
          DmStream,
          AsyncValue<List<ChatMessage>>,
          List<ChatMessage>,
          FutureOr<List<ChatMessage>>,
          String
        > {
  const DmStreamFamily._()
    : super(
        retry: null,
        name: r'dmStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  DmStreamProvider call(String chatPartnerId) =>
      DmStreamProvider._(argument: chatPartnerId, from: this);

  @override
  String toString() => r'dmStreamProvider';
}

abstract class _$DmStream extends $AsyncNotifier<List<ChatMessage>> {
  late final _$args = ref.$arg as String;
  String get chatPartnerId => _$args;

  FutureOr<List<ChatMessage>> build(String chatPartnerId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref =
        this.ref as $Ref<AsyncValue<List<ChatMessage>>, List<ChatMessage>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ChatMessage>>, List<ChatMessage>>,
              AsyncValue<List<ChatMessage>>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ChatLastSeen)
const chatLastSeenProvider = ChatLastSeenProvider._();

final class ChatLastSeenProvider
    extends $AsyncNotifierProvider<ChatLastSeen, DateTime> {
  const ChatLastSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatLastSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatLastSeenHash();

  @$internal
  @override
  ChatLastSeen create() => ChatLastSeen();
}

String _$chatLastSeenHash() => r'1c63767017ff7c355ae15cb32bc788468851fd41';

abstract class _$ChatLastSeen extends $AsyncNotifier<DateTime> {
  FutureOr<DateTime> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<DateTime>, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DateTime>, DateTime>,
              AsyncValue<DateTime>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ChatUnreadCount)
const chatUnreadCountProvider = ChatUnreadCountProvider._();

final class ChatUnreadCountProvider
    extends $NotifierProvider<ChatUnreadCount, int> {
  const ChatUnreadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatUnreadCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatUnreadCountHash();

  @$internal
  @override
  ChatUnreadCount create() => ChatUnreadCount();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$chatUnreadCountHash() => r'1eb3cdfd176de3f53a361d5828d9157bd4f9d629';

abstract class _$ChatUnreadCount extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ChatNewMessageEvent)
const chatNewMessageEventProvider = ChatNewMessageEventProvider._();

final class ChatNewMessageEventProvider
    extends $NotifierProvider<ChatNewMessageEvent, ChatMessage?> {
  const ChatNewMessageEventProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatNewMessageEventProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatNewMessageEventHash();

  @$internal
  @override
  ChatNewMessageEvent create() => ChatNewMessageEvent();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatMessage? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatMessage?>(value),
    );
  }
}

String _$chatNewMessageEventHash() =>
    r'97f1a44b8e12a13737054d1a21ab1963e27a42ec';

abstract class _$ChatNewMessageEvent extends $Notifier<ChatMessage?> {
  ChatMessage? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ChatMessage?, ChatMessage?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatMessage?, ChatMessage?>,
              ChatMessage?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(DmNewMessageEvent)
const dmNewMessageEventProvider = DmNewMessageEventProvider._();

final class DmNewMessageEventProvider
    extends $NotifierProvider<DmNewMessageEvent, ChatMessage?> {
  const DmNewMessageEventProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmNewMessageEventProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmNewMessageEventHash();

  @$internal
  @override
  DmNewMessageEvent create() => DmNewMessageEvent();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatMessage? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatMessage?>(value),
    );
  }
}

String _$dmNewMessageEventHash() => r'6256ed00c328dc3c4b624e4816f679a87682ab7c';

abstract class _$DmNewMessageEvent extends $Notifier<ChatMessage?> {
  ChatMessage? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ChatMessage?, ChatMessage?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatMessage?, ChatMessage?>,
              ChatMessage?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(CustomChannelNewMessageEvent)
const customChannelNewMessageEventProvider =
    CustomChannelNewMessageEventProvider._();

final class CustomChannelNewMessageEventProvider
    extends $NotifierProvider<CustomChannelNewMessageEvent, ChatMessage?> {
  const CustomChannelNewMessageEventProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'customChannelNewMessageEventProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$customChannelNewMessageEventHash();

  @$internal
  @override
  CustomChannelNewMessageEvent create() => CustomChannelNewMessageEvent();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatMessage? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatMessage?>(value),
    );
  }
}

String _$customChannelNewMessageEventHash() =>
    r'327c2bacd7e56d0bf22797abe48a3c2f0f12a547';

abstract class _$CustomChannelNewMessageEvent extends $Notifier<ChatMessage?> {
  ChatMessage? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ChatMessage?, ChatMessage?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatMessage?, ChatMessage?>,
              ChatMessage?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(AllAroundTallyLastSeen)
const allAroundTallyLastSeenProvider = AllAroundTallyLastSeenProvider._();

final class AllAroundTallyLastSeenProvider
    extends $AsyncNotifierProvider<AllAroundTallyLastSeen, DateTime> {
  const AllAroundTallyLastSeenProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allAroundTallyLastSeenProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allAroundTallyLastSeenHash();

  @$internal
  @override
  AllAroundTallyLastSeen create() => AllAroundTallyLastSeen();
}

String _$allAroundTallyLastSeenHash() =>
    r'3486a00ab600ced619f223a4cd06289054d71608';

abstract class _$AllAroundTallyLastSeen extends $AsyncNotifier<DateTime> {
  FutureOr<DateTime> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<DateTime>, DateTime>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<DateTime>, DateTime>,
              AsyncValue<DateTime>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(AllAroundTallyUnreadCount)
const allAroundTallyUnreadCountProvider = AllAroundTallyUnreadCountProvider._();

final class AllAroundTallyUnreadCountProvider
    extends $NotifierProvider<AllAroundTallyUnreadCount, int> {
  const AllAroundTallyUnreadCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allAroundTallyUnreadCountProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allAroundTallyUnreadCountHash();

  @$internal
  @override
  AllAroundTallyUnreadCount create() => AllAroundTallyUnreadCount();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$allAroundTallyUnreadCountHash() =>
    r'3696310228cbfeed1184186d0b3282a56eec1cd6';

abstract class _$AllAroundTallyUnreadCount extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(AllAroundTallyNewMessageEvent)
const allAroundTallyNewMessageEventProvider =
    AllAroundTallyNewMessageEventProvider._();

final class AllAroundTallyNewMessageEventProvider
    extends $NotifierProvider<AllAroundTallyNewMessageEvent, ChatMessage?> {
  const AllAroundTallyNewMessageEventProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allAroundTallyNewMessageEventProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allAroundTallyNewMessageEventHash();

  @$internal
  @override
  AllAroundTallyNewMessageEvent create() => AllAroundTallyNewMessageEvent();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ChatMessage? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ChatMessage?>(value),
    );
  }
}

String _$allAroundTallyNewMessageEventHash() =>
    r'bb61490fa89bf48311ca2e11a5bd9ad430f5e56a';

abstract class _$AllAroundTallyNewMessageEvent extends $Notifier<ChatMessage?> {
  ChatMessage? build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<ChatMessage?, ChatMessage?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ChatMessage?, ChatMessage?>,
              ChatMessage?,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(ChatController)
const chatControllerProvider = ChatControllerProvider._();

final class ChatControllerProvider
    extends $AsyncNotifierProvider<ChatController, void> {
  const ChatControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'chatControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$chatControllerHash();

  @$internal
  @override
  ChatController create() => ChatController();
}

String _$chatControllerHash() => r'9c002aa20b28e20705ec3f4b00922fbbca130295';

abstract class _$ChatController extends $AsyncNotifier<void> {
  FutureOr<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    build();
    final ref = this.ref as $Ref<AsyncValue<void>, void>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, void>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleValue(ref, null);
  }
}
