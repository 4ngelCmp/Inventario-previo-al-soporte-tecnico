# Inventario-previo-al-soporte-tecnico
Este script de PowerShell permite realizar un inventario completo del equipo, respetando los mecanismos de seguridad de Windows (UAC) y utilizando LAPS para el acceso administrativo. El objetivo es disponer de un informe trazable y auditable antes de realizar cualquier cambio en el sistema.

🎯 Objetivos del script

Obtener un inventario técnico previo al soporte.
Documentar:

Sistema
Red
Unidades de red
Impresoras
Usuarios y datos

Obtener la credencial LAPS del equipo.
Facilitar el acceso al administrador local de forma segura.
Ejecutar tareas avanzadas solo cuando se dispone de permisos de administrador.
Generar un archivo TXT único y claro con toda la información.


🧠 Concepto clave del funcionamiento
El script es uno solo, pero tiene dos modos de ejecución según el usuario que lo ejecute:

ModoUsuario
Qué hace
Modo usuario
Usuario estándar / dominio

Ejecuta FASE 1 y FASE 2
Modo administrador
Admin local (LAPS)

Ejecuta FASE 3
👉 La FASE 3 nunca se fuerza.
Solo se ejecuta cuando el script se lanza ya con permisos de administrador.

🧩 Estructura del script
🔹 FASE 1 – Recolección sin permisos de administrador (SIEMPRE)
Se ejecuta en cualquier caso y no requiere privilegios elevados.
Incluye:

Sistema

Nombre del equipo
Dominio o Workgroup
Sistema operativo
Versión
Uptime


Red

Todos los adaptadores
IP, gateway, DNS, MAC


Unidades de red

Detectadas mediante net use (GPO compatibles)


Impresoras

Impresora predeterminada
Listado completo


Usuarios locales

Perfiles detectados
Estado ACTIVO / INACTIVO


Datos del usuario actual

Escritorio
Documentos
Descargas
Número de archivos y tamaño




🔹 FASE 2 – LAPS (solo en modo usuario)

Obtiene la contraseña del administrador local desde Active Directory usando LAPS.
Muestra:

Cuenta administradora local
Contraseña
Fecha de expiración



📌 Requisitos:

Conectividad con el dominio (VPN activa si es necesario).
El usuario debe tener permisos para leer LAPS en AD.

🔐 Nota de seguridad:
El admin local no tiene permisos para leer LAPS. Por eso esta fase no se ejecuta en modo administrador.

🔹 Cambio de contexto (usuario → administrador)
Cuando el script se ejecuta como usuario:

Se muestra la información LAPS.
Se abre automáticamente una nueva PowerShell iniciada como:
EQUIPO\AdministradorLocal (LAPS)


No se usa UAC.
No se fuerza elevación.
Se respeta la seguridad de Windows.

👉 Desde esa nueva consola se vuelve a ejecutar el script.

🔹 FASE 3 – Recolección con permisos de administrador
Solo se ejecuta cuando el script ya se ejecuta como admin local.
Incluye:

Creación de punto de restauración
Estado de discos

Espacio libre
Diagnóstico preventivo


(Ampliable a más tareas administrativas si se desea)


📄 Archivo de salida
El script genera un archivo:
Inventario_PreSoporte_NOMBREDELEQUIPO.txt

📍 Ubicación:

Escritorio del usuario que ejecuta el script.
Si se ejecuta como admin local, se genera en el escritorio del administrador.

📌 Es normal que existan dos informes distintos (usuario / admin).

▶️ Uso recomendado (paso a paso)
1️⃣ Ejecutar como usuario
PowerShell.\Inventario_PreSoporte.psMostrar más líneas

Se genera el inventario básico.
Se obtiene LAPS.
Se abre una PowerShell como admin local.


2️⃣ Ejecutar como administrador local (Artemisa)
En la nueva PowerShell abierta automáticamente:
PowerShell.\Inventario_PreSoporte.ps1``Mostrar más líneas

Se ejecuta la FASE 3.
Se completa el inventario avanzado.


⚠️ Consideraciones importantes

LAPS requiere conectividad con el dominio.
Sin VPN, la FASE 2 no podrá obtener la contraseña.
El script no intenta romper UAC.
No se automatiza la elevación por motivos de seguridad (diseño de Windows).


✅ Buenas prácticas

Ejecutar siempre el script antes de intervenir el equipo.
Conservar el TXT como evidencia del estado previo.
No modificar el sistema sin haber generado el informe.
Usar LAPS solo desde cuentas autorizadas.


🧩 Estado del script
✔ Diseño finalizado
✔ Compatible con entornos corporativos
✔ Seguro y auditable
✔ Preparado para ampliaciones futuras
