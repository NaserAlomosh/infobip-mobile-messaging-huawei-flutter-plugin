// Compile-only research probe; never loaded or packaged by the plugin.
import android.content.Context;
import com.infobip.webrtc.sdk.api.InfobipRTC;
import com.infobip.webrtc.sdk.api.call.ApplicationCall;
import com.infobip.webrtc.sdk.api.event.listener.ApplicationCallEventListener;
import com.infobip.webrtc.sdk.api.options.ApplicationCallOptions;
import com.infobip.webrtc.sdk.api.request.CallApplicationRequest;
import org.infobip.mobile.messaging.api.rtc.MobileApiRtc;
import org.infobip.mobile.messaging.mobileapi.MobileApiResourceProvider;

final class CoreApiProbe {
    MobileApiRtc tokenService(Context applicationContext) {
        return new MobileApiResourceProvider().getMobileApiRtc(applicationContext);
    }

    ApplicationCall outgoing(Context applicationContext, String token,
            String callsConfigurationId, boolean video, ApplicationCallEventListener listener) throws
            com.infobip.webrtc.sdk.api.exception.IllegalStatusException,
            com.infobip.webrtc.sdk.api.exception.MissingPermissionsException {
        return InfobipRTC.getInstance().callApplication(
            new CallApplicationRequest(token, applicationContext, callsConfigurationId, listener),
            ApplicationCallOptions.builder().audio(true).video(video).build());
    }
}
