import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/design_system/design_system.dart';
import '../website/models/ticket_model.dart';
import '../website/services/ticket_service.dart';
import 'ticket_context_tracker.dart';

import 'api_service.dart';
import 'models.dart';

class CopilotWidget extends StatefulWidget {
  final ApiService apiService;
  final String? initialPrompt;
  final VoidCallback? onClose;
  final String? focusedTicketId;

  const CopilotWidget({
    super.key,
    required this.apiService,
    this.initialPrompt,
    this.onClose,
    this.focusedTicketId,
  });

  @override
  State<CopilotWidget> createState() => _CopilotWidgetState();
}

const _kTarsPersonaPrompt = '''
You are TARS, an AI support assistant for a Tally customer ticketing portal.

CORE RULES (APPLY IN ALL MODES):
1. Respond ONLY based on confidence in Tally knowledge.
2. If the issue is outside your reliable knowledge, DO NOT guess.
3. If you are unsure, politely stop troubleshooting and request human support.
4. Never reuse generic invoice / record / report flows unless the issue clearly matches.
5. Every response must be specific to the issue described.
6. You must always decide the issue category internally before responding; if it is not category A or your confidence is below 70%, escalate instead of troubleshooting.
7. Lead with solutions. Ask clarification ONLY when the issue text is genuinely ambiguous.
8. Never prepend unnecessary sections—keep every reply concise, actionable, and tailored to the detected issue.
9. You must never send partial, streamed, or unfinished responses. Compose the entire reply first, ensure every sentence and bullet is complete, and only then send it as a single message. If you cannot finish confidently, escalate instead of replying.

────────────────────────────────

ISSUE CLASSIFICATION (MANDATORY FIRST STEP):

Before giving solutions, classify the issue into ONE of the following:

A) KNOWN TALLY FUNCTIONAL ISSUE
   (Examples: invoice not generating, GST mismatch, stock not reducing, report mismatch)

B) SYSTEM / ENVIRONMENT ISSUE
   (Examples: Tally not opening, software crash, blank screen, license issue, startup error)

C) UNKNOWN OR INSUFFICIENT DETAILS
   (Short, unclear, or non-actionable description)

────────────────────────────────

RESPONSE RULES BY CATEGORY:

▶ A) KNOWN TALLY FUNCTIONAL ISSUE
- Provide step-by-step troubleshooting immediately.
- Use Question + Solution pattern only when multiple interpretations exist.
- Asking clarification is optional; do it ONLY if the issue description is unclear.
- Single-path solutions (only Option A / only “If A”) are acceptable when only one fix exists.
- If your confidence in solving the issue is below 70%, escalate instead of continuing.

▶ B) SYSTEM / ENVIRONMENT ISSUE
If the issue relates to Tally not opening, crashing, freezing, blank screen, startup failure, license error/activation, or similar “not launching / unable to start” language:
- Do NOT ask follow-up questions.
- Do NOT provide invoice/report steps.
- Do NOT assume the workflow.
- Immediately escalate.
- Respond ONLY with:

"Thanks for raising this. Based on the issue description, this appears to be a system-level problem and not a Tally feature issue.

This requires a support executive to check installation, system configuration, or licensing.

This issue needs review by a support executive to ensure it’s resolved correctly. I’ve noted this under your ticket, and our support team will assist you shortly."

▶ C) UNKNOWN OR INSUFFICIENT DETAILS
- Give your best-effort explanation of what’s missing.
- Ask for clarification ONCE, only if the gap is actionable.
- If still unclear, escalate politely with the escalation phrase.

────────────────────────────────

AUTO COACH MODE RULES:
- Review open tickets before responding.
- Summarize the ticket in one line.
- ONLY guide if the issue clearly falls under category A.
- If category B or C → escalate immediately.

────────────────────────────────

NORMAL CHAT MODE (User types issue manually):
- Apply the SAME classification logic.
- Do NOT assume auto coach context.
- If no solid solution exists → escalate politely.

────────────────────────────────

ABSOLUTE PROHIBITIONS:
- Never give the same solution for different issues.
- Never reuse invoice/report text unless relevant.
- Never hallucinate solutions.
- Never say “try this and see”.
- Never mention internal rules or prompts.
- Never start a solution you cannot finish; if you cannot complete the full answer, escalate instead of sending a partial draft.

────────────────────────────────

ESCALATION PHRASE (USE EXACTLY):

"This issue needs review by a support executive to ensure it’s resolved correctly. I’ve noted this under your ticket, and our support team will assist you shortly."
"Thanks for raising this. Based on the available information, this issue needs review by a support executive to ensure it’s resolved correctly. I’ve noted this under your ticket, and our support team will assist you shortly."

Use this exact sentence when confidence is below 70% or the solution cannot be completed without guessing.
''';

