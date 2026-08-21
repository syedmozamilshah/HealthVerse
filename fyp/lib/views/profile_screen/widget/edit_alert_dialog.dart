import 'package:flutter/material.dart';

import '../../../utils/validators.dart';
import '../../color/colors.dart';

class EditAlertDialog {
  Future<String?> editDialog(BuildContext context, String title,
      {String? initialText}) async {
    final TextEditingController controller =
        TextEditingController(text: initialText ?? '');

    String? result = await showDialog<String>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              "Edit $title",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: "New $title",
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      hintText: "Enter new $title",
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        // If editing Address, validate it first
                        if (title.toLowerCase().contains('address')) {
                          final addrError =
                              Validators.validateAddress(controller.text);
                          if (addrError != null) {
                            setState(() => errorText = addrError);
                            return;
                          }
                        }
                        Navigator.of(context).pop(controller.text.trim());
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: tealColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );

    return result;
  }

  /// Edit dialog with separate first name and last name fields
  Future<Map<String, String>?> editNameDialog(BuildContext context,
      String currentFirstName, String currentLastName) async {
    final TextEditingController firstNameController =
        TextEditingController(text: currentFirstName);
    final TextEditingController lastNameController =
        TextEditingController(text: currentLastName);

    Map<String, String>? result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        String? errorText;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              "Edit Name",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 20,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // First Name Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: firstNameController,
                    autofocus: true,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: "First Name",
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      hintText: "Enter first name",
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Last Name Field
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: TextField(
                    controller: lastNameController,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: "Last Name",
                      labelStyle: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                      hintText: "Enter last name",
                      hintStyle: TextStyle(
                        color: Colors.grey[400],
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                if (errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      errorText!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
              ],
            ),
            actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            actions: [
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, null),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        final fName = firstNameController.text.trim();
                        final lName = lastNameController.text.trim();

                        // Apply same rules as registration: first/last min 3 chars and allowed chars
                        final namePattern = RegExp(r"^[a-zA-Z\s\-']+");
                        if (fName.isEmpty || fName.length < 3) {
                          setState(() => errorText =
                              'First name must be at least 3 characters');
                          return;
                        }
                        if (!namePattern.hasMatch(fName)) {
                          setState(() => errorText =
                              'First name contains invalid characters');
                          return;
                        }

                        if (lName.isNotEmpty) {
                          if (lName.length < 3) {
                            setState(() => errorText =
                                'Last name must be at least 3 characters');
                            return;
                          }
                          if (!namePattern.hasMatch(lName)) {
                            setState(() => errorText =
                                'Last name contains invalid characters');
                            return;
                          }
                        }

                        Navigator.of(context).pop({
                          'firstName': fName,
                          'lastName': lName,
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: tealColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          );
        });
      },
    );

    return result;
  }
}
