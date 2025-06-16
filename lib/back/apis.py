from functools import wraps
from flask import Flask, request, jsonify, send_from_directory, Response
from flask_mysqldb import MySQL
import MySQLdb.cursors
from werkzeug.utils import secure_filename
import gpxpy
import uuid
import json
import os
import re
import bcrypt
import jwt
import datetime 
from datetime import timedelta
from flask_cors import CORS
import pytz
import mimetypes

app = Flask(__name__)
CORS(app)

# Configura tu base de datos
app.config['MYSQL_HOST'] = '127.0.0.1'
app.config['MYSQL_USER'] = 'root'
app.config['MYSQL_PASSWORD'] = '1234'
app.config['MYSQL_DB'] = 'hercules'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # 16 MB
mysql = MySQL(app)


UPLOAD_FOLDER = 'C:\\imagenes_hercules'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# Clave secreta para firmar el token 
SECRET_KEY = 'mi_clave_super_secreta'

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None

        if 'Authorization' in request.headers:
            auth_header = request.headers['Authorization']
            if auth_header.startswith('Bearer '):
                token = auth_header.split(' ')[1]

        if not token:
            return jsonify({'mensaje': 'Token requerido'}), 401

        try:
            data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            request.user = data  # Guarda los datos del usuario para usarlos en la ruta
        except jwt.ExpiredSignatureError:
            return jsonify({'mensaje': 'Token expirado'}), 401
        except jwt.InvalidTokenError:
            return jsonify({'mensaje': 'Token inválido'}), 401

        return f(*args, **kwargs)
    return decorated

@app.route('/login', methods=['POST'])
def login():
    data = request.get_json()
    nombre_usuario = data.get('nombre_usuario')
    contrasena = data.get('contrasena')

    if not nombre_usuario or not contrasena:
        return jsonify({'mensaje': 'Faltan datos'}), 400

    cur = mysql.connection.cursor()
    cur.execute("SELECT id, contrasena_hash FROM usuarios WHERE nombre_usuario = %s", (nombre_usuario,))
    resultado = cur.fetchone()

    if resultado:
        user_id, hash_guardado = resultado[0], resultado[1].encode('utf-8')
        if bcrypt.checkpw(contrasena.encode('utf-8'), hash_guardado):
            token = jwt.encode({
                'user_id': user_id,
                'nombre_usuario': nombre_usuario,
                'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
            }, SECRET_KEY, algorithm='HS256')

            return jsonify({
                'token': token,
                'user_id': user_id
            }), 200
        else:
            return jsonify({'mensaje': 'Contraseña incorrecta'}), 401
    else:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

@app.route('/register', methods=['POST'])
def register():
    data = request.get_json()
    nombre_usuario = data.get('nombre_usuario')
    correo = data.get('correo')
    contrasena = data.get('contrasena')
    nombre_completo = data.get('nombre_completo')
    fecha_nacimiento = data.get('fecha_nacimiento')
    genero = data.get('genero')
    peso = data.get('peso')
    altura = data.get('altura')
    nivel_actividad = data.get('nivel_actividad')

    hashed_password = bcrypt.hashpw(contrasena.encode('utf-8'), bcrypt.gensalt())

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO usuarios (
                nombre_usuario, correo, contrasena_hash, nombre_completo, 
                fecha_nacimiento, genero, peso, altura, nivel_actividad
            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        """, (nombre_usuario, correo, hashed_password, nombre_completo,
              fecha_nacimiento, genero, peso, altura, nivel_actividad))
        mysql.connection.commit()
        return jsonify({'mensaje': 'Usuario registrado correctamente'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 400

@app.route('/usuario/cambiar_contrasena', methods=['PUT'])
@token_required
def cambiar_contrasena():
    """
    Permite al usuario autenticado cambiar su contraseña.
    """
    user_id = request.user['user_id']
    data = request.get_json()

    # Extraer datos del JSON
    contrasena_actual = data.get('contrasena_actual')
    contrasena_nueva = data.get('contrasena_nueva')

    if not contrasena_actual or not contrasena_nueva:
        return jsonify({'mensaje': 'Faltan datos'}), 400

    # Consulta de la contraseña actual
    cur = mysql.connection.cursor()
    cur.execute("SELECT contrasena_hash FROM usuarios WHERE id = %s", (user_id,))
    resultado = cur.fetchone()

    if not resultado:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

    contrasena_hash = resultado[0].encode('utf-8')

    # Verificar si la contraseña actual es correcta
    if not bcrypt.checkpw(contrasena_actual.encode('utf-8'), contrasena_hash):
        return jsonify({'mensaje': 'La contraseña actual no es correcta'}), 401

    # Validar la nueva contraseña 
    if len(contrasena_nueva) < 8:
        return jsonify({'mensaje': 'La nueva contraseña debe tener al menos 8 caracteres'}), 400

    if not re.search(r'[A-Z]', contrasena_nueva):
        return jsonify({'mensaje': 'La nueva contraseña debe contener al menos una letra mayúscula'}), 400

    if not re.search(r'[a-z]', contrasena_nueva):
        return jsonify({'mensaje': 'La nueva contraseña debe contener al menos una letra minúscula'}), 400

    if not re.search(r'[0-9]', contrasena_nueva):
        return jsonify({'mensaje': 'La nueva contraseña debe contener al menos un número'}), 400

    if not re.search(r'[!@#\$%^&*(),.?":{}|<>]', contrasena_nueva):
        return jsonify({'mensaje': 'La nueva contraseña debe contener un carácter especial'}), 400

    # Encriptar la nueva contraseña
    nueva_hash = bcrypt.hashpw(contrasena_nueva.encode('utf-8'), bcrypt.gensalt())

    # Actualizar en la base de datos
    try:
        cur.execute("""
            UPDATE usuarios
            SET contrasena_hash = %s
            WHERE id = %s
        """, (nueva_hash, user_id))
        mysql.connection.commit()
        cur.close()
        return jsonify({'mensaje': 'Contraseña actualizada correctamente'}), 200
    except Exception as e:
        print(f"Error al actualizar la contraseña: {str(e)}")
        return jsonify({'mensaje': 'Error al actualizar la contraseña'}), 500


@app.route('/eliminar_cuenta', methods=['DELETE'])
@token_required
def eliminar_cuenta():
    user_id = request.user['user_id']

    cur = mysql.connection.cursor()
    cur.execute("DELETE FROM publicaciones WHERE usuario_id = %s", (user_id,))
    cur.execute("DELETE FROM amigos WHERE usuario_fk = %s OR amigo_fk = %s", (user_id, user_id))
    cur.execute("DELETE FROM usuarios WHERE id = %s", (user_id,))
    mysql.connection.commit()
    cur.close()

    return jsonify({'mensaje': 'Cuenta eliminada correctamente'}), 200


# APIS SALUD
@app.route('/usuario', methods=['GET'])
@token_required
def obtener_usuario():
    user_id = request.user['user_id']
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT nombre_usuario, peso, altura, fecha_nacimiento, nivel_actividad, genero, foto_perfil
        FROM usuarios WHERE id = %s
    """, (user_id,))
    datos = cur.fetchone()
    cur.close()

    if datos:
        peso = datos[1]
        altura = datos[2]
        fecha_nacimiento = datos[3]
        nivel_actividad = datos[4]
        genero = datos[5]
        foto_perfil = datos[6] 

        return jsonify({
            'nombre_usuario': datos[0],
            'peso': peso,
            'altura': altura,
            'fecha_nacimiento': fecha_nacimiento,
            'nivel_actividad': nivel_actividad,
            'genero': genero,
            'foto_perfil': foto_perfil,
        }), 200
    else:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

