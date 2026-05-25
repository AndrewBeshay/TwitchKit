# EventSub

Use ``TwitchKit/EventSubClient`` to receive Twitch EventSub notifications over WebSockets.

## Connect

```swift
let eventSub = client.eventSub
try await eventSub.connect()
```

After Twitch sends a welcome message, create subscriptions with ``TwitchKit/EventSubSubscription``:

```swift
try await eventSub.subscribe(
    EventSubSubscription.Chat.message(
        broadcasterID: "<#Broadcaster ID#>",
        userID: "<#User ID#>"
    )
)
```

## Consume Events

```swift
for await event in eventSub.events {
    switch event {
    case .chatMessage(let message):
        print(message.chatterUserName, message.message.text)
    case .ban(let ban):
        print("Banned:", ban.userName)
    case .known(let event):
        print("Known EventSub payload:", event.type.rawValue)
    case .unknown(let type, _):
        print("Unhandled future EventSub payload:", type)
    default:
        break
    }
}
```

## Known And Unknown Events

TwitchKit exposes dedicated Swift models for high-value EventSub payloads such as chat messages, stream state, subscriptions, moderation, channel points redemptions, warnings, shield mode, and shoutouts.

When TwitchKit recognizes the EventSub subscription type but does not yet expose a dedicated field-level model, it returns ``TwitchKit/EventSubEvent/known(_:)`` with an ``TwitchKit/EventSubKnownEventType`` and the original JSON payload. ``TwitchKit/EventSubEvent/unknown(type:payload:)`` is reserved for future Twitch subscription types that the SDK does not recognize yet.
