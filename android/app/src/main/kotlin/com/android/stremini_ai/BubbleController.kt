package com.android.stremini_ai

class BubbleController(
    private val onHide: () -> Unit,
    private val onShow: () -> Unit
) {
    private var isVisible = true

    fun setVisible(visible: Boolean) {
        isVisible = visible
    }

    fun toggle() {
        if (isVisible) {
            try { onHide(); isVisible = false } catch (_: Exception) {}
        } else {
            try { onShow(); isVisible = true } catch (_: Exception) {}
        }
    }
}
