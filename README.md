# json_request 
<!-- [![Pub](https://img.shields.io/pub/v/json_request.svg?style=flat-square)](https://pub.dartlang.org/packages/json_request) -->

根据json格式的配置内容生成请求函数.
例如这一段接口配置
```
      "postTest": {
        "path": "/post",
        "method": "POST",
        "req": {"foo": "bar"},
        "rsp": {"json": {"foo":"bar"}, "customClassIvar": "@ClassNameA", "customClassIvarList":"@[ClassNameB]",}
      }
```
会自动映射req跟rsp模型，并生成请求函数。
调用接口并指定给req的字段赋值，使用返回的数据对象即可。
```dart
// 接口
  Future<PostTestRsp> postTest({Function(PostTestReq req)? reqBuilder})
// 调用
  final rsp = await postTest(reqBuilder: (req) {
    req.foo = 'test';
  });
// 结果
  print(rsp.xxx);
```


## 安装

```yaml
dev_dependencies: 
    json_serializable: ^6.1.5
    
    json_request:
    git:
      url: https://github.com/yangzhiquan/json_request.git
      ref: master

```
`flutter pub get`

## 使用

1. 创建lib同级目录"json_config", 存放api配置信息（参照example工程）.
2. 在工程目录执行 `flutter packages run json_request` 生成请求函数与Model类，生成的文件默认在"lib/jrs"目录下.
3. 实现requestFunc函数用于发送网络请求，并赋值给全局变量jrs（参照example工程）.
4. 使用示例（如下是test配置文件名为的postTest接口）.
   ```dart
    /** 
     1. 引用生成的请求函数包装类
     2. 调用请求函数，往req填写请求参数.
     3. 使用返回的rsp访问回包数据.
     *req与rsp均为配置信息生成的模型类
    **/
    import 'jrs/json_request_service.dart';
    final rsp = await jrs.test.postTest(reqBuilder: (req) => req.foo = 'bar');
    print('请求结果 ${rsp.json} ${rsp.url}');

   ```

## 配置文件示例

Json文件: `json_config/test.json`

`base_url`: 域名；
`paths`: 接口列表，包含请求方法，api路径，请求参数，回包参数；
`models`: 自定义类型，可以用"@Name"或"@[Name]"引用，后者为包含该类型的数组；

```json
{
  "base_url": "https://httpbin.org/",

  "paths": [
    {
      "postTest": {
        "path": "/post",
        "method": "POST",
        "req": {"foo": "bar"},
        "rsp": {"json": {"foo":"bar"}, "customClassIvar": "@ClassNameA", "customClassIvarList":"@[ClassNameB]",}
      }
    },
    {
      "_请求函数名": {
          "path": "api",
          "method": "请求方式",
          "req": {"请求参数key": "value"},
          "rsp": {"回包数据key": "value", },
          "rspName": "回包数据模型对应的类名，不指定默认为 {请求函数名+Rsp}"
      }
    },
  ],
  "models": {
    "ClassNameA": {"key1": "value", "key2": "value"},
    "ClassNameB": {"key1": "value", "key2": "value"},
  },
}
```

生成的Dart model类:

```dart
class TestJsonRequest with JsonRequestData {
  String get baseURL => "https://httpbin.org/";

  Future<PostTestRsp> postTest({Function(PostTestReq req)? reqBuilder}) =>
      makeRequest(PostTestReq(),
          reqBuilder: reqBuilder,
          rspBuilder: (json) => PostTestRsp.fromJson(json ?? {})..isEmpty = json?.isEmpty ?? true,
          httpMethod: 'POST',
          path: '/post',
          baseURL: baseURL);
}
```

## 实现网络请求函数
```dart
// 根据reqData发送网络请求，并将回包数据与解包方法回传
// eg:
  Future<R> _requestFunc<R>(
      JsonRequestData reqData,
      R Function<T>(T data, Map<String, dynamic>? Function(T data) toJson) rspInfo) async {
    final args = reqData.args;
    final cookies = args.cookies;
    var response;
    if (reqData.args.httpMethod == "GET") {
        response = await get(CGI(args.path), exHeaders: args.headers, cookies: cookies, params: reqData.params);
    } if (reqData.args.httpMethod == "POST") {
        response = await post(CGI(args.path), exHeaders: args.headers, cookies: cookies, params: reqData.params, body: reqData.body, contentType: args.contentType);
    }
    return rspInfo(rawData: response,
                    toJson: (rsp) => rsp.jsonData);
  }

  jrs.requestFunc = _requestFunc;
```

##  命令参数

--unsound_null_safety 项目不支持空安全的情况使用该参数（默认开启空安全支持）.
```
flutter packages run json_request --unsound_null_safety
```

--clean 清理生成的文件.
```
flutter packages run json_request --clean
```
