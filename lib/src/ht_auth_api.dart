import 'dart:async';

import 'package:ht_auth_client/ht_auth_client.dart';
import 'package:ht_http_client/ht_http_client.dart';
import 'package:ht_shared/ht_shared.dart';

/// {@template ht_auth_api}
/// An API implementation of the [HtAuthClient] interface.
///
/// This class uses an injected [HtHttpClient] to communicate with a backend
/// authentication service, providing methods for email+code sign-in,
/// anonymous sign-in, sign-out, and retrieving the current user status.
///
/// It manages the authentication state via the [authStateChanges] stream.
///
/// All methods adhere to the standardized exception handling defined in
/// `package:ht_shared/exceptions.dart`, propagating exceptions received
/// from the underlying [HtHttpClient].
/// {@endtemplate}
class HtAuthApi implements HtAuthClient {
  /// {@macro ht_auth_api}
  ///
  /// Requires an instance of [HtHttpClient] configured with the base URL
  /// of the API and a token provider.
  HtAuthApi({required HtHttpClient httpClient}) : _httpClient = httpClient {
    // Initialize with current user status check
    _initializeAuthStatus();
  }

  final HtHttpClient _httpClient;

  // Stream controller to manage and broadcast authentication state changes.
  // Using broadcast allows multiple listeners.
  final _authStateController = StreamController<User?>.broadcast();

  // Internal flag to prevent multiple initializations
  bool _isInitialized = false;

  // Helper method to check initial auth status without exposing it publicly
  // beyond the stream.
  Future<void> _initializeAuthStatus() async {
    if (_isInitialized) return;
    _isInitialized = true;
    try {
      // Attempt to get the current user on startup.
      // This might fail if the user isn't logged in (e.g., 401),
      // which is expected.
      final user = await getCurrentUser();
      _authStateController.add(user);
    } on HtHttpException catch (_) {
      // If fetching the current user fails (e.g., 401 Unauthorized),
      // it means no user is currently logged in. Emit null.
      _authStateController.add(null);
    } on Object catch (_) {
      // Catch any other unexpected error during initialization
      // and assume no user is logged in. Consider logging this error.
      _authStateController.add(null);
    }
  }

  /// Base path for authentication endpoints (proposed).
  static const String _authBasePath = '/api/v1/auth';

  @override
  Stream<User?> get authStateChanges => _authStateController.stream;

  @override
  Future<User?> getCurrentUser() async {
    try {
      final response = await _httpClient.get<Map<String, dynamic>>(
        '$_authBasePath/me',
      );
      final apiResponse = SuccessApiResponse<User>.fromJson(
        response,
        (json) => User.fromJson(json! as Map<String, dynamic>),
      );
      // Update stream only if the state differs from the last emitted value
      // (Requires tracking the last emitted value, omitted for simplicity here,
      // or rely on stream distinctness if applicable).
      // For now, always add, letting listeners handle distinctness.
      _authStateController.add(apiResponse.data);
      return apiResponse.data;
    } on HtHttpException catch (e) {
      // If it's an UnauthorizedException, it means no user is logged in.
      // Emit null and return null.
      if (e is UnauthorizedException) {
        _authStateController.add(null);
        return null;
      }
      // Otherwise, rethrow the standardized exception.
      rethrow;
    }
  }

  @override
  Future<void> requestSignInCode(String email) async {
    try {
      await _httpClient.post<void>(
        '$_authBasePath/request-code',
        data: {'email': email},
      );
      // No user state change here, just request sent.
    } on HtHttpException {
      // Rethrow standardized exceptions (e.g., InvalidInputException,
      // ServerException, NetworkException).
      rethrow;
    }
  }

  @override
  Future<AuthSuccessResponse> verifySignInCode(
    String email,
    String code,
  ) async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_authBasePath/verify-code',
        data: {'email': email, 'code': code},
      );
      final apiResponse = SuccessApiResponse<AuthSuccessResponse>.fromJson(
        response,
        (json) => AuthSuccessResponse.fromJson(json! as Map<String, dynamic>),
      );
      // Successful verification, update stream with the user from the response.
      _authStateController.add(apiResponse.data.user);
      return apiResponse.data;
    } on HtHttpException {
      // Rethrow standardized exceptions (e.g., InvalidInputException,
      // AuthenticationException, ServerException, NetworkException).
      rethrow;
    }
  }

  @override
  Future<AuthSuccessResponse> signInAnonymously() async {
    try {
      final response = await _httpClient.post<Map<String, dynamic>>(
        '$_authBasePath/anonymous',
        // ignore: inference_failure_on_collection_literal
        data: {},
      );
      final apiResponse = SuccessApiResponse<AuthSuccessResponse>.fromJson(
        response,
        (json) => AuthSuccessResponse.fromJson(json! as Map<String, dynamic>),
      );
      // Successful anonymous sign-in, update stream with the user.
      _authStateController.add(apiResponse.data.user);
      return apiResponse.data;
    } on HtHttpException {
      // Rethrow standardized exceptions (e.g., ServerException,
      // NetworkException).
      rethrow;
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _httpClient.post<void>('$_authBasePath/sign-out');
    } on HtHttpException catch (e) {
      // Log or handle sign-out specific errors if necessary,
      // but generally proceed to clear local state regardless.
      // Example: Don't prevent local sign-out if network fails here.
      print('Error during backend sign-out notification: $e');
    } on Object catch (e) {
      // Catch potential non-HTTP errors during sign-out call
      print('Unexpected error during backend sign-out notification: $e');
    } finally {
      // Always clear the local authentication state by emitting null.
      _authStateController.add(null);
      // Note: Actual token clearing should happen where HtHttpClient's
      // tokenProvider gets its token (e.g., secure storage). This client
      // doesn't manage the token itself.
    }
  }

  /// Closes the authentication state stream controller.
  /// Should be called when the client is no longer needed to prevent leaks.
  void dispose() {
    _authStateController.close();
  }
}
