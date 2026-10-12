enum ExampleFeature {
  push('Push Notifications'),
  inbox('Inbox'),
  chat('Chat'),
  rtcAudio('Outgoing RTC Audio'),
  rtcVideo('Outgoing RTC Video'),
  user('User'),
  installation('Installation');

  const ExampleFeature(this.title);
  final String title;
}

enum InboxAuth {
  applicationCode('Application Code'),
  jwt('JWT');

  const InboxAuth(this.label);
  final String label;
}

class FeatureRequirement {
  const FeatureRequirement(this.title, this.satisfied, {this.description = ''});
  final String title;
  final bool satisfied;
  final String description;
}

class FeatureReadiness {
  FeatureReadiness(this.name, List<FeatureRequirement> requirements)
    : requirements = List.unmodifiable(requirements);
  final String name;
  final List<FeatureRequirement> requirements;
  bool get isReady => requirements.every((item) => item.satisfied);
  List<FeatureRequirement> get missing =>
      requirements.where((item) => !item.satisfied).toList();
}
