// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mensaje_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MensajeModelAdapter extends TypeAdapter<MensajeModel> {
  @override
  final int typeId = 0;

  @override
  MensajeModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MensajeModel(
      id: fields[0] as String,
      idRemitente: fields[1] as String,
      contenido: fields[2] as String,
      tipo: fields[3] as String,
      metadata: (fields[4] as Map?)?.cast<String, dynamic>(),
      timestamp: fields[5] as DateTime,
      estado: fields[6] as String,
      urlArchivo: fields[7] as String?,
      isDeleted: fields[8] as bool,
      duracionSegundos: fields[9] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, MensajeModel obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.idRemitente)
      ..writeByte(2)
      ..write(obj.contenido)
      ..writeByte(3)
      ..write(obj.tipo)
      ..writeByte(4)
      ..write(obj.metadata)
      ..writeByte(5)
      ..write(obj.timestamp)
      ..writeByte(6)
      ..write(obj.estado)
      ..writeByte(7)
      ..write(obj.urlArchivo)
      ..writeByte(8)
      ..write(obj.isDeleted)
      ..writeByte(9)
      ..write(obj.duracionSegundos);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MensajeModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
