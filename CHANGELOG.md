# Changelog

All notable changes to TwitchKit will be documented in this file.

TwitchKit follows semantic versioning while it is pre-1.0. During the 0.x series, minor versions may include source-breaking API changes as the package matures.

## Unreleased

### Added

- Expanded Helix chat coverage for chatters, emote sets, user emotes, chat settings, shared chat sessions, announcements, shoutouts, pinned messages, and user chat colors.
- Expanded Helix moderation coverage for AutoMod, bans/timeouts, unban requests, blocked terms, chat message deletion, moderated channels, moderators, VIPs, Shield Mode, warnings, and suspicious-user status.
- Expanded EventSub subscription factories across chat, subscriptions, moderation, channel points, polls, predictions, goals, Hype Train, charity, user, and whisper events.
- Typed EventSub payload decoding for key chat moderation, subscription lifecycle, unban request, VIP, Shield Mode, shoutout, and warning events.
- EventSub subscription creation now supports Twitch's batching flag for Drop entitlement subscriptions.
- Expanded Helix creator and channel-management coverage for followed channels, editors, content classification labels, search, schedules, charity, Hype Train, polls, predictions, raids, stream markers, goals, channel points rewards, subscriptions, clips, and videos.

## [0.1.0-alpha.3] - 2026-05-25

### Added

- Grouped EventSub subscription factories for chat, channel, stream, moderation, and channel points domains.
- Typed EventSub event payloads for channel updates, stream online/offline, raids, cheers, bans, unbans, moderator changes, and custom reward redemptions.
- EventSub subscription listing, pagination, filtering, cost metadata, and deletion helpers.
- Forward-compatible `RawRepresentable` enums for Twitch stream types, EventSub transport methods, EventSub subscription statuses, chat domains, and channel points redemption statuses.
- Local validation for EventSub subscription management calls that would otherwise be rejected by Twitch.
- `TwitchKitSmokeTest` executable target for live Twitch API, EventSub, chat, and cleanup smoke checks.
- Typed Helix rate-limit metadata and configurable retry policy for Twitch's recommended 503 retry.
- Successful Helix page responses and optional client callbacks now expose response metadata.
- Configurable Helix request timeouts and cancellation-preserving network error handling.
- EventSub connection timeout cleanup and reconnect cancellation when disconnecting.

### Changed

- Public documentation comments for newer Helix metadata, retry, timeout, and facade APIs.

## [0.1.0-alpha.2] - 2026-05-25

### Added

- `TwitchOAuthClient` for OAuth URL construction and token exchange.
- `TwitchTokenStore`, `KeychainTokenStore`, and `InMemoryTokenStore` for configurable token persistence.
- `TwitchTokenProvider` for loading, validating, refreshing, and supplying access tokens.
- `HelixClient` initializer that accepts any `TwitchAccessTokenProvider`.
- Helix pagination primitives and channel followers pagination helpers.
- Shared Helix query helpers for repeated parameters, optional parameters, and cursor pagination.
- Helix user lookup helpers for fetching users by ID and login.
- Helix stream and game/category helpers, including paginated streams and top games.
- Typed Send Chat Message request encoding and response coverage, including `for_source_only` and `pin`.
- EventSub subscription transport support for webhook, WebSocket, and conduit creation requests.

### Changed

- `TwitchAuth` is now a convenience facade over the OAuth client and token provider.
- `HelixClient` endpoint methods are organized into focused extension files by API area.
- Keychain writes now use an add-or-update flow and device-only background-safe accessibility.
- Helix errors preserve Twitch's structured error response.
- Helix response handling is shared across standard data responses, accepted responses, and no-content responses.
- Helix pages now preserve response `total` values when Twitch includes them.

## [0.1.0-alpha.1] - 2026-05-25

### Added

- Initial Swift Package for Twitch Helix API and EventSub WebSocket support.
- `TwitchClient` facade that exposes authentication, Helix API, and EventSub clients.
- OAuth helpers for:
  - OAuth implicit grant
  - OAuth authorization code grant
  - OIDC implicit grant
  - OIDC authorization code grant
  - OAuth client credentials grant
  - OAuth device code grant
  - External token injection
- `TwitchScope` catalog covering Twitch API, EventSub, IRC chat, and PubSub-specific chat scopes.
- Keychain-backed token storage with client/account namespacing.
- Helix helpers for:
  - Authenticated user profile
  - Stream key
  - Channel information
  - Channel updates
  - Global and channel emotes
  - Global and channel badges
  - Chat message sending
  - EventSub subscription creation
- EventSub WebSocket client with:
  - Async event stream
  - Welcome timeout
  - Keepalive timeout handling
  - Reconnect handling
  - Automatic resubscription after full reconnect
  - Duplicate message filtering
  - Revocation events
- Typed models for selected Twitch API and EventSub payloads.
- Forward-compatible enums for selected Twitch string domains:
  - `ChatMessageType`
  - `ChatFragmentType`
  - `SubscriptionTier`
  - `BadgeClickAction`
- `ChannelInfoUpdate` request type for channel updates.
- Model decoding and API design tests.
- GitHub Actions CI workflow running `swift test`.

### Notes

- This is an alpha prerelease. Public APIs may change before `1.0.0`.
- The package currently targets Swift 6.2, iOS 26, and macOS 15.
- TwitchKit currently covers a focused subset of Helix and EventSub. More endpoints and typed EventSub subscriptions are planned.
