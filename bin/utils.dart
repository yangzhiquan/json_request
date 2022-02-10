import 'package:dart_style/dart_style.dart';
import 'package:path/path.dart' as Path;
import 'dart:convert';
import 'dart:io';

const String JRConfigBaseURL = 'base_url';
const String JRConfigModels = 'models';
const String JRConfigPaths = 'paths';

const String JRCgiReq = 'req';
const String JRCgiRsp = 'rsp';
const String JRCgiPath = 'path';
const String JRCgiMethod = 'method';
const String JRCgiRspName = 'rspName';

const String JRSRequireFlag = '__require__';
const String JRSLateFlag = '__late__';

class CodeBag {
  bool unsound_null_safety = false; // 非健全的空安全
  // 头文件引用部分 + 包装类部分 + 包装类的成员变量 + 类代码内容部分
  final wrapperCode = StringBuffer();
  final imports = Set<String>();
  final code = StringBuffer();
  final iVars = <String>[];
  final distDir;
  final publicFileName;

  String iVarName = '';
  String className = '';

  // 对应生成的req类路径
  String targetFilePath(String name, [String? dir]) => dir != null
      ? Path.join(distDir, dir, "$name.dart")
      : Path.join(distDir, "$name.dart");

  // 公共头文件
  String get publicClassCode =>
      JSPublicClass.replaceAll(JRSLateFlag, unsound_null_safety ? '' : 'late')
          .replaceAll(JRSRequireFlag, unsound_null_safety ? '' : 'required');

  CodeBag(this.distDir, this.publicFileName);

  // 解析配置文件
  bool parseConfigFile(FileSystemEntity fileEty) {
    final filePath = fileEty.path;
    if (!FileSystemEntity.isFileSync(filePath)) {
      return false;
    }

    final file = File(filePath);
    var fileName = Path.basename(filePath).split(".").first;
    final fileType = Path.basename(filePath).split(".").last;

    // 不是json或者带下划线文件不处理
    if (fileType.toLowerCase() != "json" ||
        fileName.startsWith("_") ||
        fileName.isEmpty) {
      return false;
    }

    // 大小写文件名.
    fileName = fileName.toLowerCamelCase;
    final fileNameUpper = fileName.toUpperCamelCase;

    // 读取文件内容
    // todo: 校验文件格式
    final content =
        json.decode(file.readAsStringSync()) as Map<String, dynamic>;

    final baseURL = content[JRConfigBaseURL] ?? '';
    final pathInfo = content[JRConfigPaths] ?? [];
    final modelsInfo = content[JRConfigModels] ?? {};

    // 生成自定义的model类，便于后续生成的类引用
    modelsInfo.forEach((key, info) {
      final String mName = key;
      final mFileName = mName.toUnderline;
      final mClassName = mName.toUpperCamelCase;
      final mCode =
          genModelClass(info, mClassName, mFileName, JsonResponseDataName);
      final mFilePath = targetFilePath(mClassName.toUnderline, fileName);
      saveCodeToFile(mFilePath, mCode);
    });

    // 配置（域名）对应的类代码，
    final _className = fileNameUpper + 'JsonRequest';
    final source = StringBuffer();
    source.writeln('class $_className with $JsonRequestDataName {');
    source.writeln('String get baseURL => "$baseURL";');

    // 遍历path生成请求函数（添加到source参数） + req/rsp model类文件(添加到export > imports)
    pathInfo.forEach((element) {
      // 生成并收集所有生成的类文件路径 生成export文件
      String exports = _parsePathInfo(element, source, fileName);
      if (exports.isNotEmpty) {
        final exportFileName = 'export_' + fileName;
        final path = targetFilePath(exportFileName);
        saveCodeToFile(path, exports);

        imports.add('import "$exportFileName.dart"');
      }
    });
    source.write('}');

    code.writeln(source.toString());
    this.iVarName = fileName;
    this.className = _className;
    return true;
  }

