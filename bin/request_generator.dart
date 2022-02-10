import 'utils.dart';
import 'dart:io';

class RequestGenerator {
  bool incremental = false;
  bool unsound_null_safety = false; // 非健全的空安全

  String _srcDir = './json_config'; // 项目配置文件所在的目录
  String _distDir = 'lib/jrs'; // 输出解析生成物的目录
  String _jrFileName = 'json_request_service'; // 输出解析生成物的目录
  String _jrClassName = 'JsonRequestService'; // 包装类的名称
  String _jrPublicName = 'json_request_public'; // 输出解析生成物的目录

  set srcDir(String src) {
    if (src.isEmpty) {
      return;
    }
    if (src.endsWith("/")) {
      src = src.substring(0, src.length - 1);
    }
    _srcDir = src;
  }

  String distDir() {
    return _distDir;
  }

  set srcDistDir(String dist) {
    if (dist.isEmpty) {
      return;
    }
    if (dist.endsWith("/")) {
      dist = dist.substring(0, dist.length - 1);
    }
    _distDir = dist;
  }

  // 配置文件列表
  List<FileSystemEntity> get configFilePath =>
      Directory(_srcDir).listSync(recursive: true);

  bool build() {
    // 0. setup (创建目标文件夹+创建公共头文件)
    if (!Directory(_distDir).existsSync()) {
      Directory(_distDir).createSync(recursive: true);
    }

    // 1. 取配置文件
    final configs = this.configFilePath;

    // 2. 代码收集容器
    final cdoeBag = CodeBag(_distDir, _jrPublicName)
      ..unsound_null_safety = unsound_null_safety;
    {
      cdoeBag.imports.add('import "$_jrPublicName.dart"');
      cdoeBag.wrapperCode.writeln('class $_jrClassName {');
      // 3. 解析配置文件, 填充import 跟 类代码 (每份配置对应一个域名下的所有cgi)
      configs.forEach((element) {
        final result = cdoeBag.parseConfigFile(element);
        if (result) {
          final instanceCode =
              'final ${cdoeBag.iVarName} = ${cdoeBag.className}();';
          cdoeBag.wrapperCode.write(instanceCode);
          cdoeBag.iVars.add(cdoeBag.iVarName);
        }
        // else {
        //   print('空配置');
        // }
      });

      /// 添加setter函数
      final setterFunc = '''
          set requestFunc (HttpRequestFunc func) {
              ${cdoeBag.iVars.map((e) => '$e.requestFunc = func;').join('')}
            }
          ''';
      cdoeBag.wrapperCode.writeln(setterFunc);

      cdoeBag.wrapperCode.writeln('}');
    }

    // 4. 拼装最终的公共接口类代码, 生成文件.
    final importString =
        cdoeBag.imports.isEmpty ? "" : cdoeBag.imports.join(";") + ";";
    final jrsCode = importString +
        'final jrs = $_jrClassName();' +
        cdoeBag.wrapperCode.toString() +
        cdoeBag.code.toString();

    final jrsPath = cdoeBag.targetFilePath(_jrFileName);

    CodeBag.saveCodeToFile(jrsPath, jrsCode);
    CodeBag.saveCodeToFile(
        cdoeBag.targetFilePath(_jrPublicName), cdoeBag.publicClassCode);
    return true;
  }

  void cleanup() {
    final dir = Directory(_distDir);
    dir.deleteSync(recursive: true);
  }
}
