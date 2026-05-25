# Authentication

Use ``TwitchKit/TwitchAuth`` to build Twitch authorization URLs, exchange authorization codes, refresh tokens, validate tokens, revoke tokens, and run the device code flow.

## Authorization Code Flow

Authorization code flow is the right default for apps that can send the user through Twitch login and receive a redirect URI.

```swift
let auth = TwitchAuth(
    clientId: "<#Client ID#>",
    clientSecret: "<#Client Secret#>",
    redirectUri: "myapp://oauth/twitch"
)

let authorizationURL = auth.authorizationCodeURL(
    scopes: [.userReadChat, .userWriteChat],
    state: "<#CSRF Token#>"
)

try await auth.authenticate(
    withAuthorizationCode: "<#Code#>"
)
```

## Device Code Flow

Device code flow is useful for command-line tools, TV apps, and other clients where a browser redirect is awkward.

```swift
let authorization = try await auth.startDeviceCodeFlow(
    scopes: [.userReadChat]
)

print(authorization.verificationURI)
let token = try await auth.pollDeviceCode(authorization)
```

## Token Storage

TwitchKit can store tokens through ``TwitchKit/TwitchTokenStore``. Apps that already have secure credential storage or a backend token exchange service can keep ownership of token persistence and pass access tokens into ``TwitchKit/TwitchClient`` with ``TwitchKit/InMemoryTokenStore`` or a custom store.
