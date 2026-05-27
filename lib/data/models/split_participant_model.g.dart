// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'split_participant_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SplitParticipantModelAdapter extends TypeAdapter<SplitParticipantModel> {
  @override
  final int typeId = 4;

  @override
  SplitParticipantModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SplitParticipantModel(
      id: fields[0] as String,
      splitId: fields[1] as String,
      name: fields[2] as String,
      amount: fields[3] as double,
      isPaid: fields[4] as bool,
      paidAt: fields[5] as DateTime?,
      isSlipPayer: fields[6] == null ? false : fields[6] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, SplitParticipantModel obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.splitId)
      ..writeByte(2)
      ..write(obj.name)
      ..writeByte(3)
      ..write(obj.amount)
      ..writeByte(4)
      ..write(obj.isPaid)
      ..writeByte(5)
      ..write(obj.paidAt)
      ..writeByte(6)
      ..write(obj.isSlipPayer);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SplitParticipantModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
