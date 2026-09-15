# Abay Softphone

**Abay** is a modern Flutter SIP softphone designed to compete with Zoiper: a polished mobile-first VoIP client for PBX and ITSP environments.

## Features

- **Multiple SIP accounts** — add several PBX/ITSP identities and switch the active line
- **Registration over WS/WSS** — SIP over WebSocket with UDP/TCP/TLS account metadata
- **Dialer** — T9-style keypad, long-press `0` for `+`, contact suggestions while typing
- **Audio calls** — mute, hold, speakerphone, blind transfer, in-call DTMF keypad
- **Incoming calls** — full-screen answer/decline UI, optional auto-answer
- **Call history** — missed/in/out filters, tap-to-redial, swipe-to-delete
- **Contacts** — favorites strip, search, local contact management
- **SIP messaging (MESSAGE)** — chat threads per peer URI
- **Settings** — dark mode, codec preference, ring duration, auto-register, keep-alive
- **Registration ribbon** — live status (Registered / Connecting / Failed) on every tab

## Feature parity vs Zoiper (core)

| Capability | Abay | Zoiper |
|---|---|---|
| Multiple accounts | Yes | Yes |
| SIP over WebSocket | Yes | Yes |
| TLS / SRTP options | Yes | Yes |
| Call transfer | Blind (attended planned) | Blind + attended |
| DTMF RFC2833 / INFO | Account-level setting | Yes |
| SIP messaging | Yes | Yes |
| Call history | Yes | Yes |
| Contacts + favorites | Yes | Yes |
| Video calls | Scaffolded (UI ready) | Yes (paid/pro) |
| Push notifications | Ready to add (FCM/APNs) | Yes |
| Call recording | Planned | Yes |
| G.729 / proprietary codecs | Opus, PCMU/A, G722, GSM | Wider paid codec set |

## Getting started

```powershell
cd D:\mobile-apps\abay
flutter pub get
flutter run
```

### Platform notes

- **Android**: microphone, internet, and Bluetooth connect permissions are declared. Target SDK should be ≥ 33 for notification permission UX.
- **iOS**: add `NSMicrophoneUsageDescription` and `NSBluetoothPeripheralUsageDescription` to `Info.plist` when generating the Runner project.
- **Desktop**: WebRTC audio works on Windows/macOS/Linux with the right Flutter desktop embedder setup.

### PBX tips

1. Enable the **WebSocket** transport on your PBX (Asterisk `res_http_websocket`, FreeSWITCH `mod_sofia` WSS, Kamailio `websocket` module, 3CX, etc.).
2. Point Abay’s **Server** at the PBX host and **Port** at the WS/WSS port (often 8088/8089 for Asterisk, 7443 for WSS).
3. Use **TLS** transport when your PBX terminates WSS.
4. Register, then place an internal extension call from the Dialer.

## Project layout

```
lib/
  main.dart                 # bootstrap + providers
  app.dart                  # MaterialApp + SIP error/incoming wiring
  core/                     # theme, constants, formatters, validators
  models/                   # account, history, contact, chat, settings
  services/sip_service.dart # flutter_sip_ua wrapper
  providers/                # ChangeNotifiers
  screens/                  # dialer, calls, history, contacts, messages, accounts, settings
```

## Roadmap

- Attended transfer + 3-way conference
- Push notifications (FCM / APNs) for incoming calls when app is killed
- Call recording and voicemail (MWI)
- Video call UI polish
- Provisioning / QR import of account config
- BLF / presence (SUBSCRIBE/NOTIFY)

## License

MIT (for your product use). Third-party packages retain their own licenses.
