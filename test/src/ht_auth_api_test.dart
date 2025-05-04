import 'dart:async';

import 'package:ht_auth_api/src/ht_auth_api.dart';
import 'package:ht_http_client/ht_http_client.dart';
import 'package:ht_shared/ht_shared.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

// Mocks
class MockHtHttpClient extends Mock implements HtHttpClient {}

class MockUser extends Mock implements User {}

// Fake User for testing
final fakeUser =
    User(id: 'user-123', isAnonymous: false, email: 'test@test.com');
final fakeAnonymousUser = User(id: 'anon-456', isAnonymous: true);
final fakeSuccessResponseUser = SuccessApiResponse<User>(data: fakeUser);
final fakeSuccessResponseAnonUser =
    SuccessApiResponse<User>(data: fakeAnonymousUser);

// Helper to create Map<String, dynamic> from SuccessApiResponse<User>
Map<String, dynamic> successUserResponseToJson(SuccessApiResponse<User> resp) {
  return {
    'data': resp.data.toJson(),
    if (resp.metadata != null) 'metadata': resp.metadata!.toJson(),
  };
}

// Helper to wait for microtasks to complete
Future<void> pumpEventQueue() => Future<void>.delayed(Duration.zero);

void main() {
  group('HtAuthApi', () {
    late HtHttpClient mockHttpClient;
    late HtAuthApi authApi;
    late Stream<User?> authStream; // To capture the stream early

    // --- Test Group: Initialization ---
    group('Initialization', () {
      setUp(() {
        mockHttpClient = MockHtHttpClient();
        registerFallbackValue(Uri.parse('http://fallback.com'));
      });

      tearDown(() {
        authApi.dispose();
      });

      test(
          'emits null initially if getCurrentUser throws UnauthorizedException',
          () async {
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenThrow(UnauthorizedException('No session'));
        authApi = HtAuthApi(httpClient: mockHttpClient);
        authStream = authApi.authStateChanges;
        await expectLater(authStream.first, completion(isNull));
      });

      test(
          'emits null initially if getCurrentUser throws other HtHttpException',
          () async {
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenThrow(ServerException('Server init error'));
        authApi = HtAuthApi(httpClient: mockHttpClient);
        authStream = authApi.authStateChanges;
        await expectLater(authStream.first, completion(isNull));
      });

      test('emits null initially if getCurrentUser throws non-HtHttpException',
          () async {
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenThrow(Exception('Unexpected init error'));
        authApi = HtAuthApi(httpClient: mockHttpClient);
        authStream = authApi.authStateChanges;
        await expectLater(authStream.first, completion(isNull));
      });

      test('emits user initially if getCurrentUser succeeds', () async {
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenAnswer(
          (_) async =>
              successUserResponseToJson(SuccessApiResponse(data: fakeUser)),
        );
        authApi = HtAuthApi(httpClient: mockHttpClient);
        authStream = authApi.authStateChanges;
        await expectLater(authStream.first, completion(fakeUser));
      });
    });

    // --- Test Group: Operations after Successful Initialization ---
    group('Operations (Initialized with User)', () {
      setUp(() async {
        mockHttpClient = MockHtHttpClient();
        registerFallbackValue(Uri.parse('http://fallback.com'));
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenAnswer(
          (_) async =>
              successUserResponseToJson(SuccessApiResponse(data: fakeUser)),
        );
        authApi = HtAuthApi(httpClient: mockHttpClient);
        authStream = authApi.authStateChanges;
        await authStream.first;
        await pumpEventQueue();
        clearInteractions(mockHttpClient);
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenAnswer(
          (_) async =>
              successUserResponseToJson(SuccessApiResponse(data: fakeUser)),
        );
        when(() => mockHttpClient.post<void>(any(), data: any(named: 'data')))
            .thenAnswer((_) async {});
        when(() => mockHttpClient.post<void>('/api/v1/auth/sign-out'))
            .thenAnswer((_) async {});
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async =>
              successUserResponseToJson(SuccessApiResponse(data: fakeUser)),
        );
      });

      tearDown(() {
        authApi.dispose();
      });

      test('getCurrentUser returns user without extra stream emission',
          () async {
        final user = await authApi.getCurrentUser();
        expect(user, fakeUser);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'),
        ).called(1);
      });

      test('signOut emits null', () async {
        final expectation = expectLater(authStream, emits(isNull));
        await authApi.signOut();
        await expectation;
        verify(() => mockHttpClient.post<void>('/api/v1/auth/sign-out'))
            .called(1);
      });

      test('signOut completes and emits null even if HTTP call fails',
          () async {
        when(() => mockHttpClient.post<void>('/api/v1/auth/sign-out'))
            .thenThrow(NetworkException());
        final expectation = expectLater(authStream, emits(isNull));
        await expectLater(authApi.signOut(), completes);
        await expectation;
        verify(() => mockHttpClient.post<void>('/api/v1/auth/sign-out'))
            .called(1);
      });
    });

    // --- Test Group: Operations after Failed Initialization (Unauthorized) ---
    group('Operations (Initialized Unauthorized)', () {
      setUp(() async {
        mockHttpClient = MockHtHttpClient();
        registerFallbackValue(Uri.parse('http://fallback.com'));
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenThrow(UnauthorizedException('No session'));
        authApi = HtAuthApi(httpClient: mockHttpClient);
        authStream = authApi.authStateChanges;
        await authStream.first;
        await pumpEventQueue();
        clearInteractions(mockHttpClient);
        when(() => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'))
            .thenThrow(UnauthorizedException('No session'));
        when(() => mockHttpClient.post<void>(any(), data: any(named: 'data')))
            .thenAnswer((_) async {});
        when(() => mockHttpClient.post<void>('/api/v1/auth/sign-out'))
            .thenAnswer((_) async {});
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/verify-code',
            data: any(named: 'data'),
          ),
        ).thenAnswer(
          (_) async =>
              successUserResponseToJson(SuccessApiResponse(data: fakeUser)),
        );
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/anonymous',
          ),
        ) // Removed data expectation
            .thenAnswer(
          (_) async => successUserResponseToJson(
            SuccessApiResponse(data: fakeAnonymousUser),
          ),
        );
      });

      tearDown(() {
        authApi.dispose();
      });

      test('getCurrentUser returns null without extra stream emission',
          () async {
        final user = await authApi.getCurrentUser();
        expect(user, isNull);
        verify(
          () => mockHttpClient.get<Map<String, dynamic>>('/api/v1/auth/me'),
        ).called(1);
      });

      test('requestSignInCode completes normally', () async {
        await expectLater(
          authApi.requestSignInCode('test@test.com'),
          completes,
        );
        verify(
          () => mockHttpClient.post<void>(
            '/api/v1/auth/request-code',
            data: {'email': 'test@test.com'},
          ),
        ).called(1);
      });

      test('requestSignInCode rethrows HtHttpExceptions', () async {
        final exception = InvalidInputException('Bad email');
        when(
          () => mockHttpClient.post<void>(
            '/api/v1/auth/request-code',
            data: any(named: 'data'),
          ),
        ).thenThrow(exception);
        await expectLater(
          () => authApi.requestSignInCode('bad-email'),
          throwsA(isA<InvalidInputException>()),
        );
        verify(
          () => mockHttpClient.post<void>(
            '/api/v1/auth/request-code',
            data: {'email': 'bad-email'},
          ),
        ).called(1);
      });

      test('verifySignInCode returns user and emits state', () async {
        final expectation = expectLater(authStream, emits(fakeUser));
        final user = await authApi.verifySignInCode('test@test.com', '123456');
        expect(user, equals(fakeUser));
        await expectation;
        verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/verify-code',
            data: {'email': 'test@test.com', 'code': '123456'},
          ),
        ).called(1);
      });

      test('verifySignInCode rethrows HtHttpExceptions', () async {
        final exception = AuthenticationException('Invalid code');
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/verify-code',
            data: any(named: 'data'),
          ),
        ).thenThrow(exception);
        await expectLater(
          () => authApi.verifySignInCode('test@test.com', 'wrong-code'),
          throwsA(isA<AuthenticationException>()),
        );
        verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/verify-code',
            data: {'email': 'test@test.com', 'code': 'wrong-code'},
          ),
        ).called(1);
      });

      test('signInAnonymously returns user and emits state', () async {
        final expectation = expectLater(authStream, emits(fakeAnonymousUser));
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/anonymous',
          ),
        ).thenAnswer(
          (_) async => successUserResponseToJson(
            SuccessApiResponse(data: fakeAnonymousUser),
          ),
        );
        final user = await authApi.signInAnonymously();
        expect(user, equals(fakeAnonymousUser));
        await expectation;
        verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/anonymous',
          ),
        ).called(1);
      });

      test('signInAnonymously rethrows HtHttpExceptions', () async {
        final exception = ServerException('Failed to create anon user');
        when(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/anonymous',
          ),
        ).thenThrow(exception);
        await expectLater(
          () => authApi.signInAnonymously(),
          throwsA(isA<ServerException>()),
        );
        verify(
          () => mockHttpClient.post<Map<String, dynamic>>(
            '/api/v1/auth/anonymous',
          ),
        ).called(1);
      });

      test('signOut completes and emits null', () async {
        final expectation = expectLater(authStream, emits(isNull));
        await authApi.signOut();
        await expectation;
        verify(() => mockHttpClient.post<void>('/api/v1/auth/sign-out'))
            .called(1);
      });
    });

    // --- Test Group: Dispose ---
    group('Dispose', () {
      test('closes the authStateChanges stream', () async {
        // Arrange
        mockHttpClient = MockHtHttpClient();
        registerFallbackValue(Uri.parse('http://fallback.com'));
        when(() => mockHttpClient.get<Map<String, dynamic>>(any()))
            .thenThrow(UnauthorizedException('No session'));
        authApi = HtAuthApi(httpClient: mockHttpClient);
        // *** ADDED pumpEventQueue here ***
        await pumpEventQueue(); // Allow _initializeAuthStatus to complete
        final stream = authApi.authStateChanges;

        // Act: Dispose the API instance
        authApi.dispose();

        // Assert: Expect the stream to be closed
        await expectLater(stream, emitsDone);
      });
    });
  });
}
