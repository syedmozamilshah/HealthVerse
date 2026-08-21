// Mobile-specific Stripe initialization
// M-10 STRIPE INITIALIZATION FOR MOBILE PLATFORM
import 'package:flutter_stripe/flutter_stripe.dart';

Future<void> initializeStripe() async {
  Stripe.publishableKey =
      'pk_test_51SbZXqI0kIulCigoPxGSnq0N46xomVby23cdovAzyYb4vr99Kb46nwQqvHyuPL3dUuCWeQ7V51F1zHVPzvl84BmN00HxNz1Yvl';
  print('Stripe initialized for mobile platform');
}
