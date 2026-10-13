package com.infobip.mobilemessaging.huawei.core

import org.junit.Assert.*
import org.junit.Test
import org.objectweb.asm.ClassReader
import org.objectweb.asm.tree.*

/** Inspect real runtime AAR bytecode without HotSpot eagerly linking optional OEM classes. */
class HuaweiOptionalDependencyTest {
    private fun nativeClass(name: String): ClassNode {
        val stream = javaClass.classLoader!!.getResourceAsStream(name.replace('.', '/') + ".class")!!
        return ClassNode().also { node -> stream.use { ClassReader(it).accept(node, 0) } }
    }
    private fun MethodNode.calls(owner: String, name: String) = instructions.toArray()
        .filterIsInstance<MethodInsnNode>().any { it.owner == owner && it.name == name }

    @Test fun `OEM references retain class-presence checks and Java IO fallbacks`() {
        val files = nativeClass("com.huawei.hms.framework.common.CreateFileUtil")
        for ((method, fallback) in mapOf("newFile" to "java/io/File", "newFileInputStream" to "java/io/FileInputStream",
            "newFileOutputStream" to "java/io/FileOutputStream", "newRandomAccessFile" to "java/io/RandomAccessFile")) {
            val body = files.methods.single { it.name == method }
            assertTrue(method, body.calls("com/huawei/hms/framework/common/ReflectionUtils", "checkCompatible"))
            assertTrue(method, body.calls(fallback, "<init>"))
        }
        val emui = nativeClass("com.huawei.hms.framework.common.EmuiUtil").methods.single { it.name == "isUpPVersion" }
        assertTrue(emui.calls("com/huawei/hms/framework/common/ReflectionUtils", "checkCompatible"))
        assertTrue(emui.tryCatchBlocks.any { it.type == "java/lang/Throwable" })
        val network = nativeClass("com.huawei.hms.framework.common.NetworkUtil").methods.single { it.name == "getHwNetworkType" }
        assertTrue(network.tryCatchBlocks.any { it.type == "java/lang/NoClassDefFoundError" })
    }

    @Test fun `analytics retains capability probe and guarded hatool alternative`() {
        val probe = nativeClass("com.huawei.hms.stats.c").methods.single { it.name == "a" }
        assertTrue(probe.calls("java/lang/Class", "forName"))
        assertTrue(probe.tryCatchBlocks.any { it.type == "java/lang/ClassNotFoundException" })
        val callback = nativeClass("com.huawei.hms.utils.HMSBIInitializer\$a").methods.single { it.name == "onCallBackSuccess" }
        assertTrue(callback.calls("com/huawei/hms/hatool/HmsHiAnalyticsUtils", "init"))
        val network = nativeClass("com.huawei.hms.framework.common.hianalytics.HianalyticsHelper").methods.single { it.name == "<init>" }
        assertTrue(network.tryCatchBlocks.any { it.type == "java/lang/Throwable" })
    }

    @Test fun `all BouncyCastle instructions remain covered by a linkage-safe catch`() {
        val generator = nativeClass("com.huawei.secure.android.common.encrypt.utils.EncryptUtil").methods
            .single { it.name == "a" && it.desc == "()Ljava/security/SecureRandom;" }
        val instructions = generator.instructions.toArray()
        val optional = instructions.filter { instruction ->
            when (instruction) {
                is MethodInsnNode -> instruction.owner.startsWith("org/bouncycastle/")
                is TypeInsnNode -> instruction.desc.startsWith("org/bouncycastle/")
                else -> false
            }
        }
        assertTrue(optional.isNotEmpty())
        optional.forEach { instruction ->
            val offset = generator.instructions.indexOf(instruction)
            assertTrue(generator.tryCatchBlocks.any { block ->
                (block.type == null || block.type == "java/lang/Throwable") &&
                    offset >= generator.instructions.indexOf(block.start) && offset < generator.instructions.indexOf(block.end)
            })
        }
        assertTrue(generator.calls("java/security/SecureRandom", "getInstance"))
    }
}
