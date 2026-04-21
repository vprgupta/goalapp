// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'topic_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class TopicModelAdapter extends TypeAdapter<TopicModel> {
  @override
  final int typeId = 2;

  @override
  TopicModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return TopicModel(
      id: fields[0] as String,
      goalId: fields[1] as String,
      name: fields[2] as String,
      learnedOnDay: fields[3] as int,
      strengthScore: fields[4] as double,
      revisionCount: fields[5] as int,
      scheduledRevisions: (fields[6] as List?)?.cast<int>(),
      completedRevisions: (fields[7] as List?)?.cast<int>(),
      lastRevisedAt: fields[8] as DateTime?,
      tier: fields[9] as int,
      estimatedLearnMinutes: fields[10] as int,
      incorrectAnswers: fields[11] as int,
      videoId: fields[12] as String?,
      thumbnailUrl: fields[13] as String?,
      startSeconds: fields[14] as int,
      subTopics: (fields[15] as List?)?.cast<String>(),
      moduleName: fields[16] as String?,
      isBoss: fields[17] as bool,
      resources: (fields[18] as List?)?.cast<String>(),
      prerequisites: (fields[19] as List?)?.cast<String>(),
      weight: fields[20] as double,
      retentionScore: fields[21] as double,
      errorTypes: (fields[22] as Map?)?.cast<String, int>(),
      isBlueprintGenerated: fields[23] as bool,
      stability: fields[24] as double,
      difficulty: fields[25] as double,
      sortOrder: fields[26] as int,
    );
  }

  @override
  void write(BinaryWriter writer, TopicModel obj) {
    writer
      ..writeByte(27)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goalId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.learnedOnDay)
      ..writeByte(4)
      ..write(obj.strengthScore)
      ..writeByte(5)
      ..write(obj.revisionCount)
      ..writeByte(6)
      ..write(obj.scheduledRevisions)
      ..writeByte(7)
      ..write(obj.completedRevisions)
      ..writeByte(8)
      ..write(obj.lastRevisedAt)
      ..writeByte(9)
      ..write(obj.tier)
      ..writeByte(10)
      ..write(obj.estimatedLearnMinutes)
      ..writeByte(11)
      ..write(obj.incorrectAnswers)
      ..writeByte(12)
      ..write(obj.videoId)
      ..writeByte(13)
      ..write(obj.thumbnailUrl)
      ..writeByte(14)
      ..write(obj.startSeconds)
      ..writeByte(15)
      ..write(obj.subTopics)
      ..writeByte(16)
      ..write(obj.moduleName)
      ..writeByte(17)
      ..write(obj.isBoss)
      ..writeByte(18)
      ..write(obj.resources)
      ..writeByte(19)
      ..write(obj.prerequisites)
      ..writeByte(20)
      ..write(obj.weight)
      ..writeByte(21)
      ..write(obj.retentionScore)
      ..writeByte(22)
      ..write(obj.errorTypes)
      ..writeByte(23)
      ..write(obj.isBlueprintGenerated)
      ..writeByte(24)
      ..write(obj.stability)
      ..writeByte(25)
      ..write(obj.difficulty)
      ..writeByte(26)
      ..write(obj.sortOrder);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
