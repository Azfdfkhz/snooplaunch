import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/services/mirror_service.dart';

void main() {
  test('parseMirrorAddress menerima IP dengan/tanpa port dan skema', () {
    expect(parseMirrorAddress('192.168.1.5')!.toString(), '192.168.1.5:47821');
    expect(parseMirrorAddress(' 192.168.1.5:50000 ')!.toString(), '192.168.1.5:50000');
    expect(parseMirrorAddress('ws://10.42.0.1:47821/snoop-mirror')!.toString(), '10.42.0.1:47821');
    expect(parseMirrorAddress('127.0.0.1')!.host, '127.0.0.1');
    expect(parseMirrorAddress('laptop.local')!.host, 'laptop.local');
  });

  test('parseMirrorAddress menolak input tidak valid', () {
    expect(parseMirrorAddress(''), isNull);
    expect(parseMirrorAddress('999.1.1.1'), isNull);
    expect(parseMirrorAddress('192.168.1.5:99999'), isNull);
    expect(parseMirrorAddress('192.168.1.5:abc'), isNull);
    expect(parseMirrorAddress('bad host!'), isNull);
  });
}
