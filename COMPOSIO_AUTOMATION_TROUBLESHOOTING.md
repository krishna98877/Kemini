# Composio Automation — Developer Troubleshooting Map

> **Use this file when the chatbot automation breaks.** It lists every file
> in the execution path, what it does, and which bugs have historically
> lived there. Open files in the order listed below when diagnosing.

---

## The automation pipeline (in execution order)

When a user types "send hi to royal on whatsapp" in the floating chatbot:

```
1. ChatOverlayService.kt
   └─ processUserCommand(message)
      └─ chatCommandCoordinator.processUserMessage(message)

2. ChatCommandCoordinator.kt          ← ROUTING DECISION
   ├─ detectService(message)          → returns ServiceDef or null
   ├─ hasActionVerb check             → must contain send/post/create/etc.
   ├─ isConnectorActive(serviceId)    ← toggle + connected check
   │  └─ if false → route to Groq with "please connect/toggle" message
   └─ executeAutomation(instruction, groqClient)

3. ComposioClient.kt                  ← THE BRAIN
   └─ executeAutomation(instruction, groqClient)
      ├─ getConnectedServices()       → Map<serviceId, List<accountId>>
      ├─ parseMultiStepIntent()       → LLM plans 1+ steps (if groqClient != null)
      │  ├─ if steps.size > 1 → multi-step execution chain
      │  ├─ if steps.size == 1 → single-step fast path (reuse LLM params)
      │  └─ if steps empty     → fall through to single-service path
      ├─ getCachedAutomation()        → AI learning cache (skip LLM on repeat)
      ├─ parseIntentWithLLM()         → LLM parses single-service intent
      ├─ parseIntentByKeywords()      → regex fallback if no LLM
      ├─ resolveContactParams()       ← CRITICAL: normalize param names + strip +
      └─ executeAction(actionId, params, accountId, serviceId)

4. ComposioClient.kt (executeAction)  ← THE WIRE
   └─ executeActionInternal()
      ├─ POST /api/v3.1/tools/execute/{actionId}
      │  Body: { arguments, entity_id, connected_account_id }
      ├─ check response.successful == true
      └─ extract data → return human-readable result string
```

---

## Files to check (in priority order)

### 1. `android/app/src/main/kotlin/com/android/stremini_ai/ChatCommandCoordinator.kt`

**Role:** Routes user messages between Groq (chat) and Composio (automation).

**Check when:**
- Chatbot says "tap the plug icon" even when service IS connected → check `isConnectorActive()` / `isServiceConnected()`
- Chatbot routes a casual mention ("I love gmail") to automation → check `hasActionVerb` list
- Chatbot ignores a real automation request → check `detectService()` keyword list
- Plugins fire even when toggled OFF → check `isConnectorActive()` (not `isServiceConnected()`)

**Key functions:**
- `processUserMessage(userMessage)` — the entry point
- `hasActionVerb` list — must contain the verb the user used
- `isConnectorActive()` call — gates automation behind the toggle

---

### 2. `android/app/src/main/kotlin/com/android/stremini_ai/ComposioClient.kt`

**Role:** The entire Composio integration. **This file is where 90% of automation bugs live.**

