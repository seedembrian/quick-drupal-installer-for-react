#!/bin/bash

# Help function
show_help() {
  echo "Usage: $0 [options] project-name"
  echo ""
  echo "Options:"
  echo "  -f, --full          Full automatic installation"
  echo "  -u, --user USER     Admin username (default: admin)"
  echo "  -p, --pass PASS     Admin password (default: admin)"
  echo "  -e, --email EMAIL   Admin email (default: admin@example.com)"
  echo "  -n, --name NAME     Site name (default: My Drupal CMS Pro)"
  echo "  -r, --react         Install React theme"
  echo "  -g, --git URL       Git repository URL for React theme"
  echo "  -h, --help          Show this help"
  exit 0
}

# Default variables
PROJECT_NAME="drupalcms-react"
FULL_INSTALL=false
ADMIN_USER="admin"
ADMIN_PASS="admin"
ADMIN_EMAIL="admin@example.com"
SITE_NAME="My Drupal CMS React"
INSTALL_REACT=true
REACT_REPO=""

# Read arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --full|-f)
      FULL_INSTALL=true
      shift
      ;;
    --user|-u)
      ADMIN_USER="$2"
      shift 2
      ;;
    --pass|-p)
      ADMIN_PASS="$2"
      shift 2
      ;;
    --email|-e)
      ADMIN_EMAIL="$2"
      shift 2
      ;;
    --name|-n)
      SITE_NAME="$2"
      shift 2
      ;;
    --react|-r)
      INSTALL_REACT=true
      shift
      ;;
    --git|-g)
      REACT_REPO="$2"
      INSTALL_REACT=true
      shift 2
      ;;
    --help|-h)
      show_help
      ;;
    -*)
      echo "❌ Unknown option: $1"
      show_help
      ;;
    *)
      PROJECT_NAME="$1"
      shift
      ;;
  esac
done

# Verify that a project name was provided
if [ -z "$PROJECT_NAME" ]; then
  echo "❌ You must specify a project name"
  show_help
fi

PROFILE="drupal_cms_installer"

# Check DDEV
if ! command -v ddev &> /dev/null; then
  echo "❌ DDEV is not installed. Install it from https://ddev.readthedocs.io/"
  exit 1
fi

# === Avoid overwriting if exists ===
if [ -d "$PROJECT_NAME" ]; then
  echo "⚠️ The folder '$PROJECT_NAME' already exists. Please choose another name or delete it first."
  exit 1
fi

# Create folder and navigate to it
mkdir "$PROJECT_NAME"
cd "$PROJECT_NAME" || exit 1

# Configure and start DDEV
echo "⚙️ Configurando DDEV React..."
ddev config --project-type=drupal11 --docroot=web --project-name="$PROJECT_NAME" || exit 1

echo "🚀 Iniciando DDEV React..."
ddev start || exit 1

# Download Drupal CMS
echo "📦 Descargando Drupal CMS React..."
ddev composer create drupal/cms || exit 1

if [ "$FULL_INSTALL" = true ]; then
  echo "⚙️ Instalando Drupal CMS React, por favor espere..."
  ddev drush site:install "$PROFILE" \
    --account-name="$ADMIN_USER" \
    --account-pass="$ADMIN_PASS" \
    --account-mail="$ADMIN_EMAIL" \
    --site-name="$SITE_NAME" \
    --yes

  # Corregir el error de permiso 'access toolbar' para el rol 'content editor'
  echo "🔧 Corrigiendo permisos para el rol 'content editor'..."
  # Usar role:perm:remove en lugar de role:remove-permission
  ddev drush role:perm:remove content_editor "access toolbar" 2>/dev/null || true

  echo "✅ Drupal CMS React instalado."
  echo "👤 Usuario: $ADMIN_USER"
  echo "🔑 Contraseña: $ADMIN_PASS"
else
  echo "📦 Proyecto Drupal React creado."
fi

# Configurar Drupal en la carpeta /api de forma más segura
echo "📦 Configurando Drupal en la carpeta /api..."

