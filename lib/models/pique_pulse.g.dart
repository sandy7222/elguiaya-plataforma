// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'pique_pulse.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class PiquePulseAdapter extends TypeAdapter<PiquePulse> {
  @override
  final int typeId = 3;

  @override
  PiquePulse read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return PiquePulse(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      latitud: fields[2] as double,
      longitud: fields[3] as double,
      tipoActivacion: fields[4] as String,
      especieDetectada: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, PiquePulse obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.latitud)
      ..writeByte(3)
      ..write(obj.longitud)
      ..writeByte(4)
      ..write(obj.tipoActivacion)
      ..writeByte(5)
      ..write(obj.especieDetectada);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PiquePulseAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
