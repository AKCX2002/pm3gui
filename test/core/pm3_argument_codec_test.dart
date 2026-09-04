import 'package:flutter_test/flutter_test.dart';
import 'package:pm3gui/core/pm3/pm3_argument_codec.dart';

void main() {
  test('one argument per line round-trips spaces quotes and backslashes', () {
    const arguments = [
      '--flush',
      r'--path=C:\Program Files\proxmark3',
      '--label="reader one"',
      r'--pattern=one\two',
      '  preserve surrounding spaces  ',
    ];

    final encoded = encodePm3Arguments(arguments);

    expect(encoded, contains('\n'));
    expect(decodePm3Arguments(encoded), arguments);
  });

  test('decoder accepts Windows newlines and ignores final editor newline', () {
    expect(
      decodePm3Arguments('--first value\r\n--second="quoted"\r\n'),
      ['--first value', '--second="quoted"'],
    );
  });
}
