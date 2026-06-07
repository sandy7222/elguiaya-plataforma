// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'guia_local_core.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AccionOfflineAdapter extends TypeAdapter<AccionOffline> {
  @override
  final int typeId = 0;

  @override
  AccionOffline read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AccionOffline(
      id: fields[0] as String,
      tipo: fields[1] as String,
      payload: (fields[2] as Map).cast<String, dynamic>(),
      timestamp: fields[3] as DateTime,
      sincronizada: fields[4] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, AccionOffline obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.tipo)
      ..writeByte(2)
      ..write(obj.payload)
      ..writeByte(3)
      ..write(obj.timestamp)
      ..writeByte(4)
      ..write(obj.sincronizada);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AccionOfflineAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class EstadoGuiaAdapter extends TypeAdapter<EstadoGuia> {
  @override
  final int typeId = 1;

  @override
  EstadoGuia read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return EstadoGuia(
      estadoAnimo: fields[0] as String,
      ultimoParpadeo: fields[1] as DateTime?,
      ultimaActividad: fields[2] as DateTime?,
      conectado: fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, EstadoGuia obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.estadoAnimo)
      ..writeByte(1)
      ..write(obj.ultimoParpadeo)
      ..writeByte(2)
      ..write(obj.ultimaActividad)
      ..writeByte(3)
      ..write(obj.conectado);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EstadoGuiaAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
