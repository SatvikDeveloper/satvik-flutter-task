import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_task/core/network/api_client.dart';
import 'package:test_task/core/network/api_exception.dart';
import 'package:test_task/core/storage/token_storage.dart';
import 'package:test_task/features/auth/data/auth_repository.dart';
import 'package:test_task/features/auth/presentation/auth_controller.dart';

const _user = {
  'id': 1,
  'username': 'emilys',
  'email': 'emily@example.com',
  'firstName': 'Emily',
  'lastName': 'Johnson',
};

void main() {
  late _MemoryTokenStorage storage;
  late _FakeAdapter adapter;
  late ProviderContainer container;

  AuthRepository repository() => container.read(authRepositoryProvider);

  setUp(() {
    storage = _MemoryTokenStorage();
    adapter = _FakeAdapter();
    container = ProviderContainer(
      overrides: [tokenStorageProvider.overrideWithValue(storage)],
    );
    container.read(dioProvider).httpClientAdapter = adapter;
    addTearDown(container.dispose);
  });

  test('login saves the access and refresh tokens', () async {
    adapter.on('/auth/login', 200, {
      ..._user,
      'accessToken': 'access-1',
      'refreshToken': 'refresh-1',
    });

    final user = await repository().login(username: 'emilys', password: 'pw');

    expect(user.displayName, 'Emily Johnson');
    expect(storage.accessToken, 'access-1');
    expect(storage.refreshToken, 'refresh-1');
  });

  test('restoreSession returns null without a saved token', () async {
    expect(await repository().restoreSession(), isNull);
    expect(adapter.calls, isEmpty);
  });

  test('restoreSession validates the token and restores the profile', () async {
    storage
      ..accessToken = 'access-1'
      ..refreshToken = 'refresh-1';
    adapter.on('/auth/me', 200, _user);

    final user = await repository().restoreSession();

    expect(user?.displayName, 'Emily Johnson');
    expect(adapter.calls.single.headers['Authorization'], 'Bearer access-1');
  });

  test('restoreSession refreshes a rejected access token', () async {
    storage
      ..accessToken = 'expired'
      ..refreshToken = 'refresh-1';
    adapter
      ..on('/auth/me', 401, {'message': 'Invalid/Expired Token!'})
      ..on('/auth/refresh', 200, {
        'accessToken': 'access-2',
        'refreshToken': 'refresh-2',
      });
    adapter.onRequest = (options) {
      if (options.path == '/auth/refresh') {
        adapter.on('/auth/me', 200, _user);
      }
    };

    final user = await repository().restoreSession();

    expect(user?.username, 'emilys');
    expect(adapter.calls.map((c) => c.path), [
      '/auth/me',
      '/auth/refresh',
      '/auth/me',
    ]);
    expect(adapter.calls[1].data, {'refreshToken': 'refresh-1'});
    expect(adapter.calls.last.headers['Authorization'], 'Bearer access-2');
    expect(storage.accessToken, 'access-2');
    expect(storage.refreshToken, 'refresh-2');
  });

  test('restoreSession signs out when the refresh token is rejected', () async {
    storage
      ..accessToken = 'expired'
      ..refreshToken = 'bad';
    adapter
      ..on('/auth/me', 401, {'message': 'Invalid/Expired Token!'})
      ..on('/auth/refresh', 403, {'message': 'Invalid refresh token'});

    expect(await repository().restoreSession(), isNull);
    expect(storage.accessToken, isNull);
    expect(storage.refreshToken, isNull);
  });

  test(
    'restoreSession keeps the tokens when the server is unreachable',
    () async {
      storage
        ..accessToken = 'access-1'
        ..refreshToken = 'refresh-1';
      adapter.offline = true;

      await expectLater(
        repository().restoreSession(),
        throwsA(isA<ApiException>()),
      );
      expect(storage.accessToken, 'access-1');
      expect(storage.refreshToken, 'refresh-1');
    },
  );

  test(
    'controller restores the user so the app bar can show the name',
    () async {
      storage.accessToken = 'access-1';
      adapter.on('/auth/me', 200, _user);

      await container.read(authControllerProvider.notifier).restoreSession();

      final state = container.read(authControllerProvider);
      expect(state.status, AuthStatus.authenticated);
      expect(state.user?.displayName, 'Emily Johnson');
    },
  );

  test('controller stays signed in without a profile while offline', () async {
    storage.accessToken = 'access-1';
    adapter.offline = true;

    await container.read(authControllerProvider.notifier).restoreSession();

    final state = container.read(authControllerProvider);
    expect(state.status, AuthStatus.authenticated);
    expect(state.user, isNull);
  });
}

class _MemoryTokenStorage extends TokenStorage {
  String? accessToken;
  String? refreshToken;

  @override
  Future<void> writeTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    this.accessToken = accessToken;
    this.refreshToken = refreshToken;
  }

  @override
  Future<String?> readAccessToken() async => accessToken;

  @override
  Future<String?> readRefreshToken() async => refreshToken;

  @override
  Future<void> deleteTokens() async {
    accessToken = null;
    refreshToken = null;
  }
}

class _FakeAdapter implements HttpClientAdapter {
  final _responses = <String, (int, Map<String, dynamic>)>{};
  final calls = <RequestOptions>[];
  bool offline = false;
  void Function(RequestOptions options)? onRequest;

  void on(String path, int status, Map<String, dynamic> body) {
    _responses[path] = (status, body);
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(options);
    if (offline) {
      throw DioException.connectionError(
        requestOptions: options,
        reason: 'offline',
      );
    }
    final (status, body) = _responses[options.path]!;
    onRequest?.call(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
