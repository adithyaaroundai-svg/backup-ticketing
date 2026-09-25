import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/leave_request.dart';
import '../../data/repositories/leave_repository.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

final leaveRepositoryProvider = Provider<LeaveRepository>((ref) {
  return LeaveRepository();
});

/// Stream of all leaves in the company (for HR and Admin)
final allLeavesStreamProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.streamAllLeaves();
});

/// Count of pending leaves waiting for HR approval
final pendingLeavesCountProvider = Provider<int>((ref) {
  final leavesAsync = ref.watch(allLeavesStreamProvider);
  return leavesAsync.maybeWhen(
    data: (leaves) => leaves.where((l) => l.isPending).length,
    orElse: () => 0,
  );
});

/// Stream of leaves for the current logged-in employee
final myLeavesStreamProvider = StreamProvider<List<LeaveRequest>>((ref) {
  final repo = ref.watch(leaveRepositoryProvider);
  final currentUser = ref.watch(authProvider);
  if (currentUser == null) {
    return Stream.value([]);
  }
  return repo.streamAgentLeaves(currentUser.id);
});

/// Stream of leaves for a specific agent (e.g. viewed in UsersPage)
final agentLeavesFamilyProvider =
    StreamProvider.family<List<LeaveRequest>, String>((ref, agentId) {
  final repo = ref.watch(leaveRepositoryProvider);
  return repo.streamAgentLeaves(agentId);
});

class LeaveControllerState {
  final bool isLoading;
  final String? errorMessage;
  final String? successMessage;

  const LeaveControllerState({
    this.isLoading = false,
    this.errorMessage,
    this.successMessage,
  });

  LeaveControllerState copyWith({
    bool? isLoading,
    String? errorMessage,
    String? successMessage,
  }) {
    return LeaveControllerState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      successMessage: successMessage,
    );
  }
}

class LeaveController extends Notifier<LeaveControllerState> {
  @override
  LeaveControllerState build() => const LeaveControllerState();

  Future<bool> applyLeave({
    required String agentId,
    required String agentName,
    required String agentRole,
    required DateTime startDate,
    required DateTime endDate,
    required String leaveType,
    String? reason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.submitLeaveRequest(
        agentId: agentId,
        agentName: agentName,
        agentRole: agentRole,
        startDate: startDate,
        endDate: endDate,
        leaveType: leaveType,
        reason: reason,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request submitted to HR for approval.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to submit leave request: $e',
      );
      return false;
    }
  }

  Future<bool> approveLeave({
    required LeaveRequest leave,
    required Agent hrAgent,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.approveLeaveRequest(
        leaveId: leave.id,
        agentId: leave.agentId,
        hrId: hrAgent.id,
        hrName: hrAgent.fullName,
        dateRangeStr: leave.dateRangeFormatted,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request for ${leave.agentName} approved.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to approve leave: $e',
      );
      return false;
    }
  }

  Future<bool> rejectLeave({
    required LeaveRequest leave,
    required Agent hrAgent,
    String? rejectionReason,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.rejectLeaveRequest(
        leaveId: leave.id,
        agentId: leave.agentId,
        hrId: hrAgent.id,
        hrName: hrAgent.fullName,
        rejectionReason: rejectionReason,
        dateRangeStr: leave.dateRangeFormatted,
      );
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request for ${leave.agentName} rejected.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to reject leave: $e',
      );
      return false;
    }
  }

  Future<bool> cancelLeave(String leaveId) async {
    state = state.copyWith(isLoading: true, errorMessage: null, successMessage: null);
    try {
      final repo = ref.read(leaveRepositoryProvider);
      await repo.cancelLeaveRequest(leaveId);
      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request cancelled.',
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to cancel leave: $e',
      );
      return false;
    }
  }
}

final leaveControllerProvider =
    NotifierProvider<LeaveController, LeaveControllerState>(
  LeaveController.new,
);
