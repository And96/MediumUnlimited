# Medium Unlimited

An Android application written with Flutter/Dart to read medium.com without limitations. 

## Features
 - Read medium without reading limits
 - Dark mode for all pages
 - Common topics (Sidebar)
 - Favourite links (Sidebar)
 - Open links shared by others apps

 ## Screenshot
<img src="https://raw.githubusercontent.com/And96/MediumUnlimited/main/docs/Screenshot_1.jpg" width="900" height="500">

 ## Faq

 **How does it work (For users)?**

 The app works like a browser. Just navigate. 
 
 **How does it work (For developers)?**

 Under the hood, there is the package InAppWebView which clear cookies/data everytime the page change.

 **Can I login to Medium?**

 No. Read as a guest.

 **Which websites are supported?**

 It's built for Medium, but it works with custom domains too. (E.g. betterprogramming.pub) Potentially it can work with every website.

 **Does it unlock other browsers?**

 No. No other apps are involved. Everyting works only inside in this app.

## How to build
```
flutter packages get
flutter packages pub run flutter_launcher_icons:main
flutter pub run change_app_package_name:main com.medium.unlimited
flutter build apk --release
```

## Download
[Latest APK here](https://github.com/And96/MediumUnlimited/releases/latest)