@app.route('/usuario/nombre_completo', methods=['GET'])
@token_required
def obtener_nombre_completo():
    """
    Obtiene el nombre completo del usuario autenticado.
    """
    user_id = request.user['user_id']
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT nombre_completo
        FROM usuarios
        WHERE id = %s
    """, (user_id,))
    resultado = cur.fetchone()
    cur.close()

    if resultado and resultado[0]:
        return jsonify({'nombre_completo': resultado[0]}), 200
    else:
        return jsonify({'nombre_completo': None}), 200

@app.route('/usuario/nombre_completo', methods=['PUT'])
@token_required
def actualizar_nombre_completo():
    """
    Actualiza el nombre completo del usuario autenticado.
    """
    user_id = request.user['user_id']
    data = request.get_json()

    nombre_completo = data.get('nombre_completo')
    if not nombre_completo or len(nombre_completo.strip()) == 0:
        return jsonify({'mensaje': 'El nombre completo no puede estar vacío'}), 400

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE usuarios 
            SET nombre_completo = %s 
            WHERE id = %s
        """, (nombre_completo, user_id))
        mysql.connection.commit()
        cur.close()

        return jsonify({'mensaje': 'Nombre completo actualizado correctamente'}), 200
    except Exception as e:
        return jsonify({'mensaje': 'Error al actualizar el nombre'}), 500

@app.route('/buscar_usuarios', methods=['POST'])
def buscar_usuarios():
    data = request.get_json()
    nombre = data.get('nombre')
    user_id = data.get('user_id')
    
    if user_id is None:
        return jsonify({'mensaje': 'Faltan datos'}), 400

    cur = mysql.connection.cursor()
    query = """
        SELECT u.id, u.nombre_usuario, u.foto_perfil,
        CASE 
            WHEN a.estado = 'aceptado' THEN 'aceptado'
            WHEN a.estado = 'pendiente' THEN 'pendiente'
            ELSE 'no_amigo'
        END AS estado
        FROM usuarios u
        LEFT JOIN amigos a ON (
            (a.usuario_fk = u.id AND a.amigo_fk = %s) OR 
            (a.usuario_fk = %s AND a.amigo_fk = u.id)
        )
        WHERE u.nombre_usuario LIKE %s AND u.id != %s
        LIMIT 10
    """
    like_pattern = f"%{nombre}%"
    cur.execute(query, (user_id, user_id, like_pattern, user_id))
    resultados = cur.fetchall()
    cur.close()

    lista_usuarios = [
        {
            'id': r[0],
            'nombre': r[1],
            'foto': r[2] if r[2] else None,  # Devuelve None si no hay foto
            'estado': r[3]
        }
        for r in resultados
    ]

    return jsonify(lista_usuarios), 200

@app.route('/usuario', methods=['PUT'])
@token_required
def actualizar_usuario():
    user_id = request.user['user_id']
    data = request.get_json()

    peso = data.get('peso')
    altura = data.get('altura')
    fecha = data.get('fecha_nacimiento')
    genero = data.get('genero')
    nivel_actividad = data.get('nivel_actividad')

    try:
        nivel_actividad = float(nivel_actividad)
    except ValueError:
        return jsonify({'mensaje': 'Nivel de actividad inválido'}), 400

    if nivel_actividad not in [1.2, 1.375, 1.55, 1.725, 1.9]:
        return jsonify({'mensaje': 'Nivel de actividad inválido'}), 400

    cur = mysql.connection.cursor()
    cur.execute("""
        UPDATE usuarios SET 
            peso = %s, 
            altura = %s, 
            fecha_nacimiento = %s, 
            genero = %s,
            nivel_actividad = %s
        WHERE id = %s
    """, (peso, altura, fecha, genero, nivel_actividad, user_id))

    mysql.connection.commit()
    cur.close()

    return jsonify({'mensaje': 'Datos actualizados correctamente'}), 200

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS



