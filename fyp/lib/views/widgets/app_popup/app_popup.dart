import 'package:flutter/material.dart';
import 'package:fyp/views/color/colors.dart';
import 'package:responsive_sizer/responsive_sizer.dart';

enum PopupType { success, error, warning, info }

class AppPopup {
  static void show(
    BuildContext context, {
    required String message,
    String? title,
    PopupType type = PopupType.info,
    VoidCallback? onDismiss,
    Duration duration = const Duration(seconds: 3),
    bool autoDismiss = true,
  }) {
    // Determine icon, color, and default title based on type
    IconData icon;
    Color primaryColor;
    String defaultTitle;

    switch (type) {
      case PopupType.success:
        icon = Icons.check_circle_rounded;
        primaryColor = tealColor;
        defaultTitle = 'Success';
        break;
      case PopupType.error:
        icon = Icons.error_rounded;
        primaryColor = const Color(0xFFE53935);
        defaultTitle = 'Error';
        break;
      case PopupType.warning:
        icon = Icons.warning_rounded;
        primaryColor = const Color(0xFFFFA726);
        defaultTitle = 'Warning';
        break;
      case PopupType.info:
        icon = Icons.info_rounded;
        primaryColor = tealColor;
        defaultTitle = 'Information';
        break;
    }

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, animation, secondaryAnimation) {
        return const SizedBox.shrink();
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: curvedAnimation,
          child: FadeTransition(
            opacity: animation,
            child: _PopupContent(
              message: message,
              title: title ?? defaultTitle,
              icon: icon,
              primaryColor: primaryColor,
              type: type,
              onDismiss: onDismiss,
              autoDismiss: autoDismiss,
              duration: duration,
            ),
          ),
        );
      },
    );
  }

  // Convenience methods
  static void success(BuildContext context, String message, {String? title, VoidCallback? onDismiss}) {
    show(context, message: message, title: title, type: PopupType.success, onDismiss: onDismiss);
  }

  static void error(BuildContext context, String message, {String? title, VoidCallback? onDismiss}) {
    show(context, message: message, title: title, type: PopupType.error, onDismiss: onDismiss, autoDismiss: false);
  }

  static void warning(BuildContext context, String message, {String? title, VoidCallback? onDismiss}) {
    show(context, message: message, title: title, type: PopupType.warning, onDismiss: onDismiss);
  }

  static void info(BuildContext context, String message, {String? title, VoidCallback? onDismiss}) {
    show(context, message: message, title: title, type: PopupType.info, onDismiss: onDismiss);
  }
}

class _PopupContent extends StatefulWidget {
  final String message;
  final String title;
  final IconData icon;
  final Color primaryColor;
  final PopupType type;
  final VoidCallback? onDismiss;
  final bool autoDismiss;
  final Duration duration;

  const _PopupContent({
    required this.message,
    required this.title,
    required this.icon,
    required this.primaryColor,
    required this.type,
    this.onDismiss,
    required this.autoDismiss,
    required this.duration,
  });

  @override
  State<_PopupContent> createState() => _PopupContentState();
}

class _PopupContentState extends State<_PopupContent> {
  @override
  void initState() {
    super.initState();
    if (widget.autoDismiss) {
      Future.delayed(widget.duration, () {
        if (mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          widget.onDismiss?.call();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: double.infinity,
            constraints: BoxConstraints(maxWidth: 85.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: widget.primaryColor.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 2.5.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        widget.primaryColor,
                        widget.primaryColor.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: EdgeInsets.all(3.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          widget.icon,
                          color: Colors.white,
                          size: 28.sp,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      Text(
                        widget.title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                // Message content
                Padding(
                  padding: EdgeInsets.all(5.w),
                  child: Column(
                    children: [
                      Text(
                        widget.message,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[800],
                          fontSize: 16.sp,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 2.5.h),
                      // OK Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onDismiss?.call();
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primaryColor,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 1.5.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'OK',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper function to replace reusableSnackBar - maintains same signature for easy migration
void showAppPopup(BuildContext context, String message, {PopupType? type, VoidCallback? onDismiss, Duration? duration, bool autoDismiss = true}) {
  // Determine type based on message content for smart defaults
  PopupType popupType = type ?? _inferPopupType(message);
  AppPopup.show(
    context, 
    message: message, 
    type: popupType, 
    onDismiss: onDismiss,
    duration: duration ?? const Duration(seconds: 3),
    autoDismiss: autoDismiss,
  );
}

PopupType _inferPopupType(String message) {
  final lowerMessage = message.toLowerCase();
  
  // Success indicators
  if (lowerMessage.contains('success') ||
      lowerMessage.contains('confirmed') ||
      lowerMessage.contains('saved') ||
      lowerMessage.contains('updated') ||
      lowerMessage.contains('welcome') ||
      lowerMessage.contains('sent') ||
      lowerMessage.contains('complete')) {
    return PopupType.success;
  }
  
  // Error indicators
  if (lowerMessage.contains('error') ||
      lowerMessage.contains('failed') ||
      lowerMessage.contains('invalid') ||
      lowerMessage.contains('cannot') ||
      lowerMessage.contains('unable') ||
      lowerMessage.contains('not found') ||
      lowerMessage.contains('unauthorized')) {
    return PopupType.error;
  }
  
  // Warning indicators
  if (lowerMessage.contains('please') ||
      lowerMessage.contains('must') ||
      lowerMessage.contains('required') ||
      lowerMessage.contains('already') ||
      lowerMessage.contains('enter') ||
      lowerMessage.contains('select') ||
      lowerMessage.contains('fill')) {
    return PopupType.warning;
  }
  
  return PopupType.info;
}
