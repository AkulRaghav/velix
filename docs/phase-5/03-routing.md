# 03 — Routing

## Library

`go_router` 14+, with code-generated typed routes. We chose go_router because:

- Declarative route tree matches React Router / Next.js patterns engineers already know.
- Deep links (universal links / app links) are first-class — required for "Join Space" and "Add me as contact" flows.
- ShellRoute support cleanly separates the shell (floating nav) from the inner routes.
- Codegen yields type-safe path-builders so we never hand-construct route strings.

## The route tree

```
/  (Splash)
├── /onboarding              ← shown only on first run
├── /login                   ← public, auth gateway
└── ShellRoute (FloatingNav)
    ├── /home
    ├── /chats
    │   └── /chats/:conversationId   ← hides nav
    ├── /explore
    ├── /notifications
    └── /profile
        └── /profile/edit             ← hides nav
            └── /profile/edit/identity-style
        └── /profile/settings         ← hides nav
            ├── /profile/settings/privacy
            ├── /profile/settings/devices
            └── /profile/settings/accessibility

Modal routes (presented via VelixSheet/VelixModal, not in the path):
  /chats/:id/voice-record
  /chats/:id/info
  /ai-assistant
```

The story viewer, voice/video calls, and the AI assistant are **modal routes** in our model — they live outside the path-tree, presented via Phase 4 `VelixModal`/`VelixSheet`. This keeps the URL surface small and the back-stack clean.

## Typed routes

Each route declares its parameters and metadata in a code-generated route object:

```dart
@TypedGoRoute<ChatRoute>(path: '/chats/:conversationId')
class ChatRoute extends GoRouteData {
  const ChatRoute({required this.conversationId});
  final String conversationId;

  @override
  Widget build(BuildContext context, GoRouterState state) {
    return ChatScreen(conversationId: ConversationId(conversationId));
  }
}

// Usage at call site:
ChatRoute(conversationId: 'c123').push(context);
```

We never type a route string in product code outside the route definitions.

## VelixPageRoute integration

`go_router` lets us override its internal route builder. We hook in `VelixPageRoute` (Phase 4) so every push gets:

- `motion.lateral` lateral animation
- iOS edge-swipe-back inheritance
- Floating-nav hide/show coordination
- Reduce-Motion fallback

```dart
GoRouter(
  // ...
  routerConfig: ...,
  pageBuilder: (context, state, child) => VelixPage(
    child: child,
    hidesNav: state.matchedLocation.startsWith('/chats/'),
  ),
);
```

Our `VelixPage` is a `Page<T>` subclass that wraps `VelixPageRoute`.

## Shell route — floating nav

The five primary tabs are children of a `ShellRoute`. The shell builds the floating nav as a persistent layout element. Tab switches don't unmount sibling tabs — Riverpod's per-tab providers cache.

```dart
ShellRoute(
  builder: (context, state, child) => VelixAppShell(child: child),
  routes: [
    GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    GoRoute(path: '/chats', builder: (_, __) => const ChatsScreen()),
    // ...
  ],
)
```

`VelixAppShell` composes the route's child with the floating nav. Routes within the shell that need to hide the nav (e.g., a conversation detail) push *outside* the shell, so the nav is replaced by `motion.depart` rather than just hidden.

## Hide-nav routes

Routes that hide the floating nav are listed explicitly in `router_config.dart`:

```dart
const _navHidingRouteRegex = [
  '/chats/',           // /chats/:id
  '/profile/edit',
  '/profile/settings',
  // modals are not paths
];
```

Adding a hide-nav route is a single-line config change, audited at PR time.

## Deep linking

Universal links / app links are configured in `ios/Runner/Info.plist` and `android/app/src/main/AndroidManifest.xml`. Supported deep links at 1.0:

| Link | Action |
|---|---|
| `velix://invite/<token>` | Add contact (after auth) |
| `velix://space/<id>` | Join space |
| `velix://chat/<id>` | Open conversation |
| `velix://reset?email=...` | Restart account |

Tokens carried in deep links are short-lived (≤ 24 hours), single-use, and verified server-side before any action.

## Navigation guards

We use go_router's `redirect` for two guards:

1. **Auth guard.** If the user lands on a protected route while logged out, redirect to `/login` with a return query param.
2. **Onboarding guard.** First-run users land on `/onboarding`, even if they tried to deep-link.

Both guards are pure functions of the auth state read from a Riverpod `ProviderListener` exposed to the router via the standard go_router refresh pattern.

## Backstack rules

- The splash route is replaced (not pushed) when the app boots.
- Onboarding completes via `goNamed('home')` (replace, not push).
- Login completes via replace.
- Modals are presented via `Navigator.push` of a `VelixModal._Route`; they do not enter the path-stack.

## Reduce Motion behavior

Phase 4 docs already specify the per-pattern behavior. Phase 5 routing additionally:

- Disables the lateral animation parallax of outgoing siblings (200 ms cross-fade).
- Disables the edge-swipe-back gesture preview animation; releases still complete the gesture.

## Audit checklist

- [ ] Every route has a typed route data object.
- [ ] No route string is hand-typed outside `router_config.dart` or generated code.
- [ ] No `Navigator.push(MaterialPageRoute(...))` outside `velix_motion`.
- [ ] Hide-nav routes are listed centrally.
- [ ] Deep links are validated before action.
- [ ] Auth guard tested for every protected route.
- [ ] Onboarding guard tested for first-run flow.
- [ ] Backstack rules verified by widget test.
