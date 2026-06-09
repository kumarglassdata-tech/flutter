import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

void goBackOr(BuildContext context, String fallbackRoute) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(fallbackRoute);
  }
}