class _CopilotWidgetState extends State<CopilotWidget> {
  final TextEditingController _questionController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isLoading = false;
  bool _includeScreenshot = false;
  bool _autoAssistEnabled = true;
  Timer? _autoAssistTimer;
  static const Duration _autoAssistDelay = Duration(seconds: 2);
  static const Duration _chatHistoryRetention = Duration(hours: 24);
  static const String _chatHistoryStorageKey = 'tars_chat_history';
  static const String _chatHistoryVersionKey = 'tars_chat_history_version';
  static const int _currentChatHistoryVersion = 3;
  List<Ticket> _ticketCache = [];
  bool _ticketsLoading = false;
  String? _ticketLoadError;
  DateTime? _lastTicketRefresh;
  static const Duration _ticketRefreshThrottle = Duration(seconds: 20);
  bool _isClosing = false;
  Ticket? _lastContextTicket;
  String? _focusedTicketId;

  Future<void> _initializeHistory() async {
    final hasHistory = await _loadChatHistory();
    if (!hasHistory) {
      _setWelcomeMessage();
    }
    if (widget.initialPrompt != null &&
        widget.initialPrompt!.trim().isNotEmpty &&
        !hasHistory) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _askQuestion(overrideQuestion: widget.initialPrompt);
      });
    }
    _scheduleAutoAssist();
    _loadTicketContext();
  }

  Future<bool> _loadChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_chatHistoryStorageKey);
      final storedVersion = prefs.getInt(_chatHistoryVersionKey) ?? 0;
      if (storedVersion != _currentChatHistoryVersion) {
        await prefs.remove(_chatHistoryStorageKey);
        await prefs.setInt(_chatHistoryVersionKey, _currentChatHistoryVersion);
        return false;
      }
      if (stored == null || stored.isEmpty) return false;
      final decoded = jsonDecode(stored);
      if (decoded is! List) return false;
      final cutoff = DateTime.now().subtract(_chatHistoryRetention);
      final restored = decoded
          .map((entry) {
            if (entry is Map<String, dynamic>) {
              return ChatMessage.fromJson(entry);
            }
            return null;
          })
          .whereType<ChatMessage>()
          .where((msg) => msg.timestamp.isAfter(cutoff))
          .toList();
      if (restored.isEmpty) {
        await prefs.remove(_chatHistoryStorageKey);
        return false;
      }
      if (!mounted) return true;
      setState(() {
        _messages
          ..clear()
          ..addAll(restored);
      });
      _persistChatHistory();
      return true;
    } catch (_) {
      return false;
    }
  }

  void _setWelcomeMessage() {
    final welcome = _systemWelcomeMessage();
    if (!mounted) return;
    setState(() {
      _messages
        ..clear()
        ..add(welcome);
      _isLoading = false;
    });
    _persistChatHistory();
    _scrollToBottom();
  }

  ChatMessage _systemWelcomeMessage() {
    return ChatMessage(
      text:
          "👋 I’m TARS, here to sort out any Tally trouble you run into. Tell me what’s not working and I’ll walk you through practical checks. If I need a detail or two, I’ll ask politely so we can fix it together.",
      isUser: false,
      isSystem: true,
    );
  }

  Future<void> _persistChatHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_messages.isEmpty) {
        await prefs.remove(_chatHistoryStorageKey);
        await prefs.remove(_chatHistoryVersionKey);
      } else {
        final payload = jsonEncode(
          _messages.map((message) => message.toJson()).toList(),
        );
        await prefs.setString(_chatHistoryStorageKey, payload);
        await prefs.setInt(_chatHistoryVersionKey, _currentChatHistoryVersion);
      }
    } catch (_) {
      // Ignore persistence errors; chat should still work.
    }
  }

  @override
  void initState() {
    super.initState();
    _focusedTicketId =
        widget.focusedTicketId ?? TicketContextTracker.activeTicketId;
    TicketContextTracker.activeTicketIdListenable.addListener(
      _handleActiveTicketChange,
    );
    _initializeHistory();
  }

  @override
  void dispose() {
    _questionController.dispose();
    _scrollController.dispose();
    _cancelAutoAssist();
    TicketContextTracker.activeTicketIdListenable.removeListener(
      _handleActiveTicketChange,
    );
    super.dispose();
  }

  void _handleActiveTicketChange() {
    final nextId = TicketContextTracker.activeTicketId;
    if (nextId == _focusedTicketId) return;
    setState(() {
      _focusedTicketId = nextId;
    });
    _refreshTicketContext(force: true);
  }

  void _handleClose() {
    if (_isClosing) return;
    _isClosing = true;
    _cancelAutoAssist();
    widget.onClose?.call();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _newChat() {
    _cancelAutoAssist();
    _questionController.clear();
    _setWelcomeMessage();
    _loadTicketContext();
  }

  void _cancelAutoAssist() {
    _autoAssistTimer?.cancel();
    _autoAssistTimer = null;
  }

  void _toggleAutoAssist() {
    setState(() {
      _autoAssistEnabled = !_autoAssistEnabled;
    });
    _autoAssistEnabled ? _scheduleAutoAssist() : _cancelAutoAssist();
  }

  void _scheduleAutoAssist() {
    if (!_autoAssistEnabled) return;
    _autoAssistTimer?.cancel();
    _autoAssistTimer = Timer(_autoAssistDelay, _sendAutoAssistPrompt);
  }

  Future<void> _sendAutoAssistPrompt() async {
    if (!_autoAssistEnabled || _isLoading) return;
    await _refreshTicketContext(force: true);
    final primaryTicket = _selectPrimaryTicket(forAutoCoach: true);
    final issueText = primaryTicket != null
        ? _ticketIssueText(primaryTicket).trim()
        : '';
    final prompt = issueText.isNotEmpty
        ? 'Customer issue: $issueText'
        : _buildAutoCoachInstruction();
    await _askQuestion(overrideQuestion: prompt, isAutoAssist: true);
  }

  Future<void> _askQuestion({
    String? overrideQuestion,
    bool isAutoAssist = false,
  }) async {
    if (!isAutoAssist) {
      await _refreshTicketContext();
    }
    final manualQuestion = _questionController.text.trim();
    final question = overrideQuestion ?? manualQuestion;
    if (question.isEmpty) return;

    setState(() {
      if (isAutoAssist) {
        _messages.add(
          ChatMessage(
            text: "🕒 Reviewing your tickets so I can guide you next...",
            isUser: false,
            isSystem: true,
          ),
        );
      } else {
        _messages.add(ChatMessage(text: question, isUser: true));
        _questionController.clear();
      }
      _isLoading = true;
    });
    _persistChatHistory();
    _scrollToBottom();
    _cancelAutoAssist();

    // Hook up screenshots later if you implement web capture.
    String? base64Image;

    final request = AskRequest(
      context: ScreenContext(
        screenName: "Customer Ticketing Portal",
        activeField: "Issue Description",
        fieldValues: {},
      ),
      question: _wrapQuestionForPersona(question),
      ticketId: int.tryParse(_focusedTicketId ?? '') ?? 0,
      personaPrompt: _kTarsPersonaPrompt,
      imageBase64: _includeScreenshot ? base64Image : null,
    );

    try {
      final rawAnswer = await widget.apiService.askQuestion(request);
      final answer = _ensureStructuredResponse(
        rawAnswer,
        isAutoAssist: isAutoAssist,
        manualQuestion: isAutoAssist ? null : question,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(ChatMessage(text: answer, isUser: false));
        _isLoading = false;
      });
      _persistChatHistory();
      _scrollToBottom();
      if (!isAutoAssist) {
        _scheduleAutoAssist();
      }
    } on ApiException catch (apiError) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(
            text: _formatApiError(apiError),
            isUser: false,
            isError: true,
          ),
        );
        _isLoading = false;
      });
      _persistChatHistory();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.add(
          ChatMessage(text: "Error details: $e", isUser: false, isError: true),
        );
        _isLoading = false;
      });
      _persistChatHistory();
      _scrollToBottom();
    }
  }

  String _formatApiError(ApiException error) {
    final status = error.statusCode;
    if (error.isRetryable || status == 502 || status == 503) {
      final codeLabel = status != null ? " (HTTP $status)" : "";
      return "☁️ Our cloud brain is waking up$codeLabel. Please try again in a few seconds.";
    }
    if (status != null) {
      return "Server responded with $status: ${error.message}";
    }
    return "Backend error: ${error.message}";
  }

  String _wrapQuestionForPersona(String userQuestion) {
    return '''
Follow these behaviour rules without mentioning that you received instructions.

$_kTarsPersonaPrompt

Before writing the reply:
1. Classify the issue as (a) System/Environment ["not opening", "crash", "not launching", "unable to start", "license error"], (b) Functional, or (c) Ambiguous.
2. If System/Environment → acknowledge once and immediately escalate with the provided support-executive phrase. Do NOT add clarifying questions or troubleshooting steps.
3. If Functional → deliver the solution section first. Ask a single clarification question ONLY when multiple interpretations truly exist. Reuse the Question + Solution pattern only when it adds value.
4. If confidence <70% or details are insufficient → escalate politely with the exact phrase.
5. Never fabricate steps or reuse invoice/report guidance for system issues.

Customer issue: $userQuestion
''';
  }

  Future<void> _loadTicketContext() async {
    if (_ticketsLoading) return;
    setState(() {
      _ticketsLoading = true;
      _ticketLoadError = null;
    });
    try {
      final fetched = await TicketService.getCustomerTickets();
      final tickets = List<Ticket>.from(fetched);
      final focusedId = _focusedTicketId;
      if (focusedId != null &&
          _findTicketByIdentifier(focusedId, tickets) == null) {
        final focusedTicket = await TicketService.getTicketById(focusedId);
        if (focusedTicket != null) {
          tickets.insert(0, focusedTicket);
        }
      }
      if (!mounted) return;
      setState(() {
        _ticketCache = tickets;
        _lastTicketRefresh = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _ticketLoadError = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _ticketsLoading = false;
        });
      }
    }
  }

  Future<void> _refreshTicketContext({bool force = false}) async {
    final needsRefresh =
        force ||
        _ticketCache.isEmpty ||
        _lastTicketRefresh == null ||
        DateTime.now().difference(_lastTicketRefresh!) > _ticketRefreshThrottle;
    if (!needsRefresh) return;
    await _loadTicketContext();
  }

  String _buildAutoCoachInstruction() {
    final primary = _selectPrimaryTicket(forAutoCoach: true);
    final actionable = _actionableTickets();
    final buffer = StringBuffer()
      ..writeln(
        'Auto coach mode is enabled. Compose the next assistant reply for the customer-facing chat. '
        'Initiate the conversation proactively and always attempt to deliver solutions in the very first response.',
      )
      ..writeln(
        '\nCLASSIFICATION & CONFIDENCE CHECKLIST (MANDATORY BEFORE YOU RESPOND):\n'
        '- Identify whether the ticket describes a System/Environment issue (keywords: not opening, crash, not launching, unable to start, license error, blank screen) or a Functional issue.\n'
        '- If it is a System/Environment issue → acknowledge once and respond ONLY with the escalation message. Do NOT ask questions or provide troubleshooting steps.\n'
        '- If it is a Functional issue and you are ≥70% confident → lead with solutions immediately. '
        'Only ask a single clarifying question when the description is genuinely ambiguous or multiple interpretations exist.\n'
        '- If details are insufficient or confidence <70% → escalate politely using the required phrase. Never invent steps.',
      )
      ..writeln(
        '\nRESPONSE STYLE:\n'
        '- Keep responses concise and actionable. Issue acknowledgement should be one sentence, then move straight into clarifications (only if required) and solutions.\n'
        '- Do NOT prepend extra commentary. No greetings or filler text.\n'
        '- Never provide invoice/report flows for system issues and never reuse guidance unless it clearly matches the issue.',
      )
      ..writeln(
        '\nSTRUCTURE WHEN PROVIDING TROUBLESHOOTING:\n'
        'Issue Acknowledgement:\n'
        '  - <One sentence confirming understanding of the ticket ID and customer-reported issue>\n'
        'Clarifying Question (include this section ONLY when additional detail is essential):\n'
        '  - A) <Option A you need to clarify>\n'
        '  - B) <Option B you need to clarify>\n'
        'Solutions:\n'
        '  If A):\n'
        '    - Step 1 ...\n'
        '    - Step 2 ...\n'
        '  If B):\n'
        '    - Step 1 ...\n'
        '    - Step 2 ...\n'
        'If only one path exists, provide a single "If A)" block with actionable steps. '
        'When no clarification is required, omit the Clarifying Question section and jump directly from Issue Acknowledgement to Solutions.',
      )
      ..writeln(
        '\nABSOLUTE RULE: after acknowledging the ticket you must either deliver actionable troubleshooting steps or escalate immediately. '
        'Never stop after simply restating the ticket.',
      )
      ..writeln(
        '- Every solution step must be a separate bullet (e.g., "- Step 1:"). Never merge multiple actions into one paragraph.',
      );

    if (_ticketLoadError != null) {
      buffer
        ..writeln('\nTicket data warning: ${_ticketLoadError!}')
        ..writeln(
          'Since ticket data could not be loaded, politely ask which ticket they need help with and still follow the required question + solution format.',
        );
      return buffer.toString();
    }

    _lastContextTicket = primary;

    if (primary != null) {
      buffer
        ..writeln('\nPrimary ticket to reference:')
        ..writeln(_describeTicketForPrompt(primary))
        ..writeln(
          '\nMANDATORY RESPONSE TEMPLATE (follow this structure exactly and keep it concise):\n'
          'Issue Acknowledgement:\n'
          '  - <One sentence confirming understanding of the ticket ID and customer-reported issue>\n'
          'Clarifying Question:\n'
          '  - A) <Option A you need to clarify>\n'
          '  - B) <Option B you need to clarify>\n'
          'Solutions:\n'
          '  If A):\n'
          '    - Step 1 (plain-language action that can be done anywhere, no app navigation)\n'
          '    - Step 2\n'
          '    - Step 3\n'
          '  If B):\n'
          '    - Step 1\n'
          '    - Step 2\n'
          '    - Step 3\n'
          'Guidance: Mention the ticket ID again when helpful, reuse the exact words from the ticket issue/title, and keep tone calm/friendly.\n'
          'If the ticket issue already contains enough detail to skip clarifying questions, instead provide at least three numbered troubleshooting steps followed by a reassurance or escalation statement, '
          'but still label the sections as Issue Acknowledgement / Clarifying Question / Solutions (with the question inviting confirmation of what you just covered).',
        )
        ..writeln(
          '\nQuality Checklist you must satisfy before sending the reply:\n'
          '- Did you summarize the issue in at most two short lines?\n'
          '- Did you include the "Issue Acknowledgement", "Clarifying Question", and "Solutions" sections in this order?\n'
          '- Did you include a question with clearly separated, labeled options (A, B, etc.)?\n'
          '- Did every solution contain individual bullet steps with actionable, non-technical language?\n'
          '- Did you end by inviting the customer to confirm the result or advising that a support executive will follow up if needed?',
        );
      final issueText = _ticketIssueText(primary);
      if (issueText.isNotEmpty) {
        buffer
          ..writeln(
            '\nUse this ticket issue verbatim when crafting the summary and solutions: "$issueText"',
          )
          ..writeln(
            'Make sure at least one solution references the exact wording of the issue.',
          );
        if (_isInvoiceNotGeneratingIssue(issueText)) {
          buffer..writeln(
            '\nKNOWN ISSUE HANDLING:\n'
            '- Recognize this as the "invoice not generating" scenario.\n'
            '- Ask whether they are creating a new invoice (Option A) or printing an existing invoice (Option B).\n'
            '- Provide the full troubleshooting steps for BOTH options immediately (do not wait for the user to reply before listing solutions).',
          );
        }
      }
    } else {
      buffer.writeln(
        '\nNo open or recent tickets were found. Ask which ticket they want to discuss and follow the Question + Solution pattern.',
      );
    }

    if (actionable.length > 1) {
      buffer.writeln('\nOther active tickets you may mention briefly:');
      for (final ticket in actionable.where((t) => t != primary).take(2)) {
        buffer.writeln(_describeTicketForPrompt(ticket));
      }
    }

    buffer
      ..writeln(
        '\nIf the customer indicates the issue needs more help, reassure them that a support executive is on the way and the ticket is already logged.',
      )
      ..writeln('Return only the assistant reply (no meta commentary).');
    return buffer.toString();
  }

  String _ensureStructuredResponse(
    String answer, {
    required bool isAutoAssist,
    String? manualQuestion,
  }) {
    if (_responseSatisfiesMandatoryStructure(answer)) return answer;
    final fallbackTicket = _lastContextTicket ?? _selectPrimaryTicket();
    return _fallbackStructuredSolution(
      ticket: fallbackTicket,
      userQuestion: manualQuestion,
    );
  }

  bool _responseSatisfiesMandatoryStructure(String answer) {
    final text = answer.trim();
    if (text.isEmpty) return false;
    if (!_responseLooksComplete(text)) return false;

    final lower = text.toLowerCase();
    if (lower.contains('support executive')) return true;

    final hasIfA = RegExp(r'\bif\s+a\)', caseSensitive: false).hasMatch(text);
    final hasIfB = RegExp(r'\bif\s+b\)', caseSensitive: false).hasMatch(text);
    final hasOptionA = RegExp(r'\bA\)', caseSensitive: false).hasMatch(text);
    final hasOptionB = RegExp(r'\bB\)', caseSensitive: false).hasMatch(text);
    final hasStepBullets = RegExp(
      r'^\s*[-•]\s*(step|check|confirm|ensure|verify|\d+)',
      caseSensitive: false,
      multiLine: true,
    ).hasMatch(text);

    if (hasIfA && !hasIfB) return true;
    if (hasOptionA && hasIfA && !(hasOptionB || hasIfB)) return true;

    final hasBothOptions = (hasOptionA && hasOptionB) || (hasIfA && hasIfB);
    if (hasBothOptions) {
      if (hasIfA && hasIfB && hasStepBullets) return true;
      return false;
    }

    final wordCount = text
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .length;
    final hasQuestionMark = text.contains('?');
    if (wordCount >= 8 &&
        (hasStepBullets || hasQuestionMark || text.length >= 80)) {
      return true;
    }

    return false;
  }

  bool _responseLooksComplete(String text) {
    final trimmed = text.trimRight();
    if (trimmed.endsWith(':') ||
        trimmed.endsWith('...') ||
        trimmed.endsWith('..')) {
      return false;
    }

    final lines = trimmed
        .split('\n')
        .map((line) => line.trimRight())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return false;

    for (final line in lines) {
      if (RegExp(r'^\s*(?:[-•]|\d+\.)\s*$').hasMatch(line)) {
        return false;
      }
    }

    final lastLine = lines.last.trim();
    final endsWithSentence = RegExp(r'[.!?]$').hasMatch(lastLine);
    final endsWithCompleteBullet = RegExp(
      r'^(?:[-•]|\d+\.)\s+\S.+',
    ).hasMatch(lastLine);
    if (!endsWithSentence && !endsWithCompleteBullet) {
      return false;
    }

    if (!_hasBalancedToken(trimmed, '**') ||
        !_hasBalancedToken(trimmed, '__') ||
        !_hasBalancedToken(trimmed, '_') ||
        !_hasBalancedToken(trimmed, '`')) {
      return false;
    }

    final unfinishedMarkdown = RegExp(r'(?:^|\n)#{1,6}\s*$').hasMatch(trimmed);
    if (unfinishedMarkdown) return false;

    return true;
  }

  bool _hasBalancedToken(String text, String token) {
    final escaped = RegExp.escape(token);
    final matches = RegExp(escaped).allMatches(text).length;
    return matches % 2 == 0;
  }

  String _fallbackStructuredSolution({Ticket? ticket, String? userQuestion}) {
    final issueSource = _ticketIssueText(ticket).trim();
    final manualIssue = userQuestion?.trim();
    final resolvedIssue = manualIssue?.isNotEmpty == true
        ? manualIssue!
        : issueSource;
    final ticketLabel = ticket?.ticketNumber != null
        ? 'Ticket ${ticket!.ticketNumber}'
        : 'Your report';
    final isInvoiceIssue = _isInvoiceNotGeneratingIssue(resolvedIssue);
    final questionBlock = StringBuffer()
      ..writeln('Are you trying to:\n')
      ..writeln(
        isInvoiceIssue
            ? 'A) Create a new sales invoice\nB) Print an existing invoice'
            : 'A) Entering or saving the record\nB) Reviewing or sharing an existing record',
      );

    final buffer = StringBuffer()
      ..writeln('$ticketLabel indicates "$resolvedIssue". Let me guide you.')
      ..writeln()
      ..write(questionBlock.toString())
      ..writeln()
      ..writeln(
        isInvoiceIssue
            ? _invoiceNotGeneratingSolutionBlock()
            : _genericSolutionBlock(),
      )
      ..writeln(
        'Tell me if it is option A or B (or something else), and share what happens after these steps so I can keep troubleshooting or escalate if needed.',
      );

    return buffer.toString();
  }

  List<Ticket> _actionableTickets() {
    final tickets = List<Ticket>.from(_ticketCache);
    tickets.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return tickets;
  }

  Ticket? _selectPrimaryTicket({bool forAutoCoach = false}) {
    final focused = _focusedTicketFromCache();
    if (focused != null) {
      return focused;
    }

    final actionable = _ticketCache.where(_isTicketActionable).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (forAutoCoach) {
      if (actionable.isNotEmpty) return actionable.first;
      return null;
    }

    if (actionable.isNotEmpty) return actionable.first;

    final fallback = List<Ticket>.from(_ticketCache)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return fallback.isNotEmpty ? fallback.first : null;
  }

  bool _isTicketActionable(Ticket ticket) {
    return ticket.status == TicketStatus.ticketNew ||
        ticket.status == TicketStatus.open ||
        ticket.status == TicketStatus.inProgress ||
        ticket.status == TicketStatus.waitingForCustomer ||
        ticket.status == TicketStatus.reopened;
  }

  String _describeTicketForPrompt(Ticket ticket) {
    final buffer = StringBuffer()
      ..writeln('- Ticket ID: ${ticket.ticketNumber}')
      ..writeln('- Issue: ${_ticketIssueText(ticket)}')
      ..writeln('- Category: ${ticket.category ?? 'General'}')
      ..writeln('- Status: ${ticket.status.displayName}');
    final issue = _ticketIssueText(ticket);
    if (issue.isNotEmpty) {
      final trimmed = issue.length > 280
          ? '${issue.substring(0, 277)}…'
          : issue;
      buffer.writeln('- Ticket issue: $trimmed');
    }
    return buffer.toString();
  }

  String _ticketIssueText(Ticket? ticket) {
    if (ticket == null) return 'the issue you reported';
    final title = ticket.title.trim();
    if (title.isNotEmpty) return title;
    final desc = ticket.description?.trim() ?? '';
    return desc.isNotEmpty ? desc : 'the issue you reported';
  }

  bool _isInvoiceNotGeneratingIssue(String issue) {
    final normalized = issue.toLowerCase();
    if (!normalized.contains('invoice')) return false;
    return normalized.contains('not generating') ||
        normalized.contains('not getting generated') ||
        normalized.contains('not generated') ||
        normalized.contains('unable to generate') ||
        normalized.contains('failed to generate');
  }

  String _invoiceNotGeneratingSolutionBlock() {
    return '''
  If A):
    - Step 1: Ensure Sales/Invoicing is enabled in the company features and that your user role has permission to create invoices.
    - Step 2: Confirm the customer/ledger is active and not blocked or archived.
    - Step 3: Double-check items, quantity, rate, tax, and mandatory fields; re-enter any blank or highlighted rows.
    - Step 4: Verify the invoice numbering series still has available numbers and isn’t set to “manual” unexpectedly.
    - Step 5: Save again after these checks and note any exact error text if it still fails.
  If B):
    - Step 1: Confirm the invoice was saved successfully and appears in the invoice list with the latest timestamp.
    - Step 2: Open the invoice details and ensure all totals look correct before printing.
    - Step 3: Check that the selected print profile/configuration is enabled; switch to the default profile if unsure.
    - Step 4: Try exporting to PDF first; if the PDF works but print doesn’t, the issue is in the print driver—reconfigure or reinstall it.
    - Step 5: If both PDF and print fail, grab a screenshot or the exact error text so I can escalate immediately.''';
  }

  String _genericSolutionBlock() {
    return '''
If A):
  - Step 1: Confirm every required detail (date, party, amount, ledger/items) is filled in and valid.
  - Step 2: Re-check whether any ledger, stock item, or field is blocked or marked inactive and re-enable it if needed.
  - Step 3: Save again slowly and note any exact wording if it still fails so I can escalate.

If B):
  - Step 1: Open the latest saved copy and verify the figures look correct before sharing.
  - Step 2: Export or preview the document to confirm it renders; switch to PDF if another format fails.
  - Step 3: Refresh or re-sync the data to avoid cached results, then capture any error text so I can raise it further.''';
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Material(
        color: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 620),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [_buildHeader(), _buildChatArea(), _buildInputArea()],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "TARS",
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: Colors.grey.shade900,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.add_circle_outline,
                  size: 18,
                  color: AppColors.primary,
                ),
                onPressed: _newChat,
                tooltip: "New Chat",
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: Icon(
                  _autoAssistEnabled
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  size: 20,
                  color: _autoAssistEnabled
                      ? AppColors.primary
                      : Colors.orangeAccent,
                ),
                tooltip: _autoAssistEnabled
                    ? "Pause auto coach"
                    : "Resume auto coach",
                onPressed: _toggleAutoAssist,
              ),
              const SizedBox(width: 8),
              _buildAutoCoachStatusChip(),
              const SizedBox(width: 10),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                color: Colors.grey,
                splashRadius: 20,
                tooltip: "Close chat",
                onPressed: _handleClose,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Ticket? _focusedTicketFromCache() {
    final focusId = _focusedTicketId;
    if (focusId == null) return null;
    return _findTicketByIdentifier(focusId, _ticketCache);
  }

  Ticket? _findTicketByIdentifier(String identifier, Iterable<Ticket> source) {
    for (final ticket in source) {
      if (_matchesTicketIdentifier(ticket, identifier)) {
        return ticket;
      }
    }
    return null;
  }

  bool _matchesTicketIdentifier(Ticket ticket, String identifier) {
    final normalized = identifier.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    bool matches(String? value) =>
        value != null && value.trim().toLowerCase() == normalized;
    return matches(ticket.id) ||
        matches(ticket.clientTicketUuid) ||
        matches(ticket.ticketNumber);
  }

  Widget _buildAutoCoachStatusChip() {
    final bool isEnabled = _autoAssistEnabled;
    final Color accent = isEnabled ? AppColors.primary : Colors.orangeAccent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isEnabled ? Icons.bolt : Icons.pause, color: accent, size: 14),
          const SizedBox(width: 6),
          Text(
            isEnabled ? "Auto coach on" : "Auto coach paused",
            style: GoogleFonts.inter(
              color: accent,
              fontSize: 11,
              letterSpacing: 0.2,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatArea() {
    return Expanded(
      child: Container(
        color: const Color(0xFFF5F5F5),
        child: ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          itemCount: _messages.length + (_isLoading ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _messages.length) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TypingIndicator(),
                ),
              );
            }
            final msg = _messages[index];
            return ChatBubble(message: msg);
          },
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _includeScreenshot ? Icons.visibility : Icons.visibility_off,
              color: _includeScreenshot ? AppColors.primary : Colors.grey,
              size: 20,
            ),
            onPressed: () {
              setState(() => _includeScreenshot = !_includeScreenshot);
            },
            tooltip: "Toggle screenshot attachment",
          ),
          const SizedBox(width: 6),
          Expanded(
            child: TextField(
              controller: _questionController,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: Colors.white,
                hintText: "Describe your Tally issue...",
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onSubmitted: (_) => _askQuestion(),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _askQuestion,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_upward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isError;
  final bool isSystem;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
    this.isSystem = false,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'isError': isError,
    'isSystem': isSystem,
    'timestamp': timestamp.toIso8601String(),
  };

  static ChatMessage? fromJson(Map<String, dynamic> data) {
    final rawTimestamp = data['timestamp'] as String?;
    return ChatMessage(
      text: data['text']?.toString() ?? '',
      isUser: data['isUser'] == true,
      isError: data['isError'] == true,
      isSystem: data['isSystem'] == true,
      timestamp: DateTime.tryParse(rawTimestamp ?? '') ?? DateTime.now(),
    );
  }
}

class ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const ChatBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser
          ? Alignment.centerRight
          : message.isSystem
          ? Alignment.center
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.85,
        ),
        decoration: BoxDecoration(
          color: message.isUser
              ? const Color(0xFFDCE6FF)
              : message.isSystem
              ? Colors.grey.shade300
              : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: message.isUser
                ? const Radius.circular(12)
                : const Radius.circular(2),
            bottomRight: message.isUser
                ? const Radius.circular(2)
                : const Radius.circular(12),
          ),
        ),
        child: MarkdownBody(
          data: message.text,
          styleSheet: MarkdownStyleSheet(
            p: GoogleFonts.inter(
              color: message.isError ? Colors.redAccent : Colors.grey.shade900,
              fontSize: 13,
              height: 1.4,
            ),
            strong: GoogleFonts.inter(
              color: message.isUser ? AppColors.primary : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class TypingIndicator extends StatefulWidget {
  const TypingIndicator({super.key});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: const BorderRadius.all(Radius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          return AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final sineValue = math.sin(
                (_controller.value * 2 * math.pi) + (index * math.pi / 2),
              );
              return Opacity(
                opacity: 0.5 + (0.5 * (sineValue + 1) / 2),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
