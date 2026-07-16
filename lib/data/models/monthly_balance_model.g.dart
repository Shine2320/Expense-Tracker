// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'monthly_balance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MonthlyBalanceModelAdapter extends TypeAdapter<MonthlyBalanceModel> {
  @override
  final int typeId = 1;

  @override
  MonthlyBalanceModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MonthlyBalanceModel(
      id: fields[0] as String,
      salary: fields[1] as double,
      carryOver: fields[2] as double,
      totalExpenses: fields[3] as double,
      carryOverAdjustment: fields[4] == null ? 0.0 : fields[4] as double,
    );
  }

  @override
  void write(BinaryWriter writer, MonthlyBalanceModel obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.salary)
      ..writeByte(2)
      ..write(obj.carryOver)
      ..writeByte(3)
      ..write(obj.totalExpenses)
      ..writeByte(4)
      ..write(obj.carryOverAdjustment);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MonthlyBalanceModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
