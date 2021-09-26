import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:back_button_interceptor/back_button_interceptor.dart';
import 'package:share/share.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future main() async {
  WidgetsFlutterBinding.ensureInitialized();
  /*if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }*/
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSwatch(
              primarySwatch: Colors.grey,
              primaryColorDark: Colors.grey[700],
              accentColor: Colors.grey[700],
              brightness: Brightness.dark,
              backgroundColor: Colors.grey[900])
          .copyWith(
        secondary: Colors.green,
      ),
      textTheme: const TextTheme(bodyText2: TextStyle(color: Colors.purple)),
    ),
    /*theme: ThemeData(
      brightness: Brightness.dark,
      primaryColor: Colors.grey[500],
      primarySwatch: Colors.grey,
      colorScheme: ColorScheme.fromSwatch().copyWith(
          primary: Colors.grey[500],
          secondary: Colors.black,
          background: Colors.black),
    ),*/
    home: HomeScreen(),
  ));
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class DropdownChoices {
  const DropdownChoices({this.title = '', this.icon = Icons.access_alarm});

  final String title;
  final IconData icon;
}

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey webViewKey = GlobalKey();

  GlobalKey<ScaffoldState> _scaffoldKey = new GlobalKey<ScaffoldState>();

  List<DropdownChoices> dropdownChoices = <DropdownChoices>[
    DropdownChoices(title: 'Back', icon: Icons.arrow_back),
    DropdownChoices(title: 'Forward', icon: Icons.arrow_forward),
    DropdownChoices(title: 'Share', icon: Icons.share),
    DropdownChoices(title: 'Source Code', icon: Icons.code),
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
      android: AndroidInAppWebViewOptions(
          //useHybridComposition: true, //CRASH WHEN APP OPENED FROM INTENT IF USED WITH useHybridComposition
          clearSessionCache: true,
          forceDark: AndroidForceDark.FORCE_DARK_ON),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

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

  List<String>? favouriteLinks = <String>[];

  loadFavouriteLinks() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    favouriteLinks = prefs.getStringList('favourite_links');
    if (favouriteLinks == null) {
      setState(() {
        favouriteLinks = [];
      });
    }
  }

  addFavouriteLinks(String value) async {
    if (favouriteLinks == null) {
      setState(() {
        favouriteLinks = [];
      });
    }
    setState(() {
      if (value.length > 5) {
        favouriteLinks?.add(value);
      }
    });
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('favourite_links', favouriteLinks!);
  }

  deleteFavouriteLinks(String value) async {
    if (favouriteLinks == null) {
      setState(() {
        favouriteLinks = [];
      });
    }
    for (var i = 0; i < favouriteLinks!.length.toInt(); i++) {
      if (favouriteLinks!.elementAt(i) == value.toString()) {
        setState(() {
          favouriteLinks?.remove(value);
        });
      }
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setStringList('favourite_links', favouriteLinks!);
  }

  TextEditingController _textFieldController = TextEditingController();
  Future<void> _displayTextInputDialog(
      BuildContext context, String text) async {
    webViewController
        ?.getUrl()
        .then((value) => _textFieldController.text = value.toString());
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Enter link'),
            content: TextField(
              onChanged: (value) {
                setState(() {});
              },
              controller: _textFieldController,
              decoration: InputDecoration(hintText: "Url"),
            ),
            actions: <Widget>[
              TextButton(
                child: Text('Cancel'),
                onPressed: () {
                  setState(() {
                    _textFieldController.text = '';
                  });
                  Navigator.pop(context);
                },
              ),
              TextButton(
                child: Text('Add'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        });
  }

  showAlertDialogDeleteLink(BuildContext context, String item) {
    Widget cancelButton = TextButton(
      child: Text("No"),
      onPressed: () {
        Navigator.pop(context);
      },
    );
    Widget continueButton = TextButton(
      child: Text("Yes"),
      onPressed: () {
        deleteFavouriteLinks(item);
        Navigator.pop(context);
      },
    );
    AlertDialog alert = AlertDialog(
      title: Text("Confirm delete"),
      content: Text("Delete the selected link?"),
      actions: [
        cancelButton,
        continueButton,
      ],
    );
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return alert;
      },
    );
  }

  @override
  void initState() {
    try {
      super.initState();

      url = urlDefault;

      loadFavouriteLinks();

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
        'document.getElementsByClassName("branch-journeys-top").item(0).style.display = "none";',
        'document.getElementById("cv cw cx cy aj cz da s").style.display = "none";',
        'document.getElementsByClassName("mn u gs mo aj mp mq mr ms mt mu mv mw mx my mz na nb nc nd ne nf ng nh ni nj nk nl nm nn no np nq nr ns nt").item(0).style.display = "none";',
        'document.getElementById("animated-container").style.display = "none";',
        'document.getElementsByClassName("ac ae af ag ah ai aj ak al").item(0).style.display = "none";',
        'document.getElementById("credentials-picker-container").style.display = "none";',
        'document.getElementsByClassName("ah ai ix iy af iz ja jb jc jd je jf jg jh ji jj jk jl jm jn jo jp jq jr js jt ju jv jw jx jy jz ka kb kc kd").item(0).style.display = "none";',
        'document.getElementById("lo-highlight-meter-1-link").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-link").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-link").style.display = "none";',
        'document.getElementsByClassName("tv").item(0).click();',
        'document.getElementsByClassName("bv bw bx by bz ca cb cc bb cd tw tx cg to tp").item(0).click();',
        'document.getElementsByClassName("s hw u w").item(0).click();',
        'document.getElementsById("close").click();',
        'document.getElementById("kx u kz sy sz ta tb tc td te tf tg th ti dj cw tj tk tl").style.display = "none";',
        'document.getElementByClassName("haAclf WsjYwc-haAclf").item(0).style.display = "none";',
        'document.getElementByClassName("us s ut uu").item(0).style.display = "none";',
        'document.getElementByClassName("s c").item(0).style.display = "none";',
        'document.getElementByClassName("s ap x").item(0).style.display = "none";'
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

    if (choice.title == "Source Code") {
      webViewController
          ?.getHtml()
          .then((value) => Share.share(value.toString()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
        child: DefaultTabController(
          length: 2,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Container(
                margin: EdgeInsets.all(0),
                color: Colors.black12,
                height: 110,
                child: DrawerHeader(
                  child: ListTile(
                    leading: Icon(Icons.rss_feed),
                    contentPadding: EdgeInsets.only(left: 0.0, right: 0.0),
                    title: Text('Medium.com'),
                    onTap: () {
                      webViewController?.stopLoading();
                      webViewController?.clearCache();
                      webViewController?.loadUrl(
                          urlRequest:
                              URLRequest(url: Uri.parse("https://medium.com")));
                      Navigator.pop(context);
                    },
                  ),
                ),
              ),
              Container(
                height: 52,
                color: Colors.black12,
                child: TabBar(
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorColor: Colors.black12,
                    indicatorWeight: 1,
                    tabs: [
                      Tab(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.label,
                            ),
                            SizedBox(
                              width: 10.0,
                            ),
                            Text(
                              "Topics",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                      Tab(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Icon(
                              Icons.star,
                            ),
                            SizedBox(
                              width: 10.0,
                            ),
                            Text(
                              "Links",
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ]),
              ),
              Expanded(
                child: Container(
                  child: TabBarView(children: [
                    Container(
                      child: Container(
                        color: Colors.grey[900],
                        width: double.infinity,
                        height: double.infinity,
                        child: ListView(
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              ListTile(
                                leading: Icon(Icons.trending_up),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Popular'),
                                onTap: () {
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
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/topic/self")));
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.favorite_outline),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Relationships'),
                                onTap: () {
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
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/topic/programming")));
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.science),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Science'),
                                onTap: () {
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/topic/science")));
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.people),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Society'),
                                onTap: () {
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/topic/society")));
                                  Navigator.pop(context);
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.computer),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Technology'),
                                onTap: () {
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/topic/technology")));
                                  Navigator.pop(context);
                                },
                              ),
                            ]),
                      ),
                    ),
                    Container(
                      child: Container(
                        color: Colors.grey[900],
                        width: double.infinity,
                        height: double.infinity,
                        child: ListView(
                            padding: EdgeInsets.zero,
                            children: <Widget>[
                              ListTile(
                                leading: Icon(Icons.add_link),
                                title: Text('Add link'),
                                onTap: () async {
                                  await _displayTextInputDialog(
                                      context, _textFieldController.text);
                                  addFavouriteLinks(_textFieldController.text);
                                  Navigator.pop(context);
                                },
                              ),
                              Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: Colors.grey[850]),
                              for (var i = 0;
                                  i < favouriteLinks!.length.toInt();
                                  i++)
                                ListTile(
                                  leading: Icon(Icons.link),
                                  trailing: Icon(Icons.keyboard_arrow_right),
                                  title: Text(favouriteLinks!.elementAt(i)),
                                  onLongPress: () {
                                    showAlertDialogDeleteLink(
                                        context, favouriteLinks!.elementAt(i));
                                  },
                                  onTap: () {
                                    webViewController?.stopLoading();
                                    webViewController?.clearCache();
                                    webViewController?.loadUrl(
                                        urlRequest: URLRequest(
                                            url: Uri.parse(
                                                favouriteLinks!.elementAt(i))));
                                    Navigator.pop(context);
                                  },
                                ),
                            ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
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
                url = Uri.parse(urlDefault);
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
                shouldOverrideUrlLoading: (controller, navigationAction) async {
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
              progress < 2.0
                  ? LinearProgressIndicator(value: progress)
                  : Container(),
            ],
          ),
        ),
      ])),
    );
  }
}
