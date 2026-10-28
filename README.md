# Quiler Play — primera versión Android

Aplicación Flutter con interfaz oscura para:
- Buscar videos usando la búsqueda oficial de YouTube (se abre YouTube/la app o el navegador).
- Pegar un enlace de video y reproducirlo con el reproductor oficial embebido de YouTube.
- Guardar favoritos e historial localmente.
- Abrir un video en la aplicación oficial de YouTube.

## Limitaciones importantes

- No requiere una clave de API de YouTube.
- La búsqueda ocurre en YouTube, fuera de la interfaz de Quiler Play. Para reproducir dentro de la app, copia el enlace del video y pégalo en Quiler Play.
- La reproducción usa el reproductor embebido oficial de YouTube. Puede mostrar anuncios y algunos videos pueden no permitir reproducción embebida.
- La aplicación no descarga videos ni elimina anuncios.
- Los títulos se muestran como “Video de YouTube” porque esta versión no consulta metadatos con la API oficial.

## Cómo generar el APK desde GitHub

1. Crea un repositorio público nuevo llamado `quiler-play`.
2. Sube el contenido de este ZIP (no el ZIP como un solo archivo). Deben quedar `pubspec.yaml`, la carpeta `lib` y `.github/workflows/build-apk.yml` en la raíz.
3. Abre la pestaña **Actions** del repositorio.
4. Selecciona **Build Quiler Play APK** y pulsa **Run workflow** (o espera a que termine el primer flujo tras subir los archivos).
5. Cuando el flujo termine en verde, abre la ejecución y descarga **quiler-play-apk** en la sección Artifacts.
6. Extrae el ZIP descargado y abre `app-release.apk` en tu Android para instalarlo. Puede que tengas que autorizar temporalmente la instalación desde esa fuente.

## Seguridad

No subas contraseñas, claves privadas ni tokens al repositorio.
