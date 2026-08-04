class ScreenContext {
  final String screenName;
  final String activeField;
  final Map<String, String> fieldValues;

  ScreenContext({
    required this.screenName,
    required this.activeField,
    required this.fieldValues,
  });

  Map<String, dynamic> toJson() => {
    "screen_name": screenName,
    "active_field": activeField,
    "field_values": fieldValues,
  };
}

class AskRequest {
  final ScreenContext context;
  final String question;
  final int ticketId;
  final String? personaPrompt;
  final String? imageBase64;
  final bool autoCoach;

  AskRequest({
    required this.context,
    required this.question,
    required this.ticketId,
    this.personaPrompt,
    this.imageBase64,
    this.autoCoach = false,
  });

  Map<String, dynamic> toJson() => {
    "context": context.toJson(),
    "question": question,
    "ticket_id": ticketId,
    "persona_prompt": personaPrompt,
    "image_base64": imageBase64,
    "auto_coach": autoCoach,
  };
}
