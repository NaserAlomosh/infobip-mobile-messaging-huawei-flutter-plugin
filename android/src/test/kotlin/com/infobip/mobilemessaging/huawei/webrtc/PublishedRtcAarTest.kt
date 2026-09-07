package com.infobip.mobilemessaging.huawei.webrtc

import org.junit.Assert.*
import org.junit.Test
import org.objectweb.asm.ClassReader
import org.objectweb.asm.Opcodes
import org.objectweb.asm.tree.ClassNode
import org.objectweb.asm.tree.MethodInsnNode
import java.util.zip.ZipFile
import java.util.zip.ZipInputStream

class PublishedRtcAarTest {
    private fun nativeClass(name: String): ClassNode {
        ZipFile(System.getProperty("infobip.rtc.contractAar")).use { aar ->
            ZipInputStream(aar.getInputStream(aar.getEntry("classes.jar"))).use { jar ->
                while (true) {
                    val entry = jar.nextEntry ?: break
                    if (entry.name == "$name.class") return ClassNode().also { ClassReader(jar.readBytes()).accept(it, 0) }
                }
            }
        }
        throw AssertionError("Missing published class $name")
    }

    @Test fun `published final step is a public contract over a private implementation`() {
        val api = nativeClass("com/infobip/webrtc/ui/InfobipRtcUi\$BuilderFinalStep")
        assertTrue(api.access and Opcodes.ACC_PUBLIC != 0)
        assertTrue(api.access and Opcodes.ACC_INTERFACE != 0)
        assertTrue(api.methods.single { it.name == "build" }.access and Opcodes.ACC_PUBLIC != 0)
        val impl = nativeClass("com/infobip/webrtc/ui/InfobipRtcUi\$BuilderFinalStepImpl")
        assertTrue(impl.interfaces.contains(api.name))
        assertTrue(impl.innerClasses.single { it.name == impl.name }.access and Opcodes.ACC_PRIVATE != 0)
    }

    @Test fun `published Firebase service retains unsafe standard core calls requiring feature gate`() {
        val service = nativeClass("com/infobip/webrtc/ui/service/InfobipRtcUiFirebaseService")
        for (name in listOf("onMessageReceived", "onNewToken")) {
            val method = service.methods.single { it.name == name && it.access and Opcodes.ACC_STATIC == 0 }
            assertTrue(method.instructions.toArray().filterIsInstance<MethodInsnNode>().any {
                it.owner == "org/infobip/mobile/messaging/cloud/firebase/MobileMessagingFirebaseService" && it.name == name
            })
        }
    }
}
