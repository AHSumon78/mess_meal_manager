// lib/services/auth_client.dart
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;

class AuthClient extends http.BaseClient {
  final http.Client _baseClient;
  final Map<String, String> _headers;

  AuthClient(this._baseClient, this._headers);

  static Future<AuthClient> fromGoogleSignInAccount(
    GoogleSignInAccount account,
  ) async {
    final authHeaders = await account.authHeaders;
    return AuthClient(http.Client(), authHeaders);
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _baseClient.send(request);
  }
}
