import 'dart:io';
import 'lib/data/dialogues_data.dart';

void main() async {
  final client = HttpClient();
  print('Checking ${MovieDialogue.dialogues.length} URLs...');
  for (var i = 0; i < MovieDialogue.dialogues.length; i++) {
    final d = MovieDialogue.dialogues[i];
    final url = d.posterUrl.replaceAll('/original/', '/w500/');
    try {
      final req = await client.headUrl(Uri.parse(url));
      final res = await req.close();
      if (res.statusCode != 200) {
        print('FAILED [${res.statusCode}]: ${d.movieTitle} - $url');
      }
    } catch (e) {
      print('ERROR: ${d.movieTitle} - $url - $e');
    }
  }
  print('Done.');
  exit(0);
}
