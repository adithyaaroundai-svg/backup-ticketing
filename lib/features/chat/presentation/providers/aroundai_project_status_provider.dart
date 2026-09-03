import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/aroundai_project_status.dart';

class AroundaiProjectStatusState {
  final List<AroundaiProjectStatus> tasks;
  final bool loading;
  final String? error;

  AroundaiProjectStatusState({
    this.tasks = const [],
    this.loading = false,
    this.error,
  });

  AroundaiProjectStatusState copyWith({
    List<AroundaiProjectStatus>? tasks,
    bool? loading,
    String? error,
  }) {
    return AroundaiProjectStatusState(
      tasks: tasks ?? this.tasks,
      loading: loading ?? this.loading,
      error: error ?? this.error,
    );
  }
}

class AroundaiProjectStatusNotifier extends Notifier<AroundaiProjectStatusState> {
  @override
  AroundaiProjectStatusState build() {
    return AroundaiProjectStatusState();
  }

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final response = await Supabase.instance.client
          .from('aroundai_project_status')
          .select()
          .order('id', ascending: false);

      final tasks = (response as List).map((row) => AroundaiProjectStatus.fromJson(row)).toList();
      state = state.copyWith(loading: false, tasks: tasks);
    } catch (e) {
      debugPrint('Error loading AroundAI Project Status: $e');
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> createTask(String taskName, String taskStatus, String? notes, String? currentUserId) async {
    try {
      String? encodedNotes;
      if (notes != null && notes.isNotEmpty) {
        final historyList = [
          {
            'note': notes,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'created_by': currentUserId,
          }
        ];
        encodedNotes = jsonEncode(historyList);
      }

      await Supabase.instance.client.from('aroundai_project_status').insert({
        'task_name': taskName,
        'task_status': taskStatus,
        'notes': encodedNotes,
        'created_by': currentUserId,
      });

      await load();
    } catch (e) {
      debugPrint('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(int id, String taskName, String taskStatus, String? notes, String? oldNotes, String? currentUserId) async {
    try {
      String? encodedNotes = oldNotes;

      // If a new note is provided and it's different from the visual 'latest' note
      if (notes != null && notes.isNotEmpty) {
        List<dynamic> history = [];
        if (oldNotes != null && oldNotes.isNotEmpty) {
          try {
            history = jsonDecode(oldNotes);
          } catch (_) {
            // If it's old plain text data, convert to history item
            history = [
              {
                'note': oldNotes,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'created_by': null,
              }
            ];
          }
        }
        
        // Find the latest note text to see if it changed
        String latestNoteText = '';
        if (history.isNotEmpty) {
          latestNoteText = history.first['note']?.toString() ?? '';
        }

        if (notes != latestNoteText) {
          // Add to beginning of history
          history.insert(0, {
            'note': notes,
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'created_by': currentUserId,
          });
          encodedNotes = jsonEncode(history);
        }
      }

      await Supabase.instance.client.from('aroundai_project_status').update({
        'task_name': taskName,
        'task_status': taskStatus,
        'notes': encodedNotes,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id);

      await load();
    } catch (e) {
      debugPrint('Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(int id) async {
    try {
      await Supabase.instance.client.from('aroundai_project_status').delete().eq('id', id);
      await load();
    } catch (e) {
      debugPrint('Error deleting task: $e');
      rethrow;
    }
  }
}
