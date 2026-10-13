.method public static getAuthorizationHeader(Lorg/infobip/mobile/messaging/MobileMessagingCore;Lorg/infobip/mobile/messaging/MobileMessaging$ResultListener;)Ljava/lang/String;
    .registers 4

    invoke-virtual {p0}, Lorg/infobip/mobile/messaging/MobileMessagingCore;->getJwtFromSupplier()Ljava/lang/String;

    move-result-object v0

    if-eqz v0, :cond_26

    :try_start_6
    invoke-static {v0}, Lorg/infobip/mobile/messaging/util/AuthorizationUtils;->b(Ljava/lang/String;)V
    :try_end_9
    .catch Lorg/infobip/mobile/messaging/util/JwtStructureValidationException; {:try_start_6 .. :try_end_9} :catch_c
    .catch Lorg/infobip/mobile/messaging/util/JwtExpirationException; {:try_start_6 .. :try_end_9} :catch_a

    goto :goto_26

    :catch_a
    move-exception v0

    goto :goto_d

    :catch_c
    move-exception v0

    :goto_d
    const-string v1, "JWT token structure is invalid or the token is expired."

    invoke-static {v1}, Lorg/infobip/mobile/messaging/logging/MobileMessagingLogger;->e(Ljava/lang/String;)V

    if-eqz p1, :cond_24

    new-instance v1, Lorg/infobip/mobile/messaging/mobileapi/Result;

    invoke-virtual {p0}, Lorg/infobip/mobile/messaging/MobileMessagingCore;->getUser()Lorg/infobip/mobile/messaging/User;

    move-result-object p0

    invoke-static {v0}, Lorg/infobip/mobile/messaging/mobileapi/MobileMessagingError;->createFrom(Ljava/lang/Throwable;)Lorg/infobip/mobile/messaging/mobileapi/MobileMessagingError;

    move-result-object v0

    invoke-direct {v1, p0, v0}, Lorg/infobip/mobile/messaging/mobileapi/Result;-><init>(Ljava/lang/Object;Lorg/infobip/mobile/messaging/mobileapi/MobileMessagingError;)V

    invoke-virtual {p1, v1}, Lorg/infobip/mobile/messaging/MobileMessaging$ResultListener;->onResult(Lorg/infobip/mobile/messaging/mobileapi/Result;)V

    :cond_24
    const/4 p0, 0x0

    return-object p0

    :cond_26
    :goto_26
    invoke-virtual {p0}, Lorg/infobip/mobile/messaging/MobileMessagingCore;->getApplicationCode()Ljava/lang/String;

    const-string p1, "Bearer "

    if-eqz v0, :cond_30

    invoke-virtual {p1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;

    :cond_30
    sget-object v1, Ljava/lang/System;->out:Ljava/io/PrintStream;

    invoke-virtual {v1}, Ljava/lang/Object;->getClass()Ljava/lang/Class;

    invoke-virtual {p0}, Lorg/infobip/mobile/messaging/MobileMessagingCore;->getApplicationCode()Ljava/lang/String;

    move-result-object p0

    if-eqz v0, :cond_40

    invoke-virtual {p1, v0}, Ljava/lang/String;->concat(Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    return-object p0

    :cond_40
    const-string p1, "App "

    invoke-static {p1, p0}, La1/b0;->k(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;

    move-result-object p0

    return-object p0
.end method
