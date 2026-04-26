enum AiModel { pro, fast, think }

extension AiModelX on AiModel {
  String get label {
    switch (this) {
      case AiModel.pro:
        return 'Pro 3.0';
      case AiModel.fast:
        return 'Fast 3.0';
      case AiModel.think:
        return 'Think 3.0';
    }
  }

  String get remoteModel {
    switch (this) {
      case AiModel.pro:
        return 'google/gemma-4-31b-it';
      case AiModel.fast:
        return 'nvidia/nemotron-3-super-120b-a12b';
      case AiModel.think:
        return 'minimaxai/minimax-m2.7';
    }
  }

  double get temperature {
    switch (this) {
      case AiModel.pro:
        return 1.0;
      case AiModel.fast:
        return 1.0;
      case AiModel.think:
        return 1.0;
    }
  }

  double get topP {
    switch (this) {
      case AiModel.pro:
        return 0.95;
      case AiModel.fast:
        return 0.95;
      case AiModel.think:
        return 0.95;
    }
  }

  int get maxTokens {
    switch (this) {
      case AiModel.pro:
        return 4096;
      case AiModel.fast:
        return 4096;
      case AiModel.think:
        return 4096;
    }
  }

  Map<String, dynamic> get extraBody {
    switch (this) {
      case AiModel.pro:
        return {
          'chat_template_kwargs': {'enable_thinking': true},
        };
      case AiModel.fast:
        return {
          'chat_template_kwargs': {'enable_thinking': true},
          'reasoning_budget': 4096,
        };
      case AiModel.think:
        return const {};
    }
  }
}