  // 解析单个cig，生成对于的req跟rsp类文件; 返回export信息
  String _parsePathInfo(
      Map<String, dynamic> cgiInfo, StringBuffer source, String domainDir) {
    String exports = "";
    cgiInfo.forEach((cgiName, info) {
      // 下划线开始的函数名忽略
      if (cgiName.startsWith("_")) {
        return;
      }
      final funcName = cgiName.toLowerCamelCase;
      final className = cgiName.toUpperCamelCase;

      final path = info[JRCgiPath]; // cgi名.
      final method = info[JRCgiMethod]; // http请求方式.

      // 1. req文件
      final Map req = info[JRCgiReq];
      final String classNameReq = '${className}Req';
      final String fileNameReq = classNameReq.toUnderline;

      final reqCode =
          genModelClass(req, classNameReq, fileNameReq, JsonRequestDataName);
      final reqFilePath = targetFilePath(classNameReq.toUnderline, domainDir);
      // 创建文件
      CodeBag.saveCodeToFile(reqFilePath, reqCode);
      // 收集生成的文件，用于export
      exports = _exportIndexFile(reqFilePath, distDir, exports);

      // 2. rsp文件
      final Map rsp = info[JRCgiRsp];
      final String classNameRsp = info[JRCgiRspName] ?? '${className}Rsp';
      final String fileNameRsp = classNameRsp.toUnderline;

      final rspCode =
          genModelClass(rsp, classNameRsp, fileNameRsp, JsonResponseDataName);
      final rspFilePath = targetFilePath(fileNameRsp, domainDir);
      CodeBag.saveCodeToFile(rspFilePath, rspCode);

      exports = _exportIndexFile(rspFilePath, distDir, exports);

      // 3. 生成函数
      final reqFuncCode =
          "Future<$classNameRsp> $funcName({Function($classNameReq req)? reqBuilder}) =>makeRequest($classNameReq(), reqBuilder: reqBuilder, rspBuilder: (json) => $classNameRsp.fromJson(json ?? {})..isEmpty = json?.isEmpty ?? true, httpMethod: '$method', path: '$path', baseURL: baseURL);";

      source.write(reqFuncCode);
    });

    return exports;
  }

  String _exportIndexFile(String p, String distDir, String indexFile) {
    final relative = p.replaceFirst(distDir + Path.separator, "");
    indexFile += "export '$relative' ;";
    return indexFile;
  }

  String _getDataType(v, Set<String> set, String current) {
    current = current.toLowerCase();
    if (v is bool) {
      return "bool";
    } else if (v is num) {
      return "num";
    } else if (v is Map) {
      return "Map<String,dynamic>";
    } else if (v is List) {
      return "List";
    } else if (v is String) {
      // 处理自定义类型或者该类型的数组
      if (v.startsWith("@[") && v.endsWith("]")) {
        final type = v.substring(2, v.length - 1).toLowerCamelCase;
        if (type.toLowerCase() != current && !type.isBuiltInType) {
          set.add("import '${type.toUnderline}.dart'");
        }
        return "List<${type.toUpperCamelCase}>";
      } else if (v.startsWith("@")) {
        final fileName = v.substring(1).toLowerCamelCase;
        if (fileName.toLowerCase() != current) {
          set.add("import '${fileName.toUnderline}.dart'");
        }
        return fileName.toUpperCamelCase;
      }
      return "String";
    } else {
      return "String";
    }
  }

  /*****************************/
  // 生成model代码
  String genModelClass(
      Map json, String className, String fileName, String withMixin) {
    // 类代码内容
    final code = StringBuffer();
    // imprt头文件，set去重
    final imports = Set<String>();

    json.forEach((key, value) {
      key = key.trim();
      if (key.startsWith("_")) {
        return;
      }

      // 支持? 与 ！
      final bool optionalField = key.endsWith('?');
      final bool notNull = key.endsWith('!');
      if (optionalField || notNull) {
        key = key.substring(0, key.length - 1);
      }

      if (!unsound_null_safety) {
        code.write('late ');
      }
      code.write(_getDataType(value, imports, className));
      code.write(" ");
      code.write(key);
      code.writeln(";");
    });

    // 添加头文件引用.

    var importContent = imports.isEmpty ? "" : imports.join(";") + ";";

    var distCode = '''
      $importContent
      import 'package:json_annotation/json_annotation.dart';
      import '../$publicFileName.dart';
      part '$fileName.g.dart';
      
      @JsonSerializable()
      class $className with $withMixin {
        $className();
        
        ${code.toString()}
  
        factory $className.fromJson(Map<String, dynamic> json) =>
            _\$${className}FromJson(json);
        Map<String, dynamic> toJson() => _\$${className}ToJson(this);
      }
    ''';

    return distCode;
  }

