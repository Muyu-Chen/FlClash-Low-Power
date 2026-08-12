import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wifi_ssid/wifi_ssid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('wifi_ssid');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('WifiSsidManager', () {
    test('returns null when getSsid throws a platform exception', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getSsid');
        throw PlatformException(code: 'UNAVAILABLE');
      });

      final ssid = await wifiSsidManager.getSsid();

      expect(ssid, isNull);
    });

    test(
      'returns denied when checkPermission throws a platform exception',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'checkPermission');
          throw PlatformException(code: 'UNAVAILABLE');
        });

        final permission = await wifiSsidManager.checkPermission();

        expect(permission, WifiSsidPermission.denied);
      },
    );

    test(
      'returns denied when requestPermission throws a platform exception',
      () async {
        messenger.setMockMethodCallHandler(channel, (call) async {
          expect(call.method, 'requestPermission');
          throw PlatformException(code: 'UNAVAILABLE');
        });

        final permission = await wifiSsidManager.requestPermission();

        expect(permission, WifiSsidPermission.denied);
      },
    );

    test('maps native permission indexes to Dart enum values', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        return WifiSsidPermission.permanentlyDenied.index;
      });

      final permission = await wifiSsidManager.checkPermission();

      expect(permission, WifiSsidPermission.permanentlyDenied);
    });
  });
}
