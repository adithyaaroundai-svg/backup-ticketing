import 'dart:convert';
import 'package:http/http.dart' as http;
import 'zoho_auth_service.dart';
import 'package:flutter/foundation.dart';

class ZohoApiService {
  static const String baseUrl = 'https://cliq.zoho.in/api/v2';

  /// Creates a new channel in Zoho Cliq.
  /// Returns the `channel_unique_name` (or ID) of the newly created channel.
  static Future<String?> createChannel(String channelId, String title, {List<String>? participants}) async {
    try {
      final token = await ZohoAuthService.getAccessToken();
      
      String urlString = '$baseUrl/channels';
      if (kIsWeb) {
        urlString = 'https://corsproxy.io/?url=${Uri.encodeComponent(urlString)}';
      }
      final url = Uri.parse(urlString);
      
      // Format the channel name to be lowercase and dashed without spaces/special chars
      final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-').toLowerCase();
      String channelNameStr = 'crm-$channelId-$safeTitle';
      final channelName = channelNameStr.length > 30 ? channelNameStr.substring(0, 30) : channelNameStr;

      final Map<String, dynamic> bodyData = {
        'name': channelName,
        'level': 'organization',
        'description': 'Discussion for channel $channelId',
      };

      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyData),
      );

      String? channelUniqueName;
      String? numericChannelId;
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        channelUniqueName = data['unique_name'] ?? data['channel_unique_name'];
        numericChannelId = data['channel_id']?.toString() ?? data['id']?.toString();
      } else {
        final bodyStr = response.body.toLowerCase();
        // Check if the error is because the channel already exists
        if (response.statusCode == 400 && (bodyStr.contains('duplicate') || bodyStr.contains('already exist'))) {
          // Channel already exists, use the name we generated
          channelUniqueName = channelName;
        } else {
          print('Error creating Zoho channel: ${response.body}');
          return null;
        }
      }
        
      // If we have participants to add, do it in a secondary call using numeric ID
      if (numericChannelId != null && participants != null && participants.isNotEmpty) {
        String addMembersUrlString = '$baseUrl/channels/$numericChannelId/members';
          if (kIsWeb) {
            addMembersUrlString = 'https://corsproxy.io/?url=${Uri.encodeComponent(addMembersUrlString)}';
          }
          final addMembersUrl = Uri.parse(addMembersUrlString);
          
          final addResp = await http.post(
            addMembersUrl,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'email_ids': participants,
            }),
          );
          if (addResp.statusCode != 200 && addResp.statusCode != 201) {
             print('Error adding members to Zoho channel via secondary call (POST): ${addResp.body}');
             
             // Fallback to PUT just in case the API endpoint uses PUT
             final putResp = await http.put(
               addMembersUrl,
               headers: {
                 'Authorization': 'Bearer $token',
                 'Content-Type': 'application/json',
               },
               body: jsonEncode({
                 'email_ids': participants,
               }),
             );
             
             if (putResp.statusCode != 200 && putResp.statusCode != 201) {
               print('Error adding members to Zoho channel via secondary call (PUT): ${putResp.body}');
             }
          }
        }
        
        return channelUniqueName;
    } catch (e) {
      print('Exception creating Zoho channel: $e');
      return null;
    }
  }

  /// Syncs Zoho Cliq call history (MediaSessions) with the local database.
  static Future<List<Map<String, dynamic>>> fetchCallHistory() async {
    try {
      final token = await ZohoAuthService.getAccessToken();
      
      String urlString = '$baseUrl/mediasessions';
      if (kIsWeb) {
        urlString = 'https://corsproxy.io/?url=${Uri.encodeComponent(urlString)}';
      }
      final url = Uri.parse(urlString);
      
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['sessions'] != null) {
          return List<Map<String, dynamic>>.from(data['sessions']);
        }
        return [];
      } else {
        print('Error fetching Zoho call history: ${response.body}');
        return [];
      }
    } catch (e) {
      print('Exception fetching Zoho call history: $e');
      return [];
    }
  }
}
