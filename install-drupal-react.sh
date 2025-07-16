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
  echo "  -n, --name NAME     Site name (default: My Drupal React Site)"
  echo "  -r, --react         Install React theme"
  echo "  -g, --git URL       Git repository URL for React theme"
  echo "  -h, --help          Show this help"
  exit 0
}

# Default variables
PROJECT_NAME="drupal-react"
FULL_INSTALL=false
ADMIN_USER="admin"
ADMIN_PASS="admin"
ADMIN_EMAIL="admin@example.com"
SITE_NAME="My Drupal React Site"
INSTALL_REACT=false
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
echo "⚙️ Configurando DDEV..."
ddev config --project-type=drupal11 --docroot=web --project-name="$PROJECT_NAME" || exit 1

echo "🚀 Iniciando DDEV..."
ddev start || exit 1

# Download Drupal CMS
echo "📦 Descargando Drupal CMS..."
ddev composer create drupal/cms || exit 1

if [ "$FULL_INSTALL" = true ]; then
  echo "⚙️ Instalando Drupal CMS, por favor espere..."
  ddev drush site:install "$PROFILE" \
    --account-name="$ADMIN_USER" \
    --account-pass="$ADMIN_PASS" \
    --account-mail="$ADMIN_EMAIL" \
    --site-name="$SITE_NAME" \
    --yes

  # Corregir el error de permiso 'access toolbar' para el rol 'content editor'
  echo "🔧 Corrigiendo permisos para el rol 'content editor'..."
  ddev drush role:perm:remove content_editor "access toolbar" 2>/dev/null || true

  echo "✅ Drupal CMS con React instalado."
  echo "👤 Usuario: $ADMIN_USER"
  echo "🔑 Contraseña: $ADMIN_PASS"
else
  echo "📦 Proyecto Drupal React creado."
fi

# Instalar tema React si se solicitó
if [ "$INSTALL_REACT" = true ]; then
  echo "🎨 Configurando el tema React..."
  
  # Crear directorios necesarios
  ddev exec mkdir -p web/themes/custom/theme_react/templates
  ddev exec mkdir -p web/themes/custom/theme_react/react-src
  
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
    ddev exec git clone "$REACT_REPO" web/themes/custom/theme_react/react-src
    
    # Instalar dependencias si existe package.json
    if ddev exec test -f web/themes/custom/theme_react/react-src/package.json; then
      echo "📦 Instalando dependencias de Node.js..."
      ddev exec -d /var/www/html/web/themes/custom/theme_react/react-src npm install
      
      # Construir el proyecto React directamente en la carpeta raíz de Drupal web
      echo "🔨 Construyendo el proyecto React en la carpeta raíz de Drupal..."
      # Primero verificamos si existe un archivo vite.config.js o similar para modificarlo
      if ddev exec bash -c "[ -f web/themes/custom/theme_react/react-src/vite.config.js ]"; then
        echo "📝 Modificando configuración de Vite para build en carpeta raíz..."
        # Crear un archivo temporal con la nueva configuración
        ddev exec bash -c 'cat > web/themes/custom/theme_react/react-src/vite.config.js.new << "EOFVITE"
// Configuración modificada para build en carpeta raíz de Drupal
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
import path from "path";

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    // Construir directamente en la carpeta raíz de Drupal
    outDir: "../../../..",
    emptyOutDir: false,
    rollupOptions: {
      output: {
        entryFileNames: "assets/[name]-[hash].js",
        chunkFileNames: "assets/[name]-[hash].js",
        assetFileNames: "assets/[name]-[hash].[ext]"
      }
    }
  },
  base: "/"
});
EOFVITE'
        # Reemplazar el archivo original con el nuevo
        ddev exec mv web/themes/custom/theme_react/react-src/vite.config.js.new web/themes/custom/theme_react/react-src/vite.config.js
      elif ddev exec bash -c "[ -f web/themes/custom/theme_react/react-src/webpack.config.js ]"; then
        echo "📝 Modificando configuración de Webpack para build en carpeta raíz..."
        # Crear un archivo temporal con la nueva configuración para webpack
        ddev exec bash -c 'cat > web/themes/custom/theme_react/react-src/webpack.config.js.new << "EOFWEBPACK"
// Configuración modificada para build en carpeta raíz de Drupal
const path = require("path");

