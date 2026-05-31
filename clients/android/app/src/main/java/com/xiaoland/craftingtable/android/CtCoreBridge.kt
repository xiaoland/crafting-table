package com.xiaoland.craftingtable.android

import uniffi.ct_core.codexRemoteWireContractVersion

object CtCoreBridge {
    fun wireContractLabel(): String =
        runCatching { "wire v${codexRemoteWireContractVersion()}" }
            .getOrElse { "native binding unavailable" }
}