@app.route('/perfil', methods=['GET'])
@token_required
def obtener_perfil():
    user_id = request.user['user_id']
    cur = mysql.connection.cursor()

    # Obtener nombre y foto
    cur.execute("""
        SELECT nombre_usuario, foto_perfil
        FROM usuarios
        WHERE id = %s
    """, (user_id,))
    usuario = cur.fetchone()
    if not usuario:
        cur.close()
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404
    nombre_usuario, foto_perfil = usuario

    # Contar amigos aceptados
    cur.execute("""
        SELECT COUNT(*) FROM amigos 
        WHERE (usuario_fk = %s OR amigo_fk = %s) AND estado = 'aceptado'
    """, (user_id, user_id))
    num_amigos = cur.fetchone()[0]

    # Contar publicaciones
    cur.execute("""
        SELECT COUNT(*) FROM publicaciones
        WHERE usuario_id = %s
    """, (user_id,))
    num_publicaciones = cur.fetchone()[0]

    # Obtener publicaciones con su primera imagen (si tiene)
    cur.execute("""
        SELECT p.id,
               (SELECT nombre_imagen 
                FROM imagenes 
                WHERE id_publicacion = p.id 
                LIMIT 1) AS imagen
        FROM publicaciones p
        WHERE p.usuario_id = %s
        ORDER BY p.fecha DESC
    """, (user_id,))
    filas = cur.fetchall()

    publicaciones = []
    for pub_id, imagen in filas:
        publicaciones.append({
            'id': pub_id,
            'imagen': f"http://10.0.2.2:5000/imagenes_publicaciones/{imagen}" if imagen else None
        })

    cur.close()

    return jsonify({
        'nombre_usuario': nombre_usuario,
        'foto_perfil': foto_perfil,
        'num_amigos': num_amigos,
        'num_publicaciones': num_publicaciones,
        'publicaciones': publicaciones,
        'user_id' : user_id
    }), 200

@app.route('/peso', methods=['GET'])
@token_required
def obtener_peso():
    user_id = request.user['user_id']

    cur = mysql.connection.cursor()
    cur.execute("SELECT peso FROM usuarios WHERE id = %s", (user_id,))
    result = cur.fetchone()
    cur.close()

    if result:
        return jsonify({"peso": float(result[0])}), 200
    else:
        return jsonify({"error": "Usuario no encontrado"}), 404


@app.route('/perfil/<int:id_usuario>', methods=['GET'])
@token_required
def obtener_perfil_de_otro_usuario(id_usuario):
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT nombre_usuario, foto_perfil
        FROM usuarios
        WHERE id = %s
    """, (id_usuario,))
    usuario = cur.fetchone()
    if not usuario:
        cur.close()
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

    nombre_usuario, foto_perfil = usuario

    cur.execute("""
        SELECT COUNT(*) FROM amigos 
        WHERE (usuario_fk = %s OR amigo_fk = %s) AND estado = 'aceptado'
    """, (id_usuario, id_usuario))
    num_amigos = cur.fetchone()[0]

    cur.execute("""
        SELECT COUNT(*) FROM publicaciones
        WHERE usuario_id = %s
    """, (id_usuario,))
    num_publicaciones = cur.fetchone()[0]

    cur.execute("""
        SELECT p.id,
               (SELECT nombre_imagen 
                FROM imagenes 
                WHERE id_publicacion = p.id 
                LIMIT 1) AS imagen
        FROM publicaciones p
        WHERE p.usuario_id = %s
        ORDER BY p.fecha DESC
    """, (id_usuario,))
    filas = cur.fetchall()

    publicaciones = []
    for pub_id, imagen in filas:
        publicaciones.append({
            'id': pub_id,
            'user_id': id_usuario,
            'imagen': f"http://10.0.2.2:5000/imagenes_publicaciones/{imagen}" if imagen else None
        })

    cur.close()

    return jsonify({
        'nombre_usuario': nombre_usuario,
        'foto_perfil': foto_perfil,
        'num_amigos': num_amigos,
        'num_publicaciones': num_publicaciones,
        'publicaciones': publicaciones,
        'user_id': id_usuario
    }), 200



@app.route('/crear_actividad', methods=['POST'])
@token_required
def crear_actividad():
    user_id = request.user['user_id']
    descripcion = request.form.get('descripcion')
    tiene_gps = 0
    gps_data_json = None

    try:
        # GPX a JSON
        if 'gpx' in request.files:
            gpx_file = request.files['gpx']
            if gpx_file.filename != '':
                gpx = gpxpy.parse(gpx_file.stream)
                puntos = []
                for track in gpx.tracks:
                    for segment in track.segments:
                        for point in segment.points:
                            puntos.append({
                                "lat": point.latitude,
                                "lon": point.longitude,
                                "ele": point.elevation,
                                "time": point.time.isoformat() if point.time else None
                            })
                gps_data_json = puntos
                tiene_gps = 1

        # Insertar publicacion
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO publicaciones (usuario_id, descripcion, gps_data, tiene_gps, duracion)
            VALUES (%s, %s, %s, %s, %s)
        """, (user_id, descripcion, json.dumps(gps_data_json), tiene_gps, "00:00:00"))
        mysql.connection.commit()
        publicacion_id = cur.lastrowid

        # Guardar imagenes
        imagenes_guardadas = []
        if 'imagenes' in request.files:
            imagenes = request.files.getlist('imagenes')
            carpeta_destino = 'C:\\imagenes_hercules\\publicaciones'
            os.makedirs(carpeta_destino, exist_ok=True)

            for imagen in imagenes:
                if imagen and allowed_file(imagen.filename):
                    extension = os.path.splitext(imagen.filename)[1]
                    nombre_unico = f"{uuid.uuid4().hex}{extension}"
                    ruta_fisica = os.path.join(carpeta_destino, nombre_unico)
                    imagen.save(ruta_fisica)

                    # Guardamos solo el nombre para reconstruir la URL luego
                    cur.execute("""
                        INSERT INTO imagenes (id_publicacion, nombre_imagen)
                        VALUES (%s, %s)
                    """, (publicacion_id, nombre_unico))
                    #EDITADO HOST_URL
                    imagenes_guardadas.append(f"{request.host_url}imagenes_publicaciones/{nombre_unico}")

        mysql.connection.commit()
        cur.close()

        return jsonify({
            'mensaje': 'Publicación creada correctamente',
            'id_publicacion': publicacion_id,
            'imagenes': imagenes_guardadas
        }), 201

    except Exception as e:
        print(f"Error en /crear_actividad: {e}")
        return jsonify({'error': 'No se pudo crear la publicación'}), 500

