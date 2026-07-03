package com.Android.stremini_ai

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Routes user chat messages to either:
 * 1. The normal AI backend (general conversation)
 * 2. Composio automation (when a service keyword is detected & Composio is configured)
 *
 * Decision logic:
 * - If Composio is configured AND the message contains a recognized service keyword,
 *   the message is sent to Composio's action execution endpoint.
 * - Otherwise, it goes to the normal AI chat backend.
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
                        // Fallback to normal AI if Composio fails
                        sendToBackend(sanitizedMessage, historyToSend)
                    }
            } else {
                // Normal AI chat
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