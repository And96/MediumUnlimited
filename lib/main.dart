import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:share/share.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /*if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }*/
  runApp(new MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class DropdownChoices {
  const DropdownChoices({this.title = '', this.icon = Icons.access_alarm});

  final String title;
  final IconData icon;
}

class _MyAppState extends State<MyApp> {
  final GlobalKey webViewKey = GlobalKey();

  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  List<DropdownChoices> dropdownChoices = <DropdownChoices>[
    DropdownChoices(title: 'Back', icon: Icons.arrow_back),
    DropdownChoices(title: 'Forward', icon: Icons.arrow_forward),
    DropdownChoices(title: 'Share', icon: Icons.share),
  ];

  InAppWebViewController? webViewController;
  InAppWebViewGroupOptions options = InAppWebViewGroupOptions(
      crossPlatform: InAppWebViewOptions(
        javaScriptCanOpenWindowsAutomatically: false,
        useShouldOverrideUrlLoading: true,
        mediaPlaybackRequiresUserGesture: true,
        cacheEnabled: false,
        incognito: true,
        clearCache: true,
      ),
      //CRASH WHEN APP OPENED FROM INTENT IF USED WITH useHybridComposition
      /*android: AndroidInAppWebViewOptions(
        useHybridComposition: true,
        clearSessionCache: true,
      ),*/
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

  //late PullToRefreshController pullToRefreshController;

  String urlDefault = "https://medium.com/topic/popular";
  String url = "";
  double progress = 0;
  final urlController = TextEditingController();

  StreamSubscription? _intentDataStreamSubscription;

  bool myInterceptor(bool stopDefaultButtonEvent, RouteInfo info) {
    webViewController?.stopLoading();
    webViewController?.clearCache();
    webViewController?.goBack();
    return true;
  }

  @override
  void initState() {
    try {
      super.initState();

      url = urlDefault;

      BackButtonInterceptor.add(myInterceptor);

      // For sharing or opening urls/text coming from outside the app while the app is in the memory
      _intentDataStreamSubscription =
          ReceiveSharingIntent.getTextStream().listen((String value) {
        if (value.toString().length > 5) {
          this.url = value;
        }
      }, onError: (err) {
        print("getLinkStream error: $err");
      });

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialText().then((String? value) {
        if (value.toString().length > 5) {
          this.url = value.toString();
        }
      });
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    BackButtonInterceptor.remove(myInterceptor);
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  void removeElements(InAppWebViewController? controller) {
    try {
      List<String> jsCode = [
        'document.cookie.split(";").forEach(function(c) { document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); });',
        'window.localStorage.clear();',
        'sessionStorage.clear();',
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

  void choiceAction(DropdownChoices choice) {
    if (choice.title == "Back") {
      webViewController?.stopLoading();
      webViewController?.clearCache();
      webViewController?.goBack();
    }

    if (choice.title == "Forward") {
      webViewController?.stopLoading();
      webViewController?.clearCache();
      webViewController?.goForward();
    }

    if (choice.title == "Share") {
      webViewController?.stopLoading();
      webViewController?.clearCache();
      webViewController
          ?.getUrl()
          .then((value) => Share.share(value.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.grey[900],
        accentColor: Colors.black,
      ),
      home: Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
              title: Padding(
                  padding: EdgeInsets.only(right: 0.0),
                  child: Text("Medium Unlimited")),
              actions: <Widget>[
                IconButton(
                  icon: Icon(Icons.refresh),
                  onPressed: () {
                    webViewController?.stopLoading();
                    webViewController?.clearCache();
                    webViewController?.reload();
                  },
                ),
                PopupMenuButton<DropdownChoices>(
                  color: Colors.grey[900],
                  onSelected: choiceAction,
                  elevation: 6,
                  itemBuilder: (BuildContext context) {
                    return dropdownChoices.map((DropdownChoices choice) {
                      return PopupMenuItem<DropdownChoices>(
                        value: choice,
                        child: Row(
                          children: <Widget>[
                            Padding(
                              padding: EdgeInsets.only(right: 15.0),
                              child: Icon(choice.icon),
                            ),
                            Text(choice.title),
                          ],
                        ),
                      );
                    }).toList();
                  },
                ),
              ]),
          drawer: Drawer(
            child: Container(
              //child: Your widget,
              color: Colors.grey[900],
              width: double.infinity,
              height: double.infinity,
              child: ListView(
                padding: EdgeInsets.zero,
                children: <Widget>[
                  new SizedBox(
                    height: 120.0,
                    child: DrawerHeader(
                      child: ListTile(
                        leading: Icon(Icons.rss_feed),
                        contentPadding: EdgeInsets.only(left: 0.0, right: 0.0),
                        title: Text('Medium.com'),
                        onTap: () {
                          _scaffoldKey.currentState?.openEndDrawer();
                          webViewController?.stopLoading();
                          webViewController?.clearCache();
                          webViewController?.loadUrl(
                              urlRequest: URLRequest(
                                  url: Uri.parse("https://medium.com")));
                          Navigator.pop(context);
                        },
                      ),
                      decoration: BoxDecoration(color: Colors.grey[850]),
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.trending_up),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    title: Text('Popular'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse(
                                  "https://medium.com/topic/popular")));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.person),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    title: Text('Self'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse("https://medium.com/topic/self")));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.people),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    title: Text('Relationships'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse(
                                  "https://medium.com/topic/relationships")));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.work),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    title: Text('Productivity'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse(
                                  "https://medium.com/topic/productivity")));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.healing),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    title: Text('Health'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse(
                                  "https://medium.com/topic/health")));
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.code),
                    trailing: Icon(Icons.keyboard_arrow_right),
                    title: Text('Programming'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(
                              url: Uri.parse(
                                  "https://medium.com/topic/programming")));
                      Navigator.pop(context);
                    },
                  ),
                  Divider(height: 1, thickness: 1, color: Colors.grey[850]),
                  ListTile(
                    leading: Icon(Icons.add_link),
                    title: Text('Add link'),
                    onTap: () {
                      _scaffoldKey.currentState?.openEndDrawer();
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest: URLRequest(url: Uri.parse(urlDefault)));
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
            ),
          ),
          body: SafeArea(
              child: Column(children: <Widget>[
            Padding(
              padding: EdgeInsets.only(left: 15.0),
              child: GestureDetector(
                child: TextField(
                  controller: urlController,
                  keyboardType: TextInputType.url,
                  onSubmitted: (value) {
                    var url = Uri.parse(value);
                    if (url.scheme.isEmpty) {
                      url = Uri.parse(urlDefault);
                    }
                    webViewController?.loadUrl(
                        urlRequest: URLRequest(url: url));
                  },
                ),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  InAppWebView(
                    key: webViewKey,
                    initialUrlRequest: URLRequest(url: Uri.parse(url)),
                    initialOptions: this.options,
                    onWebViewCreated: (controller) {
                      webViewController = controller;
                      var address = Uri.parse(url);
                      if (address.scheme.isEmpty == false) {
                        webViewController?.loadUrl(
                            urlRequest: URLRequest(url: address));
                      }
                      removeElements(controller);
                    },
                    onLoadStart: (controller, url) {
                      removeElements(controller);
                      controller.clearCache();
                      final cookieManager = CookieManager();
                      cookieManager.deleteAllCookies();
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
                          await launch(
                            url,
                          );
                          return NavigationActionPolicy.CANCEL;
                        }
                      }

                      return NavigationActionPolicy.ALLOW;
                    },
                    onLoadStop: (controller, url) async {
                      //pullToRefreshController.endRefreshing();
                      setState(() {
                        this.url = url.toString();
                        urlController.text = this.url;
                      });
                    },
                    /*onLoadError: (controller, url, code, message) {
                    },*/
                    onProgressChanged: (controller, progress) {
                      if (progress >= 60 && progress <= 70) {
                        if (webViewController != null) {
                          removeElements(controller);
                        }
                      }
                      if (progress == 100) {
                        if (webViewController != null) {
                          removeElements(controller);
                          controller.clearCache();
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
                    /*onConsoleMessage: (controller, consoleMessage) {
                      print(consoleMessage);
                    },*/
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
