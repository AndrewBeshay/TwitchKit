# Getting Started

Create a Twitch application, request the scopes your app needs, and initialize a ``TwitchKit/TwitchClient`` with a valid access token.

## Create a Client

```swift
let client = TwitchClient(
    clientId: "<#Client ID#>",
    tokenStore: InMemoryTokenStore(
        token: OAuthToken(accessToken: "<#Access Token#>")
    )
)
```

Use the ``TwitchKit/TwitchClient/api`` property for Helix calls:

```swift
let user = try await client.api.fetchUser()
let channel = try await client.api.fetchChannelInfo(
    forBroadcasterID: user.id
)
```

## Choose Scopes Deliberately

Twitch recommends requesting only the scopes your app needs. TwitchKit exposes ``TwitchKit/TwitchScope`` so call sites are typed and typo-resistant:

```swift
let scopes: [TwitchScope] = [
    .userReadChat,
    .userWriteChat,
    .moderatorReadChatters
]
```

## Run the Smoke Test

The package includes a small command-line smoke test target for local verification:

```bash
export TWITCH_CLIENT_ID="<#Client ID#>"
export TWITCH_ACCESS_TOKEN="<#Access Token#>"
swift run TwitchKitSmokeTest all
```

The smoke test intentionally uses your real Twitch credentials, so prefer a development Twitch application and avoid checking secrets into source control.
