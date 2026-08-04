// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'comments_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(commentsStream)
const commentsStreamProvider = CommentsStreamFamily._();

final class CommentsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<TicketComment>>,
          List<TicketComment>,
          Stream<List<TicketComment>>
        >
    with
        $FutureModifier<List<TicketComment>>,
        $StreamProvider<List<TicketComment>> {
  const CommentsStreamProvider._({
    required CommentsStreamFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'commentsStreamProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$commentsStreamHash();

  @override
  String toString() {
    return r'commentsStreamProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<TicketComment>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<TicketComment>> create(Ref ref) {
    final argument = this.argument as String;
    return commentsStream(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is CommentsStreamProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$commentsStreamHash() => r'ee29d4856fbb8be7e40fb9fa9adf646592ab12f6';

final class CommentsStreamFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<TicketComment>>, String> {
  const CommentsStreamFamily._()
    : super(
        retry: null,
        name: r'commentsStreamProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CommentsStreamProvider call(String ticketId) =>
      CommentsStreamProvider._(argument: ticketId, from: this);

  @override
  String toString() => r'commentsStreamProvider';
}

@ProviderFor(CommentSubmitter)
const commentSubmitterProvider = CommentSubmitterProvider._();

final class CommentSubmitterProvider
    extends $NotifierProvider<CommentSubmitter, bool> {
  const CommentSubmitterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'commentSubmitterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$commentSubmitterHash();

  @$internal
  @override
  CommentSubmitter create() => CommentSubmitter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$commentSubmitterHash() => r'42d13b3576b49fc2bbd69a877ec7c428ca103d3c';

abstract class _$CommentSubmitter extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
