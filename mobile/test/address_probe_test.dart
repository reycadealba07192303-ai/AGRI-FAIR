import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/services/api_client.dart';
import 'package:mobile_app/services/api_config.dart';

/// The app finds a reachable backend without being told which address to use.
void main() {
  setUp(ApiConfig.forget);

  test('picks an address that actually answers', () async {
    final base = await ApiConfig.resolve();

    expect(base, endsWith('/api'));
    // Whatever it settled on must be usable, not merely first in the list.
    expect(await ApiClient.instance.get('/products'), isA<List>());
  });

  test('the answer is remembered, so only the first call searches', () async {
    final first = await ApiConfig.resolve();

    final watch = Stopwatch()..start();
    final second = await ApiConfig.resolve();
    watch.stop();

    expect(second, first);
    expect(watch.elapsedMilliseconds, lessThan(50));
  });

  test('forgetting makes it search again', () async {
    final first = await ApiConfig.resolve();
    ApiConfig.forget();
    expect(await ApiConfig.resolve(), first);
  });

  test('media URLs hang off whichever address won', () async {
    final base = await ApiConfig.resolve();
    final origin = base.substring(0, base.length - 4);

    expect(ApiConfig.mediaUrl('/uploads/media/x.jpg'), '$origin/uploads/media/x.jpg');
    expect(ApiConfig.mediaUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg');
  });
}
