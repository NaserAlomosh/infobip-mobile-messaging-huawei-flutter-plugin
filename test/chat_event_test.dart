import 'package:flutter_test/flutter_test.dart';
import 'package:infobip_mobilemessaging_huawei/src/chat/chat_event.dart';
import 'package:infobip_mobilemessaging_huawei/src/chat/chat_view.dart';

void main() {
  test('decodes successful and unsuccessful loaded events', () {
    final successful =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'loaded',
              'value': true,
            })
            as InfobipHuaweiChatLoadedEvent;
    final unsuccessful =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'loaded',
              'value': false,
            })
            as InfobipHuaweiChatLoadedEvent;

    expect(successful.success, isTrue);
    expect(unsuccessful.success, isFalse);
  });

  test('decodes exit press', () {
    expect(
      decodeInfobipHuaweiChatEvent(<String, Object>{'event': 'exitPressed'}),
      isA<InfobipHuaweiChatExitPressedEvent>(),
    );
  });

  test('decodes widget theme exactly including whitespace', () {
    const theme = '  dark theme  ';
    final event =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'widgetThemeChanged',
              'value': theme,
            })
            as InfobipHuaweiChatWidgetThemeChangedEvent;

    expect(event.theme, theme);
  });

  test('decodes every widget info field and attachment configuration', () {
    final event =
        decodeInfobipHuaweiChatEvent(<String, Object?>{
              'event': 'widgetInfoUpdated',
              'value': <String, Object?>{
                'id': 'widget-id',
                'title': 'Support',
                'primaryColor': '#112233',
                'backgroundColor': '#445566',
                'primaryTextColor': '#778899',
                'multiThread': true,
                'multiChannelConversationEnabled': false,
                'callsEnabled': true,
                'themeNames': <String>['light', 'dark'],
                'attachmentConfig': <String, Object?>{
                  'maxSize': 10485760,
                  'isEnabled': true,
                  'allowedExtensions': <String>['pdf', 'jpg'],
                },
              },
            })
            as InfobipHuaweiChatWidgetInfoUpdatedEvent;

    final info = event.widgetInfo;
    expect(info.id, 'widget-id');
    expect(info.title, 'Support');
    expect(info.primaryColor, '#112233');
    expect(info.backgroundColor, '#445566');
    expect(info.primaryTextColor, '#778899');
    expect(info.multiThread, isTrue);
    expect(info.multiChannelConversationEnabled, isFalse);
    expect(info.callsEnabled, isTrue);
    expect(info.themeNames, <String>['light', 'dark']);
    expect(info.attachmentConfig?.maxSize, 10485760);
    expect(info.attachmentConfig?.isEnabled, isTrue);
    expect(info.attachmentConfig?.allowedExtensions, <String>['pdf', 'jpg']);
  });

  test('decodes null widget info optional fields', () {
    final event =
        decodeInfobipHuaweiChatEvent(<String, Object?>{
              'event': 'widgetInfoUpdated',
              'value': <String, Object?>{
                'id': null,
                'title': null,
                'primaryColor': null,
                'backgroundColor': null,
                'primaryTextColor': null,
                'multiThread': null,
                'multiChannelConversationEnabled': null,
                'callsEnabled': null,
                'themeNames': null,
                'attachmentConfig': null,
              },
            })
            as InfobipHuaweiChatWidgetInfoUpdatedEvent;

    expect(event.widgetInfo.id, isNull);
    expect(event.widgetInfo.themeNames, isNull);
    expect(event.widgetInfo.attachmentConfig, isNull);
  });

  test('decodes attachment preview values and null values', () {
    final populated =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'attachmentPreviewOpened',
              'value': <String, Object>{
                'url': 'https://example.com/a.pdf',
                'type': 'application/pdf',
                'caption': 'invoice',
              },
            })
            as InfobipHuaweiChatAttachmentPreviewOpenedEvent;
    final empty =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'attachmentPreviewOpened',
              'value': <String, Object?>{
                'url': null,
                'type': null,
                'caption': null,
              },
            })
            as InfobipHuaweiChatAttachmentPreviewOpenedEvent;

    expect(populated.attachment.url, 'https://example.com/a.pdf');
    expect(populated.attachment.type, 'application/pdf');
    expect(populated.attachment.caption, 'invoice');
    expect(empty.attachment.url, isNull);
    expect(empty.attachment.type, isNull);
    expect(empty.attachment.caption, isNull);
  });

  test('preserves raw JSON-looking messages without decoding', () {
    const rawMessage = ' {"message": [1, true]}\n';
    final event =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'rawMessageReceived',
              'value': rawMessage,
            })
            as InfobipHuaweiChatRawMessageReceivedEvent;

    expect(event.rawMessage, rawMessage);
  });

  test('decodes every known view state and preserves order', () {
    const values = <String>[
      'LOADING',
      'THREAD_LIST',
      'LOADING_THREAD',
      'THREAD',
      'CLOSED_THREAD',
      'SINGLE_MODE_THREAD',
    ];
    final events = values
        .map(
          (value) => decodeInfobipHuaweiChatEvent(<String, Object>{
            'event': 'viewChanged',
            'value': value,
          }),
        )
        .whereType<InfobipHuaweiChatViewChangedEvent>()
        .toList();

    expect(events.map((event) => event.rawValue), values);
    expect(
      events.map((event) => event.state),
      InfobipHuaweiChatViewState.values.where(
        (state) => state != InfobipHuaweiChatViewState.unknown,
      ),
    );
  });

  test('decodes connection changes', () {
    final connected =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'connectionChanged',
              'value': 'CONNECTED',
            })
            as InfobipHuaweiChatConnectionChangedEvent;
    final disconnected =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'connectionChanged',
              'value': 'DISCONNECTED',
            })
            as InfobipHuaweiChatConnectionChangedEvent;

    expect(connected.state, InfobipHuaweiChatConnectionState.connected);
    expect(disconnected.state, InfobipHuaweiChatConnectionState.disconnected);
  });

  test('preserves unknown view values without throwing', () {
    final event =
        decodeInfobipHuaweiChatEvent(<String, Object>{
              'event': 'viewChanged',
              'value': 'FUTURE_VIEW',
            })
            as InfobipHuaweiChatViewChangedEvent;

    expect(event.state, InfobipHuaweiChatViewState.unknown);
    expect(event.rawValue, 'FUTURE_VIEW');
  });

  test('ignores malformed and unknown events', () {
    expect(decodeInfobipHuaweiChatEvent(null), isNull);
    expect(
      decodeInfobipHuaweiChatEvent(<String, Object>{'event': 'loaded'}),
      isNull,
    );
    expect(
      decodeInfobipHuaweiChatEvent(<String, Object>{
        'event': 'viewChanged',
        'value': 1,
      }),
      isNull,
    );
    expect(
      decodeInfobipHuaweiChatEvent(<String, Object>{
        'event': 'futureEvent',
        'value': 'value',
      }),
      isNull,
    );
    expect(
      decodeInfobipHuaweiChatEvent(<String, Object>{
        'event': 'widgetInfoUpdated',
        'value': <String, Object>{
          'themeNames': <Object>['light', 1],
        },
      }),
      isNull,
    );
  });
}
