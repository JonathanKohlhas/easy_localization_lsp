Future<void> suspendToScheduler() async {
  await Future.delayed(Duration(microseconds: 1), () {});
}
