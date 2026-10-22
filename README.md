# Instalar Moodle 5.3 en Windows 11 — scripts de PowerShell

Scripts del vídeo **«Instalar Moodle 5.3 en Windows 11, pieza a pieza»** del canal de Acebido
(José Luis Díaz). Hacen, en orden, lo mismo que se ve en el vídeo: IIS, PHP 8.3,
MariaDB 11.4 y Moodle 5.3, **sin XAMPP**.

> Son para un **ordenador de pruebas o de prácticas**. Para un servidor en internet hacen
> falta además HTTPS, copias de seguridad y una configuración de seguridad más estricta.

## Antes de empezar

1. Windows 11 (o Windows 10/Server) de 64 bits y una cuenta de **administrador**.
2. Unos 10 GB libres en el disco.
3. Que nada ocupe los puertos **80** y **3306** (otro servidor web, XAMPP, otra base de datos…).
4. Descarga los ZIP de la tabla. **Da igual en qué carpeta acaben**: el primer script,
   `00_preparar.ps1`, los busca en Descargas, Escritorio, Documentos y junto a los propios
   scripts, y los deja todos juntos en `C:\instaladores`, que es donde los demás los buscan.
   No hace falta descomprimirlos.

| Fichero | De dónde |
|---|---|
| `vc_redist.x64.exe` | aka.ms/vs/17/release/vc_redist.x64.exe (el script 02 lo baja e instala solo) |
| `php-8.3.x-nts-Win32-vs16-x64.zip` | downloads.php.net/~windows/releases/archives/ → el más nuevo `php-8.3.*-nts-Win32-vs16-x64.zip` |
| `mariadb-11.4.x-winx64.zip` | mariadb.org/download → 11.4 (LTS) → Windows → **ZIP** |
| `moodle-latest-503.zip` | download.moodle.org/releases/latest → el **.zip** de la 5.3 |

Moodle 5.3 pide **PHP 8.3 o superior** y **MariaDB 11.4 o superior**: las versiones de la
tabla son el mínimo, no una preferencia. Con PHP 8.2 el instalador se para.

## Cómo se ejecutan

1. En esta página de GitHub, pulsa el botón verde **Code → Download ZIP** y descomprímelo.
   Da igual dónde: la orden del punto 3 busca la carpeta sola. Ten en cuenta que Windows suele
   dejar `instalar-moodle-windows-main` **dentro de otra carpeta con el mismo nombre**.
2. **Doble clic en `abrir-powershell-aqui.cmd`**, dentro de la carpeta de los scripts, y acepta
   el aviso de Windows: abre PowerShell como administrador ya colocado en la carpeta y con los
   scripts permitidos. Si lo haces así, sáltate el punto 3.

   A mano: abre **PowerShell como administrador** (botón derecho en Inicio → *Terminal (Administrador)*).
3. Ve a la carpeta y permite los scripts **solo en esa ventana**:

   ```powershell
   cd (gci $HOME -Rec -Filter 01_iis.ps1 -EA 0|select -First 1).DirectoryName
   Set-ExecutionPolicy Bypass -Scope Process -Force; gci *.ps1 | Unblock-File
   ```

   Pega **una línea, Intro, y luego la otra**. Si las copias juntas desde un PDF se pierde el
   salto de línea y PowerShell las junta en una orden sin sentido (`-ForceGet-ChildItem`).

4. Ejecútalos **en orden**, uno a uno, y lee el resultado de cada uno antes de seguir:

   | Script | Qué hace | Te pide |
   |---|---|---|
   | `.\00_preparar.ps1` | Recoge los ZIP y los deja en `C:\instaladores` | — |
   | `.\01_iis.ps1` | Activa IIS y CGI | — |
   | `.\02_php.ps1` | PHP 8.3 en `C:\php` con su `php.ini` | — |
   | `.\03_iis_php.ps1` | Une IIS y PHP (FastCGI) con tiempos ampliados | — |
   | `.\04_mariadb.ps1` | MariaDB 11.4, base de datos `moodle` y usuario `moodleuser` | contraseñas de root y de moodleuser |
   | `.\05_moodle.ps1` | Código en `C:\moodle`, `C:\moodledata` y el sitio de IIS | — |
   | `.\06_instalar_moodle.ps1` | Instala Moodle por consola *(o usa el instalador de http://localhost)* | contraseña de moodleuser, nombre del campus y datos del administrador |

5. Abre **http://localhost** y entra con el usuario `admin`.

Cada script termina con una **comprobación** en verde (bien) o en rojo (algo ha fallado,
con el motivo). Si uno falla, no pases al siguiente.

## Apunta las contraseñas

| Qué | Para qué |
|---|---|
| root de MariaDB | Crear bases de datos, copias y restauraciones |
| moodleuser | La usa Moodle (queda en `C:\moodle\config.php`) |
| admin de Moodle | Entrar en el campus |

## Las tres trampas que estos scripts ya resuelven

1. **IIS corta PHP a los 90 segundos.** La instalación de Moodle tarda más y se queda a
   medias sin ningún error. El script 03 sube los tiempos.
2. **MariaDB 11.4 no arranca sin certificado.** El script 04 pone `skip_ssl` en el `my.ini`
   que lee el servicio (el de `C:\mariadb\data`, no otro).
3. **Moodle 5 se publica desde la carpeta `public`.** El script 05 apunta el sitio a
   `C:\moodle\public`, no a `C:\moodle`.

---
Acebido · Formación · Tecnología · Futuro — José Luis Díaz.
Moodle es software libre (GPLv3) de Moodle HQ; las marcas citadas pertenecen a sus titulares.
