# Quick Drupal Installer for React

Una herramienta avanzada para instalar rápidamente Drupal 11 desacoplado con React en la interfaz de usuario.

## Características

- Instalación rápida de Drupal 11 con DDEV
- Instalación automática de React en la interfaz de usuario
- Estructura desacoplada: Drupal en carpeta `/api` y React en la raíz de `/web`
- Clonación de repositorios Git de temas React
- Configuración automática del tema para eliminar estilos de Drupal
- Soporte para desarrollo con React/Preact
- Instalación global mediante curl o wget

## Requisitos

- DDEV instalado
- Git instalado
- Bash shell
- curl o wget (para la instalación global)

## Instalación

Elija uno de estos métodos:

1. Usando curl:

```bash
curl -o- https://raw.githubusercontent.com/seedembrian/quick-drupal-installer-for-react/master/install.sh | sh
```

2. Usando wget:

```bash
wget -qO- https://raw.githubusercontent.com/seedembrian/quick-drupal-installer-for-react/master/install.sh | sh
```

3. O descargue y ejecute manualmente:

```bash
# Descargar el instalador
curl -o install-drupal-react.sh https://raw.githubusercontent.com/seedembrian/quick-drupal-installer-for-react/master/install.sh

# Hacerlo ejecutable
chmod +x install-drupal-react.sh

# Ejecutar el instalador
./install-drupal-react.sh
```

Esto instalará dos comandos en su sistema:
- `quick-drupal-react`: Para uso directo con opciones de línea de comandos
- `quick-drupal-react-interactive`: Para una experiencia guiada con preguntas interactivas

## Uso

### Modo interactivo

```bash
quick-drupal-pro-interactive
```

### Modo directo

```bash
quick-drupal-react [opciones] nombre-proyecto
```

### Opciones

- `-f, --full`: Instalación automática completa
- `-u, --user USUARIO`: Nombre de usuario administrador (predeterminado: admin)
- `-p, --pass CONTRASEÑA`: Contraseña de administrador (predeterminado: admin)
- `-e, --email EMAIL`: Correo electrónico de administrador (predeterminado: admin@example.com)
- `-n, --name NOMBRE`: Nombre del sitio (predeterminado: My Drupal CMS React)
- `-g, --git URL`: URL del repositorio Git para el tema React
- `-h, --help`: Mostrar ayuda

Nota: React siempre se instala automáticamente, por lo que la opción `-r` ya no es necesaria.

### Ejemplos

```bash
# Instalación básica de Drupal con React (preguntará la URL)
quick-drupal-react mi-drupal-react

# Instalación completa con React desde un repositorio específico
quick-drupal-react -f -g https://github.com/user/react-theme.git mi-drupal-react

# Instalación completa con opciones personalizadas
quick-drupal-react -f -u admin -p secreto -e admin@example.com -n "Mi sitio React" mi-drupal-react
```

## Estructura del proyecto

El proyecto se instalará con la siguiente estructura:

```
proyecto/
├─ web/                # Raíz del sitio web
│   ├─ api/            # Backend de Drupal (movido a subcarpeta)
│   │   ├─ core/        # Núcleo de Drupal
│   │   ├─ modules/     # Módulos de Drupal
│   │   ├─ themes/      # Temas de Drupal
│   │   │   └─ custom/theme_react/  # Tema React
│   │   │       ├─ react-src/  # Código fuente de React
│   │   │       ├─ templates/  # Plantillas Twig
│   │   │       ├─ theme_react.info.yml
│   │   │       ├─ theme_react.libraries.yml
│   │   │       └─ theme_react.theme
│   │   └─ index.php    # Punto de entrada de Drupal
│   ├─ index.html     # Punto de entrada de React
│   ├─ assets/        # Archivos compilados de React (JS/CSS)
│   └─ .htaccess      # Configuración para redireccionar API y SPA
├─ vendor/            # Dependencias de Composer
└─ composer.json      # Configuración de Composer
```

## Desarrollo

Para trabajar con el proyecto después de la instalación:

### Frontend (React)

1. Navega a la carpeta del código fuente de React: `cd web/api/themes/custom/theme_react/react-src`
2. Instala dependencias si es necesario: `npm install`
3. Ejecuta el servidor de desarrollo: `npm run dev`
4. Compila para producción: `npm run build`
   - Los archivos compilados se ubicarán en la raíz de `/web`

### Backend (Drupal)

1. Accede a la administración de Drupal en: `https://tu-proyecto.ddev.site/api/user/login`
2. Limpia la caché de Drupal: `ddev drush cr`
3. Para trabajar con la API, usa la ruta base: `/api`

## Desinstalación

Para desinstalar los comandos globales:

```bash
sudo rm /usr/bin/quick-drupal-react /usr/bin/quick-drupal-react-interactive
```