# ----------------------
# API: COMENTARIOS
# ----------------------
@app.route('/publicacion/<int:publicacion_id>/comentar', methods=['POST'])
@token_required
def comentar(publicacion_id):
    user_id = request.user['user_id']
    data = request.get_json()
    contenido = data.get('contenido')

    if not contenido:
        return jsonify({'mensaje': 'El comentario no puede estar vacío'}), 400

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO comentarios (id_publicacion, id_usuario, contenido)
            VALUES (%s, %s, %s)
        """, (publicacion_id, user_id, contenido))
        mysql.connection.commit()
        cur.close()
        return jsonify({'mensaje': 'Comentario publicado correctamente'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/publicacion/<int:publicacion_id>', methods=['DELETE'])
@token_required
def eliminar_publicacion(publicacion_id):
    user_id = request.user['user_id']

    try:
        cur = mysql.connection.cursor()

        # Eliminar relaciones dependientes primero si no usas ON DELETE CASCADE
        cur.execute("DELETE FROM comentarios WHERE id_publicacion = %s", (publicacion_id,))
        cur.execute("DELETE FROM imagenes WHERE id_publicacion = %s", (publicacion_id,))
        cur.execute("DELETE FROM me_gustas WHERE id_publicacion = %s", (publicacion_id,))

        # Corrige el nombre de la columna
        cur.execute("""
            DELETE FROM publicaciones
            WHERE id = %s AND usuario_id = %s
        """, (publicacion_id, user_id))

        mysql.connection.commit()
        cur.close()

        return jsonify({'mensaje': 'Publicación eliminada'}), 200
    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

@app.route('/publicacion/<int:id>/gps')
@token_required
def obtener_gps(id):
    cur = mysql.connection.cursor()
    cur.execute("SELECT gps_data FROM publicaciones WHERE id = %s", (id,))
    row = cur.fetchone()
    cur.close()

    if row and row[0]:
        try:
            datos = json.loads(row[0])  # Convierte la cadena JSON a lista real
            return jsonify(datos)
        except Exception as e:
            print(f"Error parseando gps_data: {e}")
            return jsonify({'error': 'Formato inválido de gps_data'}), 500

    return jsonify([]), 404



@app.route('/publicacion/<int:publicacion_id>/comentarios', methods=['GET'])
@token_required
def obtener_comentarios(publicacion_id):
    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT c.contenido, u.nombre_usuario, u.id AS id_usuario
            FROM comentarios c
            JOIN usuarios u ON c.id_usuario = u.id
            WHERE c.id_publicacion = %s
            ORDER BY c.id_comentario ASC
        """, (publicacion_id,))
        resultados = cur.fetchall()
        cur.close()

        comentarios = [
            {
                'usuario': fila[1],
                'contenido': fila[0],
                'id_usuario': fila[2]
            }
            for fila in resultados
        ]
        return jsonify(comentarios), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500



