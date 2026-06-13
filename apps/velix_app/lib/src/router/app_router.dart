import 'package:go_router/go_router.dart';
import 'package:velix_domain/velix_domain.dart';

import '../presentation/screens/ai_assistant/ai_assistant_screen.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/chat/chat_screen.dart';
import '../presentation/screens/chats/chats_screen.dart';
import '../presentation/screens/explore/explore_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/notifications/notifications_screen.dart';
import '../presentation/screens/onboarding/onboarding_screen.dart';
import '../presentation/screens/privacy/privacy_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/settings/accessibility_screen.dart';
import '../presentation/screens/settings/settings_screen.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/stories/stories_screen.dart';
import '../presentation/screens/video_call/video_call_screen.dart';
import '../presentation/screens/voice_message/voice_message_screen.dart';
import '../presentation/shell/floating_nav_shell.dart';

class Routes {
  Routes._();
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const auth = '/auth';
  static const home = '/home';
  static const chats = '/chats';
  static const explore = '/explore';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const settings = '/profile/settings';
  static const privacy = '/profile/settings/privacy';
  static const accessibility = '/profile/settings/accessibility';
  static const aiAssistant = '/ai-assistant';
  static const voiceMessage = '/voice-message';
  static const videoCall = '/video-call';
  static const stories = '/stories';

  static String chat(ConversationId id) => '/chats/${id.value}';
}

const _shellRoutes = {
  Routes.home,
  Routes.chats,
  Routes.explore,
  Routes.notifications,
  Routes.profile,
};

bool routeHidesNav(String location) {
  if (location == Routes.auth) return true;
  if (location.startsWith('/chats/') && location != '/chats') return true;
  if (location.startsWith('/profile/settings')) return true;
  if (location.startsWith('/profile/edit')) return true;
  if (location == Routes.aiAssistant) return true;
  if (location == Routes.voiceMessage) return true;
  if (location == Routes.videoCall) return true;
  if (location == Routes.stories) return true;
  return false;
}

bool routeBelongsToShell(String location) =>
    _shellRoutes.contains(location);

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: Routes.splash,
    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: Routes.auth,
        builder: (_, __) => const AuthScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => FloatingNavShell(
          location: state.matchedLocation,
          child: child,
        ),
        routes: [
          GoRoute(
            path: Routes.home,
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: Routes.chats,
            builder: (_, __) => const ChatsScreen(),
          ),
          GoRoute(
            path: Routes.explore,
            builder: (_, __) => const ExploreScreen(),
          ),
          GoRoute(
            path: Routes.notifications,
            builder: (_, __) => const NotificationsScreen(),
          ),
          GoRoute(
            path: Routes.profile,
            builder: (_, __) => const ProfileScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/chats/:conversationId',
        builder: (context, state) => ChatScreen(
          conversationId: ConversationId(
            state.pathParameters['conversationId']!,
          ),
        ),
      ),
      GoRoute(
        path: Routes.settings,
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: Routes.privacy,
        builder: (_, __) => const PrivacyScreen(),
      ),
      GoRoute(
        path: Routes.accessibility,
        builder: (_, __) => const AccessibilityScreen(),
      ),
      GoRoute(
        path: Routes.aiAssistant,
        builder: (_, __) => const AIAssistantScreen(),
      ),
      GoRoute(
        path: Routes.voiceMessage,
        builder: (_, __) => const VoiceMessageScreen(),
      ),
      GoRoute(
        path: Routes.videoCall,
        builder: (_, __) => const VideoCallScreen(),
      ),
      GoRoute(
        path: Routes.stories,
        builder: (_, __) => const StoriesScreen(),
      ),
    ],
  );
}
