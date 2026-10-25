import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snoop/main.dart';

void main() {
  test('SnoopApp is a const-constructible widget', () {
    const app = SnoopApp();
    expect(app, isA<StatelessWidget>());
  });
}
