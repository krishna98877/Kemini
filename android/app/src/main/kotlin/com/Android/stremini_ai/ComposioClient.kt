package com.Android.stremini_ai

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.util.Log
import android.view.Gravity
import android.widget.Toast
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.URLEncoder

/**
 * Client for Composio's managed-auth automation platform.
 *
 * Handles:
 * - Listing / checking connected service accounts
 * - Initiating OAuth connection for 13 supported services
 * - Executing automation actions via Composio MCP (natural language → action)
 * - Disconnecting services
 */
class ComposioClient(private val context: Context) {

    companion object {
        private const val TAG = "ComposioClient"
        const val COMPOSIO_API_BASE = "https://backend.composio.dev/api/v1"
        const val COMPOSIO_MCP_URL = "https://connect.composio.dev/mcp"

        // Service definitions — id must match Composio's provider names
        data class ServiceDef(
            val id: String,
            val name: String,
            val keywords: List<String>,   // NLP trigger words
            val color: Long,              // accent color for the icon
        )

        val ALL_SERVICES = listOf(
            ServiceDef("github",       "GitHub",       listOf("github", "repo", "repository", "commit", "pull request", "issue", "branch", "code"),              0xFF6e40c9),
            ServiceDef("gmail",        "Gmail",        listOf("gmail", "email", "mail", "send email", "inbox", "draft"),                                          0xFFEA4335),
            ServiceDef("telegram",     "Telegram",     listOf("telegram", "tg", "message", "send message", "chat", "channel"),                                     0xFF0088cc),
            ServiceDef("twitter",      "Twitter",      listOf("twitter", "tweet", "x.com", "post tweet", "timeline", "retweet"),                                 0xFF1DA1F2),
            ServiceDef("instagram",    "Instagram",    listOf("instagram", "ig", "story", "reel", "post", "dm", "direct message", "follow"),                     0xFFE4405F),
            ServiceDef("facebook",     "Facebook",     listOf("facebook", "fb", "post", "page", "group", "message"),                                              0xFF1877F2),
            ServiceDef("whatsapp",     "WhatsApp",     listOf("whatsapp", "wa", "whats app", "send message"),                                                    0xFF25D366),
            ServiceDef("googlechrome", "Chrome",       listOf("chrome", "browser", "open url", "browse", "search", "tab"),                                        0xFF4285F4),
            ServiceDef("googledrive",  "Google Drive", listOf("drive", "google drive", "upload", "file", "document", "folder", "share file", "spreadsheet"),      0xFF0F9D58),
            ServiceDef("discord",      "Discord",      listOf("discord", "server", "channel", "dm", "message discord", "guild"),                                   0xFF5865F2),
            ServiceDef("linkedin",     "LinkedIn",     listOf("linkedin", "profile", "connection", "job", "post", "network"),                                       0xFF0A66C2),
            ServiceDef("reddit",       "Reddit",       listOf("reddit", "subreddit", "post", "upvote", "comment", "thread"),                                       0xFFFF4500),
            ServiceDef("googleheets",  "Google Sheets",listOf("sheet", "spreadsheet", "google sheets", "cell", "row", "column", "table"),                         0xFF0F9D58),
        )
    }

    private val prefs = EncryptedPrefs.getEncrypted(context, "composio_prefs")

    /** Get the stored Composio API key (from the login flow) */
    fun getApiKey(): String? = prefs.getString("composio_token")

    /** Check if Composio is set up (has API key) */
    fun isConfigured(): Boolean = !getApiKey().isNullOrBlank()

    // ── Connected Accounts ──────────────────────────────────────────────────

    /**
     * Check if a specific service has a connected account.
     * Uses Composio's connected-accounts endpoint.
     */
    suspend fun isServiceConnected(serviceId: String): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: return@withContext false
            val client = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")
            val request = okhttp3.Request.Builder()
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
     * Returns map of serviceId → list of account IDs.
     */
    suspend fun getConnectedServices(): Map<String, List<String>> = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: return@withContext emptyMap()
            val client = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")
            val request = okhttp3.Request.Builder()
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
     * Opens the auth URL in the device browser.
     * After OAuth completes, Composio redirects to stremini://composio?code=xxx
     */
    fun connectService(serviceId: String) {
        if (!isConfigured()) {
            Toast.makeText(context, "Connect Composio first", Toast.LENGTH_SHORT).show()
            return
        }
        try {
            val encodedService = URLEncoder.encode(serviceId, "UTF-8")
            // Composio's managed auth URL triggers OAuth for the specified provider
            val authUrl = "https://connect.composio.dev/api/v1/auth/connect?providerName=$encodedService&redirectUri=stremini://composio"
            val intent = Intent(Intent.ACTION_VIEW, Uri.parse(authUrl)).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        } catch (e: Exception) {
            Log.e(TAG, "Error opening auth for $serviceId", e)
            Toast.makeText(context, "Could not open auth page", Toast.LENGTH_SHORT).show()
        }
    }

    // ── Disconnect a Service ───────────────────────────────────────────────

    suspend fun disconnectService(serviceId: String): Boolean = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: return@withContext false
            // First get the account ID for this service
            val connected = getConnectedServices()
            val accountIds = connected[serviceId] ?: return@withContext false
            val client = secureHttpClient(connectTimeoutSeconds = 10, readTimeoutSeconds = 15, useCase = "composio")

            for (accountId in accountIds) {
                val request = okhttp3.Request.Builder()
                    .url("$COMPOSIO_API_BASE/connectedAccounts/$accountId")
                    .addHeader("x-api-key", apiKey)
                    .delete()
                    .build()
                client.newCall(request).execute().use { it.close() }
            }
            true
        }.getOrDefault(false)
    }

    // ── Execute Automation (Natural Language) ───────────────────────────────

    /**
     * Send a natural-language instruction to Composio's MCP endpoint.
     * Composio's AI handles intent detection, service routing, and action execution.
     * Returns the result text, or an error message.
     */
    suspend fun executeAutomation(instruction: String): Result<String> = withContext(Dispatchers.IO) {
        runCatching {
            val apiKey = getApiKey() ?: error("Composio not connected")

            val requestBody = JSONObject().apply {
                put("message", sanitizeUserInput(instruction, maxLength = 4_000))
            }.toString()
                .toRequestBody("application/json".toMediaType())

            val request = okhttp3.Request.Builder()
                .url("$COMPOSIO_API_BASE/actions/execute")
                .addHeader("x-api-key", apiKey)
                .addHeader("Content-Type", "application/json")
                .post(requestBody)
                .build()

            secureHttpClient(connectTimeoutSeconds = 15, readTimeoutSeconds = 60, useCase = "composio_execute")
                .newCall(request)
                .execute()
                .use { response ->
                    if (!response.isSuccessful) {
                        when (response.code) {
                            401 -> error("Composio session expired. Please reconnect in Settings.")
                            403 -> error("Permission denied. Reconnect the service and try again.")
                            404 -> error("Action not found. Try rephrasing your request.")
                            422 -> error("Invalid request. Please be more specific.")
                            else -> error("Automation failed. Please try again.")
                        }
                    }
                    val body = response.body?.string() ?: "{}"
                    val json = JSONObject(body)
                    json.optString("result", json.optString("response", json.optString("message", json.optString("output", "Done."))))
                }
        }
    }

    /**
     * Detect which service a user message is likely about, based on keywords.
     * Returns the ServiceDef or null if no match.
     */
    fun detectService(message: String): ServiceDef? {
        val lower = message.lowercase()
        return ALL_SERVICES.firstOrNull { svc ->
            svc.keywords.any { kw -> lower.contains(kw) }
        }
    }
}