import 'package:flutter/material.dart';
import 'package:fyp/views/widgets/app_popup/app_popup.dart';

/// Shows a professional popup dialog instead of a snackbar.
/// This function maintains backward compatibility with existing code.
void reusableSnackBar(BuildContext context, String text, {VoidCallback? onDismiss, bool autoDismiss = true}) {
  showAppPopup(context, text, onDismiss: onDismiss, autoDismiss: autoDismiss);
}