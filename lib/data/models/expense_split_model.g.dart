// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_split_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExpenseSplitModelAdapter extends TypeAdapter<ExpenseSplitModel> {
  @override
  final int typeId = 3;

  @override
  ExpenseSplitModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExpenseSplitModel(
      id: fields[0] as String,
      expenseId: fields[1] as String,
      totalAmount: fields[2] as double,
      createdAt: fields[3] as DateTime,
      splitMethod: fields[4] as String,
      slipPersonId: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ExpenseSplitModel obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.expenseId)
      ..writeByte(2)
      ..write(obj.totalAmount)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.splitMethod)
      ..writeByte(5)
      ..write(obj.slipPersonId);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExpenseSplitModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
