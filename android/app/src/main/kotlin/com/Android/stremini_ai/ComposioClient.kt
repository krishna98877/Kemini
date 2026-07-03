package com.Android.stremini_ai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.widget.Toast
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.net.URLEncoder

/**
 * Client for Composio's managed-auth automation platform.
 *
 * Handles:
 * - Initiating API key setup (opens Composio dashboard)
 * - Checking connected service accounts
 * - Initiating OAuth connection for 13 supported services
 * - Executing automation actions via Composio API
 * - LLM-powered intent parsing (natural language → actionId + params)
 *
 * Authentication: Uses a Composio API key stored in EncryptedPrefs.
 * Get your key at https://composio.dev/settings → API Keys.
 */
class ComposioClient(private val context: Context) {

    companion object {
        private const val TAG = "ComposioClient"
        const val COMPOSIO_API_BASE = "https://backend.composio.dev/api/v1"
        const val COMPOSIO_MCP_URL = "https://connect.composio.dev/mcp"
        const val COMPOSIO_DASHBOARD = "https://composio.dev/settings"

        // Service definitions — id matches Composio's provider slug
        data class ServiceDef(
            val id: String,
            val name: String,
            val keywords: List<String>,
            val color: Long,
        )

        val ALL_SERVICES = listOf(
            ServiceDef("github",        "GitHub",        listOf("github", "repo", "repository", "commit", "pull request", "issue", "branch"),           0xFF6e40c9),
            ServiceDef("gmail",         "Gmail",         listOf("gmail", "email", "mail", "send email", "inbox", "draft"),                               0xFFEA4335),
            ServiceDef("telegram",      "Telegram",      listOf("telegram", "tg", "telegram message", "telegram chat", "telegram channel"),               0xFF0088cc),
            ServiceDef("twitter",       "Twitter",       listOf("twitter", "tweet", "x.com", "post tweet", "timeline", "retweet"),                         0xFF1DA1F2),
            ServiceDef("instagram",     "Instagram",     listOf("instagram", "ig", "instagram story", "instagram reel", "instagram dm", "instagram post"), 0xFFE4405F),
            ServiceDef("facebook",      "Facebook",      listOf("facebook", "fb", "facebook post", "facebook page", "facebook group"),                      0xFF1877F2),
            ServiceDef("whatsapp",      "WhatsApp",      listOf("whatsapp", "wa", "whats app", "whatsapp message"),                                       0xFF25D366),
            ServiceDef("googlechrome",  "Chrome",        listOf("chrome", "browser", "open url", "browse", "search", "tab"),                                 0xFF4285F4),
            ServiceDef("googledrive",   "Google Drive",  listOf("drive", "google drive", "upload", "drive file", "drive folder", "share file"),               0xFF0F9D58),
            ServiceDef("discord",       "Discord",       listOf("discord", "discord server", "discord channel", "discord dm", "guild"),                      0xFF5865F2),
            ServiceDef("linkedin",      "LinkedIn",      listOf("linkedin", "linkedin profile", "linkedin connection", "linkedin job", "linkedin post"),      0xFF0A66C2),
            ServiceDef("reddit",        "Reddit",        listOf("reddit", "subreddit", "reddit post", "upvote", "comment", "thread"),                        0xFFFF4500),
            ServiceDef("googleheets",   "Google Sheets", listOf("sheet", "spreadsheet", "google sheets", "cell", "row", "column", "table"),                  0xFF0F9D58),
        )

        /**
         * Map of common user intents → Composio action IDs.
         * The LLM can also return actions not in this map.
         */
        val INTENT_ACTION_MAP = mapOf(
            // Gmail
            "send_email"      to "GMAIL_SEND_EMAIL",
            "read_email"      to "GMAIL_READ_EMAILS",
            "search_email"    to "GMAIL_SEARCH_EMAILS",
            // GitHub
            "create_issue"    to "GITHUB_CREATE_AN_ISSUE",
            "create_repo"     to "GITHUB_CREATE_A_REPOSITORY",
            "list_repos"      to "GITHUB_LIST_REPOSITORIES_FOR_AUTHENTICATED_USER",
            "create_pr"       to "GITHUB_CREATE_A_PULL_REQUEST",
            // Twitter
            "post_tweet"      to "TWITTER_CREATE_A_TWEET",
            "get_timeline"    to "TWITTER_GET_USER_TIMELINE",
            // Discord
            "send_discord"    to "DISCORD_SEND_A_MESSAGE_TO_A_CHANNEL",
            // LinkedIn
            "linkedin_post"   to "LINKEDIN_CREATE_A_POST",
            // Reddit
            "reddit_post"     to "REDDIT_CREATE_A_POST",
            // Google Drive
            "upload_drive"    to "GOOGLE_DRIVE_UPLOAD_FILE",
            "list_drive"      to "GOOGLE_DRIVE_LIST_FILES",
            // Sheets
            "read_sheet"      to "GOOGLE_SHEETS_READ_SHEET",
            "update_sheet"    to "GOOGLE_SHEETS_UPDATE_SHEET",
        )
    }

