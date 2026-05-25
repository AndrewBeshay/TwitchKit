# Helix

Use ``TwitchKit/HelixClient`` for Twitch REST API calls.

## User And Channel APIs

```swift
let user = try await client.api.fetchUser()

let channel = try await client.api.fetchChannelInfo(
    forBroadcasterID: user.id
)
```

## Updating Channel Info

Use ``TwitchKit/ChannelInfoUpdate`` to keep update call sites readable as Twitch adds more optional fields:

```swift
let update = ChannelInfoUpdate(
    gameId: "509658",
    title: "Building a Swift Twitch SDK"
)

try await client.api.updateChannelInfo(
    forBroadcasterID: user.id,
    with: update
)
```

## Chat

```swift
let response = try await client.api.sendChatMessage(
    broadcasterId: "<#Broadcaster ID#>",
    senderId: "<#Sender ID#>",
    message: "Hello from TwitchKit"
)
```

## Pagination

Many Twitch APIs return paginated ``TwitchKit/HelixResponse`` values. Use the response data immediately and keep the cursor when you need another page.