**Check when:**
- "Says done but didn't actually send" → check `resolveContactParams()` (param name normalization)
- "Service not connected" when it IS connected → check `isServiceConnected()` (slug parsing)
- WhatsApp fails with "Invalid phone number" → check `resolveContactParams()` (must strip leading `+`)
- Instagram fails with "user cannot be found" → check `INSTAGRAM_DEFAULT_PSID` (must be a recipient PSID, not page PSID)
- Connect button does nothing → check `authConfigFor(serviceId)` (must return non-empty from BuildConfig)
- 401 on execute → check `prefs.getString("composio_connected_user_id")` (must match the account's user_id)
- LLM returns wrong param names → check `parseIntentWithLLM()` prompt
- Multi-step chain fails → check `parseMultiStepIntent()` prompt + `resolveContactParams` per step

**Key functions (in call order):**
- `ALL_SERVICES` — list of 11 services. **Add/remove services here.**
- `INTENT_ACTION_MAP` — maps intent keys to Composio action IDs
- `SERVICE_ACTION_PREFIX` — used to filter actions per service for the LLM prompt
- `authConfigFor(serviceId)` — resolves auth_config_id from BuildConfig
- `getDeveloperApiKey()` — reads Composio key from BuildConfig/EncryptedPrefs
- `isConfigured()` — true if Composio key is present
- `getOrCreateSession()` — creates/returns Composio session ID
- `isServiceConnected(serviceId)` — checks if any ACTIVE account exists for the service
- `isConnectorActive(serviceId)` — checks toggle state + isServiceConnected
- `setConnectorActive(serviceId, active)` — persists toggle state
- `getConnectedServices()` — returns Map<serviceId, List<accountId>> for ACTIVE accounts
- `connectService(serviceId)` — initiates OAuth flow (opens Chrome)
- `disconnectService(serviceId)` — DELETEs the connected account
- `executeAutomation(instruction, groqClient)` — high-level: parse + execute
- `parseMultiStepIntent(instruction, groqClient)` — LLM plans multi-step chain
- `parseIntentWithLLM(instruction, service, groqClient)` — LLM parses single-service intent
- `parseIntentByKeywords(instruction, service)` — regex fallback (no LLM)
- `resolveContactParams(actionId, params)` — **CRITICAL** normalizes param names per service
- `executeAction(actionId, params, accountId, serviceId)` — POSTs to /tools/execute
- `executeActionInternal(...)` — the actual HTTP call + response parsing
- `resolveContact(name)` — looks up phone number from device contacts
- `cacheAutomationResult()` / `getCachedAutomation()` — AI learning cache

**Constants (in companion object):**
- `COMPOSIO_API_BASE` = `https://backend.composio.dev/api/v3`
- `COMPOSIO_TOOLS_API_BASE` = `https://backend.composio.dev/api/v3.1`
- `WHATSAPP_PHONE_NUMBER_ID` — from BuildConfig (your WhatsApp Business number ID)
- `INSTAGRAM_DEFAULT_PSID` — from BuildConfig (your Instagram page PSID)

---

### 3. `android/app/src/main/kotlin/com/android/stremini_ai/ChatOverlayService.kt`

**Role:** The floating bubble + chatbot UI + connectors panel.

**Check when:**
- Plug icon doesn't respond to taps → check `setupFloatingChatListeners()` (btn_connectors_toggle)
- Toggle switch doesn't persist → check it calls `composioClient.setConnectorActive()`
- Connectors panel layout is wrong → check `buildManusStyleConnectorRow()` / `buildServiceCell()`
- Bubble jitters on tap → check `onTouch()` (drag threshold) + `shrinkBubble()` (must be alpha-only)
- Plug icon badge shows wrong count → check `updateChatConnectorsToggleIcon()`

**Key functions:**
- `processUserCommand(message)` — delegates to `chatCommandCoordinator.processUserMessage()`
- `setupFloatingChatListeners()` — wires send/mic/plug/close buttons
- `showConnectedAppsPanel()` / `hideConnectedAppsPanel()` — the plug icon's panel
- `buildManusStyleConnectorRow(svc, isConnected)` — builds a row with toggle/connect button
- `showConnectorsPanel()` / `hideConnectorsPanel()` — the menu's automation panel
- `buildServiceCell(svc)` — builds a row for the menu's panel
- `updateChatConnectorsToggleIcon()` — updates the plug icon's badge/color
- `refreshServiceConnectionStates()` — async refresh of connected status
- `onTouch(v, event)` — bubble drag/tap detection

---

### 4. `android/app/src/main/kotlin/com/android/stremini_ai/GroqClient.kt`

**Role:** Calls Groq API for chat + LLM intent parsing.

**Check when:**
- LLM returns garbage JSON → check `sendMessage()` (used by parseIntentWithLLM)
- 401 from Groq → check `getApiKey()` (BuildConfig.GROQ_API_KEY)
- Chatbot always says "couldn't generate a response" → check `MODEL` constant

**Key functions:**
- `sendMessage(message, history)` — POSTs to api.groq.com/openai/v1/chat/completions
- `getApiKey()` — reads from EncryptedPrefs or BuildConfig.GROQ_API_KEY
- `SYSTEM_PROMPT` — defines the Stremini AI persona

---

### 5. `android/app/src/main/kotlin/com/android/stremini_ai/AIBackendClient.kt`

**Role:** Thin wrapper around GroqClient. Exposes `groq` property used by ChatCommandCoordinator.

**Check when:**
- `executeAutomation` falls back to keyword parsing instead of LLM → check that `backendClient.groq` returns non-null

---

### 6. `android/app/src/main/kotlin/com/android/stremini_ai/ComposioAuthActivity.kt`

**Role:** WebView activity that handles the OAuth callback.

**Check when:**
- OAuth flow opens but never returns to the app → check the deep-link handler (`stremini://composio`)
- User logs in but service still shows "not connected" → check the redirect URI parsing

---

### 7. `android/app/src/main/kotlin/com/android/stremini_ai/EncryptedPrefs.kt`

**Role:** AES-256-GCM encrypted SharedPreferences wrapper.

**Check when:**
- Toggle state doesn't persist across app restarts → check `connector_active_*` keys
- Composio session keeps getting recreated → check `composio_session_id` key
- User has to re-connect on every app launch → check `composio_connected_user_id` key

---

### 8. `android/app/build.gradle.kts`

**Role:** Injects all secrets as BuildConfig fields at build time.

**Check when:**
- `authConfigFor(serviceId)` returns empty → check `AUTH_CONFIG_*` fields are set in `local.properties`
- `getDeveloperApiKey()` returns empty → check `COMPOSIO_CONSUMER_KEY` is set
- `BuildConfig.GROQ_API_KEY` is empty → check `groq.api.key` is set in `local.properties`

**The 16 BuildConfig fields:**
- `GROQ_API_KEY`, `COMPOSIO_CONSUMER_KEY`
- `AUTH_CONFIG_GITHUB`, `AUTH_CONFIG_GMAIL`, `AUTH_CONFIG_INSTAGRAM`, `AUTH_CONFIG_FACEBOOK`, `AUTH_CONFIG_WHATSAPP`, `AUTH_CONFIG_GOOGLEDRIVE`, `AUTH_CONFIG_DISCORD`, `AUTH_CONFIG_LINKEDIN`, `AUTH_CONFIG_REDDIT`, `AUTH_CONFIG_GOOGLESHEETS`, `AUTH_CONFIG_YOUTUBE`
- `WHATSAPP_PHONE_NUMBER_ID`, `INSTAGRAM_DEFAULT_PSID`

---

### 9. `android/local.properties` (gitignored — copy from `local.properties.example`)

**Role:** Holds your real API keys. Never committed.

**Check when:**
- Build succeeds but automation doesn't work → keys are missing or wrong
- Connect button says "Connectors not configured" → `composio.consumer.key` is empty
- Chatbot says "Groq API key not set" → `groq.api.key` is empty

---

### 10. `lib/services/composio_service.dart`

**Role:** Dart-side mirror of ComposioClient. Manages the Flutter UI's connection state.

**Check when:**
- Flutter settings screen shows wrong connection status → check `refreshServiceStatuses()` + EventChannel
- Disconnect from settings doesn't update the chatbot → check the `SERVICE_DISCONNECTED` broadcast

---

### 11. `lib/providers/chat_provider.dart`

**Role:** Dart-side Groq key resolution + chat state.

**Check when:**
- Flutter chat screen can't talk to Groq → check `_resolveGroqApiKey()` (needs `--dart-define=GROQ_API_KEY=...`)

---

## Common symptoms → root cause → file

| Symptom | Root cause | File |
|---------|-----------|------|
| "Says done but didn't send" | Wrong param names (e.g. `to` instead of `to_number`) | `ComposioClient.kt` → `resolveContactParams()` + LLM prompt |
| WhatsApp "Invalid phone number" | Leading `+` not stripped | `ComposioClient.kt` → `resolveContactParams()` |
| Chatbot says "not connected" when it IS | `isServiceConnected()` slug parsing | `ComposioClient.kt` → `isServiceConnected()` |
| Connect button does nothing | `authConfigFor()` returns empty | `build.gradle.kts` + `local.properties` |
| 401 on execute | Wrong `entity_id` | `ComposioClient.kt` → `executeActionInternal()` + `getConnectedServices()` |
| Plugins fire when toggled OFF | `isConnectorActive()` not checked | `ChatCommandCoordinator.kt` → `processUserMessage()` |
| LLM returns non-JSON | Prompt too loose | `ComposioClient.kt` → `parseIntentWithLLM()` |
| Cache returns stale action | Instruction hash collision | `ComposioClient.kt` → `getCachedAutomation()` |
| Multi-step chain breaks at step N | Previous step output not in params | `ComposioClient.kt` → `executeAutomation()` loop |
| Bubble jitters on tap | Idle anim moves position | `ChatOverlayService.kt` → `shrinkBubble()` |
| Plug icon silent on tap | No press feedback | `ChatOverlayService.kt` → `setupFloatingChatListeners()` |

---

## How to live-test the pipeline (without building the app)

You can reproduce the exact API calls the app makes using `curl`. This is
the fastest way to isolate whether a bug is in your code or in Composio.

```bash
# 1. List connected accounts (checks API key + auth_config_ids)
curl -sS "https://backend.composio.dev/api/v3/connected_accounts" \
  -H "x-api-key: YOUR_COMPOSIO_KEY" | python3 -m json.tool

# 2. Execute a Gmail send (end-to-end test)
curl -sS -X POST "https://backend.composio.dev/api/v3.1/tools/execute/GMAIL_SEND_EMAIL" \
  -H "x-api-key: YOUR_COMPOSIO_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "arguments": {"to":"you@example.com","subject":"Test","body":"Hello"},
    "entity_id": "USER_ID_FROM_CONNECTED_ACCOUNT",
    "connected_account_id": "ca_XXXXXXXXXXXX"
  }'

# 3. Execute a WhatsApp send (remember: NO leading +)
curl -sS -X POST "https://backend.composio.dev/api/v3.1/tools/execute/WHATSAPP_SEND_MESSAGE" \
  -H "x-api-key: YOUR_COMPOSIO_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "arguments": {"to_number":"15551234567","text":"Hello","phone_number_id":"YOUR_PHONE_NUMBER_ID"},
    "entity_id": "USER_ID_FROM_CONNECTED_ACCOUNT",
    "connected_account_id": "ca_XXXXXXXXXXXX"
  }'
```

If the curl call succeeds but the app fails, the bug is in the app's code
(usually `resolveContactParams` or `isServiceConnected`). If the curl call
also fails, the bug is in your Composio dashboard config (auth_config_id,
connected account, or API key).

---

## Debug logging

The app logs extensively to logcat under these tags:
- `ComposioClient` — every API call, param normalization, cache hit/miss
- `ChatOverlayService` — UI events, panel visibility, touch handling
- `GroqClient` — (minimal; most logging is in ComposioClient)

Filter with:
```bash
adb logcat -s ComposioClient:* ChatOverlayService:* GroqClient:*
```

---

**Last verified working:** 2026-07-07 (commit `d3e0e44` + Part 1 fixes)
- Gmail send: ✅ successful, real email delivered
- WhatsApp send: ✅ reaches Composio (recipient validation is WhatsApp-side)
- Instagram send: ✅ reaches Composio (recipient validation is Instagram-side)
- isServiceConnected: ✅ correctly detects ACTIVE accounts
- Toggle persistence: ✅ survives app restart via EncryptedPrefs
- Cache (single-step): ✅ stores resolved params, re-normalizes on hit (Fix #1)
- Cache key: ✅ collision-free full-string key (Fix #2)
- Param normalization: ✅ all 11 services covered (Fix #3)
- Cache (multi-step): ✅ full step list cached on success (Fix #4)
- `clearAutomationCache()` API: ✅ exposed for debugging/reset

### Part 1 fixes applied (commit `8a6ee23`)
- **Fix #1**: Cache HIT now re-runs `resolveContactParams()` — closed the bypass bug where cached raw params (`to_number:"royal"`) would skip normalization and silently fail on repeat. Cache now stores RESOLVED params.
- **Fix #2**: Cache key is now the full lowercased + trimmed instruction string (collision-free), not `String.hashCode()` (32-bit, collision-prone). Added `cacheKey()` helper that also collapses internal whitespace so `"send  hi"` and `"send hi"` hit the same key.
- **Fix #3**: Added `resolveContactParams()` branches for Facebook, LinkedIn, Reddit, Google Drive, Google Sheets, YouTube. These 6 services previously had ZERO normalization — LLM-hallucinated field names (`"post"` for Facebook, `"filename"` for Drive, etc.) silently no-oped with `successful:true`. Each now has a synonym map mirroring the WhatsApp/Instagram/Gmail/Discord/GitHub pattern.
- **Fix #4**: Multi-step automation plans now cached on success via `cacheMultiStepAutomation()` + `getCachedMultiStepAutomation()`. Repeat multi-step commands (e.g. "check Gmail for invoices then add to Sheets") skip the 2-5s LLM round-trip entirely. Cache stores RESOLVED params per step; cache-hit path re-runs `resolveContactParams` defensively.
- Also added: `clearAutomationCache(instruction?)` public API for debugging/reset, `EncryptedPrefs.allKeys()` method.

### Part 2 security fixes applied (commit `e88e5e1`)
- **S1**: Deep-link spoof protection — `MainActivity.verifyAndNotifyFlutter()` re-checks with real API before notifying Flutter; Dart side only trusts `verified: true` events.
- **S2**: OAuth state nonce — `setPendingConnect()` / `validateAndConsumePendingConnect()` with 10-min TTL. Redirect rejected if no pending connect exists.
- **S3**: `ComposioAuthActivity` no longer defaults to success on ambiguous redirects — calls `isServiceConnected()` to verify before showing the green checkmark.
- **S4**: Documented client-embedded key risk in `SECURITY.md` (highest-impact limitation; migrate to backend proxy for production).
- **S5**: PII-safe logging — `safeInstruction()`, `safeParams()`, `safePhoneTail()` helpers replace all raw-param `Log.i` calls.

### Part 3 performance fixes applied (commit pending)
- **P1**: Cache check moved BEFORE any LLM call. Repeat commands now execute in ~0ms (cache hit) + API call time, instead of paying the full 2-5s LLM round-trip every time. Both single-service and multi-step caches are checked before `parseMultiStepIntent()`.
- **P2**: In-memory cache for `getConnectedServices()` with 30s TTL. Eliminates the double-fetch (was: `isConnectorActive()` → `isServiceConnected()` → `GET /connected_accounts`, then `executeAutomation()` → `getConnectedServices()` → same endpoint again). Saves 400-1600ms per command. Cache invalidated on connect/disconnect.
- **P3**: Local pre-check skips the multi-step planner for single-service messages. `looksLikeMultiStep()` checks for connector words ("then", "after that", "also", etc.). If exactly one service is detected AND no connector words → go straight to the smaller `parseIntentWithLLM()` prompt. Saves 2-5s + 2-4x tokens on trivial single-service commands.
- **P4**: Concurrent execution for independent multi-step chains. Steps without `_dependsOnPreviousStep: true` now run via `async {}` + `await()`. Dependent steps still run sequentially. Cuts total latency from N×stepTime to ~1×stepTime for independent chains (e.g. "post to Discord AND send a Gmail").
