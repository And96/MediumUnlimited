import 'dart:async';
//import 'dart:io';
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

bool hybridComposition = true;

class _HomeScreenState extends State<HomeScreen> {
  final GlobalKey webViewKey = GlobalKey();

  String urlDefault = "https://medium.com/tag/popular";
  String url = "";

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
          useHybridComposition:
              hybridComposition, //CRASH WHEN APP OPENED FROM INTENT IF USED WITH useHybridComposition
          clearSessionCache: true,
          forceDark: AndroidForceDark.FORCE_DARK_ON),
      ios: IOSInAppWebViewOptions(
        allowsInlineMediaPlayback: true,
      ));

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
        hybridComposition = false;
        if (value.toString().length > 5) {
          this.url = value;
          webViewController!.loadUrl(
              urlRequest: URLRequest(url: Uri.parse(value.toString())));
        }
      }, onError: (err) {
        print("getLinkStream error: $err");
      });

      // For sharing or opening urls/text coming from outside the app while the app is closed
      ReceiveSharingIntent.getInitialText().then((String? value) {
        hybridComposition = false;
        if (value.toString().length > 5) {
          this.url = value.toString();
          webViewController!.loadUrl(
              urlRequest: URLRequest(url: Uri.parse(value.toString())));
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
        'document.querySelector(`[data-testid="close-button"]`).click();',
        'document.querySelector(`[aria-label="Chiudi"]`).click();',
        'document.querySelectorAll("div").forEach( el => {if (el.ariaLabel.toUpperCase().includes("CLOSE")){el.Click()}});',
        'document.querySelectorAll("div").forEach( el => {if (el.ariaLabel.toUpperCase().includes("CHIUDI")){el.Click()}});',
        'document.getElementById("header-lohp-header-start-writing-button").style.display = "none";',
        'document.getElementById("top-nav-our-story-cta-desktop").style.display = "none";',
        'document.getElementById("top-nav-membership-cta-desktop").style.display = "none";',
        'document.getElementById("top-nav-write-cta-desktop").style.display = "none";',
        'document.getElementById("top-nav-sign-in-cta-desktop").style.display = "none";',
        'document.getElementById("top-nav-logo").style.display = "none";',
        'document.getElementById("header-background-color").style.display = "none";',
        'document.getElementById("lo-meta-header-sign-up-button").style.display = "none";',
        'document.getElementById("lo-meta-header-sign-in-link").style.display = "none";',
        'document.getElementById("header-background-color").style.display = "none";',
        'document.getElementById("top-nav-get-started-cta").style.display = "none";',
        'document.getElementById("lo-highlight-meter-1-copy").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-copy").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-copy").style.display = "none";',
        'document.getElementById("lo-highlight-meter-1-highlight-box").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-highlight-box").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-highlight-box").style.display = "none";',
        'document.getElementsByClassName("branch-journeys-top")[0].style.display = "none";',
        'document.getElementById("cv cw cx cy aj cz da s").style.display = "none";',
        'document.getElementsByClassName("mn u gs mo aj mp mq mr ms mt mu mv mw mx my mz na nb nc nd ne nf ng nh ni nj nk nl nm nn no np nq nr ns nt")[0].style.display = "none";',
        'document.getElementById("animated-container").style.display = "none";',
        'document.getElementsByClassName("ac ae af ag ah ai aj ak al")[0].style.display = "none";',
        'document.getElementById("credentials-picker-container").style.display = "none";',
        'document.getElementsByClassName("ah ai ix iy af iz ja jb jc jd je jf jg jh ji jj jk jl jm jn jo jp jq jr js jt ju jv jw jx jy jz ka kb kc kd")[0].style.display = "none";',
        'document.getElementById("lo-highlight-meter-1-link").style.display = "none";',
        'document.getElementById("lo-highlight-meter-2-link").style.display = "none";',
        'document.getElementById("lo-highlight-meter-3-link").style.display = "none";',
        'document.getElementsByClassName("tv")[0].click();',
        'document.getElementsByClassName("bv bw bx by bz ca cb cc bb cd tw tx cg to tp")[0].click();',
        'document.getElementsByClassName("s hw u w")[0].click();',
        'document.getElementsById("close").click();',
        'document.getElementById("kx u kz sy sz ta tb tc td te tf tg th ti dj cw tj tk tl").style.display = "none";',
        'document.getElementsByClassName("haAclf WsjYwc-haAclf")[0].style.display = "none";',
        'document.getElementsByClassName("us s ut uu")[0].style.display = "none";',
        'document.getElementsByClassName("s c")[0].style.display = "none";',
        'document.getElementsByClassName("s ap x")[0].style.display = "none";',
        'document.getElementsByClassName("n cp ng nh")[0].style.display = "none";',
        'document.getElementsByClassName("bf b gk bh nf")[0].style.display = "none";',
        'document.getElementsByClassName("ea eb ce cf cg ch ci cj ck bq cl ni nj lf)[0].style.display = "none";',
        'document.getElementsByClassName("bf b bg bh dx")[0].style.display = "none";',
        'document.getElementById("lo-ShowPostUnderCollection-navbar-open-in-app-button").style.display = "none";',
        'document.getElementsByClassName("bi bl ce cf cg ch ci cj ck bq bn bo cl lh li")[0].style.display = "none";',
        'document.getElementsByClassName("wv ww wx wy wz xa n cp")[0].style.display = "none";',
        'document.getElementsByClassName("aq xc xd xe cr")[0].style.display = "none";',
        'document.getElementsByClassName("aq xg mb cr nh")[0].style.display = "none";',
        'document.getElementsByClassName("xn xo xp xq sd xr zf")[0].style.display = "none";',
        'document.getElementsByClassName("yz n o p")[0].style.display = "none";',
        'document.getElementsByClassName("newsletter email_icon orange default")[0].style.display = "none";',
        'document.getElementById("sliderbox").style.display = "none";',
        'document.body.innerHTML = document.body.innerHTML.replace(/To make Medium work, we log user data. By using Medium, you agree to our/g, "");',
        'document.body.innerHTML = document.body.innerHTML.replace(/Privacy Policy/g, "");',
        'document.body.innerHTML = document.body.innerHTML.replace(/, including cookie policy./g, "");',
        'document.body.innerHTML = document.body.innerHTML.replace(/To make Medium work, we log user data./g, "");',
        'document.getElementsByClassName("ay az ba bb bc bd be bf bg bh jw jx bk jl jm").item(0).click();',
        'document.querySelector("ex ez hy lg lh li lj lk ll lm ln lo lp lq ga fp lr ls lt").style.cssText = `display: none;`',
        'document.cookie.split(";").forEach(function(c) { document.cookie = c.replace(/^ +/, "").replace(/=.*/, "=;expires=" + new Date().toUTCString() + ";path=/"); });',
        'window.localStorage.clear();',
        'sessionStorage.clear();'
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
                      FocusScope.of(context).unfocus();
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
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/popular")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.person),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Self'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/self")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.favorite_outline),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Relationships'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/relationships")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.work),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Productivity'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/productivity")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.healing),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Health'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/health")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.code),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Programming'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/programming")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.science),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Science'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/science")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.people),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Society'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/society")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
                                },
                              ),
                              ListTile(
                                leading: Icon(Icons.computer),
                                trailing: Icon(Icons.keyboard_arrow_right),
                                title: Text('Technology'),
                                onTap: () {
                                  FocusScope.of(context).unfocus();
                                  webViewController?.stopLoading();
                                  webViewController?.clearCache();
                                  webViewController?.loadUrl(
                                      urlRequest: URLRequest(
                                          url: Uri.parse(
                                              "https://medium.com/tag/technology")));
                                  Navigator.pop(context);
                                  FocusManager.instance.primaryFocus!.unfocus();
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
                                    FocusScope.of(context).unfocus();
                                    webViewController?.stopLoading();
                                    webViewController?.clearCache();
                                    webViewController?.loadUrl(
                                        urlRequest: URLRequest(
                                            url: Uri.parse(
                                                favouriteLinks!.elementAt(i))));
                                    Navigator.pop(context);
                                    FocusManager.instance.primaryFocus!
                                        .unfocus();
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
              if (!value.toString().toLowerCase().contains('http')) {
                if (value.toString().contains('.')) {
                  value = "https://" + value;
                }
              }
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
                onLoadStop: (controller, url) async {
                  setState(() {
                    removeElements(controller);
                  });
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
                /*onLoadError: (controller, url, code, message) {
                    },*/
                onProgressChanged: (controller, progress) {
                  if (progress >= 95 && progress <= 97) {
                    if (webViewController != null) {
                      removeElements(webViewController);
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
