/// Represents a Server-Sent Event from the Flask server
class ServerEvent {
  final ServerEventType type;
  final String data;

  const ServerEvent({
    required this.type,
    required this.data,
  });

  @override
  String toString() => 'ServerEvent(type: $type, data: $data)';
}

/// Types of events received from /process endpoint
enum ServerEventType {
  /// Server status update (e.g., "Audio obtained", "Transcribing...")
  status,
  
  /// Content chunk from LM generation
  data,
  
  /// Generation complete
  done,
  
  /// Error occurred
  error,
  
  /// Unknown event type
  unknown,
}

/// Parse event type from SSE event string
ServerEventType parseEventType(String eventLine) {
  if (eventLine.startsWith('event: status')) {
    return ServerEventType.status;
  } else if (eventLine.startsWith('event: done')) {
    return ServerEventType.done;
  } else if (eventLine.startsWith('event: error')) {
    return ServerEventType.error;
  } else if (eventLine.startsWith('data: ')) {
    return ServerEventType.data;
  }
  return ServerEventType.unknown;
}