  // 保存代码到文件
  static void saveCodeToFile(String path, String code) {
    File(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(DartFormatter().format(code));
    print('create file: $path');
  }
}

extension ChangeFirstChar on String {
  String changeFirstChar({bool upper = true}) => this.isEmpty
      ? this
      : (upper ? this[0].toUpperCase() : this[0].toLowerCase()) +
          this.substring(1);

  String get toUnderline => this
      .replaceAllMapped(
          RegExp(r'(?<=[a-z])[A-Z]'), (Match match) => '_' + match.group(0)!)
      .toLowerCase();

  String get toUpperCamelCase => changeFirstChar(upper: true);
  String get toLowerCamelCase => changeFirstChar(upper: false);
  bool get isBuiltInType =>
      ['int', 'num', 'string', 'double', 'map', 'list'].contains(this);
}

/// code & tpl

const JsonRequestDataName = 'JsonRequestData';
const JsonResponseDataName = 'JsonResponseData';

// public
const JSPublicClass = ''' 
    import 'package:flutter/foundation.dart';
    import 'package:json_annotation/json_annotation.dart';

    typedef HttpRequestFunc = Future<R> Function<R>(
                              JsonRequestData reqData,
                              R Function<T>({$JRSRequireFlag T rawData, $JRSRequireFlag Map<String, dynamic>? Function(T rawData) toJson}) rspInfo); 

    mixin $JsonRequestDataName {
      Map<String, dynamic> toJson() => {};
      Map<String, dynamic> get params => args.httpMethod == "GET" ? this.toJson() : args.query;
      Map<String, dynamic> get body => args.httpMethod == "POST" ? this.toJson() : {};

      @JsonKey(ignore: true)
      $JRSLateFlag HttpRequestFunc requestFunc;
    
      @JsonKey(ignore: true)
      _JsonRequestArgs args = _JsonRequestArgs();

      @protected
      Future<R> makeRequest<R extends JsonResponseData, T extends JsonRequestData>(
          T req,
          {Function(T req)? reqBuilder,
          $JRSRequireFlag R Function(Map<String, dynamic>? json) rspBuilder,
          $JRSRequireFlag String httpMethod,
          $JRSRequireFlag String path,
          $JRSRequireFlag String baseURL}) async {
        req.args = args;
        req.requestFunc = requestFunc;
        req.args.baseUrl = baseURL;
        req.args.httpMethod = httpMethod;
        req.args.path = path;

        if (reqBuilder != null) {
          reqBuilder(req);
        }

        final res = await req.requestFunc(req, <T>(
            {required T rawData,
            required Map<String, dynamic>? Function(T rawData) toJson}) {
          final info = toJson(rawData);
          final rspModel = rspBuilder(info);
          rspModel.rspObj = rawData;
          return rspModel;
        });

        return res;
      }
    }

    mixin $JsonResponseDataName {
      @JsonKey(ignore: true)
      dynamic rspObj;

      @JsonKey(ignore: true)
      bool isEmpty = false;
    }
    
    class _JsonRequestArgs {
      String contentType = 'application/json; charset=utf-8';
      $JRSLateFlag String path;
      $JRSLateFlag String baseUrl;
      $JRSLateFlag String httpMethod;
      
      Map<String, dynamic> headers = {};
      Map<String, dynamic> query = {};
      dynamic cookies = '';
    }
  ''';
