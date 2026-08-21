import 'dart:io';
import 'dart:convert';
import 'package:fyp/services/http_helper/http_helper.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../../views/links/base_url_link/base_url_link.dart';

// M-4 USED IN VOICE TRANSCRIPTION
Future<String?> uploadAudioAndTranscribe(String filePath) async {
  try {
    final cloudName = "";
    final uploadPreset = "";

    final cloudinaryUrl =
        Uri.parse("https://api.cloudinary.com/v1_1/$cloudName/auto/upload");

    var uploadRequest = http.MultipartRequest("POST", cloudinaryUrl)
      ..fields['upload_preset'] = uploadPreset
      ..files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          filename: path.basename(filePath),
        ),
      );

    final uploadResponse = await uploadRequest.send();
    if (uploadResponse.statusCode != 200) {
      print(" Cloudinary upload failed: ${uploadResponse.statusCode}");
      return null;
    }

    final uploadedBody = await uploadResponse.stream.bytesToString();
    final uploadedJson = jsonDecode(uploadedBody);
    final secureUrl = uploadedJson['secure_url'];
    print("Cloudinary URL (original .3gp): $secureUrl");

    final mp3Url = secureUrl.replaceAll(path.extension(secureUrl), '.mp3');
    print("Cloudinary MP3 URL: $mp3Url");

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    final Uri apiUrl = Uri.parse('$base_url/api/Voice/transcribe/send');

    final backendResponse = await HttpHelper.post(
      apiUrl,
      contentType: 'application/json',
      authorization: 'Bearer $token',
      body: jsonEncode({
        "fileUrl": mp3Url,
        "fileName": path
            .basename(filePath)
            .replaceAll(path.extension(filePath), '.mp3'),
      }),
    );

    print('Backend response: ${backendResponse.body}');
    if (backendResponse.statusCode != 200) {
      print('Failed backend call: ${backendResponse.statusCode}');
    }
    final localFile = File(filePath);
    if (await localFile.exists()) {
      await localFile.delete();
      print("Local file deleted: $filePath");
    }

    return mp3Url;
  } catch (e, st) {
    print('Error: $e');
    print(st);

    try {
      final localFile = File(filePath);
      if (await localFile.exists()) await localFile.delete();
    } catch (_) {}

    return null;
  }
}
