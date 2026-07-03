package com.Android.stremini_ai

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Routes user chat messages to either:
 * 1. Groq API (general conversation) — the new brain
 * 2. Composio automation (when a service keyword is detected & Composio is configured)
 *
 * Decision logic:
 * - If Composio is configured AND the message contains a recognized service keyword,
 *   the message is sent to Composio's action execution endpoint.
 * - Otherwise, it goes to Groq for normal AI chat.
 *
 * If Composio automation fails, it falls back to Groq with context about what failed.
 */
class ChatCommandCoordinator(
    private val scope: CoroutineScope,
    private val backendClient: AIBackendClient,
    val composioClient: ComposioClient,
    private val onBotMessage: (String) -> Unit,
) {
    private val sessionHistory = mutableListOf<Map<String, String>>()

    fun processUserMessage(userMessage: String) {
        scope.launch {
            val sanitizedMessage = sanitizeUserInput(userMessage)
            sessionHistory.add(mapOf("role" to "user", "content" to sanitizedMessage))
            if (sessionHistory.size > 20) sessionHistory.removeAt(0)

            val historyToSend = sessionHistory.dropLast(1)

            // Check if this should go to Composio automation
            val detectedService = composioClient.detectService(sanitizedMessage)

            if (composioClient.isConfigured() && detectedService != null) {
                // Route to Composio automation
                onBotMessage("Working on it via ${detectedService.name}...")
                composioClient.executeAutomation(sanitizedMessage)
                    .onSuccess { reply ->
                        sessionHistory.add(mapOf("role" to "assistant", "content" to reply))
                        onBotMessage(reply)
                    }
                    .onFailure { error ->
                        // Fallback to Groq with context about the failed automation
                        val fallbackMessage = "The user tried to do something with ${detectedService.name} but the automation failed. Error: ${error.message}. Help them with their request: $sanitizedMessage"
                        sendToBackend(fallbackMessage, historyToSend)
                    }
            } else if (detectedService != null && !composioClient.isConfigured()) {
                // Service detected but Composio not connected — tell user via Groq
                val helpMessage = "The user wants to use ${detectedService.name} but Composio is not connected. Tell them to go to Settings → Connect Automations to enable it. Their request: $sanitizedMessage"
                sendToBackend(helpMessage, historyToSend)
            } else {
                // Normal AI chat via Groq
                sendToBackend(sanitizedMessage, historyToSend)
            }
        }
    }

    private suspend fun sendToBackend(message: String, history: List<Map<String, String>>) {
        backendClient.sendChatMessage(message, history)
            .onSuccess { reply ->
                sessionHistory.add(mapOf("role" to "assistant", "content" to reply))
                onBotMessage(reply)
            }
            .onFailure { error ->
                sessionHistory.removeLastOrNull()
                onBotMessage(error.message ?: "Something went wrong. Please try again.")
            }
    }

    fun clearHistory() {
        sessionHistory.clear()
    }
}