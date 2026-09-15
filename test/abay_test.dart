import 'package:abay/core/utils/formatters.dart';
import 'package:abay/models/sip_account.dart';
import 'package:test/test.dart';

void main() {
  test('Formatters.prettyUri strips sip scheme and domain', () {
    expect(Formatters.prettyUri('sip:1001@pbx.example.com'), '1001');
    expect(Formatters.prettyUri('sips:alice@example.com'), 'alice');
    expect(Formatters.prettyUri('bob'), 'bob');
  });

  test('Formatters.formatDuration pads minutes/seconds', () {
    expect(Formatters.formatDuration(const Duration(seconds: 5)), '00:05');
    expect(
      Formatters.formatDuration(const Duration(minutes: 1, seconds: 5)),
      '01:05',
    );
    expect(
      Formatters.formatDuration(
          const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
  });

  test('Formatters.normalizeTarget builds sip URIs', () {
    expect(Formatters.normalizeTarget('1001', domain: 'pbx.local'),
        'sip:1001@pbx.local');
    expect(Formatters.normalizeTarget('sip:2000@x.com'), 'sip:2000@x.com');
    expect(Formatters.normalizeTarget('a@b.com'), 'sip:a@b.com');
  });

  test('SipAccount serializes and restores', () {
    const a = SipAccount(
      id: 'id-1',
      displayName: 'Office',
      username: '1001',
      authUser: '1001',
      password: 'secret',
      domain: 'pbx.local',
      server: 'pbx.local',
      port: 5061,
      transport: SipTransport.tls,
      useSrtp: true,
    );
    final restored = SipAccount.decode(a.encode());
    expect(restored.username, '1001');
    expect(restored.transport, SipTransport.tls);
    expect(restored.useSrtp, true);
    expect(restored.uri, 'sip:1001@pbx.local');
  });

  test('looksLikeNumber accepts DTMF digits', () {
    expect(Formatters.looksLikeNumber('1001'), true);
    expect(Formatters.looksLikeNumber('*21'), true);
    expect(Formatters.looksLikeNumber('alice'), false);
  });
}
