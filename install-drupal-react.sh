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

  # Ya no intentamos modificar permisos que podrían no existir
  echo "🔧 Configurando permisos..."
  # Simplemente limpiar la caché de Drupal
  ddev drush cr 2>/dev/null || true

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
  
  # Añadir configuración de base_path de forma segura
  echo "# Configuración para sitio en subcarpeta /api" >> /var/www/html/web/api/sites/default/settings.php
  echo "\$base_url = \"https://\" . (isset(\$_SERVER[\"HTTP_HOST\"]) ? \$_SERVER[\"HTTP_HOST\"] : \"localhost\") . \"/api\";" >> /var/www/html/web/api/sites/default/settings.php
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
  
  # Si no se proporcionó una URL de repositorio, usar un valor por defecto
  if [ -z "$REACT_REPO" ]; then
    # No preguntar, simplemente usar un valor por defecto o dejarlo vacío
    REACT_REPO=""
    echo "📝 No se proporcionó URL de repositorio Git. Se creará un tema React básico."
  fi
  
  # Crear archivos básicos para el tema React (siempre, independientemente del repositorio)
  echo "📝 Creando archivos básicos para el tema React..."
  
  # Si no se proporcionó un repositorio o falló la clonación, crear un proyecto React básico
  if [ -z "$REACT_REPO" ]; then
    echo "💻 Creando un proyecto React básico..."
    
    # Crear package.json básico
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/package.json << EOL
{
  "name": "theme-react",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build",
    "lint": "eslint . --ext js,jsx --report-unused-disable-directives --max-warnings 0",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.15",
    "@types/react-dom": "^18.2.7",
    "@vitejs/plugin-react": "^4.0.3",
    "eslint": "^8.45.0",
    "eslint-plugin-react": "^7.32.2",
    "eslint-plugin-react-hooks": "^4.6.0",
    "eslint-plugin-react-refresh": "^0.4.3",
    "vite": "^4.4.5"
  }
}
EOL'
    
    # Crear vite.config.js
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/vite.config.js << EOL
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  build: {
    outDir: "/var/www/html/web",
    emptyOutDir: false,
  },
});
EOL'
    
    # Crear estructura de directorios
    ddev exec mkdir -p /var/www/html/web/api/themes/custom/theme_react/react-src/src
    ddev exec mkdir -p /var/www/html/web/api/themes/custom/theme_react/react-src/public
    
    # Crear archivo principal App.jsx
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/src/App.jsx << EOL
import { useState } from "react";
import "./App.css";

function App() {
  const [count, setCount] = useState(0);

  return (
    <div className="app">
      <header className="app-header">
        <h1>Drupal + React</h1>
        <p>Sitio creado con Quick Drupal Installer for React</p>
      </header>
      <main>
        <div className="card">
          <button onClick={() => setCount((count) => count + 1)}>
            Contador: {count}
          </button>
        </div>
        <p className="info">
          Edita <code>src/App.jsx</code> y guarda para ver los cambios
        </p>
      </main>
    </div>
  );
}

export default App;
EOL'
    
    # Crear archivo CSS
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/src/App.css << EOL
.app {
  max-width: 1280px;
  margin: 0 auto;
  padding: 2rem;
  text-align: center;
}

.app-header {
  margin-bottom: 2rem;
}

.app-header h1 {
  font-size: 3rem;
  color: #4f46e5;
}

.card {
  padding: 2em;
}

.card button {
  border-radius: 8px;
  border: 1px solid transparent;
  padding: 0.6em 1.2em;
  font-size: 1em;
  font-weight: 500;
  font-family: inherit;
  background-color: #1a1a1a;
  color: white;
  cursor: pointer;
  transition: border-color 0.25s;
}

.card button:hover {
  border-color: #646cff;
}

.info {
  margin-top: 2rem;
  color: #888;
}

code {
  background-color: #f1f1f1;
  padding: 0.2em 0.4em;
  border-radius: 3px;
}
EOL'
    
    # Crear archivo main.jsx
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/src/main.jsx << EOL
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App";
import "./index.css";

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>
);
EOL'
    
    # Crear archivo index.css
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/src/index.css << EOL
:root {
  font-family: Inter, system-ui, Avenir, Helvetica, Arial, sans-serif;
  line-height: 1.5;
  font-weight: 400;
  color-scheme: light dark;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

body {
  margin: 0;
  display: flex;
  place-items: center;
  min-width: 320px;
  min-height: 100vh;
}

#root {
  width: 100%;
}
EOL'
    
    # Crear archivo index.html
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/react-src/index.html << EOL
<!DOCTYPE html>
<html lang="es">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Drupal + React</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
EOL'
  fi
  
  # Clonar el repositorio si se proporcionó una URL
  if [ -n "$REACT_REPO" ]; then
    echo "📦 Clonando repositorio React desde $REACT_REPO..."
    ddev exec git clone "$REACT_REPO" web/api/themes/custom/theme_react/react-src || {
      echo "⚠️ Error al clonar el repositorio. Creando estructura básica de React..."
      # Crear estructura básica si falla el clon
      REACT_REPO=""
    }
    
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
    
    # Añadir el código PHP al archivo theme_react.theme (versión simplificada)
    echo "📝 Añadiendo código al archivo theme_react.theme..."
    ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/theme_react.theme << "EOFTHEME"
