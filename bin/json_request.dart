import 'dart:io';

import 'build_runner.dart' as BuildRunner;
import 'request_generator.dart';
import 'package:args/args.dart';

void main(List<String> args) {
  bool clean = false;
  final parser = ArgParser();
  final RequestGenerator generator = RequestGenerator();

  parser.addFlag('clean', callback: (v) => clean = v);
  parser.addFlag('incr', callback: (v) => generator.incremental = v);
  parser.addFlag('unsound_null_safety',
      callback: (v) => generator.unsound_null_safety = v);
  parser.parse(args);

  if (clean) {
    generator.cleanup();
    BuildRunner.run(['clean']);
    print('cleanup');
  } else {
    run(generator);
  }
}

void run(RequestGenerator generator) {
  if (generator.build()) {
    print('✅ json to request done.');
    BuildRunner.run(['build', '--delete-conflicting-outputs']).then((value) {
      print('✅ All Done.');
    });
  }
}

copyDirectory(String src, String dist) async {
  await Directory(dist).create(recursive: true);
  var directory = await Directory(src);
  assert(await directory.exists() == true);

  Stream<FileSystemEntity> entityList = directory.list(recursive: true);
  await for (FileSystemEntity entity in entityList) {
    if (entity is Directory) {
      if (await entity.exists() == false) {
        await Directory(entity.path.replaceFirst(src, dist))
            .create(recursive: true);
      }
    } else {
      file(entity.path, entity.path.replaceFirst(src, dist));
    }
  }
}

file(String src, String dist) async {
  File file = File(src);
  assert(await file.exists() == true);

  Stream<List<int>> stream = file.openRead();

  File target = await File(dist).create(recursive: true);
  IOSink sink = target.openWrite();

  await sink.addStream(stream);
  await sink.close();
}