# ----------------------
# API: DAR LIKE
# ----------------------
@app.route('/publicacion/<int:publicacion_id>/like', methods=['POST'])
@token_required
def dar_like(publicacion_id):
    user_id = request.user['user_id']

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT IGNORE INTO me_gustas (id_publicacion, id_usuario)
            VALUES (%s, %s)
        """, (publicacion_id, user_id))
        mysql.connection.commit()
        cur.close()
        return jsonify({'mensaje': 'Like registrado'}), 201
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ----------------------
# API: QUITAR LIKE
# ----------------------
@app.route('/publicacion/<int:publicacion_id>/like', methods=['DELETE'])
@token_required
def quitar_like(publicacion_id):
    user_id = request.user['user_id']

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            DELETE FROM me_gustas WHERE id_publicacion = %s AND id_usuario = %s
        """, (publicacion_id, user_id))
        mysql.connection.commit()
        cur.close()
        return jsonify({'mensaje': 'Like eliminado'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

# ----------------------
# API: GET PUBLICACION COMPLETA
# ----------------------
@app.route('/publicacion/<int:publicacion_id>', methods=['GET'])
@token_required
def obtener_publicacion(publicacion_id):
    user_id = request.user['user_id']
    try:
        cur = mysql.connection.cursor(MySQLdb.cursors.DictCursor)

        # Obtener publicacion
        cur.execute("""
            SELECT p.id, p.descripcion, p.fecha, p.gps_data, p.tiene_gps,
                   u.nombre_usuario, p.duracion
            FROM publicaciones p
            JOIN usuarios u ON p.usuario_id = u.id
            WHERE p.id = %s
        """, (publicacion_id,))
        publicacion = cur.fetchone()
        if not publicacion:
            return jsonify({'mensaje': 'Publicación no encontrada'}), 404

        # Justo después de recuperar la publicacion
        duracion = publicacion.get('duracion')
        if isinstance(duracion, datetime.timedelta):
            total_seconds = int(duracion.total_seconds())
            hours = total_seconds // 3600
            minutes = (total_seconds % 3600) // 60
            seconds = total_seconds % 60
            publicacion['duracion'] = f"{hours:02}:{minutes:02}:{seconds:02}"
        else:
            publicacion['duracion'] = str(duracion)

        # Obtener imágenes
        cur.execute("""
            SELECT nombre_imagen FROM imagenes WHERE id_publicacion = %s
        """, (publicacion_id,))
        imagenes = cur.fetchall()
        publicacion['imagenes'] = [
            f"http://localhost:5000/imagenes_publicaciones/{img['nombre_imagen']}"
            for img in imagenes
        ]

        # Obtener comentarios
        cur.execute("""
            SELECT c.contenido, c.fecha, u.nombre_usuario
            FROM comentarios c
            JOIN usuarios u ON c.id_usuario = u.id
            WHERE c.id_publicacion = %s
            ORDER BY c.fecha ASC
        """, (publicacion_id,))
        publicacion['comentarios'] = cur.fetchall()

        # Contar likes
        cur.execute("SELECT COUNT(*) AS total_likes FROM me_gustas WHERE id_publicacion = %s", (publicacion_id,))
        publicacion['me_gustas'] = cur.fetchone()['total_likes']

        cur.execute("""SELECT 1 FROM me_gustas WHERE id_publicacion = %s AND id_usuario = %s
        """, (publicacion_id, user_id))
        publicacion['me_gusta_usuario'] = bool(cur.fetchone())

        cur.close()
        return jsonify(publicacion), 200

    except Exception as e:
        import traceback
        traceback.print_exc()
        return jsonify({'error': str(e)}), 500

# ----------------------
# API: LISTAR PUBLICACIONES DE AMIGOS + PROPIAS
# ----------------------
@app.route('/publicaciones', methods=['GET'])
@token_required
def listar_publicaciones_amigos():
    user_id = request.user['user_id']

    try:
        cur = mysql.connection.cursor()

        # Obtener IDs de amigos aceptados + el usuario actual
        cur.execute("""
            SELECT amigo_fk FROM amigos WHERE usuario_fk = %s AND estado = 'aceptado'
            UNION
            SELECT usuario_fk FROM amigos WHERE amigo_fk = %s AND estado = 'aceptado'
        """, (user_id, user_id))
        amigos = [row[0] for row in cur.fetchall()]
        amigos.append(user_id)

        # Obtener publicaciones (sin formato en query)
        formato_in = ','.join(['%s'] * len(amigos))
        query = f"""
    SELECT p.id, p.descripcion, p.fecha, p.duracion, p.usuario_id AS id_usuario,
           u.nombre_usuario, u.foto_perfil,
           (SELECT COUNT(*) FROM me_gustas WHERE id_publicacion = p.id) AS total_likes,
           p.tiene_gps
    FROM publicaciones p
    JOIN usuarios u ON p.usuario_id = u.id
    WHERE p.usuario_id IN ({formato_in})
    ORDER BY p.fecha DESC
"""
        cur.execute(query, tuple(amigos))
        resultados = cur.fetchall()
        columnas = [col[0] for col in cur.description]
        publicaciones = [dict(zip(columnas, row)) for row in resultados]

        for pub in publicaciones:
            # Convertir timedelta a string si aplica
            duracion = pub['duracion']
            if isinstance(duracion, timedelta):
                total_seconds = int(duracion.total_seconds())
                hours = total_seconds // 3600
                minutes = (total_seconds % 3600) // 60
                seconds = total_seconds % 60
                pub['duracion'] = f"{hours:02}:{minutes:02}:{seconds:02}"
            else:
                pub['duracion'] = str(duracion)

            cur.execute("SELECT nombre_imagen FROM imagenes WHERE id_publicacion = %s", (pub['id'],))
            imagenes = [row[0] for row in cur.fetchall()]
            pub['imagenes'] = imagenes

            cur.execute("SELECT 1 FROM me_gustas WHERE id_publicacion = %s AND id_usuario = %s", (pub['id'], user_id))
            pub['me_gusta_usuario'] = bool(cur.fetchone())

        cur.close()
        return jsonify(publicaciones), 200

    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/son_amigos/<int:id1>/<int:id2>', methods=['GET'])
@token_required
def son_amigos(id1, id2):
    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 1 FROM amigos
            WHERE (
                (usuario_fk = %s AND amigo_fk = %s) OR 
                (usuario_fk = %s AND amigo_fk = %s)
            )
            AND estado = 'aceptado'
            LIMIT 1
        """, (id1, id2, id2, id1))
        
        resultado = cur.fetchone()
        cur.close()

        if resultado:
            return jsonify({'son_amigos': True}), 200
        else:
            return jsonify({'son_amigos': False}), 200
    except Exception as e:
        print(f"Error al verificar amistad: {e}")
        return jsonify({'mensaje': 'Error al verificar amistad'}), 500


@app.route('/enviar_mensaje', methods=['POST'])
@token_required
def enviar_mensaje():
    data = request.get_json()
    emisor_fk = data.get('emisor_fk')
    receptor_fk = data.get('receptor_fk')
    mensaje = data.get('mensaje')

    if not emisor_fk or not receptor_fk or not mensaje:
        return jsonify({'mensaje': 'Faltan datos para enviar el mensaje'}), 400

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            INSERT INTO mensajes (emisor_fk, receptor_fk, mensaje, fecha_envio)
            VALUES (%s, %s, %s, NOW())
        """, (emisor_fk, receptor_fk, mensaje))

        mysql.connection.commit()
        cur.close()
        return jsonify({'mensaje': 'Mensaje enviado correctamente'}), 201

    except Exception as e:
        print(f"Error al enviar el mensaje: {e}")
        return jsonify({'mensaje': 'Error al enviar el mensaje'}), 500

@app.route('/obtener_conversacion', methods=['POST'])
@token_required
def obtener_conversacion():
    data = request.get_json()
    usuario_id = data.get('usuario_id')
    amigo_id = data.get('amigo_id')

    if not usuario_id or not amigo_id:
        return jsonify([]), 200 

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT 
                m.id, 
                m.emisor_fk AS emisor_id, 
                u1.nombre_usuario AS emisor_nombre, 
                u1.foto_perfil AS emisor_foto,
                m.receptor_fk AS receptor_id, 
                u2.nombre_usuario AS receptor_nombre, 
                u2.foto_perfil AS receptor_foto,
                m.mensaje, 
                m.fecha_envio, 
                m.leido
            FROM mensajes m
            JOIN usuarios u1 ON u1.id = m.emisor_fk
            JOIN usuarios u2 ON u2.id = m.receptor_fk
            WHERE (m.emisor_fk = %s AND m.receptor_fk = %s) 
               OR (m.emisor_fk = %s AND m.receptor_fk = %s)
            ORDER BY m.fecha_envio ASC
        """, (usuario_id, amigo_id, amigo_id, usuario_id))

        mensajes = cur.fetchall()
        columnas = [desc[0] for desc in cur.description]
        resultado = [dict(zip(columnas, fila)) for fila in mensajes]

        cur.close()

        return jsonify(resultado if resultado else []), 200
    except Exception as e:
        return jsonify([]), 500

@app.route('/obtener_mensajes', methods=['POST'])
@token_required
def obtener_mensajes():
    data = request.get_json()
    user_id = data.get('usuario_id')

    if not user_id:
        return jsonify({'mensaje': 'Faltan datos'}), 400

    try:
        cur = mysql.connection.cursor()

        #Ejecutamos la consulta optimizada
        cur.execute("""
            SELECT 
                m.id, 
                m.emisor_fk, 
                u1.nombre_usuario AS emisor_nombre, 
                u1.foto_perfil AS emisor_foto,
                m.receptor_fk, 
                u2.nombre_usuario AS receptor_nombre, 
                u2.foto_perfil AS receptor_foto,
                m.mensaje, 
                m.fecha_envio, 
                m.leido
            FROM 
                mensajes m
            JOIN 
                usuarios u1 ON u1.id = m.emisor_fk
            JOIN 
                usuarios u2 ON u2.id = m.receptor_fk
            WHERE 
                m.emisor_fk = %s OR m.receptor_fk = %s
            ORDER BY 
                m.fecha_envio DESC
        """, (user_id, user_id))

        # Transformamos directamente en el formato que quieres
        mensajes = [{
            'id': msg[0],
            'emisor_id': msg[1],
            'emisor_nombre': msg[2],
            'emisor_foto': msg[3] if msg[3] else 'default.png',  # Valor por defecto si vacio
            'receptor_id': msg[4],
            'receptor_nombre': msg[5],
            'receptor_foto': msg[6] if msg[6] else 'default.png',  # Valor por defecto si vacio
            'mensaje': msg[7],
            'fecha_envio': msg[8].strftime("%Y-%m-%d %H:%M:%S"),
            'leido': bool(msg[9])
        } for msg in cur.fetchall()]

        cur.close()

        print(f"Conversaciones abiertas: {mensajes}")
        return jsonify(mensajes), 200
    except Exception as e:
        print(f"Error al obtener los mensajes: {e}")
        return jsonify({'mensaje': 'Error al obtener los mensajes'}), 500




@app.route('/marcar_leido', methods=['POST'])
@token_required
def marcar_leido():
    data = request.get_json()
    mensaje_id = data.get('mensaje_id')

    if not mensaje_id:
        return jsonify({'mensaje': 'Faltan datos para marcar como leído'}), 400

    try:
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE mensajes 
            SET leido = TRUE 
            WHERE id = %s
        """, (mensaje_id,))
        mysql.connection.commit()
        cur.close()
        return jsonify({'mensaje': 'Mensaje marcado como leído'}), 200
    except Exception as e:
        print(f"Error al marcar como leído: {e}")
        return jsonify({'mensaje': 'Error al marcar como leído'}), 500


