# Ban AbuseIPDB IPs ️

Este script Bash descarga direcciones IP reportadas como maliciosas desde [AbuseIPDB](https://www.abuseipdb.com/) y las bloquea utilizando `ip route add blackhole`. Además, gestiona los bloqueos, añadiendo solo IPs nuevas y eliminando las antiguas (más de 30 días) para mantener tu red segura y limpia.

## ✨ Características ✨

* Descarga IPs maliciosas de AbuseIPDB.
* Bloquea IPs IPv4 e IPv6.
* Gestiona los bloqueos, añadiendo solo IPs nuevas y eliminando las antiguas.
* Registra todas las acciones en un archivo de registro (`/var/log/ban_abuseipdb.log`).
* ⏰ ¡Fácil de programar con `cron`!

## ️ Requisitos ️

* `curl`
* `jq`
* `iproute2`
* Clave API de AbuseIPDB (obténla [aquí](https://www.abuseipdb.com/api.html))

##  Instalación y Uso 

1.  Clona o descarga el script `ban_abuseipdb.sh`.
2.  Mueve el archivo a /usr/local/bin/
    ```bash
    sudo mv ban_abuseipdb.sh /usr/local/bin/
    ```
 
2.  Dale permisos de ejecución y crea el log:

    ```bash
    sudo chmod +x /usr/local/bin/ban_abuseipdb.sh
    sudo touch /var/log/ban_abuseipdb.log
    sudo chmod 666 /var/log/ban_abuseipdb.log
    ```

3.  Edita el script y reemplaza `"your_abuseipdb_api_key"` con tu clave API real.

    ```bash
    sudo nano /usr/local/bin/ban_abuseipdb.sh
    ```

4.  Ejecuta el script:

    ```bash
    sudo /usr/local/bin/ban_abuseipdb.sh
    ```

## ⏰ Programación con `cron` (¡Recomendado!) ⏰

La mejor opción es programar el script con `cron` para que se ejecute automáticamente, por ejemplo, una vez al día a las 3 AM:

    0 3 * * * /ruta/del/script.sh

Para editar tu crontab, usa:

    crontab -e o sudo nano /etc/crontab

Monitoreo en Tiempo Real
Para ver el registro en tiempo real:

```tail -f /var/log/ban_abuseipdb.log```

Nota: El script usa "Added IPv4 blackhole for ..." en lugar de "Bloqueado ...". Por lo tanto, para contar las IPs bloqueadas, usa:

```grep "Added IPv4 blackhole for" /var/log/ban_abuseipdb.log | wc -l```

️‍♂️ Ver IPs Bloqueadas ️‍♂️
IPv4: 🟢

```bash
ip route show | grep blackhole
```
IPv6: 
```bash
ip -6 route show | grep blackhole
```


**IPv4 + IPv6 en un solo comando:** 🟣

```bash
(ip route show | grep blackhole; ip -6 route show | grep blackhole)
```

Contar IPs Bloqueadas
IPv4: 1️⃣

```
ip route show | grep blackhole | wc -l
```

IPv6: 2️⃣

```
ip -6 route show | grep blackhole | wc -l
```

Todas las IPs (IPv4 + IPv6): 3️⃣

```
(ip route show | grep blackhole; ip -6 route show | grep blackhole) | wc 
```

⚠️ Consideraciones Importantes ⚠️

Este script requiere privilegios de root.
Bloquear direcciones IP puede afectar la conectividad. ¡Úsalo con precaución!
Prueba el script en un entorno de pruebas antes de usarlo en producción.
Ten en cuenta las limitaciones de la API de AbuseIPDB.
¡Guarda tu clave API de forma segura!



**Thanks to [AbuseIPDB](https://www.abuseipdb.com/) por el increíble servicio!**

**Thanks to [xRuffKez](https://github.com/xRuffKez/) por la idea y la base del script!**


<a href="https://www.abuseipdb.com/user/193901" title="AbuseIPDB is an IP address blacklist for webmasters and sysadmins to report IP addresses engaging in abusive behavior on their networks">
	<img src="https://www.abuseipdb.com/contributor/193901.svg" alt="AbuseIPDB Contributor Badge" style="width: 401px;">
</a>

---

## 📄 Licencia

**CC BY-NC-SA 4.0** — Compartir con atribución, sin uso comercial. Consulta [LICENSE](LICENSE) para más detalles.

---

<div align="center">

**Desarrollado por [Hugo Perez-Vigo](https://hugopvigo.es)** · [@hugopvigo](https://x.com/hugopvigo)

[![GitHub](https://img.shields.io/badge/GitHub-Hugopvigo-181717?style=for-the-badge&logo=github)](https://github.com/Hugopvigo)

</div>
