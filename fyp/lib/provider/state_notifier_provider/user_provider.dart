import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/user_data/user_data.dart';
import '../../view_models/user_notifier/user_notifier.dart';

final userProvider =
StateNotifierProvider<UserNotifier, UserData>((ref) => UserNotifier());