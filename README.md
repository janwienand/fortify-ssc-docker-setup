# Fortify Software Security Center (SSC) - Docker Setup

Docker-basiertes Setup für **Fortify SSC 25.4** – ideal für Evaluierung und Proof of Concept.

> **Hinweis:** Nicht für den Produktionsbetrieb gedacht. Für Produktionsumgebungen siehe die [offizielle Kubernetes-Deployment-Dokumentation](https://www.microfocus.com/documentation/fortify-software-security-center/2540/Deploying_SSC_in_Kubernetes_25.4.0.html).

## Voraussetzungen

| Software         | Version | Hinweis                                              |
|------------------|---------|------------------------------------------------------|
| Docker Desktop   | 24.0+   | [Download](https://docs.docker.com/get-docker/)      |
| Java (keytool)   | JDK 17+ | Für SSL-Zertifikatserstellung                        |
| Fortify-Lizenz   | 25.x    | Von OpenText erhalten                                |
| Docker Hub Login | –       | Zugang zu `fortifydocker` erforderlich (nicht öffentlich) |

## Schnellstart

```bash
git clone https://github.com/janwienand/fortify-ssc-docker-setup.git
cd fortify-ssc-docker-setup

# Lizenz bereitstellen
cp /pfad/zu/deiner/fortify.license ssc-webapp/secrets/fortify.license

# Setup ausführen
./setup.sh
```

## Manuelle Installation

### 1. Lizenz bereitstellen

```bash
cp /pfad/zu/deiner/fortify.license ssc-webapp/secrets/fortify.license
```

### 2. HTTP-Zertifikat erstellen

Keystore-Passwort generieren:

```bash
KEYSTORE_PW="$(openssl rand -base64 32)"
echo -n "$KEYSTORE_PW" > ssc-webapp/secrets/keystore_password
```

Keystore mit selbstsigniertem Zertifikat erstellen:

```bash
keytool -genkeypair -keyalg RSA -keysize 2048 \
  -storetype PKCS12 \
  -keystore ssc-webapp/secrets/ssc-keystore.pfx \
  -alias ssc-server \
  -validity 365 \
  -storepass "$KEYSTORE_PW" \
  -keypass "$KEYSTORE_PW" \
  -dname "CN=localhost, OU=Fortify, O=Demo, C=DE" \
  -ext "SAN=dns:localhost,ip:127.0.0.1"
```

### 3. SSC Autoconfig erstellen

```bash
cp ssc-webapp/secrets/ssc.autoconfig.example ssc-webapp/secrets/ssc.autoconfig
```

Passe bei Bedarf `host.url` in der Datei an (Standard: `https://localhost:8443`).

### 4. Umgebungsvariablen konfigurieren

```bash
cp .env.example .env
```

### 5. Berechtigungen setzen

Der SSC-Container läuft als User mit UID `1111`. Die Volumes müssen entsprechend beschreibbar sein:

```bash
mkdir -p ssc-webapp/data ssc-mysql/data
chown -R 1111 ssc-webapp/data ssc-webapp/secrets
```

> **Hinweis:** Unter macOS/Docker Desktop ist dieser Schritt in der Regel nicht erforderlich.

### 6. Docker Hub Login

```bash
docker login
```

### 7. Container starten

```bash
docker compose up -d
docker compose logs -f
```

Der erste Start kann 2–5 Minuten dauern. SSC ist bereit, wenn folgende Meldung erscheint:

```
Server startup in [xxx] milliseconds
```

### 8. SSC aufrufen

Öffne **https://localhost:8443** im Browser.

> Zertifikatswarnung ist bei selbstsignierten Zertifikaten normal – einfach fortfahren.

**Standard-Login:** `admin` / `admin` (muss beim ersten Login geändert werden)

### 9. Secret Key sichern

Nach dem ersten erfolgreichen Start generiert SSC einen Verschlüsselungs-Key.
Diesen für zukünftige Neustarts sichern:

```bash
docker cp ssc-webapp:/fortify/ssc/conf/secret.key ssc-webapp/secrets/secret.key
```

Anschließend in `.env` die folgende Zeile einkommentieren:

```
COM_FORTIFY_SSC_SECRETKEY=/app/secrets/secret.key
```

## Nützliche Befehle

| Befehl                            | Beschreibung                    |
|-----------------------------------|---------------------------------|
| `docker compose up -d`            | Container starten               |
| `docker compose down`             | Container stoppen und entfernen |
| `docker compose logs -f`          | Logs anzeigen                   |
| `docker compose ps`               | Status anzeigen                 |
| `docker compose restart`          | Neustarten                      |
| `docker exec -it ssc-webapp bash` | Shell im SSC-Container          |
| `docker exec -it ssc-mysql bash`  | Shell im MySQL-Container        |

## Dateistruktur

```
├── docker-compose.yml              # SSC + MySQL
├── .env.example                    # Umgebungsvariablen
├── setup.sh                        # Automatisches Setup
├── ssc-webapp/
│   ├── secrets/                    # Zertifikate, Lizenz, Konfiguration
│   │   └── ssc.autoconfig.example
│   └── data/                       # Persistente SSC-Daten
└── ssc-mysql/
    ├── config/
    │   └── config-file.cnf         # MySQL-Konfiguration
    └── data/                       # Persistente DB-Daten
```

## Systemanforderungen

| Komponente | Minimum  | Empfohlen |
|------------|----------|-----------|
| RAM        | 8 GB     | 16 GB     |
| CPU        | 4 Kerne  | 8 Kerne   |
| Festplatte | 10 GB    | 20 GB     |

## Fehlerbehebung

**SSC startet nicht:** Prüfe ob MySQL bereit ist – `docker compose logs ssc-mysql | tail -20`

**Image-Pull schlägt fehl:** `docker login` ausführen und sicherstellen, dass Zugang zu `fortifydocker` besteht.

**Alles zurücksetzen:**

```bash
docker compose down
rm -rf ssc-mysql/data ssc-webapp/data
```

## Weiterführende Dokumentation

- [SSC 25.4 Benutzerhandbuch](https://www.microfocus.com/documentation/fortify-software-security-center/2540/ssc-ugd-html-25.4.0/index.html)
- [SSC Kubernetes Deployment](https://www.microfocus.com/documentation/fortify-software-security-center/2540/Deploying_SSC_in_Kubernetes_25.4.0.html)

---

> **Disclaimer:** Community-basiertes Setup, nicht offiziell von OpenText unterstützt.
