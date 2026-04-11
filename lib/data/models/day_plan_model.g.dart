// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'day_plan_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class DayPlanModelAdapter extends TypeAdapter<DayPlanModel> {
  @override
  final int typeId = 3;

  @override
  DayPlanModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DayPlanModel(
      id: fields[0] as String,
      goalId: fields[1] as String,
      dayNumber: fields[2] as int,
      tasks: (fields[3] as List?)?.cast<TaskModel>(),
      isUnlocked: fields[4] as bool,
      isCompleted: fields[5] as bool,
      completedAt: fields[6] as DateTime?,
      startedAt: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, DayPlanModel obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.goalId)
      ..writeByte(2)
      ..write(obj.dayNumber)
      ..writeByte(3)
      ..write(obj.tasks)
      ..writeByte(4)
      ..write(obj.isUnlocked)
      ..writeByte(5)
      ..write(obj.isCompleted)
      ..writeByte(6)
      ..write(obj.completedAt)
      ..writeByte(7)
      ..write(obj.startedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DayPlanModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
