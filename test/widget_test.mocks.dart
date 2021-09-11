import 'package:mockito/mockito.dart' as _i1;
import 'package:muopener/api.dart' as _i2;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as _i3;

/// A class which mocks [OpenerApi].
///
/// See the documentation for Mockito's code generation for more information.
class MockOpenerApi extends _i1.Mock implements _i2.OpenerApi {
  MockOpenerApi() {
    _i1.throwOnMissingStub(this);
  }
}

/// A class which mocks [FlutterSecureStorage].
///
/// See the documentation for Mockito's code generation for more information.
class MockFlutterSecureStorage extends _i1.Mock
    implements _i3.FlutterSecureStorage {
  MockFlutterSecureStorage() {
    _i1.throwOnMissingStub(this);
  }
}
