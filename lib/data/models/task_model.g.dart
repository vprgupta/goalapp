// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'task_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecallPromptAdapter extends TypeAdapter<RecallPrompt> {
  @override
  final int typeId = 7;

  @override
  RecallPrompt read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecallPrompt(
      type: fields[0] as PromptType,
      prompt: fields[1] as String,
      options: (fields[2] as List?)?.cast<String>(),
      answer: fields[3] as String?,
      answeredCorrectly: fields[4] as bool?,
      selectedOptionIndex: fields[5] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, RecallPrompt obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.type)
      ..writeByte(1)
      ..write(obj.prompt)
      ..writeByte(2)
      ..write(obj.options)
      ..writeByte(3)
      ..write(obj.answer)
      ..writeByte(4)
      ..write(obj.answeredCorrectly)
      ..writeByte(5)
      ..write(obj.selectedOptionIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecallPromptAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskModelAdapter extends TypeAdapter<TaskModel> {
  @override
  final int typeId = 8;

  @override
  TaskModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TaskModel(
      id: fields[0] as String,
      dayPlanId: fields[1] as String,
      type: fields[2] as TaskType,
      topicId: fields[3] as String,
      title: fields[4] as String,
      description: fields[5] as String,
      estimatedMinutes: fields[6] as int,
      status: fields[7] as TaskStatus,
      recallPrompt: fields[8] as RecallPrompt?,
      completedAt: fields[9] as DateTime?,
      sortOrder: fields[10] as int,
      videoId: fields[11] as String?,
      startSeconds: fields[12] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TaskModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.dayPlanId)
      ..writeByte(2)
      ..write(obj.type)
      ..writeByte(3)
      ..write(obj.topicId)
      ..writeByte(4)
      ..write(obj.title)
      ..writeByte(5)
      ..write(obj.description)
      ..writeByte(6)
      ..write(obj.estimatedMinutes)
      ..writeByte(7)
      ..write(obj.status)
      ..writeByte(8)
      ..write(obj.recallPrompt)
      ..writeByte(9)
      ..write(obj.completedAt)
      ..writeByte(10)
      ..write(obj.sortOrder)
      ..writeByte(11)
      ..write(obj.videoId)
      ..writeByte(12)
      ..write(obj.startSeconds);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskTypeAdapter extends TypeAdapter<TaskType> {
  @override
  final int typeId = 4;

  @override
  TaskType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskType.learn;
      case 1:
        return TaskType.revise;
      default:
        return TaskType.learn;
    }
  }

  @override
  void write(BinaryWriter writer, TaskType obj) {
    switch (obj) {
      case TaskType.learn:
        writer.writeByte(0);
        break;
      case TaskType.revise:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class TaskStatusAdapter extends TypeAdapter<TaskStatus> {
  @override
  final int typeId = 5;

  @override
  TaskStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return TaskStatus.pending;
      case 1:
        return TaskStatus.completed;
      case 2:
        return TaskStatus.skipped;
      default:
        return TaskStatus.pending;
    }
  }

  @override
  void write(BinaryWriter writer, TaskStatus obj) {
    switch (obj) {
      case TaskStatus.pending:
        writer.writeByte(0);
        break;
      case TaskStatus.completed:
        writer.writeByte(1);
        break;
      case TaskStatus.skipped:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class PromptTypeAdapter extends TypeAdapter<PromptType> {
  @override
  final int typeId = 6;

  @override
  PromptType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return PromptType.question;
      case 1:
        return PromptType.flashcard;
      case 2:
        return PromptType.miniQuiz;
      default:
        return PromptType.question;
    }
  }

  @override
  void write(BinaryWriter writer, PromptType obj) {
    switch (obj) {
      case PromptType.question:
        writer.writeByte(0);
        break;
      case PromptType.flashcard:
        writer.writeByte(1);
        break;
      case PromptType.miniQuiz:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PromptTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
