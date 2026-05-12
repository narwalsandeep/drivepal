import 'dart:html' as html;

Future<void> openCurrentTabUrlImpl(String url) async {
  html.window.location.assign(url);
}
