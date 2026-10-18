package com.hermesmobile.hermes_mobile

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.graphics.Rect
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

class HermesAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "HermesA11yService"
        var instance: HermesAccessibilityService? = null

        fun isRunning(): Boolean = instance != null

        fun clickByText(query: String, exact: Boolean = false): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false

            val nodes = root.findAccessibilityNodeInfosByText(query)
            if (nodes.isNullOrEmpty()) return false

            for (node in nodes) {
                val nodeText = node.text?.toString() ?: ""
                val nodeDesc = node.contentDescription?.toString() ?: ""
                val matches = if (exact) {
                    nodeText.equals(query, ignoreCase = true) || nodeDesc.equals(query, ignoreCase = true)
                } else {
                    nodeText.contains(query, ignoreCase = true) || nodeDesc.contains(query, ignoreCase = true)
                }

                if (matches) {
                    if (clickNodeOrParent(node)) return true
                }
            }
            return false
        }

        fun clickById(viewId: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false

            val nodes = root.findAccessibilityNodeInfosByViewId(viewId)
            if (nodes.isNullOrEmpty()) return false

            for (node in nodes) {
                if (clickNodeOrParent(node)) return true
            }
            return false
        }

        private fun clickNodeOrParent(node: AccessibilityNodeInfo): Boolean {
            var curr: AccessibilityNodeInfo? = node
            while (curr != null) {
                if (curr.isClickable) {
                    return curr.performAction(AccessibilityNodeInfo.ACTION_CLICK)
                }
                curr = curr.parent
            }
            // If not marked clickable, still try ACTION_CLICK directly
            return node.performAction(AccessibilityNodeInfo.ACTION_CLICK)
        }

        fun clickCoords(x: Float, y: Float, callback: (Boolean) -> Unit) {
            val service = instance
            if (service == null) {
                callback(false)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val path = Path().apply { moveTo(x, y) }
                val stroke = GestureDescription.StrokeDescription(path, 0, 80)
                val gesture = GestureDescription.Builder().addStroke(stroke).build()

                service.dispatchGesture(gesture, object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        callback(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        callback(false)
                    }
                }, null)
            } else {
                callback(false)
            }
        }

        fun swipe(startX: Float, startY: Float, endX: Float, endY: Float, durationMs: Long = 300, callback: (Boolean) -> Unit) {
            val service = instance
            if (service == null) {
                callback(false)
                return
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                val path = Path().apply {
                    moveTo(startX, startY)
                    lineTo(endX, endY)
                }
                val stroke = GestureDescription.StrokeDescription(path, 0, durationMs.coerceIn(100, 1500))
                val gesture = GestureDescription.Builder().addStroke(stroke).build()

                service.dispatchGesture(gesture, object : GestureResultCallback() {
                    override fun onCompleted(gestureDescription: GestureDescription?) {
                        callback(true)
                    }

                    override fun onCancelled(gestureDescription: GestureDescription?) {
                        callback(false)
                    }
                }, null)
            } else {
                callback(false)
            }
        }

        fun inputText(text: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false

            // Try focused input node first
            val focused = root.findFocus(AccessibilityNodeInfo.FOCUS_INPUT)
            if (focused != null && isNodeEditable(focused)) {
                return setTextOnNode(focused, text)
            }

            // Fallback: search any editable node
            val editable = findFirstEditable(root)
            if (editable != null) {
                return setTextOnNode(editable, text)
            }

            return false
        }

        fun setTextByTarget(targetHintOrText: String, textToSet: String): Boolean {
            val service = instance ?: return false
            val root = service.rootInActiveWindow ?: return false

            val nodes = root.findAccessibilityNodeInfosByText(targetHintOrText)
            if (!nodes.isNullOrEmpty()) {
                for (node in nodes) {
                    if (isNodeEditable(node)) {
                        return setTextOnNode(node, textToSet)
                    }
                }
            }

            // Try viewId match
            val idNodes = root.findAccessibilityNodeInfosByViewId(targetHintOrText)
            if (!idNodes.isNullOrEmpty()) {
                for (node in idNodes) {
                    if (isNodeEditable(node)) {
                        return setTextOnNode(node, textToSet)
                    }
                }
            }

            return inputText(textToSet)
        }

        private fun isNodeEditable(node: AccessibilityNodeInfo): Boolean {
            return node.isEditable || node.className?.contains("EditText", ignoreCase = true) == true
        }

        private fun setTextOnNode(node: AccessibilityNodeInfo, text: String): Boolean {
            val args = Bundle().apply {
                putCharSequence(AccessibilityNodeInfo.ACTION_ARGUMENT_SET_TEXT_CHARSEQUENCE, text)
            }
            val res = node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
            if (res) return true

            // Fallback: focus first then set text
            node.performAction(AccessibilityNodeInfo.ACTION_FOCUS)
            return node.performAction(AccessibilityNodeInfo.ACTION_SET_TEXT, args)
        }

        private fun findFirstEditable(node: AccessibilityNodeInfo): AccessibilityNodeInfo? {
            if (isNodeEditable(node)) return node
            for (i in 0 until node.childCount) {
                val child = node.getChild(i) ?: continue
                val res = findFirstEditable(child)
                if (res != null) return res
            }
            return null
        }

        fun performGlobal(action: String): Boolean {
            val service = instance ?: return false
            return when (action.lowercase().trim()) {
                "back" -> service.performGlobalAction(GLOBAL_ACTION_BACK)
                "home" -> service.performGlobalAction(GLOBAL_ACTION_HOME)
                "recents" -> service.performGlobalAction(GLOBAL_ACTION_RECENTS)
                "notifications" -> service.performGlobalAction(GLOBAL_ACTION_NOTIFICATIONS)
                "quick_settings" -> service.performGlobalAction(GLOBAL_ACTION_QUICK_SETTINGS)
                "lock" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                        service.performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
                    } else false
                }
                else -> false
            }
        }

        fun readScreen(): List<Map<String, Any>> {
            val service = instance ?: return emptyList()
            val root = service.rootInActiveWindow ?: return emptyList()

            val elements = mutableListOf<Map<String, Any>>()
            traverse(root, elements, 0)
            return elements
        }

        private fun traverse(node: AccessibilityNodeInfo?, list: MutableList<Map<String, Any>>, depth: Int) {
            if (node == null || depth > 18 || list.size > 80) return

            val text = node.text?.toString()?.trim()
            val desc = node.contentDescription?.toString()?.trim()
            val viewId = node.viewIdResourceName
            val isClickable = node.isClickable
            val isEditable = node.isEditable

            if (!text.isNullOrEmpty() || !desc.isNullOrEmpty() || isClickable || isEditable) {
                val bounds = Rect()
                node.getBoundsInScreen(bounds)

                val map = mutableMapOf<String, Any>(
                    "className" to (node.className?.toString() ?: ""),
                    "isClickable" to isClickable,
                    "isEditable" to isEditable,
                    "bounds" to mapOf(
                        "left" to bounds.left,
                        "top" to bounds.top,
                        "right" to bounds.right,
                        "bottom" to bounds.bottom,
                        "centerX" to bounds.centerX(),
                        "centerY" to bounds.centerY()
                    )
                )
                if (!text.isNullOrEmpty()) map["text"] = text
                if (!desc.isNullOrEmpty()) map["desc"] = desc
                if (!viewId.isNullOrEmpty()) map["viewId"] = viewId

                list.add(map)
            }

            for (i in 0 until node.childCount) {
                traverse(node.getChild(i), list, depth + 1)
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        Log.i(TAG, "HermesAccessibilityService connected successfully")
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // We poll on-demand via MethodChannel queries, so passive logging only
    }

    override fun onInterrupt() {
        Log.w(TAG, "HermesAccessibilityService interrupted")
    }

    override fun onDestroy() {
        super.onDestroy()
        if (instance == this) {
            instance = null
        }
        Log.i(TAG, "HermesAccessibilityService destroyed")
    }
}
