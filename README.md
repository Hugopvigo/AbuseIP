# Ban AbuseIPDB IPs

Descarga IPs reportadas como maliciosas desde [AbuseIPDB](https://www.abuseipdb.com/) y las bloquea usando `ipset` + `iptables`. La lista se reemplaza completamente en cada ejecución mediante swap atómico, sin ventanas de desprotección.

> **Por qué ipset y no `ip route blackhole`:** El método de rutas blackhole acumula decenas de miles de entradas en la tabla de routing del kernel. Esto provoca que `systemd-networkd` falle al arrancar (timeout enumerando rutas), generando un crash loop que satura la CPU. `ipset` almacena las IPs en estructuras hash del kernel, totalmente ajenas a la tabla de rutas.

## Características

- Descarga la blacklist de AbuseIPDB con umbral de confianza configurable.
- Bloquea IPv4 e IPv6 (configurable).
- Swap atómico: el set activo nunca queda vacío durante la actualización.
- Las reglas `iptables` se crean automáticamente si no existen (idempotente).
- Guarda `/etc/ipset.conf` para restaurar los sets tras un reinicio.
- Log en `/var/log/ban_abuseipdb.log`.

## Requisitos

- `curl`
- `jq`
- `ipset`
- `iptables` / `ip6tables`
- Clave API de AbuseIPDB ([obtenerla aquí](https://www.abuseipdb.com/api.html))

```bash
sudo apt install curl jq ipset iptables
```

## Instalación

```bash
sudo cp ban_abuseipdb.sh /usr/local/bin/
sudo chmod +x /usr/local/bin/ban_abuseipdb.sh
```

Edita el script y reemplaza `your_abuseipdb_api_key` con tu clave API real:

```bash
sudo nano /usr/local/bin/ban_abuseipdb.sh
```

> **Seguridad:** nunca subas el script con la API key real al repositorio. El repo contiene el placeholder `your_abuseipdb_api_key`; la key real vive solo en el servidor. Una alternativa más segura es leerla desde una variable de entorno o un fichero externo:
>
> ```bash
> # En el servidor, crear /etc/abuseipdb.conf (root:root, 600)
> echo 'ABUSEIPDB_API_KEY=tu_clave_real' | sudo tee /etc/abuseipdb.conf
> sudo chmod 600 /etc/abuseipdb.conf
> ```
>
> Y en el script cambiar `API_KEY="your_abuseipdb_api_key"` por:
>
> ```bash
> source /etc/abuseipdb.conf
> API_KEY="$ABUSEIPDB_API_KEY"
> ```

Primera ejecución:

```bash
sudo /usr/local/bin/ban_abuseipdb.sh
```

## Programación con cron

```bash
crontab -e
```

Añade estas dos líneas:

```
# Actualizar lista diariamente a las 5 AM
0 5 * * * /usr/local/bin/ban_abuseipdb.sh

# Restaurar ipsets tras reinicio (los sets se pierden al apagar)
@reboot sleep 30 && sudo ipset restore < /etc/ipset.conf 2>/dev/null || true
```

## Verificar estado

**IPs bloqueadas actualmente:**
```bash
sudo ipset list abuseipdb | grep "Number of entries"
sudo ipset list abuseipdb6 | grep "Number of entries"
```

**Ver IPs en el set:**
```bash
sudo ipset list abuseipdb | head -20
```

**Reglas iptables activas:**
```bash
sudo iptables -L INPUT | grep abuseipdb
sudo iptables -L FORWARD | grep abuseipdb
```

**Log en tiempo real:**
```bash
tail -f /var/log/ban_abuseipdb.log
```

## Consideraciones

- Requiere privilegios de root.
- La blacklist de AbuseIPDB tiene límite de descargas según el plan (normalmente 1/día en free).
- Las reglas `iptables` bloquean tanto `INPUT` como `FORWARD` (útil si el servidor actúa como router/gateway).
- Los sets `ipset` se pierden al reiniciar; el `@reboot` del cron los restaura desde `/etc/ipset.conf`.

---

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