# Crear la estructura de directorios
ddev exec mkdir -p /var/www/html/web/api

# Usar rsync para copiar los archivos (más seguro que mover)
ddev exec bash -c 'rsync -a --exclude="api" /var/www/html/web/ /var/www/html/web/api/'

# Crear un index.php en la raíz que redireccione a /api
ddev exec bash -c 'cat > /var/www/html/web/index.php << EOL
<?php
// Redireccionar a la página principal de Drupal
header("Location: /api/");
exit;
EOL'

# Actualizar settings.php para las nuevas rutas
ddev exec bash -c 'if [ -f /var/www/html/web/api/sites/default/settings.php ]; then
  # Hacer backup del archivo original
  cp /var/www/html/web/api/sites/default/settings.php /var/www/html/web/api/sites/default/settings.php.bak
  
  # Actualizar rutas
  sed -i "s|\$settings\[\"file_public_path\"\] = \"sites/default/files\"|\$settings\[\"file_public_path\"\] = \"api/sites/default/files\"|g" /var/www/html/web/api/sites/default/settings.php
  
  # Añadir configuración de base_path si no existe
  if ! grep -q "\$base_url" /var/www/html/web/api/sites/default/settings.php; then
    echo "\$base_url = \'https://\$_SERVER[\"HTTP_HOST\"]/api\';" >> /var/www/html/web/api/sites/default/settings.php
  fi
fi'

# Copiar .htaccess a la carpeta api
ddev exec bash -c 'if [ -f /var/www/html/web/.htaccess ]; then
  cp /var/www/html/web/.htaccess /var/www/html/web/api/
fi'

# Instalar tema React (siempre se instala)
echo "🎨 Configurando el tema React..."
  
  # Crear directorios necesarios
  ddev exec mkdir -p web/api/themes/custom/theme_react/templates
  ddev exec mkdir -p web/api/themes/custom/theme_react/react-src
  
  # Si no se proporcionó una URL de repositorio, preguntar al usuario
  if [ -z "$REACT_REPO" ]; then
    echo "📝 Ingrese la URL del repositorio Git para el tema React (o presione Enter para omitir):"
    read -r REACT_REPO
  fi
  
  # Crear archivos básicos para el tema React (siempre, independientemente del repositorio)
  echo "📝 Creando archivos básicos para el tema React..."
  
  # Clonar el repositorio si se proporcionó una URL
  if [ -n "$REACT_REPO" ]; then
    echo "📦 Clonando repositorio React desde $REACT_REPO..."
    ddev exec git clone "$REACT_REPO" web/api/themes/custom/theme_react/react-src
    
    # Instalar dependencias si existe package.json
    if ddev exec test -f web/api/themes/custom/theme_react/react-src/package.json; then
      echo "📦 Instalando dependencias de Node.js..."
      ddev exec -d /var/www/html/web/api/themes/custom/theme_react/react-src npm install
      
      # Modificar la configuración de build para que los archivos queden en la raíz de /web
      echo "⚙️ Configurando el build de React para la raíz de /web..."
      
      # Verificar si es un proyecto Vite
      if ddev exec test -f web/api/themes/custom/theme_react/react-src/vite.config.js; then
        echo "📝 Modificando vite.config.js para build en raíz..."
        # Crear un archivo de configuración Vite personalizado
        ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/vite.config.js << EOL
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "/var/www/html/web",
    emptyOutDir: false,
  },
});
EOL'
      fi
      
      # Construir el proyecto React
      echo "🔨 Construyendo el proyecto React..."
      ddev exec -d /var/www/html/web/api/themes/custom/theme_react/react-src npm run build
    fi
  fi
    
    # Crear theme_react.info.yml
    ddev exec bash -c 'cat > web/api/themes/custom/theme_react/theme_react.info.yml << EOL
name: Theme React
type: theme
description: "Tema personalizado con integración de React"
core_version_requirement: ^11
base theme: olivero

regions:
  header: "Header"
  content: "Content"
  footer: "Footer"
EOL'
    
    # Crear theme_react.libraries.yml
    ddev exec bash -c 'cat > web/api/themes/custom/theme_react/theme_react.libraries.yml << EOL
