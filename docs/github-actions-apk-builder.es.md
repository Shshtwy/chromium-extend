# Compilación del APK mediante GitHub Actions

El flujo [`Compilar APK arm64 en español`](../.github/workflows/build-apk-self-hosted.yml) construye Chromium Extend con el parche `0038` de localización española y publica el resultado como artefacto del flujo.

> Este flujo está diseñado para un **runner propio**. No se ejecuta en cada `push` ni en solicitudes de cambios; solo se inicia de forma manual desde la pestaña **Actions**.

## Por qué se requiere un runner propio

Los runners Linux estándar alojados por GitHub proporcionan 16 GB de RAM y 14 GB de almacenamiento SSD en repositorios públicos. La construcción de este proyecto necesita alrededor de 32 GB de memoria y, como mínimo, 100 GB para el checkout y los productos de Chromium. Además, los trabajos alojados por GitHub se cancelan tras seis horas, mientras una construcción limpia de Chromium puede superar ese tiempo. Por tanto, ejecutar este proyecto en `ubuntu-latest` no es viable. [1] [2]

| Recurso | Runner propio etiquetado `chromium-builder` |
| --- | --- |
| Sistema | Linux x86-64 |
| Docker | Instalado y disponible para el usuario del runner |
| Espacio libre en el directorio de Docker | 100 GB o más |
| Memoria RAM | 32 GB o más |
| Etiquetas de Actions | `self-hosted`, `linux`, `x64`, `chromium-builder` |
| Tiempo máximo configurado | 24 horas |

GitHub permite asignar runners propios a un único repositorio y elegir el sistema, hardware y herramientas. El mantenimiento del sistema, sus actualizaciones y su capacidad es responsabilidad de quien opera el runner. [3]

## Preparación única del runner

En una máquina que cumpla los requisitos, abre el repositorio en GitHub y ve a **Settings → Actions → Runners → New self-hosted runner**. Selecciona Linux x64 y ejecuta los comandos de descarga y registro que GitHub muestra para este repositorio. Añade la etiqueta personalizada `chromium-builder` durante el registro, o después desde la configuración del runner.

El servicio del runner debe permanecer en línea durante la construcción. El workflow crea un contenedor Ubuntu 22.04, descarga Chromium en un volumen Docker persistente, aplica los 38 parches, compila `chrome_public_apk` y apaga el contenedor al finalizar.

## Ejecución y descarga

Una vez que el runner figure como **Idle** en GitHub, sigue estos pasos:

1. Abre la pestaña **Actions** del fork.
2. Selecciona **Compilar APK arm64 en español**.
3. Pulsa **Run workflow** y deja `clean_build` desactivado para permitir reutilizar la salida incremental; actívalo si se necesita una reconstrucción limpia.
4. Espera a que termine el trabajo.
5. Descarga el artefacto **ChromiumExtend-es-arm64** desde la página del run.

El artefacto contiene el archivo `ChromiumExtend-es-arm64.apk`, su suma SHA-256 y los commits de Chromium y del fork utilizados durante la construcción. La retención configurada es de 14 días.

## Referencias

[1]: https://docs.github.com/en/actions/reference/runners/github-hosted-runners "GitHub-hosted runners reference"
[2]: https://docs.github.com/en/actions/reference/limits "GitHub Actions limits"
[3]: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners "Self-hosted runners"
