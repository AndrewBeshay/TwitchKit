# TwitchKit

[![CI](https://github.com/AndrewBeshay/TwitchKit/actions/workflows/ci.yml/badge.svg)](https://github.com/AndrewBeshay/TwitchKit/actions/workflows/ci.yml)
![Swift](https://img.shields.io/badge/Swift-6.2-orange.svg)
![Platforms](https://img.shields.io/badge/platforms-iOS%2026%20%7C%20macOS%2015-lightgrey.svg)
[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/tag/AndrewBeshay/TwitchKit?include_prereleases&label=release)](https://github.com/AndrewBeshay/TwitchKit/releases)

TwitchKit is a Swift Package for working with the Twitch Helix API and EventSub WebSocket transport from modern Swift apps.

The package is currently in early development. It focuses on a small, typed foundation for authentication, Helix requests, Twitch chat-related models, and EventSub event delivery.

## Requirements

- Swift 6.2 or newer
- iOS 26 or newer
- macOS 15 or newer

## Installation

Add TwitchKit as a Swift Package dependency:

```swift
.package(url: "https://github.com/AndrewBeshay/TwitchKit.git", branch: "main")
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
- Helix user, channel, follower, emote, badge, stream key, and chat message APIs
- EventSub WebSocket connection management
- Typed models for selected Twitch API and EventSub payloads
- Swift 6 `Sendable` annotations and actor-isolated auth/EventSub clients

Planned areas for expansion:

- More typed EventSub subscription builders and event models
- More Helix endpoint coverage
- Injectable networking, token providers, and token stores for host-app configuration
- Broader API documentation and examples

## License

TwitchKit is available under the MIT License. See [LICENSE](LICENSE).