global:
  version: VERSION
  js:
    # Los archivos JS se cargan dinámicamente desde el hook
  css:
    # Los archivos CSS se cargan dinámicamente desde el hook
EOL'
    
    # Crear un archivo theme_react.theme vacío
    echo "📝 Creando archivo theme_react.theme vacío..."
    ddev exec bash -c 'touch web/api/themes/custom/theme_react/theme_react.theme'
    
    # Añadir el código PHP al archivo theme_react.theme
    echo "📝 Añadiendo código al archivo theme_react.theme..."
    ddev exec bash -c 'cat > web/api/themes/custom/theme_react/theme_react.theme << "EOFTHEME"
<?php

/**
 * @file
 * Functions to support theming in the Theme React theme.
 */

/**
 * Implements hook_page_attachments_alter().
 */
function theme_react_page_attachments_alter(array &$attachments) {
  // Buscar archivos CSS y JS en la raíz de /web
  $web_root = DRUPAL_ROOT . "/../";
  
  // Definir rutas relativas para los assets
  $css_files = glob($web_root . "*.css");
  $js_files = glob($web_root . "*.js");
  
  // Añadir archivos CSS
  foreach ($css_files as $css_file) {
    $file_name = basename($css_file);
    $file_path = "/" . $file_name;
    
    $attachments["#attached"]["html_head"][] = [
      [
        "#type" => "html_tag",
        "#tag" => "link",
        "#attributes" => [
          "rel" => "stylesheet",
          "href" => $file_path,
        ],
      ],
      "theme_react_css_" . md5($file_path),
    ];
  }
  
  // Añadir archivos JS
  foreach ($js_files as $js_file) {
    $file_name = basename($js_file);
    $file_path = "/" . $file_name;
    
    $attachments["#attached"]["html_head"][] = [
      [
        "#type" => "html_tag",
        "#tag" => "script",
        "#attributes" => [
          "src" => $file_path,
          "defer" => TRUE,
        ],
      ],
      "theme_react_js_" . md5($file_path),
    ];
  }
  
  // Añadir CSS para manejar el div dialog-off-canvas-main-canvas
  $attachments["#attached"]["html_head"][] = [
    [
      "#type" => "html_tag",
      "#tag" => "style",
      "#value" => "
        /* Hacer que el wrapper dialog-off-canvas-main-canvas se comporte como un contenedor transparente */
        .dialog-off-canvas-main-canvas {
          display: contents !important;
        }
      ",
    ],
    "theme_react_fix_canvas",
  ];
}

/**
 * Implements hook_css_alter().
 */
