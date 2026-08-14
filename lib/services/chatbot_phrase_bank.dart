import '../models/chat_message_model.dart';

/// Small per-language phrase bank the conversation engine uses to phrase
/// its replies (chatbot spec Section 5: auto-detect the user's language
/// and "respond in kind — English, Filipino, or Taglish"), and Section 7
/// (friendly, casual, locally-knowledgeable tour-guide voice).
///
/// This is template-based rather than a translation model — appropriate
/// for a scoped assistant whose factual content always comes from
/// [ChatbotKnowledgeService] (English source data); only the
/// conversational framing around that data is localized here. Full
/// free-form generation in Filipino/Taglish would need a real language
/// model integration, which is out of scope for this offline app.
class ChatbotPhraseBank {
  const ChatbotPhraseBank();

  String scopeDecline(ChatMessageLanguage language) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return 'Pasensya na, pero tungkol lang ako sa Intramuros at sa '
            'app na ito — subukan mong itanong tungkol sa isang lugar, '
            'sa itinerary mo, o kung paano gumagana ang isang feature.';
      case ChatMessageLanguage.taglish:
        return "Sorry, pero I can only help with Intramuros- and "
            "app-related stuff lang talaga — try mo itanong about a "
            "location, your itinerary, or how a feature works.";
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return 'I can only help with things related to Intramuros and '
            'this app — try asking about a location, your itinerary, or '
            'how a feature works.';
    }
  }

  String unknownLocation(ChatMessageLanguage language, String mention) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return "Hindi ko mahanap ang \"$mention\" sa listahan ng mga "
            "lugar namin — pwede mo bang i-check ang spelling o sabihin "
            "ulit?";
      case ChatMessageLanguage.taglish:
        return "Hmm, wala akong makita na \"$mention\" sa places namin — "
            "can you double-check the name or try ulit?";
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return "I couldn't find \"$mention\" in our list of places — "
            "could you check the spelling or try again?";
    }
  }

  String missingDetail(ChatMessageLanguage language) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return "Wala akong specific na detalye tungkol dito sa app — "
            "pero sigurado akong makakatulong ako sa iba pang tanong "
            "mo tungkol sa Intramuros!";
      case ChatMessageLanguage.taglish:
        return "I don't have that specific detail sa app namin — pero "
            "ask mo lang ulit, baka may iba akong info na makakatulong!";
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return "I don't have that specific detail in the app right now "
            "— but feel free to ask me something else about Intramuros!";
    }
  }

  String confirmAction(ChatMessageLanguage language, String actionSummary) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return '$actionSummary Sigurado ka ba? (Oo/Hindi)';
      case ChatMessageLanguage.taglish:
        return '$actionSummary Confirm ka ba? (Yes/No)';
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return '$actionSummary (Yes/No)';
    }
  }

  String actionCancelled(ChatMessageLanguage language) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return 'Ayos, kinansela ko na. May iba pa ba akong matutulong?';
      case ChatMessageLanguage.taglish:
        return "Okay, cancelled na. Anything else I can help with?";
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return "Okay, cancelled. Anything else I can help with?";
    }
  }

  String greeting(ChatMessageLanguage language) {
    switch (language) {
      case ChatMessageLanguage.filipino:
        return 'Kumusta! Ako si IntraBadi, ang local guide mo dito sa '
            'Intramuros. Ano ang gusto mong malaman?';
      case ChatMessageLanguage.taglish:
        return "Hey! I'm IntraBadi, your local guide dito sa Intramuros. "
            "Ano gusto mong alamin?";
      case ChatMessageLanguage.english:
      case ChatMessageLanguage.unknown:
        return "Hey! I'm IntraBadi, your local guide here in Intramuros. "
            "What would you like to know?";
    }
  }
}
