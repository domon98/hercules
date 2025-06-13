CREATE TABLE usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_usuario VARCHAR(50) UNIQUE NOT NULL,
    correo VARCHAR(100) UNIQUE NOT NULL,
    contrasena_hash VARCHAR(255) NOT NULL,
    nombre_completo VARCHAR(100),
    fecha_nacimiento DATE,
    genero ENUM('hombre', 'mujer', 'otro'),
    peso DECIMAL(5,2),
    altura DECIMAL(5,2),
    nivel_actividad TINYINT CHECK (nivel_actividad BETWEEN 1 AND 5),
    creado_en TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    foto_perfil VARCHAR(255) DEFAULT NULL
);

CREATE TABLE comidas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuarios_fk INT NOT NULL,
    nombre_comida VARCHAR(100) NOT NULL,
    kcal DECIMAL(6, 2) NOT NULL,
    carbs DECIMAL(5, 2) NOT NULL,
    proteinas DECIMAL(5, 2) NOT NULL,
    grasas DECIMAL(5, 2) NOT NULL,
    fecha_agregacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (usuarios_fk) REFERENCES usuarios(id) ON DELETE CASCADE
);

SET GLOBAL time_zone = '+02:00';
SET time_zone = '+02:00';

CREATE TABLE amigos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_fk INT NOT NULL,
    amigo_fk INT NOT NULL,
    estado ENUM('pendiente', 'aceptado') DEFAULT 'pendiente',
    fecha_solicitud TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_aceptacion TIMESTAMP NULL,
    FOREIGN KEY (usuario_fk) REFERENCES usuarios(id),
    FOREIGN KEY (amigo_fk) REFERENCES usuarios(id)
);

CREATE TABLE mensajes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    emisor_fk INT NOT NULL,
    receptor_fk INT NOT NULL,
    mensaje TEXT NOT NULL,
    fecha_envio TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    leido BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (emisor_fk) REFERENCES usuarios(id) ON DELETE CASCADE,
    FOREIGN KEY (receptor_fk) REFERENCES usuarios(id) ON DELETE CASCADE
);

CREATE TABLE publicaciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    usuario_id INT NOT NULL,
    duracion TIME NOT NULL,
    distancia DECIMAL(5,2) DEFAULT 0.00,
    gps_data JSON NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    tiene_gps BOOLEAN DEFAULT FALSE,
    descripcion TEXT,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
);

CREATE TABLE imagenes (
    id_imagen INT AUTO_INCREMENT PRIMARY KEY,
    id_publicacion INT NOT NULL,
    nombre_imagen VARCHAR(255) NOT NULL UNIQUE,
    FOREIGN KEY (id_publicacion) REFERENCES publicaciones(id)
);

CREATE TABLE comentarios (
    id_comentario INT AUTO_INCREMENT PRIMARY KEY,
    id_publicacion INT NOT NULL,
    id_usuario INT NOT NULL,
    contenido TEXT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (id_publicacion) REFERENCES publicaciones(id),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
);

CREATE TABLE me_gustas (
    id_like INT AUTO_INCREMENT PRIMARY KEY,
    id_publicacion INT NOT NULL,
    id_usuario INT NOT NULL,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (id_publicacion, id_usuario),  -- cada usuario solo puede dar like una vez a una publicación
    FOREIGN KEY (id_publicacion) REFERENCES publicaciones(id),
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id)
);



