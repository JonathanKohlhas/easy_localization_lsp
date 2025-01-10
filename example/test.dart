extension StringExtension on String {
  void tr({String? gender}) {
    print("Translate $this");
  }

  void plural(int count) {
    print("Plural $this $count");
  }
}

void main() {
  "group.h".tr();
  "group.plural".plural(1);
}
