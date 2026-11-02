package com.infobip.mobilemessaging.huawei.user

import org.junit.Assert.*
import org.junit.Test
import org.objectweb.asm.ClassReader
import org.objectweb.asm.tree.ClassNode
import org.objectweb.asm.tree.MethodInsnNode

/** Installed-AAR characterization only: does not execute SDK storage or background work. */
class UserPrivacySdkBytecodeTest {
    private val root = "org/infobip/mobile/messaging/"
    private fun calls(owner: String, method: String, descriptor: String? = null): List<MethodInsnNode> {
        val node = ClassNode()
        javaClass.classLoader!!.getResourceAsStream("$root$owner.class")!!.use {
            ClassReader(it).accept(node, 0)
        }
        val target = node.methods.single { it.name == method && (descriptor == null || it.desc == descriptor) }
        return target.instructions.toArray().filterIsInstance<MethodInsnNode>()
    }
    private fun names(owner: String, method: String, descriptor: String? = null) =
        calls(owner, method, descriptor).map { it.name }

    @Test fun `SDK stores pending merge before reporter validation and reads it from preferences`() {
        val save = names("MobileMessagingCore", "saveUser",
            "(L${root}User;L${root}MobileMessaging\$ResultListener;)V")
        assertTrue(save.containsAll(listOf("storeAndMergeUnreportedUserLocally", "patch")))
        assertTrue(save.indexOf("storeAndMergeUnreportedUserLocally") < save.indexOf("patch"))
        assertEquals(listOf("getUnreportedUserData", "merge", "saveUnreportedUserData"),
            names("MobileMessagingCore", "storeAndMergeUnreportedUserLocally"))
        assertTrue(names("MobileMessagingCore", "saveUnreportedUserData").containsAll(listOf("shouldSaveUserData", "toJson", "saveString")))
        assertTrue(names("MobileMessagingCore", "getUnreportedUserData").containsAll(listOf("findString", "fromJson")))
        assertTrue(names("MobileMessagingCore", "getUser").containsAll(listOf("getUnreportedUserData", "merge")))
    }

    @Test fun `SDK sync and network recovery can submit pending data without plugin calls`() {
        val sync = names("MobileMessagingCore", "performSyncActions")
        assertTrue(sync.containsAll(listOf("isDepersonalizeInProgress", "shouldRepersonalize", "repersonalize", "getUnreportedUserData", "patch")))
        assertTrue(sync.indexOf("getUnreportedUserData") < sync.indexOf("patch"))
        assertTrue(names("MobileMessagingCore", "retrySyncOnNetworkAvailable").contains("performSyncActions"))
        assertTrue(names("MobileMessagingSynchronizationReceiver", "onReceive").contains("foregroundSync"))
        assertTrue(names("MobileMessagingConnectivityReceiver", "onReceive").contains("retrySyncOnNetworkAvailable"))
        assertTrue(names("platform/MobileMessagingJobService", "onStartJob").contains("retrySyncOnNetworkAvailable"))
        assertTrue(names("cloud/RegistrationTokenHandler", "sendRegistrationToServer").containsAll(listOf("sync", "lazySync")))
    }

    @Test fun `SDK validates before scheduling transport retries which do not rerun validator`() {
        val reporter = calls("mobileapi/user/UserDataReporter", "patch")
        assertTrue(reporter.any { it.name == "validate" })
        assertTrue(reporter.any { it.name == "execute" })
        assertTrue(reporter.indexOfFirst { it.name == "validate" } < reporter.indexOfFirst { it.name == "execute" })
        val task = calls("mobileapi/user/UserDataReporter\$1", "run", "([L${root}User;)Ljava/lang/Void;")
        assertTrue(task.any { it.name == "patchUser" })
        assertFalse(task.any { it.owner.endsWith("UserDataValidator") })
        assertTrue(names("mobileapi/common/MRetryableTask\$1", "error").contains("postDelayed"))
        assertTrue(names("mobileapi/common/MRetryableTask\$1\$1", "run").contains("execute"))
        assertFalse(calls("mobileapi/user/PersonalizeSynchronizer", "repersonalize").any {
            it.owner.endsWith("UserDataValidator")
        })
    }

    @Test fun `SDK personalization validates identity and logs failure after core force state changes`() {
        val core = names("MobileMessagingCore", "personalize",
            "(L${root}UserIdentity;L${root}UserAttributes;ZZZL${root}MobileMessaging\$ResultListener;)V")
        assertTrue(core.containsAll(listOf("depersonalizeCurrentInstallation", "personalize")))
        assertTrue(core.indexOf("depersonalizeCurrentInstallation") < core.indexOf("personalize"))
        val calls = calls("mobileapi/user/PersonalizeSynchronizer", "personalize")
        assertEquals("validate", calls.first().name)
        assertEquals("(L${root}UserIdentity;)V", calls.first().desc)
        assertTrue(calls.any { it.owner.endsWith("MobileMessagingLogger") && it.name == "e" && it.desc.contains("Throwable") })
        assertTrue(calls.any { it.name == "createFrom" })
        assertTrue(calls.any { it.name == "onResult" })
    }
}