function theme_react_css_alter(&$css, $assets) {
  // Eliminar todos los CSS de Drupal
  foreach ($css as $key => $value) {
    unset($css[$key]);
  }
}
EOFTHEME'

    # Verificar si la creación fue exitosa
    if ddev exec test -f web/api/themes/custom/theme_react/theme_react.theme; then
        echo "✅ Archivo theme_react.theme creado correctamente."
    else
        echo "❌ Error: No se pudo crear el archivo theme_react.theme."
    fi
    
    # Eliminar el archivo theme_react.theme.test si existe
    ddev exec bash -c 'rm -f web/api/themes/custom/theme_react/theme_react.theme.test 2>/dev/null || true'
    
    # Crear html.html.twig
    ddev exec mkdir -p web/api/themes/custom/theme_react/templates
    ddev exec bash -c 'cat > web/api/themes/custom/theme_react/templates/html.html.twig << EOL
{#
/**
 * @file
 * Theme override for the basic structure of a single Drupal page.
 */
#}
<!DOCTYPE html>
<html{{ html_attributes }}>
  <head>
    <head-placeholder token="{{ placeholder_token }}">
    <title>{{ head_title|safe_join(" | ") }}</title>
    <css-placeholder token="{{ placeholder_token }}">
    <js-placeholder token="{{ placeholder_token }}">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
  </head>
  <body{{ attributes }}>
    {{ page }}
    {# <js-bottom-placeholder token="{{ placeholder_token }}"> #}
  </body>
</html>
EOL'
    
    # Crear page.html.twig
    ddev exec bash -c 'cat > web/api/themes/custom/theme_react/templates/page.html.twig << EOL
{#
/**
 * @file
 * Theme override to display a single page.
 */
#}
<div id="root"></div>
EOL'
  
  # Crear un archivo .htaccess en la carpeta api para asegurar que Drupal funcione correctamente
  echo "📝 Creando archivo .htaccess para Drupal en /api..."
  ddev exec bash -c 'if [ -f /var/www/html/web/.htaccess ]; then
    cp /var/www/html/web/.htaccess /var/www/html/web/api/
  fi'

  # Asegurarse de que bootstrap.inc esté accesible
  echo "🔧 Verificando archivos de core de Drupal..."
  ddev exec bash -c 'if [ ! -f /var/www/html/web/api/core/includes/bootstrap.inc ] && [ -f /var/www/html/web/core/includes/bootstrap.inc ]; then
    mkdir -p /var/www/html/web/api/core/includes/
    cp /var/www/html/web/core/includes/bootstrap.inc /var/www/html/web/api/core/includes/
  fi'

  # Activar el tema con manejo de errores
  echo "🔌 Activando el tema React..."
  ddev drush theme:enable theme_react || echo "\u26A0\ufe0f No se pudo activar el tema, pero continuamos con la instalación"
  ddev drush config-set system.theme default theme_react -y || echo "\u26A0\ufe0f No se pudo establecer el tema por defecto"
  ddev drush cr || echo "\u26A0\ufe0f Error al limpiar la caché, pero continuamos con la instalación"
  
  echo "✅ Tema React instalado y activado correctamente."
  echo "📝 Para trabajar con el tema React, edite los archivos en web/api/themes/custom/theme_react/"
  echo "🔨 Para compilar el tema React, ejecute 'npm run build' en web/api/themes/custom/theme_react/react-src/"
  echo "🌐 Los archivos compilados de React se ubicarán en la raíz de /web"
fi

# Crear un archivo .htaccess para redirigir las solicitudes a la API
echo "📝 Creando archivo .htaccess para redirecciones..."
ddev exec bash -c 'cat > web/.htaccess << EOL
# Redireccionar solicitudes a /api/* al backend de Drupal
RewriteEngine On

# Permitir acceso directo a archivos estáticos
RewriteCond %{REQUEST_FILENAME} -f [OR]
RewriteCond %{REQUEST_FILENAME} -d
RewriteRule ^ - [L]

# Redirigir solicitudes a /api/* a index.php de Drupal
RewriteCond %{REQUEST_URI} ^/api/.*$
RewriteRule ^api/(.*)$ /api/index.php [L,QSA]

# Redirigir todas las demás solicitudes a index.html para SPA
RewriteCond %{REQUEST_URI} !^/api/.*$
RewriteRule ^ index.html [L]
EOL'

# Crear un archivo index.html básico si no existe
if ! ddev exec test -f web/index.html; then
  echo "📝 Creando archivo index.html básico..."
  ddev exec bash -c 'cat > web/index.html << EOL
<!DOCTYPE html>
<html lang="es">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>React App</title>
</head>
<body>
  <div id="root"></div>
  <script>
    // Este archivo será reemplazado por el build de React
    console.log("Esperando build de React");
  </script>
</body>
</html>
EOL'
fi

echo "✨ Estado del proyecto React:"
ddev status

# Mostrar URL y abrir en el navegador al final
echo "🌐 URL del sitio: $(ddev describe -j | grep -oP '"https_url"\s*:\s*"\K[^"]+')"  
echo "🌐 Abriendo el sitio en su navegador..."

# Open in browser (WSL or Linux/macOS)
if grep -qEi "(Microsoft|WSL)" /proc/version &> /dev/null ; then
  SITE_URL=$(ddev describe -j | grep -oP '"https_url"\s*:\s*"\K[^"]+')    
  powershell.exe start "$SITE_URL"
else
  ddev launch
fi
