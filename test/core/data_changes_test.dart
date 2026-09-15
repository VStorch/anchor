import 'package:anchor/core/state/data_changes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('publish fora de um hold notifica na hora', () {
    final changes = DataChanges();
    var notified = 0;
    changes.addListener(() => notified++);

    changes.publish();

    expect(notified, 1);
  });

  test('hold aninhado segura os publish e notifica uma vez no fim', () async {
    final changes = DataChanges();
    var notified = 0;
    changes.addListener(() => notified++);

    final result = await changes.hold(() async {
      changes.publish();
      await changes.hold(() async {
        changes.publish();
        changes.publish();
      });
      expect(notified, 0);
      return 42;
    });

    expect(result, 42);
    expect(notified, 1);
  });

  test('hold sem publish não notifica', () async {
    final changes = DataChanges();
    var notified = 0;
    changes.addListener(() => notified++);

    await changes.hold(() async {});

    expect(notified, 0);
  });

  test('hold que falha ainda solta o que ficou pendente', () async {
    final changes = DataChanges();
    var notified = 0;
    changes.addListener(() => notified++);

    await expectLater(
      changes.hold(() async {
        changes.publish();
        throw StateError('falhou');
      }),
      throwsStateError,
    );

    expect(notified, 1);
    changes.publish();
    expect(notified, 2);
  });
}