@app.route('/enviar_solicitud', methods=['POST'])
def enviar_solicitud():
    data = request.json
    usuario_fk = data['usuario_fk']
    amigo_fk = data['amigo_fk']

    cur = mysql.connection.cursor()
    cur.execute("""
        INSERT INTO amigos (usuario_fk, amigo_fk, estado)
        VALUES (%s, %s, 'pendiente')
    """, (usuario_fk, amigo_fk))
    mysql.connection.commit()
    cur.close()

    return jsonify({'mensaje': 'Solicitud enviada correctamente'}), 200

@app.route('/aceptar_solicitud', methods=['POST'])
@token_required
def aceptar_solicitud():
    data = request.get_json()
    usuario_fk = data.get('usuario_fk')
    amigo_fk = data.get('amigo_fk')

    if not usuario_fk or not amigo_fk:
        return jsonify({'mensaje': 'Faltan datos para procesar la solicitud'}), 400

    try:
        cur = mysql.connection.cursor()
        
        #Buscamos la solicitud pendiente
        query = """
            SELECT * FROM amigos 
            WHERE usuario_fk = %s AND amigo_fk = %s AND estado = 'pendiente'
        """
        print(f"📝 Consulta SQL:\n{query}\nParámetros: usuario_fk={amigo_fk}, amigo_fk={usuario_fk}")
        
        #Invertimos los params al buscar
        cur.execute(query, (amigo_fk, usuario_fk))
        
        solicitud = cur.fetchone()
        
        if solicitud:
            print(f"✅ Solicitud encontrada: {solicitud}")
            
            #Actualizamos el estado 
            update_query = """
                UPDATE amigos 
                SET estado = 'aceptado', fecha_aceptacion = NOW() 
                WHERE usuario_fk = %s AND amigo_fk = %s
            """
            print(f"📝 Actualización SQL:\n{update_query}\nParámetros: usuario_fk={amigo_fk}, amigo_fk={usuario_fk}")
            
            # Invertimos tmbn en el UPDATE
            cur.execute(update_query, (amigo_fk, usuario_fk))
            mysql.connection.commit()
            cur.close()
            print("Solicitud aceptada correctamente.")
            return jsonify({'mensaje': 'Solicitud aceptada correctamente'}), 200
        else:
            cur.close()
            print("No se encontro la solicitud pendiente para actualizar.")
            return jsonify({'mensaje': 'No se encontró la solicitud pendiente'}), 404
    except Exception as e:
        print(f"Error al aceptar la solicitud: {e}")
        return jsonify({'mensaje': 'Error interno del servidor'}), 500





#Rechazar solicitud de amistad
@app.route('/rechazar_solicitud', methods=['POST'])
def rechazar_solicitud():
    data = request.json
    usuario_fk = data['usuario_fk']
    amigo_fk = data['amigo_fk']

    cur = mysql.connection.cursor()
    cur.execute("""
        DELETE FROM amigos 
        WHERE usuario_fk = %s AND amigo_fk = %s AND estado = 'pendiente'
    """, (usuario_fk, amigo_fk))
    mysql.connection.commit()
    cur.close()

    return jsonify({'mensaje': 'Solicitud rechazada correctamente'}), 200

