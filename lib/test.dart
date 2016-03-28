/// Testing utilities for Corsac RPC.
///
/// This library provides two function main functions [setUpApiServer] and
/// [apiTest].
///
/// The `apiTest` function is just a thin wrapper around regular `test` function
/// from the `test` package.
///
/// Basic usage example:
///
///     import 'package:corsac_rpc/test.dart';
///
///     void main() {
///       setUpApiServer(() => getMyApiServer);
///       // `getMyApiServer` must return `Future<ApiServer>`.
///
///       apiTest('it returns good response', (ApiClient client) {
///         var request = await client.get('/users/4');
///         expect(request, responseStatus(HttpStatus.OK));
///         expect(request, responseBody(contains('Burt Macklin')));
///       });
///     }
///
/// Additionally one can generate API documentation from all the API tests.
/// The documentation will be in the "API Blueprint" format.
/// In order to enable this feature one needs to set a specific environment
/// variable which points to a directory where `.apib` files should be stored:
///
///     export CORSAC_RPC_API_BLUEPRINT_PATH="doc/blueprint"
///     pub run test
///
/// The path is relative to the project's root.
library corsac_rpc.test;

import 'dart:async';

import 'package:corsac_rpc/corsac_rpc.dart';
import 'package:http_mocks/http_mocks.dart';
import 'package:test/test.dart';
import 'dart:mirrors';
import 'dart:io';
import 'package:corsac_rpc/middleware.dart';

export 'dart:io' show HttpStatus;

export 'package:http_mocks/http_mocks.dart';
export 'package:test/test.dart';

part 'src/api_blueprint.dart';

Future<ApiServer> _server;

setUpApiServer(Future<ApiServer> callback()) {
  _server = callback();
}

void apiTest(description, body(ApiClient client), {dynamic tags}) {
  test(description, () {
    return _server
        .then((server) => new ApiClient(server))
        .then((client) => body(client));
  }, tags: tags);
}

class ApiClient {
  final ApiServer server;

  ApiClient(this.server);

  Future<HttpRequestMock> get(String path,
      {Map<String, String> query, Map<String, String> headers}) {
    return send('GET', path, query: query, headers: headers);
  }

  Future<HttpRequestMock> post(String path, String body,
      {Map<String, String> query, Map<String, String> headers}) {
    return send('POST', path, body: body, query: query, headers: headers);
  }

  Future<HttpRequestMock> send(String method, String path,
      {String body, Map<String, String> query, Map<String, String> headers}) {
    var uri = new Uri(path: path, queryParameters: query);
    var request =
        new HttpRequestMock(uri, method, body: body, headers: headers);
    var context = new MiddlewareContext(
        request.requestedUri, new ApiMethod.fromRequest(request));
    return server.handleRequest(request, context: context).then((_) {
      if (Platform.environment.containsKey('CORSAC_RPC_API_BLUEPRINT_PATH')) {
        var apib = new _ApiBlueprint();
        return apib
            .generate(Directory.current.path, context, request, server)
            .then((_) => request);
      } else {
        return request;
      }
    });
  }
}
