import 'package:flutter_riverpod/flutter_riverpod.dart';

class MyNotifier extends Notifier<String> {
  final String arg;
  MyNotifier(this.arg);

  @override
  String build() {
    return arg;
  }
}

final myProvider = NotifierProvider.family<MyNotifier, String, String>(
  (arg) => MyNotifier(arg),
);

void main() {
  print(myProvider);
}
