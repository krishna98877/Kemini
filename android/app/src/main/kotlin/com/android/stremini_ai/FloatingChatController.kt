package com.android.stremini_ai

/**
 * Controls the floating chat panel visibility.
 *
 * Instead of maintaining a duplicate `isVisible` flag that can go stale
 * when the panel is closed through a different code-path (e.g. the X
 * button calling `hideFloatingChatbot()` directly), this controller
 * always queries the *real* state via [isCurrentlyVisible].
 */
class FloatingChatController(
    private val isCurrentlyVisible: () -> Boolean,
    private val onShow: () -> Unit,
    private val onHide: () -> Unit
) {
    fun toggle() {
        if (isCurrentlyVisible()) hide() else show()
    }

    fun show() {
        if (isCurrentlyVisible()) return
        onShow()
    }

    fun hide() {
        if (!isCurrentlyVisible()) return
        onHide()
    }

    fun setVisible(visible: Boolean) {
        if (visible == isCurrentlyVisible()) return
        if (visible) onShow() else onHide()
    }
}