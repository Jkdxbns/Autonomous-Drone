/// Assistant response models for two-pass LLM pipeline
library;

class AssistantResponse {
  final String task;
  final String userData;
  final String processingDevice;
  final String sourceDevice;
  final String targetDevice;
  final String? parentDevice;
  final List<String>? outputFormat;
  final AssistantOutput output;
  final AssistantError? error;

  AssistantResponse({
    required this.task,
    required this.userData,
    required this.processingDevice,
    required this.sourceDevice,
    required this.targetDevice,
    this.parentDevice,
    this.outputFormat,
    required this.output,
    this.error,
  });

  factory AssistantResponse.fromJson(Map<String, dynamic> json) {
    return AssistantResponse(
      task: json['task'] as String,
      userData: json['user-data'] as String,
      processingDevice: json['processing-device'] as String,
      sourceDevice: json['source-device'] as String,
      targetDevice: json['target-device'] as String,
      parentDevice: json['parent-device'] as String?,
      outputFormat: json['output-format'] != null
          ? List<String>.from(json['output-format'] as List)
          : null,
      output: AssistantOutput.fromJson(json['output'] as Map<String, dynamic>),
      error: json['error'] != null
          ? AssistantError.fromJson(json['error'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task': task,
      'user-data': userData,
      'processing-device': processingDevice,
      'source-device': sourceDevice,
      'target-device': targetDevice,
      'parent-device': parentDevice,
      'output-format': outputFormat,
      'output': output.toJson(),
      'error': error?.toJson(),
    };
  }

  bool get isTextGeneration => task == 'text-generation';
  bool get isBtControl => task == 'bt-control';
  bool get hasError => error != null;
}

class AssistantOutput {
  final String generatedOutput;

  AssistantOutput({required this.generatedOutput});

  factory AssistantOutput.fromJson(Map<String, dynamic> json) {
    return AssistantOutput(
      generatedOutput: json['generated_output'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'generated_output': generatedOutput,
    };
  }
}

class AssistantError {
  final String code;
  final String message;

  AssistantError({
    required this.code,
    required this.message,
  });

  factory AssistantError.fromJson(Map<String, dynamic> json) {
    return AssistantError(
      code: json['code'] as String,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'message': message,
    };
  }
}
