# Orby Live for iPhone — development branch

Native iPhone app and Lock Screen / Dynamic Island extension for desktop Orby 10.42. This branch checks the iPhone source on a GitHub Mac runner. It does not publish a signed iPhone app or change the existing Windows release.

Start with [iPhone setup](docs/IPHONE-SETUP.md). The build compiles simulator and unsigned device targets. Signing, Apple push and real-device validation are separate. No Apple account or subscription is created automatically.

The relay and native phone use independent, single-request signed decisions. Windows pins the phone key and rechecks the current native permission card. Task viewing follows the readable ChatGPT, Claude and Gemini contexts. Remote approval currently covers supported ChatGPT/Codex Allow once / Deny cards, not arbitrary provider prompts.

Private water tracking, credentials, databases, device tokens and signing files are excluded. The withdrawn MCP plugin is not used. Desktop Orby 10.42 is required for the opt-in desktop adapter. Native iPhone behavior remains unverified until a signed phone build is installed and tested.