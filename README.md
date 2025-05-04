# ht_auth_api

![coverage: 97%](https://img.shields.io/badge/coverage-97-green)
[![style: very good analysis](https://img.shields.io/badge/style-very_good_analysis-B22C89.svg)](https://pub.dev/packages/very_good_analysis)
[![License: PolyForm Free Trial](https://img.shields.io/badge/License-PolyForm%20Free%20Trial-blue)](https://polyformproject.org/licenses/free-trial/1.0.0)

Concrete API implementation of the `HtAuthClient` interface defined in
`package:ht_auth_client`. This package provides the logic for interacting
with a backend authentication service via HTTP requests using
`package:ht_http_client`.

## Getting Started

Add this package to your `pubspec.yaml` dependencies:

```yaml
dependencies:
  ht_auth_api:
    git:
      url: https://github.com/headlines-toolkit/ht-auth-api.git
      # Optionally specify a ref (branch, tag, commit hash)
      # ref: main
```

You also need to include `ht_http_client` and `ht_auth_client` (which this
package depends on).

## Features

Provides an `HtAuthApi` class implementing `HtAuthClient` with the following
capabilities:

*   Requesting a sign-in code via email (`requestSignInCode`).
*   Verifying the sign-in code to complete authentication (`verifySignInCode`).
*   Signing in anonymously (`signInAnonymously`).
*   Retrieving the current authenticated user (`getCurrentUser`).
*   Monitoring authentication state changes via a stream (`authStateChanges`).
*   Signing out the current user (`signOut`).

## Usage

Instantiate `HtAuthApi` with a configured `HtHttpClient` instance:

```dart
import 'package:ht_auth_api/ht_auth_api.dart';
import 'package:ht_auth_client/ht_auth_client.dart';
import 'package:ht_http_client/ht_http_client.dart';

void main() async {
  // Configure HtHttpClient (replace with your actual base URL and token logic)
  final httpClient = HtHttpClient(
    baseUrl: 'https://your-api.com',
    tokenProvider: () async => 'YOUR_AUTH_TOKEN', // Or null if not logged in
  );

  // Create the auth API client
  final HtAuthClient authClient = HtAuthApi(httpClient: httpClient);

  // Listen to authentication state changes
  authClient.authStateChanges.listen((user) {
    if (user != null) {
      print('User signed in: ${user.id}, Anonymous: ${user.isAnonymous}');
    } else {
      print('User signed out.');
    }
  });

  try {
    // Example: Request sign-in code
    await authClient.requestSignInCode('user@example.com');
    print('Sign-in code requested.');

    // Example: Verify code (replace '123456' with actual code)
    // final user = await authClient.verifySignInCode('user@example.com', '123456');
    // print('User verified: ${user.id}');

    // Example: Sign in anonymously
    // final anonUser = await authClient.signInAnonymously();
    // print('Signed in anonymously: ${anonUser.id}');

    // Example: Get current user
    // final currentUser = await authClient.getCurrentUser();
    // if (currentUser != null) { ... }

    // Example: Sign out
    // await authClient.signOut();

  } on HtHttpException catch (e) {
    print('Authentication error: $e');
  } finally {
    // Remember to dispose the client if it has resources like streams
    // (In this specific implementation, HtAuthApi has a dispose method)
    (authClient as HtAuthApi).dispose();
  }
}

```

## License

This package is licensed under the [PolyForm Free Trial](LICENSE). Please
review the terms before use.
