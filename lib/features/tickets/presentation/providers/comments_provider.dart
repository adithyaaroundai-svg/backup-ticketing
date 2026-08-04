import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/entities/comment.dart';
import '../../../tickets/presentation/providers/ticket_provider.dart';

part 'comments_provider.g.dart';

// Stream of comments for a specific ticket
@riverpod
Stream<List<TicketComment>> commentsStream(Ref ref, String ticketId) {
  final repository = ref.watch(ticketRepositoryProvider);
  return repository.getComments(ticketId);
}

// Comment submitter
@riverpod
class CommentSubmitter extends _$CommentSubmitter {
  @override
  bool build() => false;

  Future<bool> submitComment({
    required String ticketId,
    required String author,
    required String body,
    required bool isInternal,
  }) async {
    if (!ref.mounted) return false;

    state = true;
    final repository = ref.read(ticketRepositoryProvider);
    final result = await repository.addComment(
      ticketId: ticketId,
      author: author,
      body: body,
      isInternal: isInternal,
    );

    if (result.isRight() && ref.mounted) {
      ref.invalidate(commentsStreamProvider(ticketId));
    }

    // Update state only if still mounted, but return actual result
    if (ref.mounted) {
      state = false;
    }
    return result.isRight();
  }
}