@app.route('/buscar_usuario_por_nombre', methods=['POST'])
@token_required
def buscar_usuario_por_nombre():
    data = request.get_json()
    nombre = data.get('nombre_usuario')

    cur = mysql.connection.cursor()
    cur.execute("SELECT id FROM usuarios WHERE nombre_usuario = %s", (nombre,))
    resultado = cur.fetchone()
    cur.close()

    if resultado:
        return jsonify({'id': resultado[0]}), 200
    else:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404


@app.route('/amigos_de/<int:usuario_id>', methods=['GET'])
@token_required
def amigos_de_usuario(usuario_id):
    current_user_id = request.user['user_id']
    cur = mysql.connection.cursor()

   # Ejecutar consulta
    cur.execute("""
        SELECT u.id, u.nombre_usuario, u.foto_perfil
        FROM amigos a
        JOIN usuarios u ON u.id = 
          CASE 
            WHEN a.usuario_fk = %s THEN a.amigo_fk 
            ELSE a.usuario_fk 
        END
    WHERE (a.usuario_fk = %s OR a.amigo_fk = %s)
      AND u.id != %s
      AND a.estado = 'aceptado'
    """, (usuario_id, usuario_id, usuario_id, usuario_id))

    columns = [col[0] for col in cur.description]
    amigos = [dict(zip(columns, row)) for row in cur.fetchall()]


    # Verificar ellos tmbn son amigos del usuario actual
    ids_amigos = [amigo['id'] for amigo in amigos]
    if ids_amigos:
        format_ids = ','.join(['%s'] * len(ids_amigos))
        query = f"""
            SELECT 
                CASE 
                    WHEN usuario_fk = %s THEN amigo_fk 
                    ELSE usuario_fk 
                END AS id_amigo
            FROM amigos
            WHERE estado = 'aceptado'
              AND (usuario_fk = %s OR amigo_fk = %s)
              AND (usuario_fk IN ({format_ids}) OR amigo_fk IN ({format_ids}))
        """
        params = [current_user_id, current_user_id, current_user_id] + ids_amigos + ids_amigos
        cur.execute(query, params)
        rows = cur.fetchall()
        column_names = [desc[0] for desc in cur.description]
        amigos_mutuos = {
            dict(zip(column_names, row))['id_amigo']
            for row in rows
        }
    else:
        amigos_mutuos = set()

    for amigo in amigos:
        amigo['es_amigo_actual'] = amigo['id'] in amigos_mutuos
        amigo['foto_perfil'] = f"{request.host_url}fotos_perfil/{amigo['foto_perfil']}"

    # primero los que son amigos del usuario actual
    amigos.sort(key=lambda a: not a['es_amigo_actual'])

    cur.close()
    return jsonify(amigos)


@app.route('/obtener_amigos', methods=['POST'])
def obtener_amigos():
    data = request.get_json()
    user_id = data.get('user_id')

    if not user_id:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

    try:
        cur = mysql.connection.cursor()
        
        # consulta para obtener amigos aceptados
        cur.execute("""
            SELECT u.id, u.nombre_usuario, u.foto_perfil 
            FROM amigos a 
            JOIN usuarios u ON (
                (u.id = a.usuario_fk AND a.amigo_fk = %s) OR 
                (u.id = a.amigo_fk AND a.usuario_fk = %s)
            )
            WHERE a.estado = 'aceptado'
        """, (user_id, user_id))
        
        amigos = cur.fetchall()
        cur.close()

        # formatear la respuesta
        resultado = [{'id': amigo[0], 'nombre': amigo[1], 'foto': amigo[2]} for amigo in amigos]
        
        return jsonify(resultado), 200

    except Exception as e:
        print(f"❌ Error al obtener amigos: {e}")
        return jsonify({'mensaje': 'Error al obtener amigos'}), 500



@app.route('/obtener_solicitudes', methods=['GET'])
@token_required
def obtener_solicitudes():
    user_id = request.args.get('usuario_id')
    
    if not user_id:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT s.id, s.usuario_fk, u.nombre_usuario as nombre, u.foto_perfil as foto
        FROM amigos s
        JOIN usuarios u ON u.id = s.usuario_fk
        WHERE s.amigo_fk = %s AND s.estado = 'pendiente'
    """, (user_id,))
    
    solicitudes = cur.fetchall()
    cur.close()

    # ahora incluimos el usuario_fk en el JSON a Flutter
    resultado = [{'id': sol[0], 'usuario_fk': sol[1], 'nombre': sol[2], 'foto': sol[3]} for sol in solicitudes]

    return jsonify(resultado), 200


@app.route('/agregar_comida', methods=['POST'])
@token_required
def agregar_comida():
    data = request.json
    
    user_id = request.user['user_id']
    nombre_comida = data['nombre_comida']
    kcal = float(data['kcal'])
    carbs = float(data['carbs'])
    proteinas = float(data['proteinas'])
    grasas = float(data['grasas'])
    gramos = float(data.get('gramos', 100))

    # Ajustar hora
    tz = pytz.timezone('Europe/Madrid')
    fecha_local = datetime.datetime.now(tz)

    cur = mysql.connection.cursor()
    cur.execute("""
        INSERT INTO comidas (usuarios_fk, nombre_comida, kcal, carbs, proteinas, grasas, fecha_agregacion)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, (user_id, nombre_comida, kcal, carbs, proteinas, grasas, fecha_local))

    mysql.connection.commit()
    cur.close()

    return jsonify({"mensaje": "Comida añadida correctamente"}), 200

