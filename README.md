# Proyecto HERCULES – Flutter + API Python

Este repositorio contiene una aplicación Flutter y una API escrita en Python (Flask), utilizada para manejar peticiones backend como registros, consultas, autenticación, etc.

---

## Estructura del proyecto

```
HERCULES/
├── database/
│   └── BASE.sql  
├── lib/
│   ├── back/              # Backend en Python
│   │   └── apis.py        # API Flask
│   ├── features/          # Funcionalidades de Flutter
│   ├── routes/            # Navegación
│   └── main.dart          # Punto de entrada Flutter
├── pubspec.yaml
├── BASE.sql               # Script de base de datos MySQL
└── README.md
```

---

## Requisitos

### Backend (Python)
- Python 3.9 o superior
- pip

### Frontend (Flutter)
- Flutter SDK instalado
- Android Studio o Visual Studio Code (opcional)

---

##  Cómo ejecutar la API (Python)

1. Entra en la carpeta del backend:

```bash
cd lib/back
```

4. Instala las dependencias:

```bash
pip install -r requirements.txt
```

5. Ejecuta la API:

```bash
python apis.py
```

---

## Cómo ejecutar la app Flutter

1. En la raíz del proyecto:

```bash
flutter pub get
flutter run
```
---

## Configuración de la base de datos

La API está configurada para conectarse así:

```python
app.config['MYSQL_HOST'] = '127.0.0.1'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = '1234'
app.config['MYSQL_DB'] = 'hercules'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16 MB
```

---

## Cómo importar la base de datos MySQL

1. Abre tu terminal o consola de MySQL.

2. Crea la base de datos:

```sql
CREATE DATABASE hercules DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
```

3. Usa la base de datos:

```sql
USE hercules;
```

4. Importa el archivo:

```bash
mysql -u root -p hercules < database/BASE.sql
```

---

## Tablas incluidas

- `usuarios`: Información personal, peso, altura, actividad, etc.
- `comidas`: Registro de alimentos con macros.
- `amigos`: Relaciones sociales entre usuarios.
- `mensajes`: Chat privado entre usuarios.
- `publicaciones`: Actividades compartidas (con GPS o sin).
- `imagenes`: Imágenes asociadas a publicaciones.
- `comentarios`: Comentarios en publicaciones.
- `me_gustas`: Likes por publicación (uno por usuario).

---

## Zona horaria

```sql
SET GLOBAL time_zone = '+02:00';
SET time_zone = '+02:00';
```

---

## Autor

- Nombre: [Domingo F. Ramos Castillo]
- GitHub: [@domon98](https://github.com/domon98)