import 'dart:async';
import 'dart:io';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }

  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: true,
        cacheEnabled: false,
        incognito: true,
        clearCache: true,
      ),
      android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
      ),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  late PullToRefreshController pullToRefreshController;
  String url = "https://medium.com/topic/popular";
  double progress = 0;
  final urlController = TextEditingController();

  String? _sharedText = '';

  late StreamSubscription _intentDataStreamSubscription;
  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    webViewController?.stopLoading();
    webViewController?.clearCache();
    webViewController?.goBack();
    return true;
  }

  @override
  void initState() {
    super.initState();

    BackButtonInterceptor.add(myInterceptor);

    pullToRefreshController = PullToRefreshController(
      options: PullToRefreshOptions(
        color: Colors.grey,
      ),
      onRefresh: () async {
        webViewController?.stopLoading();
        webViewController?.clearCache();
        if (Platform.isAndroid) {
          webViewController?.reload();
        } else if (Platform.isIOS) {
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: await webViewController?.getUrl()));
        }
      },
    );

    // For sharing or opening urls/text coming from outside the app while the app is in the memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.getTextStream().listen((String value) {
      setState(() {
        _sharedText = value;
        if (_sharedText != null && _sharedText.toString().length > 5) {
          url = _sharedText.toString();
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: Uri.parse(url)));
        }
      });
    }, onError: (err) {
      print("getLinkStream error: $err");
    });

    // For sharing or opening urls/text coming from outside the app while the app is closed
    ReceiveSharingIntent.getInitialText().then((String? value) {
      setState(() {
        _sharedText = value;
        if (_sharedText != null && _sharedText.toString().length > 5) {
          url = _sharedText.toString();
          webViewController?.loadUrl(
              urlRequest: URLRequest(url: Uri.parse(url)));
        }
      });
    });
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    _intentDataStreamSubscription.cancel();
    super.dispose();
  }

  void removeElements(InAppWebViewController? controller) {
    try {
      List<String> jsCode = [
        'document.cookie.split(";").forEach(function(c) { document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); });',
        'document.getElementById("lo-highlight-meter-1-copy").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-copy").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-copy").style.display = "none";',
        'document.getElementById("lo-highlight-meter-1-highlight-box").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-highlight-box").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-highlight-box").style.display = "none";',
        'document.getElementById("cv cw cx cy aj cz da s").style.display = "none";',
        'document.getElementsByClassName("branch-journeys-top").item(0).style.display = "none";',
        'document.getElementById("lo-highlight-meter-1-link").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-link").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-link").style.display = "none";'
      ];
      jsCode.forEach((String js) {
        controller?.evaluateJavascript(source: js);
      });
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        // Define the default brightness and colors.
        brightness: Brightness.dark,
        primaryColor: Colors.grey[900],
        accentColor: Colors.black,
      ),
      home: Scaffold(
          appBar: AppBar(
            title: Padding(
                padding: EdgeInsets.only(right: 0.0),
                child: GestureDetector(
                    onTap: () {
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse(
                                  "https://medium.com/topic/popular")));
                    },
                    child: Text("Medium Unlimited"))),
            actions: <Widget>[
              Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: GestureDetector(
                    onTap: () {
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.goBack();
                    },
                    child: Icon(
                      Icons.arrow_back,
                    ),
                  )),
              Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: GestureDetector(
                    onTap: () {
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.goForward();
                    },
                    child: Icon(
                      Icons.arrow_forward,
                    ),
                  )),
              Padding(
                  padding: EdgeInsets.only(right: 20.0),
                  child: GestureDetector(
                    onTap: () {
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.reload();
                    },
                    child: Icon(Icons.refresh),
                  )),
            ],
          ),
          body: SafeArea(
              child: Column(children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: 15.0),
              child: TextField(
                controller: urlController,
                keyboardType: TextInputType.url,
                onSubmitted: (value) {
                  var url = Uri.parse(value);
                  if (url.scheme.isEmpty) {
                    url = Uri.parse("https://www.google.com/search?q=" + value);
                  }
                  webViewController?.loadUrl(urlRequest: URLRequest(url: url));
                },
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    initialUrlRequest: URLRequest(url: Uri.parse(url)),
                    initialOptions: options,
                    pullToRefreshController: pullToRefreshController,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                      if (webViewController != null) {
                        removeElements(controller);
                      }
                    },
                    onLoadStart: (controller, url) {
                      if (webViewController != null) {
                        removeElements(controller);
                        controller.clearCache();
                        final cookieManager = CookieManager();
                        cookieManager.deleteAllCookies();
                      }
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    androidOnPermissionRequest:
                        (controller, origin, resources) async {
                      return PermissionRequestResponse(
                          resources: resources,
                          action: PermissionRequestResponseAction.GRANT);
                    },
                    shouldOverrideUrlLoading:
                        (controller, navigationAction) async {
                      var uri = navigationAction.request.url!;

                      if (![
                        "http",
                        "https",
                        "file",
                        "chrome",
                        "data",
                        "javascript",
                        "about"
                      ].contains(uri.scheme)) {
                        if (await canLaunch(url)) {
                          // Launch the App
                          await launch(
                            url,
                          );
                          // and cancel the request
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onLoadError: (controller, url, code, message) {
                      pullToRefreshController.endRefreshing();
                    },
                    onProgressChanged: (controller, progress) {
                      if (progress >= 65 && progress <= 75) {
                        if (webViewController != null) {
                          removeElements(controller);
                        }
                      }
                      if (progress >= 100) {
                        pullToRefreshController.endRefreshing();
                        if (webViewController != null) {
                          removeElements(controller);
                        }
                      }
                      setState(() {
                        this.progress = progress / 100;
                        urlController.text = this.url;
                      });
                    },
                    onUpdateVisitedHistory: (controller, url, androidIsReload) {
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage);
                    },
                  ),
                  progress < 1.0
                      ? LinearProgressIndicator(value: progress)
                      : Container(),
                ],
              ),
            ),
          ]))),
    );
  }
}
