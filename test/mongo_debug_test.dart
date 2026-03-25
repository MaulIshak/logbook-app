import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:my_logbook_app/services/mongo_service.dart';

void main() {
  setUpAll(() async {
    await dotenv.load(fileName: ".env");
  });

  test('Full flow: MongoService.connect() + getLogs() — tanpa isolate', () async {
    final sw = Stopwatch()..start();

    // Step 1: Connect
    print('[1] MongoService().connect()...');
    await MongoService().connect();
    print('[1] ✅ Connect: ${sw.elapsedMilliseconds}ms');

    // Step 2: getLogs
    print('[2] MongoService().getLogs("1")...');
    final logs = await MongoService().getLogs('1');
    print('[2] ✅ getLogs: ${logs.length} logs — ${sw.elapsedMilliseconds}ms');

    if (logs.isNotEmpty) {
      print('[2] Contoh: "${logs.first.title}" by ${logs.first.username}');
      print('[2] isSynced: ${logs.first.isSynced}');
    }

    // Step 3: Close
    await MongoService().close();
    print('[3] ✅ Closed — total: ${sw.elapsedMilliseconds}ms');
  }, timeout: const Timeout(Duration(seconds: 30)));
}
