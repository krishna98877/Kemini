package com.Android.stremini_ai

import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * Routes user chat messages to either:
 * 1. Groq API (general conversation) — the brain
 * 2. Composio automation (when a service keyword is detected & Composio is configured)
 *
 * When Composio is used, Groq is also called to parse the natural language
 * into a specific Composio actionId + structured parameters.
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
                // Route to Composio automation (with Groq intent parsing)
                onBotMessage("Working on it via ${detectedService.name}...")
                composioClient.executeAutomation(
                    instruction = sanitizedMessage,
                    groqClient = backendClient.groq
                )
                    .onSuccess { reply ->
                        sessionHistory.add(mapOf("role" to "assistant", "content" to reply))
                        onBotMessage(reply)
                    }
                    .onFailure { error ->
                        // Fallback to Groq with context about the failed automation
                        val fallbackMessage = "The user tried to do something with ${detectedService.name} but the automation failed: ${error.message}. Help them with their request: $sanitizedMessage"
                        sendToBackend(fallbackMessage, historyToSend)
                    }
            } else if (detectedService != null && !composioClient.isConfigured()) {
                // Service detected but Composio not connected
                val helpMessage = "The user wants to use ${detectedService.name} but Composio automation is not set up. Tell them to: 1) Go to Settings, 2) Enter their Composio API key from composio.dev/settings, 3) Connect ${detectedService.name}. Their request: $sanitizedMessage"
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