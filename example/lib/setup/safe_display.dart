import 'package:flutter/services.dart';
import 'package:infobip_mobilemessaging_huawei/infobip_mobilemessaging_huawei.dart';

String masked(String? value) {
  if (value == null || value.trim().isEmpty) return 'missing';
  if (value.length <= 8) return '••••';
  return '${value.substring(0, 3)}••••${value.substring(value.length - 3)}';
}

String status(bool? value) => switch (value) {
  true => '✅',
  false => '❌',
  null => 'unknown',
};

/// Never render exception messages/details: they may contain backend credentials.
String safeFailure(String operation, Object error) {
  final candidate = switch (error) {
    PlatformException e => e.code,
    HuaweiRtcException e => e.code,
    ArgumentError() || FormatException() => 'invalid_argument',
    _ => 'operation_failed',
  };
  // Keep only stable, known plugin codes (not arbitrary backend error text).
  const codes = {
    'invalid_argument',
    'not_initialized',
    'initialization_failed',
    'hms_configuration_missing',
    'registration_failed',
    'native_error',
    'user_error',
    'installation_error',
    'inbox_error',
    'chat_error',
    'rtc_not_initialized',
    'rtc_invalid_argument',
    'rtc_permission_denied',
    'rtc_call_already_active',
    'rtc_no_active_call',
    'rtc_token_failed',
    'rtc_call_failed',
    'rtc_invalid_state',
    'permission_request_active',
    'operation_failed',
    'inbox_fetch_failed',
    'inbox_update_failed',
    'user_fetch_failed',
    'user_save_failed',
    'personalization_failed',
    'depersonalization_failed',
    'installation_fetch_failed',
    'installation_save_failed',
    'installation_depersonalization_failed',
    'installation_primary_update_failed',
    'chat_unavailable',
    'stale_request',
    'not_available',
  };
  final code = codes.contains(candidate) ? candidate : 'operation_failed';
  return '$operation • $code\nCheck configuration, device permissions and connectivity, then retry.';
}