    private val prefs = EncryptedPrefs.getEncrypted(context, "composio_prefs")

    /** Get the stored Composio API key */
    fun getApiKey(): String? = prefs.getString("composio_token")

    /** Check if Composio is set up (has API key) */
    fun isConfigured(): Boolean = !getApiKey().isNullOrBlank()

    /** Set the Composio API key (called from Settings) */
    fun setApiKey(key: String) {
        prefs.putString("composio_token", key)
    }

    // ── Connected Accounts ──────────────────────────────────────────────────

    /**
     * Check if a specific service has a connected account.
     */
    suspend fun isServiceConnected(serviceId: String): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: return@withContext false
            val client = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")
            val request = Request.Builder()
                .url("$COMPOSIO_API_BASE/connectedAccounts?providerName=${URLEncoder.encode(serviceId, "UTF-8")}")
                .addHeader("x-api-key", apiKey)
                .get()
                .build()
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val body = response.body?.string() ?: return@use false
                    val json = JSONObject(body)
                    val accounts = json.optJSONArray("connectedAccounts") ?: json.optJSONArray("data")
                    accounts != null && accounts.length() > 0
                } else false
            }
        }.getOrDefault(false)
    }

    /**
     * Get all connected account IDs grouped by service.
     */
    suspend fun getConnectedServices(): Map<String, List<String>> = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: return@withContext emptyMap()
            val client = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")
            val request = Request.Builder()
                .url("$COMPOSIO_API_BASE/connectedAccounts")
                .addHeader("x-api-key", apiKey)
                .get()
                .build()
            client.newCall(request).execute().use { response ->
                if (response.isSuccessful) {
                    val body = response.body?.string() ?: return@use emptyMap()
                    val json = JSONObject(body)
                    val accounts = json.optJSONArray("connectedAccounts") ?: json.optJSONArray("data") ?: return@use emptyMap()
                    val result = mutableMapOf<String, MutableList<String>>()
                    for (i in 0 until accounts.length()) {
                        val acct = accounts.getJSONObject(i)
                        val provider = acct.optString("providerName", acct.optString("provider", ""))
                        val id = acct.optString("id", acct.optString("connectedAccountId", ""))
                        if (provider.isNotBlank() && id.isNotBlank()) {
                            result.getOrPut(provider) { mutableListOf() }.add(id)
                        }
                    }
                    result
                } else emptyMap()
            }
        }.getOrDefault(emptyMap())
    }

    // ── Connect a Service (Managed Auth) ───────────────────────────────────

    /**
     * Initiate Composio managed OAuth for a service.
     *
     * Step 1: POST to /connectedAccounts with providerName → get the auth URL
     * Step 2: Open that auth URL in the browser for OAuth
     */
    fun connectService(serviceId: String) {
        if (!isConfigured()) {
            Toast.makeText(context, "Set your Composio API key first", Toast.LENGTH_SHORT).show()
            return
        }
        // Launch a coroutine to call the API and get the auth URL
        kotlinx.coroutines.CoroutineScope(Dispatchers.IO).launch {
            try {
                val apiKey = getApiKey() ?: return@launch
                val body = JSONObject().apply {
                    put("providerName", serviceId)
                    put("redirectUri", "stremini://composio")
                }.toString().toRequestBody("application/json".toMediaType())

                val request = Request.Builder()
                    .url("$COMPOSIO_API_BASE/connectedAccounts")
                    .addHeader("x-api-key", apiKey)
                    .addHeader("Content-Type", "application/json")
                    .post(body)
                    .build()

                val response = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")
                    .newCall(request).execute()

                if (response.isSuccessful) {
                    val respBody = response.body?.string() ?: "{}"
                    val json = JSONObject(respBody)
                    // Composio returns the redirect URL in the response
                    val authUrl = json.optString("redirectUrl", json.optString("authUrl", json.optString("connectionUrl", "")))
                    if (authUrl.isNotBlank()) {
                        kotlinx.coroutines.Dispatchers.Main.immediate {
                            try {
                                val intent = Intent(Intent.ACTION_VIEW, Uri.parse(authUrl)).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                context.startActivity(intent)
                            } catch (e: Exception) {
                                Toast.makeText(context, "Could not open auth page", Toast.LENGTH_SHORT).show()
                            }
                        }
                    } else {
                        // If no URL returned, open Composio dashboard for manual connection
                        kotlinx.coroutines.Dispatchers.Main.immediate {
                            val intent = Intent(Intent.ACTION_VIEW, Uri.parse("$COMPOSIO_DASHBOARD/connected-accounts")).apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(intent)
                        }
                    }
                } else {
                    Log.e(TAG, "connectService failed: ${response.code}")
                    kotlinx.coroutines.Dispatchers.Main.immediate {
                        Toast.makeText(context, "Connection failed. Try from Composio dashboard.", Toast.LENGTH_SHORT).show()
                    }
                }
            } catch (e: Exception) {
                Log.e(TAG, "connectService error", e)
                kotlinx.coroutines.Dispatchers.Main.immediate {
                    // Fallback: open Composio dashboard
                    val intent = Intent(Intent.ACTION_VIEW, Uri.parse("$COMPOSIO_DASHBOARD/connected-accounts")).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                    context.startActivity(intent)
                }
            }
        }
    }

    // ── Disconnect a Service ───────────────────────────────────────────────

    suspend fun disconnectService(serviceId: String): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: return@withContext false
            val connected = getConnectedServices()
            val accountIds = connected[serviceId] ?: return@withContext false
            val client = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")

            for (accountId in accountIds) {
                val request = Request.Builder()
                    .url("$COMPOSIO_API_BASE/connectedAccounts/$accountId")
                    .addHeader("x-api-key", apiKey)
                    .delete()
                    .build()
                client.newCall(request).execute().use { it.close() }
            }
            true
        }.getOrDefault(false)
    }

    // ── Execute Automation ─────────────────────────────────────────────────

    /**
     * Execute a Composio action by action ID with structured parameters.
     *
     * @param actionId Composio action ID (e.g., "GMAIL_SEND_EMAIL")
     * @param params Map of input parameters for the action
     * @param connectedAccountId The connected account to use
     */
    suspend fun executeAction(
        actionId: String,
        params: Map<String, Any>,
        connectedAccountId: String
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: error("Composio not connected")

            val body = JSONObject().apply {
                put("actionId", actionId)
                put("inputParams", JSONObject(params))
                put("connectedAccountId", connectedAccountId)
            }.toString().toRequestBody("application/json".toMediaType())

            val request = Request.Builder()
                .url("$COMPOSIO_API_BASE/actions/execute")
                .addHeader("x-api-key", apiKey)
                .addHeader("Content-Type", "application/json")
                .post(body)
                .build()

            secureHttpClient(connectTimeoutSeconds = 15, readTimeoutSeconds = 60, useCase = "composio_execute")
                .newCall(request)
                .execute()
                .use { response ->
                    if (!response.isSuccessful) {
                        val errBody = response.body?.string() ?: ""
                        when (response.code) {
                            401 -> error("Composio session expired. Please reconnect in Settings.")
                            403 -> error("Permission denied. Reconnect the service and try again.")
                            else -> {
                                try {
                                    val errJson = JSONObject(errBody)
                                    error(errJson.optString("message", "Automation failed. Please try again."))
                                } catch (_: Exception) {
                                    error("Automation failed (error ${response.code}). Please try again.")
                                }
                            }
                        }
                    }
                    val respBody = response.body?.string() ?: "{}"
                    val json = JSONObject(respBody)
                    // Composio returns result data — try to extract a readable response
                    val resultData = json.optJSONObject("result") ?: json.optJSONObject("data") ?: json
                    resultData.optString("message", resultData.optString("response", resultData.optString("output",
                        if (resultData.length() > 0) resultData.toString().take(500) else "Done."
                    )))
                }
        }
    }

    /**
     * High-level automation: takes natural language, finds the right account,
     * and uses the LLM (Groq) to parse the intent into an action + params.
     *
     * @param instruction The user's natural language request
     * @param groqClient The Groq client for intent parsing
     */
    suspend fun executeAutomation(
        instruction: String,
        groqClient: GroqClient? = null
    ): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: error("Composio not connected")

            // Step 1: Detect which service
            val service = detectService(instruction)
                ?: error("Couldn't detect which service to use. Try mentioning the service name.")

            // Step 2: Get a connected account for this service
            val connected = getConnectedServices()
            val accountIds = connected[service.id]
            if (accountIds.isNullOrEmpty()) {
                error("${service.name} is not connected. Go to Settings → Automations and connect it first.")
            }
            val accountId = accountIds.first()

            // Step 3: Use Groq to parse the intent into actionId + params
            val actionParams = if (groqClient != null) {
                parseIntentWithLLM(instruction, service, groqClient)
            } else {
                // Fallback: try keyword-based mapping
                parseIntentByKeywords(instruction, service)
            }

            if (actionParams == null) {
                error("Couldn't understand what action to take. Try being more specific, e.g. 'send an email to john@example.com'")
            }

            // Step 4: Execute the action
            val (actionId, params) = actionParams
            executeAction(actionId, params, accountId).getOrThrow()
        }
    }

    /**
     * Use Groq to parse natural language into a Composio actionId + params.
     */
    private suspend fun parseIntentWithLLM(
        instruction: String,
        service: ServiceDef,
        groqClient: GroqClient
    ): Pair<String, Map<String, Any>>? {
        val prompt = """You are an automation intent parser. Given a user request for ${service.name}, return a JSON object with exactly two fields:
- "actionId": The most appropriate Composio action ID for ${service.name}. Common ones: ${INTENT_ACTION_MAP.values.filter { it.startsWith(service.id.uppercase()) }.joinToString(", ")}
- "params": A flat key-value map of parameters needed for this action.

User request: $instruction

Return ONLY valid JSON, nothing else. Example: {"actionId":"GMAIL_SEND_EMAIL","params":{"to":"john@example.com","subject":"Hello","body":"Hi there"}}"""

        val response = groqClient.sendMessage(
            message = prompt,
            history = emptyList()
        )

        return runCatching {
            // Extract JSON from the response (may be wrapped in markdown code blocks)
            val jsonStr = response
                .replace(Regex("```json\\s*"), "")
                .replace(Regex("```\\s*"), "")
                .trim()
            val json = JSONObject(jsonStr)
            val actionId = json.getString("actionId")
            val paramsJson = json.getJSONObject("params")
            val params = mutableMapOf<String, Any>()
            paramsJson.keys().forEach { key ->
                params[key] = paramsJson.get(key)
            }
            Pair(actionId, params)
        }.getOrNull()
    }

    /**
     * Keyword-based fallback for intent parsing (no LLM needed).
     */
    private fun parseIntentByKeywords(
        instruction: String,
        service: ServiceDef
    ): Pair<String, Map<String, Any>>? {
        val lower = instruction.lowercase()

        return when (service.id) {
            "gmail" -> when {
                lower.contains("send") && (lower.contains("email") || lower.contains("mail")) -> {
                    val toRegex = Regex("(?:to|for)\\s+([\\w.+-]+@[\\w.-]+)", RegexOption.IGNORE_CASE)
                    val toMatch = toRegex.find(instruction)
                    val subjectRegex = Regex("(?:subject|about|re)\\s+[:\"]?([^\".]+)", RegexOption.IGNORE_CASE)
                    val subjectMatch = subjectRegex.find(instruction)
                    "GMAIL_SEND_EMAIL" to mapOf(
                        "to" to (toMatch?.groupValues?.get(1) ?: ""),
                        "subject" to (subjectMatch?.groupValues?.get(1)?.trim() ?: "No subject"),
                        "body" to instruction
                    )
                }
                else -> "GMAIL_READ_EMAILS" to mapOf("maxResults" to 10)
            }
            "github" -> when {
                lower.contains("issue") && lower.contains("create") -> "GITHUB_CREATE_AN_ISSUE" to mapOf(
                    "owner" to "", "repo" to "", "title" to instruction
                )
                lower.contains("repo") && lower.contains("create") -> "GITHUB_CREATE_A_REPOSITORY" to mapOf(
                    "name" to "new-repo", "private" to false
                )
                else -> "GITHUB_LIST_REPOSITORIES_FOR_AUTHENTICATED_USER" to emptyMap()
            }
            "twitter" -> "TWITTER_CREATE_A_TWEET" to mapOf("text" to instruction)
            "discord" -> "DISCORD_SEND_A_MESSAGE_TO_A_CHANNEL" to mapOf("content" to instruction)
            "linkedin" -> "LINKEDIN_CREATE_A_POST" to mapOf("text" to instruction)
            "reddit" -> "REDDIT_CREATE_A_POST" to mapOf("title" to instruction, "text" to instruction)
            "googledrive" -> "GOOGLE_DRIVE_UPLOAD_FILE" to mapOf("content" to instruction)
            "googleheets" -> "GOOGLE_SHEETS_READ_SHEET" to mapOf("spreadsheetId" to "", "range" to "A1:Z100")
            else -> null
        }
    }

    // ── Service Detection (Longest-Match) ─────────────────────────────────

    /**
     * Detect which service a user message is likely about.
     * Uses longest-keyword-match to avoid collisions (e.g., "discord message" beats "message" → Telegram).
     */
    fun detectService(message: String): ServiceDef? {
        val lower = message.lowercase()
        var bestMatch: ServiceDef? = null
        var bestKeywordLength = 0

        for (svc in ALL_SERVICES) {
            for (kw in svc.keywords) {
                if (lower.contains(kw) && kw.length > bestKeywordLength) {
                    bestMatch = svc
                    bestKeywordLength = kw.length
                }
            }
        }
        return bestMatch
    }
}