@app.route('/calorias_consumidas_hoy', methods=['GET'])
@token_required
def calorias_consumidas_hoy():
    user_id = request.user['user_id']

    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT SUM(kcal) 
        FROM comidas 
        WHERE usuarios_fk = %s AND DATE(fecha_agregacion) = CURDATE()
    """, (user_id,))
    
    resultado = cur.fetchone()
    total_calorias = resultado[0] if resultado[0] is not None else 0
    cur.close()

    return jsonify({"calorias_consumidas": float(total_calorias)}), 200



@app.route('/obtener_comidas', methods=['GET'])
@token_required
def obtener_comidas():
    user_id = request.user['user_id']

    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT nombre_comida, kcal, carbs, proteinas, grasas, fecha_agregacion
        FROM comidas 
        WHERE usuarios_fk = %s
    """, (user_id,))
    
    rows = cur.fetchall()
    cur.close()

    comidas = []
    for row in rows:
        comidas.append({
            'nombre_comida': row[0],
            'kcal': row[1],
            'carbs': row[2],
            'proteinas': row[3],
            'grasas': row[4],
            'fecha_agregacion': row[5].strftime("%Y-%m-%d %H:%M:%S")
        })

    return jsonify(comidas), 200

@app.route('/historico_diario', methods=['GET'])
@token_required
def historico_diario():
    user_id = request.user['user_id']

    cur = mysql.connection.cursor()
    # Seleccionar solo las comidas de hoy 
    cur.execute("""
        SELECT 
            nombre_comida,
            gramos,
            kcal,
            IFNULL(DATE_FORMAT(CONVERT_TZ(fecha_agregacion, '+00:00', '+02:00'), '%%H:%%i:%%s'), '--:--:--') AS hora
        FROM comidas 
        WHERE usuarios_fk = %s 
        AND DATE(CONVERT_TZ(fecha_agregacion, '+00:00', '+02:00')) = CURDATE()
        ORDER BY fecha_agregacion DESC
    """, (user_id,))
    
    rows = cur.fetchall()
    cur.close()

    historico = []
    for row in rows:
        historico.append({
            'nombre_comida': row[0],
            'gramos': float(row[1]),
            'kcal': float(row[2]),
            'hora': row[3] if row[3] is not None else "--:--:--"
        })

    return jsonify(historico), 200




# Tasa metabolica
@app.route('/tmb', methods=['GET'])
@token_required
def obtener_tmb():
    user_id = request.user['user_id']
    
    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT peso, altura, fecha_nacimiento, genero, nivel_actividad
        FROM usuarios WHERE id = %s
    """, (user_id,))
    
    resultado = cur.fetchone()
    cur.close()

    if not resultado:
        return jsonify({'mensaje': 'Usuario no encontrado'}), 404

    peso, altura, fecha_nacimiento, genero, nivel_actividad = resultado
  
  # Convertir a float para evitar conflictos
    peso = float(peso)
    altura = float(altura)
    nivel_actividad = float(nivel_actividad)

    # Calcular edad correctamente
    if isinstance(fecha_nacimiento, datetime.datetime):
        fecha_nacimiento = fecha_nacimiento.date()

    edad = datetime.datetime.now().year - fecha_nacimiento.year

    # Fórmula 
    if genero == 'hombre':
        tmb = 88.362 + (13.397 * peso) + (4.799 * altura * 100) - (5.677 * edad)
    else:
        tmb = 447.593 + (9.247 * peso) + (3.098 * altura * 100) - (4.330 * edad)

    # Multi por el nivel de actividad
    tmb_total = tmb * nivel_actividad

    return jsonify({
        'tmb': round(tmb_total, 2),
        'peso': peso,
        'altura': altura,
        'edad': edad,
        'genero': genero,
        'nivel_actividad': nivel_actividad
    }), 200

@app.route('/usuario/foto_perfil', methods=['POST'])
@token_required
def actualizar_foto_perfil():
    user_id = request.user['user_id']

    if 'foto_perfil' not in request.files:
        return jsonify({'mensaje': 'No se ha enviado ninguna imagen'}), 400

    file = request.files['foto_perfil']

    if file and allowed_file(file.filename):
        # Generar un nombre seguro para el archivo con un timestamp
        filename = secure_filename(f"{user_id}_{datetime.datetime.now().strftime('%Y%m%d%H%M%S')}.png")
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        # Guardar el archivo en el directorio 
        file.save(filepath)

        # Guardar en la bd la ruta relativa
        cur = mysql.connection.cursor()
        cur.execute("""
            UPDATE usuarios SET foto_perfil = %s WHERE id = %s
        """, (filename, user_id))
        mysql.connection.commit()
        cur.close()

        # Devolver el nombre del archivo actualizado
        return jsonify({
            'mensaje': 'Foto de perfil actualizada',
            'ruta': filename
        }), 200
    else:
        return jsonify({'mensaje': 'Formato de archivo no permitido'}), 400

@app.route('/fotos_perfil/<filename>', methods=['GET'])
def uploaded_file(filename):
   
    try:
        print(f"Intentando servir la imagen: {filename}")
        filepath = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        
        def generate():
            with open(filepath, 'rb') as f:
                chunk = f.read(4096)
                while chunk:
                    yield chunk
                    chunk = f.read(4096)
        
        # Encabezados necesarios 
        headers = {
            "Content-Type": "image/png",
            "Connection": "keep-alive",
            "Keep-Alive": "timeout=5, max=1",
            "Cache-Control": "no-cache",
            "Access-Control-Allow-Origin": "*"
        }
        
        return app.response_class(generate(), headers=headers)
    except FileNotFoundError:
        print(f"Imagen no encontrada: {filename}")
        return "Archivo no encontrado", 404

@app.route('/imagenes_publicaciones/<filename>', methods=['GET'])
def imagen_publicacion(filename):
    try:
        print(f"Sirviendo imagen de publicación: {filename}")
        carpeta = os.path.join('C:\\imagenes_hercules', 'publicaciones')
        return send_from_directory(carpeta, filename)
    except FileNotFoundError:
        print(f"Archivo no encontrado: {filename}")
        return "Archivo no encontrado", 404


if __name__ == '__main__':
    print("Iniciando API Flask en modo desarrollo...")
    app.run(debug=True)
 