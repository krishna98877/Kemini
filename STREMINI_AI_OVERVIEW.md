# Stremini AI — Complete Product & Technical Overview

> **Version 1.0.0** | Android | Flutter + Kotlin | Groq LLM + Composio Automation  
> **Repository:** [github.com/krishna98877/Stremini.ai](https://github.com/krishna98877/Stremini.ai)

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [The Problem](#2-the-problem)
3. [The Solution](#3-the-solution)
4. [Key Features](#4-key-features)
5. [How It Works — User Journey](#5-how-it-works--user-journey)
6. [Competitive Landscape](#6-competitive-landscape)
7. [Technical Architecture](#7-technical-architecture)
8. [Technology Stack](#8-technology-stack)
9. [Security & Privacy](#9-security--privacy)
10. [Supported Integrations](#10-supported-integrations)
11. [Build & Development Guide](#11-build--development-guide)
12. [Roadmap](#12-roadmap)

---

## 1. Executive Summary

Stremini AI is an Android AI keyboard and system-wide assistant that brings the power of large language models directly into every app on your phone. Unlike traditional AI chatbots that live inside a single app, Stremini operates as a **floating overlay** accessible from any screen, combined with a **full AI-powered keyboard** that can rewrite, translate, correct, and complete text in real time — in WhatsApp, Gmail, Instagram, or any other app.

The product integrates **Groq's ultra-fast LLM inference** for chat and keyboard intelligence, and **Composio's managed authentication platform** for seamless third-party service automation — enabling users to send emails, post to social media, manage GitHub repos, and interact with 11 services directly through natural language, all without ever providing API keys.

**Key differentiators:**
- AI that lives **outside** any single app — a true system-wide assistant
- Zero-config automation — users connect services with their own OAuth login, not API keys
- Two AI models working in parallel: a powerful 70B model for chat, a fast 8B model for keyboard actions
- Enterprise-grade security: AES-256-GCM encryption, trusted-host whitelisting, prompt injection defense, and rate limiting

---

## 2. The Problem

### For Users

- **Context switching kills productivity.** To use AI, you must leave your current app, open a chatbot, get your answer, switch back, and type it manually. This breaks flow and wastes time on every single interaction.
- **Keyboards are dumb.** Your keyboard types what you tell it to — it doesn't help you write better, fix mistakes, or adapt your tone to the conversation.
- **Connecting services is painful.** Sending an email via AI, posting to social media, or automating workflows requires managing API keys, OAuth flows, and developer tools that most people don't understand.

### For the Market

- Existing AI keyboards (Gboard, SwiftKey) offer basic predictions but no real intelligence — no tone rewriting, no multi-step automation, no service integration.
- AI chatbots (ChatGPT, Gemini) are powerful but siloed — they can't interact with your other apps.
- Automation tools (Zapier, IFTTT) require technical setup and don't live on your keyboard.

**Stremini AI eliminates all three gaps in a single app.**

---

## 3. The Solution

Stremini AI is a **three-in-one product**:

### 3.1 Floating AI Assistant (Overlay)

A draggable floating bubble that appears over any app. Tap it to open a full AI chat panel directly on screen — no app switching required. The chat understands context, supports multi-turn conversation, and can trigger service automations through natural language.

### 3.2 AI-Powered Keyboard (IME)

A complete replacement keyboard with:
- **AI Rewrite** — Select text and rewrite it in Professional, Casual, Friendly, Formal, or Concise tone
- **AI Complete** — Autocomplete sentences contextually
- **AI Correct** — Fix grammar, spelling, and punctuation on the fly
- **AI Translate** — Translate text into 30 languages instantly
- **Voice Typing** — Speech-to-text with 14 language options
- **Emoji Panel** — Categorized emoji keyboard with recent emoji tracking
- **Kaomoji Panel** — Japanese-style text emoticons
- **One-Handed Mode** — Left/right handed keyboard layouts
- **Adjustable Height** — Resize the keyboard for comfort

### 3.3 Service Automation Engine

Connect 11 services (Gmail, GitHub, WhatsApp, Discord, Google Drive, Instagram, and more) through Composio's managed OAuth. Once connected, simply tell the AI what you want — "Send an email to John about the meeting tomorrow" — and it handles the entire flow: intent parsing, API call, authentication, and execution.

---

## 4. Key Features

### 4.1 Floating Chat Bubble

- **Draggable** — Place the bubble anywhere on screen; it stays pinned across apps
- **Semicircle radial menu** — Tap to reveal: AI Chat, Keyboard Switcher, Connectors (automation), Settings
- **Full chat interface** — Glassmorphic dark UI with message bubbles, typing indicators, and voice input
- **Voice input** — Tap the microphone to speak your message; speech-to-text with error handling
- **Document context** — Upload PDFs and images (with OCR text extraction) to chat about their content
- **Session management** — Chat history optionally persisted across sessions; thread-safe with synchronized collections
- **Connectors toggle** — Switch between chat mode and service automation panel from within the floating UI

### 4.2 AI Keyboard Intelligence

| Feature | Description | Model |
|---------|-------------|-------|
| **Grammar Correct** | Fixes grammar, spelling, and punctuation in selected text | Llama 3.1 8B (fast) |
| **Tone Rewrite** | Rewrites text in 5 tones: Professional, Casual, Friendly, Formal, Concise | Llama 3.1 8B (fast) |
| **Auto Complete** | Contextual sentence completion based on app context | Llama 3.1 8B (fast) |
| **Translate** | Translates selected text into 30 languages | Llama 3.1 8B (fast) |
| **Smart Reply** | Inline paste suggestions from clipboard | Local (no AI) |

### 4.3 Composio Automation

- **11 supported services** — GitHub, Gmail, Instagram, Facebook, WhatsApp, Google Drive, Discord, LinkedIn, Reddit, Google Sheets, YouTube (only services with Composio-managed OAuth are included; Telegram/Twitter/TikTok were removed because they have no managed auth flow)
- **Natural language commands** — "Create a GitHub issue titled Bug fix" or "Send a Gmail to team@company.com"
- **Multi-step chaining** — Complex requests are broken into sequential steps, with each step's output feeding into the next
- **Managed OAuth** — Users log in with their own credentials via a secure WebView. No API keys ever touch the device
- **Connection persistence** — Connected accounts survive app restarts, stored server-side by Composio
- **Live status sync** — Connection state updates in real-time via EventChannel (deep-link callbacks and 401 disconnect events)
- **401 auto-heal** — If a token expires, the app automatically calls Composio's DELETE endpoint and notifies the user to reconnect

### 4.4 Keyboard Features (Non-AI)

- **Multilingual typing** — QWERTY layout with symbols, numbers, and extended symbol panels
- **Voice typing** — 14 languages: Hindi, English (US/UK/India), Bengali, Tamil, Telugu, Marathi, Gujarati, Kannada, Malayalam, Punjabi, Urdu
- **Clipboard history** — Last 5 clipboard entries with quick paste
- **Emoji panel** — 9 categories: Recent, Smileys, People, Animals, Food, Activity, Travel, Objects, Symbols
- **Kaomoji panel** — Japanese text faces organized by category
- **One-handed mode** — Left or right hand optimized layout
- **Keyboard height adjustment** — 3 height presets
- **Haptic feedback** — Configurable in settings
- **App-context detection** — Keyboard adapts hints based on the current app (messaging, email, social, general)

### 4.5 Main App (Flutter)

- **Glassmorphic dark UI** — Frosted glass cards, cyan accent glow, smooth backdrop blur
- **Home dashboard** — Agent status, permission management, keyboard setup wizard
- **Full chat screen** — Complete chat interface with document upload, image upload (with OCR), and connector access
- **Settings** — Notifications, haptic feedback, chat history persistence, keyboard settings, Groq API key configuration
- **Contact / FAQ** — Built-in support section with quick contact options and frequently asked questions
- **Multi-language UI** — 6 languages: English, Hindi, Spanish, French, Arabic, Japanese
- **Navigation drawer** — Quick access to Chat, Settings, and Contact screens

---

## 5. How It Works — User Journey

### First Launch

1. User installs and opens Stremini AI
2. Home screen shows AI Agent status and permission requests (Overlay, Microphone)
3. User enables overlay permission — the floating bubble appears
4. User enables the Stremini keyboard in system settings
5. User sets their Groq API key in Settings (for AI features)

### Connecting a Service (e.g., Gmail)

1. From the floating bubble, tap the connectors icon
2. The connectors panel slides in, showing all 15 services with connection status
3. Tap "Connect" next to Gmail
4. A secure WebView opens Composio's hosted OAuth page
5. User logs in with their own Gmail credentials
6. Composio redirects back to the app via deep-link (`stremini://composio?provider=gmail&status=success`)
7. Gmail now shows as "Connected" — no API key was ever stored on the device

### Using AI in Any App

1. User is typing in WhatsApp
2. They tap the floating bubble, the AI chat panel opens over WhatsApp
3. They type: "Send a Gmail to john@example.com saying the project is ready"
4. The system detects "Gmail" and "email" keywords, checks Gmail is connected
5. Groq parses the intent into a structured action
6. Composio executes the Gmail API call
7. User sees "Email sent successfully" — all without leaving WhatsApp

### Using Keyboard AI

1. User is typing an email in Gmail
2. They select a sentence they wrote
3. The AI tools toolbar appears with: Correct, Complete, Tone, Translate
4. They tap "Tone" → select "Professional"
5. The selected text is instantly rewritten in a professional tone
6. They tap to accept — the text is replaced in-place

---

## 6. Competitive Landscape

### Why Stremini Is Different

| Feature | Stremini AI | Gboard | SwiftKey | ChatGPT App | Grammarly Keyboard |
|---------|-------------|--------|----------|-------------|-------------------|
| **Floating overlay AI** | ✅ System-wide | ❌ | ❌ | ❌ | ❌ |
| **AI chat in any app** | ✅ | ❌ | ❌ | ❌ (siloed) | ❌ |
| **Keyboard AI (rewrite/translate)** | ✅ 5 tones + 30 langs | Basic predict only | Basic predict only | ❌ | ✅ English only |
| **Service automation** | ✅ 11 services | ❌ | ❌ | ❌ (plugins limited) | ❌ |
| **Multi-step chaining** | ✅ | ❌ | ❌ | ✅ (chat only) | ❌ |
| **Voice typing** | ✅ 14 languages | ✅ | ✅ | ✅ | ❌ |
| **Document/PDF chat** | ✅ OCR + PDF | ❌ | ❌ | ✅ | ❌ |
| **No API key needed for automation** | ✅ (managed OAuth) | N/A | N/A | ❌ | N/A |
| **Open source** | ✅ | ❌ | ❌ | ❌ | ❌ |

### The Key Differentiator

Stremini AI is not a chatbot app, not just a keyboard, and not just an automation tool — it's the **first product to combine all three** into a single system-wide experience. The AI doesn't live in a box; it lives on your screen, in your keyboard, and connected to your services.

---

## 7. Technical Architecture

### 7.1 System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        ANDROID SYSTEM                          │
│                                                                 │
│  ┌──────────────┐    MethodChannel    ┌─────────────────────┐  │
│  │  Flutter App  │◄──────────────────►│   Kotlin Native      │  │
│  │  (Dart/UI)    │                    │   Layer              │  │
│  │              │    EventChannel     │                     │  │
│  │  - HomeScreen│──────────────────►│  - MainActivity      │  │
│  │  - ChatScreen│                    │  - ChatOverlayService│  │
│  │  - Settings  │                    │  - StreminiIME       │  │
│  │  - Providers │                    │  - ComposioClient    │  │
│  │  (Riverpod)  │                    │  - GroqClient        │  │
│  └──────────────┘                    │  - SecurityGuards    │  │
│                                       └──────────┬──────────┘  │
│                                                  │              │
│                              ┌───────────────────┼──────────┐  │
│                              │                   │          │  │
│                              ▼                   ▼          ▼  │
│                        ┌──────────┐      ┌──────────┐ ┌──────┐ │
│                        │ Groq API │      │ Composio │ │Android│ │
│                        │ (LLM)    │      │ (OAuth+  │ │System│ │
│                        │          │      │ Actions) │ │Services│
│                        └──────────┘      └──────────┘ └──────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### 7.2 Cross-Platform Bridge: Flutter + Kotlin

The app uses a **Flutter frontend** (Dart) for the main app UI and a **Kotlin native layer** for system-level features that Flutter cannot access directly. The two layers communicate via:

**MethodChannel `stremini.composio`** — Dart → Kotlin command channel
- `connectComposioService` — Initiate OAuth flow for a service
- `disconnectComposioService` — Disconnect a service (server-side DELETE + local broadcast)
- `executeAutomation` — Send automation instruction for execution
- `getConnectedServices` — Fetch connection status map
- `isComposioConnected` — Check if any service is connected

**EventChannel `stremini.composio/events`** — Kotlin → Dart event stream
- `connection_success` — Fired when OAuth deep-link returns with success status
- `connection_lost` — Fired when a 401 triggers automatic disconnect

**MethodChannel `stremini.chat.overlay`** — Overlay service control
- `startOverlayService` / `stopOverlayService` — Lifecycle management
- `hasOverlayPermission` / `requestOverlayPermission` — Permission handling
- `hasMicrophonePermission` / `requestMicrophonePermission` — Mic access

**MethodChannel `stremini.keyboard`** — Keyboard service bridge
- `isKeyboardEnabled` / `isKeyboardSelected` — Keyboard status
- `openKeyboardSettings` / `showKeyboardPicker` — Keyboard setup

### 7.3 AI Integration — Dual-Model Architecture

Stremini uses **two Groq LLM models** optimized for different use cases:

| Use Case | Model | Max Tokens | Temperature | Rate Limit |
|----------|-------|-----------|-------------|------------|
| **Chat (overlay & in-app)** | Llama 3.3 70B Versatile | 2048 | 0.7 | 30 req / 30s |
| **Keyboard actions** (rewrite, correct, complete, translate) | Llama 3.1 8B Instant | 1024 | 0.2–0.8 | 60 req / 30s |

**Why two models?** Keyboard actions need sub-200ms response times to feel instant. The 8B model delivers this consistently. Chat interactions benefit from the 70B model's superior reasoning, especially for complex automation intent parsing.

**Chat system prompt** — The 70B model is configured as "Stremini AI, a powerful AI assistant built into a keyboard app" with awareness of all 15 Composio services. When a user's request involves an external service, the model acknowledges it and the system routes to the automation engine.

**Keyboard system prompts** — Each action type has a specialized prompt:
- **Complete:** "Return ONLY the completion text, nothing else"
- **Tone:** "Rewrite the user's text in the specified tone. Return ONLY the rewritten text"
- **Correct:** "Fix grammar, spelling, and punctuation. Return ONLY the corrected text"
- **Translate:** "Translate to [language]. Return ONLY the translation"

This "return ONLY" pattern ensures keyboard actions inject text directly without user-visible artifacts.

### 7.4 Composio Managed Authentication

The automation system uses a **developer-managed, user-authenticated** model:

```
Developer's Consumer Key (embedded at build time)
        │
        ▼
┌─────────────────────┐
│  Composio Platform  │ ◄── Server-side token storage
│  backend.composio   │
│  .dev               │
└─────────┬───────────┘
          │ OAuth URL
          ▼
┌─────────────────────┐
│  ComposioAuthActivity│ ◄── WebView (FLAG_SECURE, no screenshots)
│  (Android WebView)   │
└─────────┬───────────┘
          │ User logs in
          ▼
┌─────────────────────┐
│  Service Provider   │ ◄── GitHub / Gmail / WhatsApp etc.
│  (OAuth Provider)   │
└─────────┬───────────┘
          │ Token stored by Composio
          ▼
   Deep-link: stremini://composio?provider=xxx&status=success
```

**API Endpoints used:**

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/v1/connectedAccounts` | Initiate connection (returns OAuth URL) |
| GET | `/api/v1/connectedAccounts` | List all connected accounts |
| GET | `/api/v1/connectedAccounts?providerName=xxx` | Check specific service |
| DELETE | `/api/v1/connectedAccounts/{id}` | Disconnect an account |
| POST | `/api/v1/actions/execute` | Execute an automation action |

**Multi-step chaining:** When Groq determines a user request requires multiple sequential actions, it returns a JSON array of steps. The `executeAutomation()` function loops through each step, passing the previous step's output as context (`_previousStepOutput`) to the next step. This enables workflows like "Create a GitHub issue and then send a Slack message about it" in a single user message.

### 7.5 Android Overlay Service Architecture

The `ChatOverlayService` is the core of the system-wide experience:

- **Foreground service** with `FOREGROUND_SERVICE_SPECIAL_USE` type and a persistent notification
- **Floating bubble** — A `WindowManager`-managed `ImageView` (55dp) that's draggable across the screen
- **Semicircle menu** — 4 items (AI Chat, Keyboard, Connectors, Settings) expand in an arc from the bubble
- **Floating chat panel** — A full chat UI (messages, input, send button, voice input, connectors toggle) in an overlay window
- **Connectors panel** — Service grid with real-time connection status, connect/disconnect buttons
- **Lifecycle-aware** — Service starts when app goes to background, stops when app comes to foreground (via `SessionLifecycleManager`)
- **`FloatingChatController`** — Uses a ground-truth `isCurrentlyVisible: () -> Boolean` lambda (no internal cache) to prevent state desync between the Kotlin service and Dart UI

### 7.6 Security Architecture

#### Network Security

- **HTTPS-only enforcement** — `TrustedHostInterceptor` blocks all non-HTTPS requests
- **Host whitelisting** — Only `api.groq.com`, `backend.composio.dev`, `connect.composio.dev`, `auth.composio.dev`, `app.composio.dev` are allowed
- **Certificate pinning light** — System CAs only; no user-installed CAs (`network_security_config.xml`)
- **Response body cap** — 512 KB max response to prevent OOM attacks
- **Request body cap** — 1 MB max request size

#### Rate Limiting

Per-use-case in-memory rate limiters (sliding window):

| Use Case | Max Requests | Window |
|----------|-------------|--------|
| Chat (overlay) | 30 | 30 seconds |
| Keyboard AI | 60 | 30 seconds |
| Groq chat API | 30 | 30 seconds |
| Groq keyboard API | 60 | 30 seconds |
| Config operations | 10 | 30 seconds |

#### Input Sanitization

- **Control character stripping** — Removes non-printable characters
- **Bidi control removal** — Prevents Unicode direction attacks
- **Excess whitespace normalization** — Collapses multiple spaces/tabs
- **Prompt injection defense** — Detects patterns like "ignore previous instructions", "reveal your prompt", "jailbreak", etc.
- **`protectForAi()` wrapper** — Wraps all user input sent to the LLM with a security boundary preamble, flagging potential injection attempts to the model
- **Dual implementation** — Both Kotlin (`SecurityGuards.kt`) and Dart (`input_sanitizer.dart`) have independent sanitization

#### Data Encryption

- **AES-256-GCM encryption** for all sensitive stored data via `EncryptedPrefs`
- **Android Keystore** backed key generation — Keys never leave the secure hardware
- **GCM authentication tag** (128-bit) — Ensures data integrity
- **IV prepended to ciphertext** — Unique IV per encryption operation

#### WebView Security

- `ComposioAuthActivity` uses `FLAG_SECURE` to prevent screenshots and screen recording
- Full cleanup on destroy: `CookieManager`, `clearCache`, `clearHistory`, `WebStorage`
- No JavaScript bridge exposed

#### ProGuard (Release Builds)

- `isMinifyEnabled = true` — Code obfuscation
- `isShrinkResources = true` — Unused resource removal
- All Stremini, Flutter, OkHttp, JSON, and ML Kit classes are kept
- LogCat stripping: `Log.d`, `Log.v`, `Log.i` calls removed in release

---

## 8. Technology Stack

### Frontend (Flutter / Dart)

| Component | Technology |
|-----------|-----------|
| **Framework** | Flutter 3.x (Dart SDK >=3.0.0) |
| **State Management** | Riverpod 3.x (`AsyncNotifier`, `StateProvider`, `FutureProvider`) |
| **HTTP Client** | `http` package (Dart-side chat) |
| **Local Storage** | `shared_preferences` (settings, chat history) |
| **Image Handling** | `image_picker`, `file_picker`, `mime` |
| **PDF Processing** | `syncfusion_flutter_pdf` |
| **URL Launching** | `url_launcher` |
| **Localization** | `flutter_localizations` (6 languages) |
| **Architecture Pattern** | Clean Architecture (use cases, repositories, providers) |

### Native Layer (Kotlin / Android)

| Component | Technology |
|-----------|-----------|
| **Language** | Kotlin 2.1.0 |
| **Build System** | Gradle 8.11.1, AGP 8.9.1 |
| **Min SDK** | 26 (Android 8.0) |
| **Target SDK** | 36 (Android 16) |
| **HTTP Client** | OkHttp 4.11.0 |
| **JSON Parsing** | org.json (built-in) |
| **OCR** | Google ML Kit Text Recognition 16.0.1 |
| **Encryption** | Android Keystore + AES-256-GCM |
| **UI** | Programmatic (no XML layouts for overlay — `WindowManager` + programmatic views) |

### AI & Automation

| Component | Technology |
|-----------|-----------|
| **LLM Provider** | Groq API (api.groq.com) |
| **Chat Model** | Llama 3.3 70B Versatile |
| **Keyboard Model** | Llama 3.1 8B Instant |
| **Automation** | Composio Managed Auth (backend.composio.dev) |
| **Supported Services** | 11 (GitHub, Gmail, Instagram, Facebook, WhatsApp, Google Drive, Discord, LinkedIn, Reddit, Google Sheets, YouTube) |

### Project Structure

```
Streminiai--main/
├── android/
│   ├── app/src/main/kotlin/com/android/stremini_ai/
│   │   ├── MainActivity.kt              # Flutter embedding + MethodChannel hub
│   │   ├── ChatOverlayService.kt        # Floating bubble, menu, chat, connectors
│   │   ├── StreminiIME.kt               # Full AI keyboard (1760 lines)
│   │   ├── ComposioClient.kt            # Composio REST API + multi-step automation
│   │   ├── ComposioAuthActivity.kt      # WebView OAuth flow
│   │   ├── GroqClient.kt                # Chat LLM client (70B model)
│   │   ├── IMEBackendClient.kt          # Keyboard LLM client (8B model)
│   │   ├── SecurityGuards.kt            # Rate limiters, sanitization, trusted hosts
│   │   ├── EncryptedPrefs.kt            # AES-256-GCM encrypted storage
│   │   ├── KeyboardPanels.kt            # Emoji, Kaomoji, Tone, Language panels
│   │   ├── FloatingChatController.kt    # Chat visibility state (ground-truth lambda)
│   │   ├── BubbleController.kt          # Bubble show/hide animation
│   │   ├── ChatCommandCoordinator.kt    # Session history, command routing
│   │   └── ...
│   └── app/src/main/res/                # XML layouts, drawables, values, configs
├── lib/
│   ├── main.dart                        # App entry (ProviderScope + MaterialApp)
│   ├── screens/
│   │   ├── home/home_screen.dart        # Dashboard with glassmorphic UI
│   │   ├── chat_screen.dart             # Full chat with document upload
│   │   ├── settings_screen.dart         # App settings
│   │   └── contact_us_screen.dart       # FAQ + support
│   ├── providers/
│   │   ├── chat_provider.dart           # Chat state, Groq client, automation routing
│   │   └── app_settings_provider.dart   # Settings persistence (notifications, haptics, theme, language)
│   ├── services/
│   │   ├── composio_service.dart        # Composio Dart client (15 services, keyword detection)
│   │   ├── groq_client.dart             # Dart HTTP client for Groq API
│   │   ├── keyboard_service.dart        # Keyboard status bridge
│   │   ├── permission_service.dart      # Permission check/request bridge
│   │   ├── overlay_service.dart         # Overlay service lifecycle bridge
│   │   └── image_text_extractor.dart     # OCR via ML Kit
│   ├── core/
│   │   ├── security/input_sanitizer.dart # Dart-side prompt injection defense
│   │   ├── theme/                       # AppTheme, AppColors, AppTextStyles
│   │   ├── localization/app_strings.dart # 6-language string map
│   │   ├── constants/app_constants.dart  # Channel names
│   │   ├── result/result.dart           # Result<T> type (success/failure)
│   │   └── widgets/                     # AppDrawer, AppContainer
│   └── features/chat/
│       ├── domain/                       # ChatRepository, UseCases (Clean Architecture)
│       └── data/                         # ChatRepositoryImpl, ChatClient
└── pubspec.yaml
```

---

## 9. Security & Privacy

### Data That Leaves the Device

| Data | Destination | Encryption | Purpose |
|------|------------|-----------|---------|
| Chat messages | Groq API | HTTPS | AI responses |
| Keyboard text | Groq API | HTTPS | Rewrite/correct/translate |
| Service commands | Composio API | HTTPS | Automation execution |
| OCR text | Groq API | HTTPS | Document Q&A |

### Data That Stays on Device

| Data | Storage | Encryption |
|------|---------|-----------|
| Groq API key | SharedPreferences | AES-256-GCM (Android Keystore) |
| Chat history (optional) | SharedPreferences | Plain text (user choice) |
| Clipboard history | SharedPreferences | Plain text |
| Theme/language settings | SharedPreferences | Plain text |
| Keyboard preferences | SharedPreferences | Plain text |

### What Stremini Does NOT Do

- Does not collect, transmit, or store personal data on any Stremini-owned server
- Does not use Firebase Analytics, Crashlytics, or any tracking SDK
- Does not require user registration or accounts
- Does not serve ads
- Does not access contacts, camera, location, or any permission beyond overlay and microphone
- The Composio consumer key is embedded at build time — end users never see or provide any developer key

---

## 10. Supported Integrations

All 11 services use Composio's managed OAuth — users log in with their own credentials via a secure WebView. No API keys are stored on the device.

| Service | Actions | Keywords Detected |
|---------|---------|-------------------|
| **GitHub** | Create issues, manage repos, commits, branches | pull request, repository, commit, issue, github |
| **Gmail** | Send emails, read inbox, manage drafts | send email, email, mail, inbox, gmail |
| **Instagram** | Create posts, stories, reels, DMs | instagram story, instagram post, instagram |
| **Facebook** | Create posts, manage pages, groups | facebook post, facebook page, facebook |
| **WhatsApp** | Send messages | whatsapp message, whatsapp |
| **Google Drive** | Upload files, manage folders | google drive, drive file, upload |
| **Discord** | Send messages, manage servers/channels | discord server, discord channel, discord |
| **LinkedIn** | Manage profile, connections, jobs, posts | linkedin profile, linkedin post, linkedin |
| **Reddit** | Post, comment, manage subreddits | subreddit, reddit post, reddit |
| **Google Sheets** | Read/write cells, manage spreadsheets | google sheets, spreadsheet, sheet |
| **YouTube** | Upload videos, manage channels, comments | youtube, upload video, subscribe |

> **Note:** Telegram, Twitter/X, and TikTok are not supported because they
> do not offer Composio-managed OAuth. End users cannot reliably log in to
> these services from the device.

---

## 11. Build & Development Guide

### Prerequisites

- Flutter SDK (>=3.0.0)
- Android SDK with API 36
- Java 11+
- Groq API key (for AI features)

### Setup

```bash
git clone https://github.com/krishna98877/Stremini.ai.git
cd Stremini.ai

# Create local.properties with your own API keys (NEVER commit this file)
cp android/local.properties.example android/local.properties
# Edit android/local.properties and fill in your Groq + Composio keys

flutter pub get
flutter build apk --release --dart-define=GROQ_API_KEY=gsk_your_key_here
```

### Configuration

**`android/local.properties`** (gitignored — see `android/local.properties.example` for the full template):
```properties
flutter.sdk=/path/to/flutter/sdk
groq.api.key=gsk_your_groq_api_key
composio.consumer.key=ak_your_composio_api_key
auth.config.github=ac_your_github_auth_config_id
auth.config.gmail=ac_your_gmail_auth_config_id
# ... one per service you want to enable
```

The Composio consumer key is embedded at build time via `BuildConfig.COMPOSIO_CONSUMER_KEY`. Set it in `local.properties` (gitignored) or via the `COMPOSIO_CONSUMER_KEY` environment variable.

### Build Output

Release APK: `build/app/outputs/flutter-apk/app-release.apk`

The release build uses ProGuard obfuscation (`isMinifyEnabled = true`) and resource shrinking (`isShrinkResources = true`), signed with the debug keystore by default.

---

## 12. Roadmap

### Near-Term (v1.1)

- **iOS support** — Port the overlay service to iOS using platform channels
- **Custom API key UI** — Let users set their own Groq key directly in the app (currently set in Settings)
- **Conversation branches** — Save and resume multiple chat threads
- **Image generation** — Generate images from text prompts via the floating chat

### Mid-Term (v2.0)

- **On-device LLM** — Run a small model locally for offline keyboard AI (no API needed)
- **Workflow automation builder** — Visual no-code automation builder ("when X happens, do Y")
- **Rich message types** — Tables, code blocks, formatted text in chat
- **Widget support** — Android home screen widget for quick AI access

### Long-Term (v3.0)

- **Stremini API** — Let developers build on top of Stremini's automation layer
- **Team features** — Shared automation workflows, team service accounts
- **Desktop companion** — Browser extension and desktop app with the same automation capabilities
- **App store distribution** — Google Play Store listing with production signing

---

*Built with Flutter, Kotlin, Groq, and Composio. Open source at [github.com/krishna98877/Stremini.ai](https://github.com/krishna98877/Stremini.ai).*