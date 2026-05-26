# TwitchKit

[![CI](https://github.com/AndrewBeshay/TwitchKit/actions/workflows/ci.yml/badge.svg)](https://github.com/AndrewBeshay/TwitchKit/actions/workflows/ci.yml)
[![Swift Package Index](https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/AndrewBeshay/TwitchKit/badge?type=swift-versions)](https://swiftpackageindex.com/AndrewBeshay/TwitchKit)
[![SPI Platforms](https://img.shields.io/endpoint?url=https://swiftpackageindex.com/api/packages/AndrewBeshay/TwitchKit/badge?type=platforms)](https://swiftpackageindex.com/AndrewBeshay/TwitchKit)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2026%20%7C%20macOS%2015-lightgrey.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/tag/AndrewBeshay/TwitchKit?include_prereleases&label=release)](https://github.com/AndrewBeshay/TwitchKit/releases)

TwitchKit is a Swift Package for working with the Twitch Helix API, Twitch OAuth, and EventSub WebSocket transport from modern Swift apps.

The package is currently pre-1.0. It provides typed authentication, token storage, Helix request helpers, EventSub subscription builders, and EventSub WebSocket delivery while the public API continues to settle.

## Requirements

- Swift 6.2 or newer
- iOS 16 or newer
- macOS 13 or newer

## Installation

Add TwitchKit as a Swift Package dependency:

```swift
.package(url: "https://github.com/AndrewBeshay/TwitchKit.git", from: "0.2.0-beta.4")
```

Then add the product to your target:

```swift
.product(name: "TwitchKit", package: "TwitchKit")
```

## Quick Start

```swift
import TwitchKit

let twitch = TwitchClient(
    clientId: "<your client id>",
    tokenNamespace: "primary-account"
)

let authURL = twitch.auth.implicitGrantURL(
    scopes: [
        .userReadEmail,
        .userReadChat,
        .userWriteChat,
    ],
    state: "<csrf token>"
)
```

For server-backed apps that can protect a client secret:

```swift
let twitch = TwitchClient(
    clientId: "<your client id>",
    clientSecret: "<your client secret>",
    tokenNamespace: "primary-account"
)

let authURL = twitch.auth.authorizationCodeURL(
    scopes: [
        .userReadEmail,
        .channelManageBroadcast,
    ],
    state: "<csrf token>"
)
```

After your app receives an authorization code:

```swift
try await twitch.auth.authenticate(withAuthorizationCode: code)
```

If your host app or backend owns OAuth, inject an existing token:

```swift
try await twitch.auth.setToken(
    OAuthToken(
        accessToken: "<access token>",
        refreshToken: nil,
        expiresIn: nil,
        scope: nil,
        tokenType: "bearer"
    )
)
```

## Helix API

```swift
let user = try await twitch.api.fetchUser()
let channel = try await twitch.api.fetchChannelInfo(forBroadcasterID: user.id)
let emotes = try await twitch.api.fetchGlobalEmotes()
```

Current Helix coverage includes users, channels, streams, games, chat, moderation, EventSub management, followed channels, channel editors, search, schedules, charity, Hype Train, polls, predictions, raids, stream markers, goals, channel points rewards/redemptions, subscriptions, clips, and videos.

Paginated endpoints are available as either single pages or lazy async sequences:

```swift
let firstPage = try await twitch.api.fetchChannelFollowersPage(
    forBroadcasterID: user.id,
    first: 100
)

for try await follower in twitch.api.channelFollowers(forBroadcasterID: user.id) {
    print("Follower:", follower.userName)
}
```

Sending a chat message:

```swift
let result = try await twitch.api.sendChatMessage(
    broadcasterId: "<broadcaster id>",
    senderId: "<sender id>",
    message: "Hello from TwitchKit"
)

if result.isSent {
    print("Sent message:", result.messageId)
}
```

## EventSub WebSocket

Connect to EventSub and subscribe to typed subscription requests:

```swift
try await twitch.eventSub.connect()

try await twitch.eventSub.subscribe(
    .makeChannelChatMessage(
        broadcasterID: "<broadcaster id>",
        userID: "<user id>"
    )
)

for await event in twitch.eventSub.events {
    switch event {
    case .chatMessage(let message):
        print("\(message.chatterUserName): \(message.message.text)")

    case .follow(let follow):
        print("New follower:", follow.userName)

    case .subscription(let subscription):
        print("New subscription:", subscription.userName)

    case .revocation(let revocation):
        print("Subscription revoked:", revocation.status)

    case .unknown(let type, _):
        print("Unhandled EventSub event:", type)
    }
}
```

EventSub reconnects automatically and re-creates desired subscriptions after a full disconnect. Duplicate EventSub messages are ignored by message ID.

## Supported APIs

### Helix

| Area | Coverage |
| --- | --- |
| Users | Authenticated user, users by ID/login |
| Channels | Channel info, channel updates, followers, followed channels, editors, content classification labels |
| Streams and games | Streams, stream lookup, stream key, top games, games by ID/name/IGDB ID |
| Chat | Global/channel badges, global/channel emotes, emote sets, user emotes, chatters, chat settings, shared chat sessions, announcements, shoutouts, pinned messages, user chat colors, Send Chat Message |
| Moderation | AutoMod status/settings, bans/timeouts, unban requests, blocked terms, delete chat message, moderated channels, moderators, VIPs, Shield Mode, warnings, suspicious users |
| EventSub management | Create/list/delete subscriptions, WebSocket/webhook/conduit transports, batching flag |
| Creator tools | Schedules, charity campaigns/donations, Hype Train status, polls, predictions, raids, stream markers, goals |
| Channel points | Custom rewards and custom reward redemptions |
| Media | Clips, clip downloads, videos, video deletion |
| Subscriptions | Broadcaster subscriptions and user subscription checks |

### EventSub

| Area | Subscription builders | Typed notification payloads |
| --- | --- | --- |
| Chat | Chat messages, notifications, clear events, message deletion, chat settings, user message hold/update, shared chat sessions | Chat messages, notifications, clear events, message deletion, chat settings, user message hold/update |
| Subscriptions | Subscribe, end, gift, message | Subscribe, end, gift, message |
| Moderation | Ban, unban, moderator add/remove, moderate, unban requests, VIP add/remove, warnings, Shield Mode, suspicious users | Ban, unban, moderator add/remove, moderate, unban requests, VIP add/remove, warnings, Shield Mode |
| Channel points | Automatic redemptions, custom rewards, custom reward redemptions, power-up redemptions | Automatic redemptions, custom rewards, custom reward redemptions |
| Creator engagement | Polls, predictions, goals, Hype Train, charity campaigns/donations, raids, shoutouts, follows, cheers | Polls, predictions, goals, Hype Train, charity campaigns/donations, raids, shoutouts, follows, cheers |
| Streams and users | Stream online/offline, user authorization grant/revoke, user update, whispers | Stream online/offline |
| Platform/specialized | AutoMod, conduits, drops, extension bits, Guest Star, user authorization/update, whispers | AutoMod, conduits, drops, extension bits, Guest Star, user authorization/update, whispers |

Known EventSub subscription types that do not yet have dedicated field-level models decode as `.known(EventSubKnownEvent)` with the original JSON payload preserved. Future Twitch types decode as `.unknown(type:payload:)`.

## OAuth Support

TwitchKit exposes helpers for Twitch-supported OAuth flows:

- OAuth implicit grant
- OAuth authorization code grant
- OIDC implicit grant
- OIDC authorization code grant
- OAuth client credentials grant
- OAuth device code grant
- Token injection for apps that manage OAuth outside the package

For iOS apps, avoid shipping a client secret in the app bundle. Prefer implicit grant, device code flow, or a backend-owned authorization code exchange depending on your app model.

OAuth is split into composable pieces:

- `TwitchOAuthClient` builds OAuth URLs and exchanges grants for tokens.
- `TwitchTokenStore` abstracts token persistence.
- `KeychainTokenStore` is the default Apple-platform token store.
- `InMemoryTokenStore` is useful for tests, previews, and backend-owned OAuth.
- `TwitchTokenProvider` loads, validates, refreshes, and supplies access tokens.
- `TwitchAuth` is a convenience facade that composes the pieces above.

Apps that already receive tokens from a backend can bypass Keychain storage entirely:

```swift
let twitch = TwitchClient(
    clientId: "<your client id>",
    tokenStore: InMemoryTokenStore(
        token: OAuthToken(accessToken: "<backend issued access token>")
    )
)
```

## Scope Catalog

`TwitchScope` includes the current Twitch API, EventSub, IRC chat, and PubSub-specific scope strings documented by Twitch.

Use `TwitchAuth.defaultScopes` for the small starter set used by TwitchKit convenience APIs, or `TwitchAuth.allScopes` when you need the complete catalog. OAuth helper methods prefer typed `[TwitchScope]` values and also provide raw-scope overloads for newly added Twitch scopes.

Request only the scopes your app needs. Twitch warns that requesting unnecessary scopes can put API access at risk.

## Status

TwitchKit is pre-1.0 and the public API may change. Current coverage includes:

- OAuth helper flows and Keychain-backed token storage
- Broad Helix creator, chat, channel-management, moderation, media, and EventSub-management APIs
- EventSub WebSocket connection management and subscription re-creation
- EventSub subscription factories for the current Twitch subscription type catalog
- Typed models for Twitch's current EventSub subscription type catalog, with raw fallbacks for future Twitch types and decode-resilience
- Swift 6 `Sendable` annotations and actor-isolated auth/EventSub clients

Planned areas for expansion:

- iOS OAuth example app
- Server/platform-oriented Helix areas such as ads, analytics, extensions, drops, conduits, teams, tags, and user extension management
- Broader API documentation and examples

## License

TwitchKit is available under the MIT License. See [LICENSE](LICENSE).
