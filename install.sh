#!/bin/sh

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Installation variables
INSTALL_DIR="/usr/bin"
SCRIPT_NAME="quick-drupal-react"
REPO_URL="https://raw.githubusercontent.com/seedembrian/quick-drupal-installer-for-react/master/install-drupal-react.sh"

# Mensaje de bienvenida
echo "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo "${BLUE}║                                                        ║${NC}"
echo "${BLUE}║  ${GREEN}Quick Drupal Installer for React${BLUE}                           ║${NC}"
echo "${BLUE}║  ${YELLOW}Instalador avanzado de Drupal 11 con temas React${BLUE}    ║${NC}"
echo "${BLUE}║                                                        ║${NC}"
echo "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if sudo is available
if ! command -v sudo > /dev/null 2>&1; then
    echo "${RED}Error: El comando 'sudo' es necesario para la instalación${NC}"
    exit 1
fi

# Request sudo access
echo "${YELLOW}Se requieren permisos de administrador para instalar en $INSTALL_DIR${NC}"
echo -n "Por favor ingrese su contraseña: "
if ! sudo -v; then
    echo "\n${RED}Error: Acceso de administrador denegado${NC}"
    exit 1
fi

echo "\n${GREEN}Instalando Quick Drupal Installer for React...${NC}"

# Download script
echo "Descargando script..."
TMP_FILE=$(mktemp)

# Try with curl first, then wget if curl is not available
if command -v curl > /dev/null 2>&1; then
    curl -s -o "$TMP_FILE" "$REPO_URL" || {
        rm -f "$TMP_FILE"
        echo "${RED}Error al descargar el script con curl${NC}"
        exit 1
    }
elif command -v wget > /dev/null 2>&1; then
    wget -q -O "$TMP_FILE" "$REPO_URL" || {
        rm -f "$TMP_FILE"
        echo "${RED}Error al descargar el script con wget${NC}"
        exit 1
    }
else
    echo "${RED}Error: Se requiere curl o wget para la instalación${NC}"
    exit 1
fi

# Install script
echo "Instalando en $INSTALL_DIR..."
sudo mv "$TMP_FILE" "$INSTALL_DIR/$SCRIPT_NAME" && \
sudo chmod +x "$INSTALL_DIR/$SCRIPT_NAME" && \
echo "${GREEN}¡Instalación completada!${NC}" && \
echo "Ahora puede usar el comando 'quick-drupal-react' desde cualquier ubicación." && \
echo "Ejemplo: quick-drupal-react --help"

# Crear un script de instalación interactivo
echo "\n${YELLOW}Creando script de instalación interactivo...${NC}"

INTERACTIVE_SCRIPT="$INSTALL_DIR/quick-drupal-react-interactive"

cat > "$TMP_FILE" << 'EOL'
#!/bin/bash

# Colores para mensajes
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Mensaje de bienvenida
echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                                                        ║${NC}"
echo -e "${BLUE}║  ${GREEN}Quick Drupal Installer for React${BLUE}                           ║${NC}"
echo -e "${BLUE}║  ${YELLOW}Instalador avanzado de Drupal 11 con temas React${BLUE}    ║${NC}"
echo -e "${BLUE}║                                                        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Preguntar por el nombre del proyecto
read -p "Ingrese el nombre del proyecto: " PROJECT_NAME
if [ -z "$PROJECT_NAME" ]; then
  echo -e "${RED}Error: Debe especificar un nombre de proyecto.${NC}"
  exit 1
fi

# La instalación siempre será completa y con React
FULL_OPTION="-f"
REACT_OPTION="-r"
echo -e "${GREEN}Se realizará una instalación completa con React automáticamente${NC}"

# Preguntar por URL del repositorio Git para React
GIT_OPTION=""
read -p "URL del repositorio Git para el tema React (dejar en blanco para omitir): " REACT_REPO
if [ -n "$REACT_REPO" ]; then
  GIT_OPTION="-g $REACT_REPO"
fi

# Preguntar por opciones avanzadas
read -p "¿Desea configurar opciones avanzadas (usuario, contraseña, etc.)? (s/n): " ADVANCED_OPTIONS
ADMIN_OPTIONS=""
if [[ "$ADVANCED_OPTIONS" =~ ^[Ss]$ ]]; then
  read -p "Nombre de usuario administrador (predeterminado: admin): " ADMIN_USER
  if [ -n "$ADMIN_USER" ]; then
    ADMIN_OPTIONS="$ADMIN_OPTIONS -u $ADMIN_USER"
  fi
  
  read -p "Contraseña de administrador (predeterminado: admin): " ADMIN_PASS
  if [ -n "$ADMIN_PASS" ]; then
    ADMIN_OPTIONS="$ADMIN_OPTIONS -p $ADMIN_PASS"
  fi
  
  read -p "Correo electrónico de administrador (predeterminado: admin@example.com): " ADMIN_EMAIL
  if [ -n "$ADMIN_EMAIL" ]; then
    ADMIN_OPTIONS="$ADMIN_OPTIONS -e $ADMIN_EMAIL"
  fi
  
  read -p "Nombre del sitio (predeterminado: My Drupal CMS React): " SITE_NAME
  if [ -n "$SITE_NAME" ]; then
    ADMIN_OPTIONS="$ADMIN_OPTIONS -n \"$SITE_NAME\""
  fi
fi

# Construir el comando completo
COMMAND="quick-drupal-react $FULL_OPTION $REACT_OPTION $GIT_OPTION $ADMIN_OPTIONS $PROJECT_NAME"

echo ""
echo -e "${YELLOW}Comando a ejecutar:${NC}"
echo -e "${GREEN}$COMMAND${NC}"
echo ""

# Confirmar ejecución
read -p "¿Desea continuar con la instalación? (s/n): " CONFIRM
if [[ "$CONFIRM" =~ ^[Ss]$ ]]; then
  # Ejecutar el comando
  eval "$COMMAND"
else
  echo -e "${RED}Instalación cancelada.${NC}"
  exit 0
fi
EOL

sudo mv "$TMP_FILE" "$INTERACTIVE_SCRIPT" && \
sudo chmod +x "$INTERACTIVE_SCRIPT" && \
echo -e "${GREEN}Script interactivo instalado como 'quick-drupal-react-interactive'${NC}"
