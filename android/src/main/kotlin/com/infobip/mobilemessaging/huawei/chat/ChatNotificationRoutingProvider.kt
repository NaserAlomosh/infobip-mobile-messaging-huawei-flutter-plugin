package com.infobip.mobilemessaging.huawei.chat

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri

/** No data is exposed. Android initializes this even when a tap starts the process without Flutter. */
class ChatNotificationRoutingProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        ChatNotificationRouting.install(requireNotNull(context))
        return true
    }
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, selectionArgs: Array<out String>?, sortOrder: String?): Cursor? = null
    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
