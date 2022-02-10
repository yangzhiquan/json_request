import 'dart:async';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'jrs/json_request_public.dart';
import 'jrs/json_request_service.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with TickerProviderStateMixin {
  Dio? dio;

  @override
  Widget build(BuildContext context) {
    jrsTest();
    return CupertinoApp(
      title: 'Json Request Demo',
      home: Container(
        color: Colors.blueGrey,
      ),
    );
  }

  void jrsTest() async {
    jrs.requestFunc = _requestFunc;
    // jrs.agify.userInfo((req) {
    //   req.name = 'jay';
    //   req.args.headers = {'someKey': "xxValue"};
    // }).then((value) {
    //   final rsp = value?.item1;
    //   print('get结果 ${rsp?.name} + ${rsp?.age}');
    // });

    final res = await jrs.test.postTest(reqBuilder: (req) => req.foo = 'bar');
    print('请求结果 ${res.json} ${res.url}');
  }

  Future<R> _requestFunc<R>(
      JsonRequestData reqData,
      R Function<T>(
              {required T rawData,
              required Map<String, dynamic>? Function(T rawData) toJson})
          rspInfo) async {
    // if (reqData.args.httpMethod == "GET") {
    //   final rsp = await _dioGet(reqData.args.path, reqData.args.params, baseURL: reqData.args.baseUrl);
    //
    //   var rawInfo;
    //   if (rsp.data is Map) {
    //     rawInfo = rsp.data;
    //   } else if (rsp.data is String) {
    //     rawInfo = json.decode(rsp.data);
    //   }
    //
    //   return Tp(rawInfo, rawInfo);
    // }
    // if (reqData.args.httpMethod == "POST") {
    final rsp = await _dioPost(reqData.args.path, reqData.toJson(),
        baseURL: reqData.args.baseUrl);

    return rspInfo(
        rawData: rsp,
        toJson: (rsp) {
          var targetInfo = <String, dynamic>{};
          if (rsp is Response) {
            final rspJson = rsp.data;
            if (rspJson is Map<String, dynamic>) {
              targetInfo = rspJson;
            } else if (rspJson is String) {
              targetInfo = json.decode(rspJson);
            }
          }
          return targetInfo;
        });
    // }
    // return null;
  }

  Future<Response> _dioPost(String path, Map<String, dynamic>? body,
      {String baseURL = ''}) async {
    dio ??= Dio();
    dio?.options.baseUrl = baseURL;

    return dio!.post(path, data: body);
  }

  Future<Response> _dioGet(String path, Map<String, dynamic>? params,
      {String baseURL = ''}) async {
    dio ??= Dio();
    dio?.options.baseUrl = baseURL;

    return dio!.get(path, queryParameters: params);
  }
}