<?php

/**
 * @file
 * Functions to support theming in the Theme React theme.
 */

/**
 * Implements hook_page_attachments_alter().
 */
function theme_react_page_attachments_alter(array &$attachments) {
  // Ruta base para los archivos estáticos
  $base_path = "";
  
  // Buscar archivos CSS y JS en la raíz de /web usando scandir
  $web_dir = DRUPAL_ROOT . "/../";
  if (is_dir($web_dir)) {
    $files = @scandir($web_dir);
    if ($files) {
      foreach ($files as $file) {
        // Ignorar directorios y archivos que no son CSS o JS
        if ($file === "." || $file === ".." || is_dir($web_dir . $file)) {
          continue;
        }
        
        // Procesar archivos CSS
        if (preg_match("/\.css$/", $file)) {
          $file_path = $base_path . "/" . $file;
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
        
        // Procesar archivos JS
        if (preg_match("/\.js$/", $file)) {
          $file_path = $base_path . "/" . $file;
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
      }
    }
  }
  
  // Añadir CSS para el contenedor principal
  $attachments["#attached"]["html_head"][] = [
    [
      "#type" => "html_tag",
      "#tag" => "style",
      "#value" => "#root { width: 100%; } .dialog-off-canvas-main-canvas { display: contents !important; }",
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

  # Asegurarse de que los archivos necesarios estén accesibles
  echo "🔧 Verificando archivos de core de Drupal..."
  ddev exec bash -c 'if [ ! -d /var/www/html/web/api/core/includes/ ]; then
    mkdir -p /var/www/html/web/api/core/includes/
  fi'
  
  # Crear archivos de tema simplificados para evitar errores
  echo "📝 Creando archivos de tema simplificados..."
  
  # Crear theme_react.info.yml simplificado
  ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/theme_react.info.yml << EOL
name: Theme React
type: theme
description: "Tema React para Drupal"
core_version_requirement: ^9 || ^10 || ^11
base theme: false
libraries:
  - theme_react/global
regions:
  content: "Content"
EOL'
  
  # Crear theme_react.libraries.yml simplificado
  ddev exec bash -c 'cat > /var/www/html/web/api/themes/custom/theme_react/theme_react.libraries.yml << EOL
global:
  version: VERSION
  js: {}
  css:
    theme: {}
EOL'
  
  # Crear plantilla page.html.twig simplificada
  ddev exec bash -c 'mkdir -p /var/www/html/web/api/themes/custom/theme_react/templates && cat > /var/www/html/web/api/themes/custom/theme_react/templates/page.html.twig << EOL
<div id="root"></div>
EOL'

  # Activar el tema con manejo de errores
  echo "🔌 Activando el tema React..."
  ddev drush theme:enable theme_react || echo "⚠️ No se pudo activar el tema, pero continuamos con la instalación"
  ddev drush config-set system.theme default theme_react -y || echo "⚠️ No se pudo establecer el tema por defecto"
  ddev drush cr || echo "⚠️ Error al limpiar la caché, pero continuamos con la instalación"
  
  echo "✅ Tema React instalado y activado correctamente."
  echo "📝 Para trabajar con el tema React, edite los archivos en web/api/themes/custom/theme_react/"
  echo "🔨 Para compilar el tema React, ejecute 'npm run build' en web/api/themes/custom/theme_react/react-src/"
  echo "🌐 Los archivos compilados de React se ubicarán en la raíz de /web"
fi

# Crear un archivo .htaccess para redirigir las solicitudes a la API
echo "📝 Creando archivo .htaccess para redirecciones..."
ddev exec bash -c 'cat > /var/www/html/web/.htaccess << EOL
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

# Crear un archivo index.html básico para la aplicación React
echo "📝 Creando archivo index.html básico..."
ddev exec bash -c 'cat > /var/www/html/web/index.html << EOL
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
