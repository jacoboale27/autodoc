---
trigger: always_on
---

-- 1. Tabla de Usuarios
CREATE TABLE Usuarios (
    id_usuario VARCHAR(50) PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    rol VARCHAR(20) CHECK (rol IN ('Propietario', 'Administrador', 'Mecanico')),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Tabla de Talleres
CREATE TABLE Talleres (
    id_taller VARCHAR(50) PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    ubicacion_municipio VARCHAR(100),
    especialidad VARCHAR(100),
    telefono VARCHAR(20),
    calificacion_promedio DECIMAL(3,2) DEFAULT 0.0
);

-- 3. Tabla de Vehículos
CREATE TABLE Vehiculos (
    id_vehiculo VARCHAR(50) PRIMARY KEY,
    id_propietario VARCHAR(50) NOT NULL,
    placa VARCHAR(20) UNIQUE NOT NULL,
    marca VARCHAR(50),
    modelo VARCHAR(50),
    anio INT,
    color VARCHAR(30),
    kilometraje_actual INT DEFAULT 0,
    vencimiento_tarjeta DATE,
    vencimiento_soat DATE,
    foto_url TEXT,
    CONSTRAINT fk_propietario FOREIGN KEY (id_propietario) 
        REFERENCES Usuarios(id_usuario) ON DELETE CASCADE
);

-- 4. Tabla de Servicios (Historial)
CREATE TABLE Servicios (
    id_servicio VARCHAR(50) PRIMARY KEY,
    id_vehiculo VARCHAR(50) NOT NULL,
    id_taller VARCHAR(50),
    tipo_servicio VARCHAR(100),
    fecha DATE NOT NULL,
    kilometraje_servicio INT,
    costo DECIMAL(10,2),
    foto_factura_url TEXT,
    descripcion TEXT,
    CONSTRAINT fk_vehiculo_servicio FOREIGN KEY (id_vehiculo) 
        REFERENCES Vehiculos(id_vehiculo) ON DELETE CASCADE,
    CONSTRAINT fk_taller_servicio FOREIGN KEY (id_taller) 
        REFERENCES Talleres(id_taller) ON DELETE SET NULL
);

-- 5. Tabla de Alertas y Recordatorios
CREATE TABLE Alertas (
    id_alerta VARCHAR(50) PRIMARY KEY,
    id_vehiculo VARCHAR(50) NOT NULL,
    tipo_alerta VARCHAR(50), -- Ej: 'SOAT', 'Tarjeta de Circulación', 'Mantenimiento'
    fecha_limite DATE NOT NULL,
    estado VARCHAR(20) DEFAULT 'Pendiente' CHECK (estado IN ('Pendiente', 'Completada', 'Vencida')),
    CONSTRAINT fk_vehiculo_alerta FOREIGN KEY (id_vehiculo) 
        REFERENCES Vehiculos(id_vehiculo) ON DELETE CASCADE
);

-- 6. Tabla de Reseñas
CREATE TABLE Resenias (
    id_resenia VARCHAR(50) PRIMARY KEY,
    id_usuario VARCHAR(50) NOT NULL,
    id_taller VARCHAR(50) NOT NULL,
    estrellas INT CHECK (estrellas >= 1 AND estrellas <= 5),
    comentario TEXT,
    fecha_resenia TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_usuario_resenia FOREIGN KEY (id_usuario) 
        REFERENCES Usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_taller_resenia FOREIGN KEY (id_taller) 
        REFERENCES Talleres(id_taller) ON DELETE CASCADE
);

Análisis de Tablas según la UI - AutoDoc
1. Registro y Perfiles de Usuario (Pantallas: Registro / Onboarding)
Usuarios: Al completar el flujo de registro, se crea un documento en esta tabla. El campo rol es crítico aquí; por defecto, los usuarios que se registran desde la app móvil obtienen el rol Propietario.
Lógica UI: La pantalla de Registro captura el nombre_completo y correo. Al ser Firebase, el id_usuario se vincula directamente con el UID de autenticación para asegurar que solo el dueño vea sus propios autos.
2. Gestión de Garaje Virtual (Pantallas: Mis Vehículos / Perfil del Vehículo)
Vehiculos: Esta tabla alimenta las "Cards" de la pantalla Mis Vehículos.
Lógica UI: * Los campos marca, modelo y placa son los encabezados principales de la interfaz.
El campo kilometraje_actual se actualiza manualmente o por el mecánico, y es lo que dispara el cambio de color en los indicadores de mantenimiento de la UI (Verde/Amarillo/Rojo).
3. Centro de Control y Notificaciones (Pantallas: Dashboard / Alertas y Recordatorios)
Alertas: Es la tabla motor de la pantalla de Alertas y Recordatorios.
Lógica UI: El sistema realiza una consulta (query) filtrando por id_vehiculo y estado = 'Pendiente'.
Si la fecha_limite está a menos de 15 días, la UI resalta el icono en rojo.
Los documentos como SOAT y Tarjeta de Circulación se gestionan aquí comparando la fecha actual con los campos de vencimiento en la tabla Vehiculos.
4. Buscador de Talleres y Reputación (Pantalla: Directorio de Talleres)
Talleres: Alimenta el listado principal del directorio. La UI muestra el nombre, especialidad y municipio.
Resenias: Esta tabla es la que permite mostrar las "estrellas" en el directorio.
Cómputo UI: La calificación que ve el usuario es un AVG(estrellas) de la tabla Resenias agrupado por el id_taller.
5. Trazabilidad de Mantenimiento (Pantallas: Historial de Servicios / Iniciar Servicio)
Servicios: Es la tabla con más movimiento de datos.
Lógica UI (Mecánico): En la pantalla "Iniciar Servicio", el mecánico registra el tipo_servicio y el costo, lo que genera una nueva fila en esta tabla.
Lógica UI (Usuario): La pantalla Historial de Servicios hace un JOIN (o referencia) entre Servicios y Talleres para que el usuario pueda ver no solo qué se le hizo al carro, sino en qué taller específico fue atendido.
Evidencia: El campo foto_factura_url almacena la imagen capturada en la UI para que el usuario pueda descargarla o verla como comprobante legal.
6. Panel de Administración y Moderación (Pantallas: Gestión de Usuarios / Talleres / Reseñas)
Control Admin: Las tablas Usuarios, Talleres y Resenias tienen vistas tipo lista para el administrador.
Lógica UI: * Gestión de Reseñas: Permite al administrador cambiar el estado de una reseña o eliminarla si es ofensiva.
Gestión de Usuarios: Permite al administrador cambiar el rol de un usuario (por ejemplo, ascender a un usuario a Mecanico para que pueda usar las funciones de taller).

