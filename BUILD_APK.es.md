# Compilar Chromium Extend en español y obtener el APK

Este fork incorpora `patches/0038-Add-Spanish-translations-for-Chromium-Extend.patch`. Al aplicar la serie completa, ese último parche añade traducciones para `es` y `es-419` de las opciones nuevas de gestor de descargas y de la descripción de acceso de barra.

> El repositorio contiene los parches, no un APK listo para descargar. Para que el APK incluya esta traducción hay que compilar Chromium desde la revisión base indicada en el proyecto.

## Requisitos

| Recurso | Mínimo recomendado |
| --- | --- |
| Equipo de construcción | Linux x86-64 con Docker; el proyecto usa un contenedor Ubuntu 22.04 x86-64 |
| Memoria asignada a Docker | 32 GB para una compilación completa |
| Espacio disponible | 100 GB o más |
| Dispositivo de prueba | Android arm64 y depuración USB, si se instalará por ADB |
| Tiempo | Una compilación completa puede tardar varias horas |

El proyecto guarda el código fuente y los artefactos de compilación dentro del volumen Docker `chromium-android-source`. La carpeta `exchange/` es el puente entre el contenedor y el host; usa esa carpeta para extraer el APK. Consulta también [BUILDING.md](BUILDING.md) y la [guía oficial de Chromium para Android](https://chromium.googlesource.com/chromium/src/+/main/docs/android_build_instructions.md).

## 1. Iniciar el entorno de construcción

En el host, clona este fork y crea el contenedor:

```bash
git clone https://github.com/NeoTurcios/chromium-extend.git
cd chromium-extend
./builder.sh build
./builder.sh start
./builder.sh shell
```

Los comandos restantes de esta guía se ejecutan **dentro** de la consola abierta por `./builder.sh shell`.

## 2. Descargar la revisión de Chromium correcta

El contenedor deja preparada la ruta de `depot_tools`, pero el primer uso requiere descargarla. El comando `fetch --nohooks --no-history android` obtiene un checkout Android de Chromium sin descargar todo el historial Git.

```bash
git clone https://chromium.googlesource.com/chromium/tools/depot_tools.git ~/depot_tools
export PATH="$HOME/depot_tools:$PATH"

mkdir -p /work/chromium
cd /work/chromium
fetch --nohooks --no-history android
cd src

git checkout 945b51156108ba94d62f235a75379772da8ced30
gclient sync
sudo build/install-build-deps.sh
gclient runhooks
```

La revisión anterior corresponde a Chromium `153.0.7999.0`, que es la base declarada por este proyecto. No sustituyas ese commit por `main`: los 38 parches están preparados para esta base concreta.

## 3. Aplicar la serie, incluida la traducción española

El directorio `/exchange` del contenedor corresponde a la carpeta `exchange/` del fork en tu host. Aplica los parches en orden numérico.

```bash
cd /work/chromium/src
git am /exchange/patches/*.patch
```

Al final del comando deben haberse aplicado los parches `0001` a `0038`. El número 0038 modifica solamente estos recursos de localización:

```text
chrome/browser/ui/android/strings/translations/android_chrome_strings_es.xtb
chrome/browser/ui/android/strings/translations/android_chrome_strings_es-419.xtb
```

## 4. Configurar GN y compilar

Crea un directorio de salida y define los argumentos de Android, Desktop Android y las opciones de privacidad del proyecto.

```bash
mkdir -p out/ChromiumExtend
cat > out/ChromiumExtend/args.gn <<'EOF'
target_os = "android"
target_cpu = "arm64"
is_component_build = false
is_debug = false

# Chromium Desktop Android
automatically_apply_desktop_user_agent = false
is_desktop_android = true
enable_extensions_core = true

# Códecs para reproducción multimedia
ffmpeg_branding = "Chrome"
proprietary_codecs = true

# Opciones de privacidad de Chromium Extend
use_mlkit_for_aicore = false
enable_glic_internal_resources = false
enable_reporting = false
enable_service_discovery = false
enable_mdns = false
EOF

gn gen out/ChromiumExtend
autoninja -C out/ChromiumExtend -j 12 chrome_public_apk
```

La construcción correcta deja el artefacto principal en:

```text
/work/chromium/src/out/ChromiumExtend/apks/ChromePublic.apk
```

Para copiarlo fuera del contenedor y encontrarlo inmediatamente en el host, usa:

```bash
cp out/ChromiumExtend/apks/ChromePublic.apk /exchange/ChromiumExtend-es-arm64.apk
sha256sum /exchange/ChromiumExtend-es-arm64.apk
```

El archivo estará disponible como `exchange/ChromiumExtend-es-arm64.apk` dentro de tu clon del fork. Conecta un teléfono arm64 con depuración USB para instalarlo, o copia el archivo al dispositivo mediante el método de transferencia que prefieras.

## Verificación de la traducción

Instala el APK, cambia el idioma del sistema Android a **Español (España)** o a una variante latinoamericana y abre **Ajustes → Descargas**. Deben verse en español el interruptor de gestor de descargas externo, sus dos textos de estado, el selector de aplicación, «Preguntar cada vez» y el estado sin aplicaciones compatibles. También se traduce la descripción sobre ocultarse cuando la ventana es ancha.

## Publicar el APK como una versión de GitHub

La publicación de binarios no se realiza automáticamente. Cuando hayas instalado y probado el APK, puedes crear una versión desde la interfaz de GitHub o usar la CLI en el host:

```bash
gh release create v1.4-es exchange/ChromiumExtend-es-arm64.apk \
  --title "Chromium Extend v1.4-es" \
  --notes "APK arm64 compilado desde el fork con traducciones para es y es-419."
```

Antes de distribuirlo, conserva el valor SHA-256 y declara la revisión de Chromium, la lista de parches y los argumentos GN utilizados. Así otras personas podrán repetir la construcción y verificar el binario.