module.exports = {
  // Configuración existente...
  output: {
    path: path.resolve(__dirname, "../../../.."),
    filename: "assets/[name]-[contenthash].js",
    publicPath: "/",
    clean: false
  },
  // Resto de la configuración...
};
EOFWEBPACK'
        echo "⚠️ NOTA: La configuración de Webpack es genérica y puede requerir ajustes manuales."
      fi
      
      # Ejecutar el build
      ddev exec -d /var/www/html/web/themes/custom/theme_react/react-src npm run build
    fi
  fi
    
    # Crear theme_react.info.yml
    ddev exec bash -c 'cat > web/themes/custom/theme_react/theme_react.info.yml << EOL
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
    ddev exec bash -c 'cat > web/themes/custom/theme_react/theme_react.libraries.yml << EOL
global:
  version: VERSION
  js:
    # Los archivos JS se cargan dinámicamente desde el hook
  css:
    # Los archivos CSS se cargan dinámicamente desde el hook
EOL'
    
    # Crear un archivo theme_react.theme vacío
    echo "📝 Creando archivo theme_react.theme vacío..."
    ddev exec bash -c 'touch web/themes/custom/theme_react/theme_react.theme'
    
    # Añadir el código PHP al archivo theme_react.theme
    echo "📝 Añadiendo código al archivo theme_react.theme..."
    ddev exec bash -c 'cat > web/themes/custom/theme_react/theme_react.theme << "EOFTHEME"
<?php

/**
 * @file
 * Functions to support theming in the Theme React theme.
 */

/**
 * Implements hook_page_attachments_alter().
 */
function theme_react_page_attachments_alter(array &\$attachments) {
  // Buscar archivos CSS y JS tanto en la carpeta raíz como en assets
  \$assets_paths = [
    'assets', // Carpeta assets en la raíz
    'web/assets', // Alternativa si se construye en web/assets
  ];
  
  foreach (\$assets_paths as \$assets_path) {
    // Verificar si la carpeta existe
    if (is_dir(DRUPAL_ROOT . '/' . \$assets_path)) {
      \$files = scandir(DRUPAL_ROOT . '/' . \$assets_path);
    
    foreach (\$files as \$file) {
      // Ignorar directorios y archivos ocultos
      if (\$file === "." || \$file === ".." || is_dir(DRUPAL_ROOT . "/" . \$assets_path . "/" . \$file)) {
        continue;
      }
      
      \$file_path = "/" . \$assets_path . "/" . \$file;
      
      // Añadir archivos CSS
      if (preg_match("/\\.css\$/", \$file)) {
        \$attachments["#attached"]["html_head"][] = [
          [
            "#type" => "html_tag",
            "#tag" => "link",
            "#attributes" => [
              "rel" => "stylesheet",
              "href" => \$file_path,
            ],
          ],
          "theme_react_css_" . md5(\$file),
        ];
      }
      
      // Añadir archivos JS
      if (preg_match("/\\.js\$/", \$file)) {
        \$attachments["#attached"]["html_head"][] = [
          [
            "#type" => "html_tag",
            "#tag" => "script",
            "#attributes" => [
              "src" => \$file_path,
              "type" => "module",
              "defer" => TRUE,
            ],
          ],
          "theme_react_js_" . md5(\$file),
        ];
      }
    }
  }
  }
  
  // Añadir CSS para manejar el div dialog-off-canvas-main-canvas
  \$attachments["#attached"]["html_head"][] = [
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
    "theme_react_dialog_fix",
  ];
}
EOFTHEME'
    
    # Verificar si la creación fue exitosa
    if ddev exec test -f web/themes/custom/theme_react/theme_react.theme; then
        echo "✅ Archivo theme_react.theme creado correctamente."
    else
        echo "❌ Error: No se pudo crear el archivo theme_react.theme."
    fi
    
    # Eliminar el archivo theme_react.theme.test si existe
    ddev exec bash -c 'rm -f web/themes/custom/theme_react/theme_react.theme.test 2>/dev/null || true'
    
    # Crear html.html.twig
    ddev exec mkdir -p web/themes/custom/theme_react/templates
    ddev exec bash -c 'cat > web/themes/custom/theme_react/templates/html.html.twig << EOL
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
    ddev exec bash -c 'cat > web/themes/custom/theme_react/templates/page.html.twig << EOL
{#
/**
 * @file
 * Theme override to display a single page.
 */
#}
<div id="root"></div>
EOL'
  
  # Activar el tema
  echo "🔌 Activando el tema React..."
  ddev drush theme:enable theme_react
  ddev drush config-set system.theme default theme_react -y
  ddev drush cr
  
  echo "✅ Tema React instalado y activado correctamente."
  echo "📝 Para trabajar con el tema React, edite los archivos en web/themes/custom/theme_react/"
  echo "🔨 Para compilar el tema React, ejecute 'npm run build' en web/themes/custom/theme_react/react-src/"
fi

echo "✨ Estado del proyecto:"
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
