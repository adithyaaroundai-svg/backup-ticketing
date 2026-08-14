import 'web_eval_stub.dart' if (dart.library.js) 'web_eval_web.dart';

/// Opens a specific user's DM in Zoho Cliq (by ZUID or email).
/// Tries the desktop app protocol first, falls back to web (India DC).
Future<void> launchZohoCliqUser(String zohoUserId) async {
  final desktopUrl = 'zohocliqapp://users/$zohoUserId';
  final webUrl = 'https://cliq.zoho.in/users/$zohoUserId';
  evalJs("""
    (function() {
      var iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = '$desktopUrl';
      document.body.appendChild(iframe);
      setTimeout(function() { document.body.removeChild(iframe); }, 2000);
      setTimeout(function() { window.open('$webUrl', '_blank'); }, 1500);
    })();
  """);
}

/// Opens a specific channel in Zoho Cliq by channel unique name/ID.
Future<void> launchZohoCliqChannel(String channelId) async {
  final desktopUrl = 'zohocliqapp://channels/$channelId';
  final webUrl = 'https://cliq.zoho.in/channels/$channelId';
  evalJs("""
    (function() {
      var iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = '$desktopUrl';
      document.body.appendChild(iframe);
      setTimeout(function() { document.body.removeChild(iframe); }, 2000);
      setTimeout(function() { window.open('$webUrl', '_blank'); }, 1500);
    })();
  """);
}

/// Opens the Zoho Cliq home/dashboard (fallback when no specific target).
Future<void> launchZohoCliqHome() async {
  const desktopUrl = 'zohocliqapp://';
  const webUrl = 'https://cliq.zoho.in/';
  evalJs("""
    (function() {
      var iframe = document.createElement('iframe');
      iframe.style.display = 'none';
      iframe.src = '$desktopUrl';
      document.body.appendChild(iframe);
      setTimeout(function() { document.body.removeChild(iframe); }, 2000);
      setTimeout(function() { window.open('$webUrl', '_blank'); }, 1500);
    })();
  """);
}
