# Fortify Software Security Center (SSC) - Docker Setup

Dieses Repository ermöglicht eine schnelle Installation des **Fortify Software Security Center (SSC) 25.4** mit Docker.
Ideal für Evaluierung, Demos und Proof-of-Concept-Umgebungen.

> **Hinweis:** Dieses Setup ist für Test- und Evaluierungszwecke gedacht, nicht für den Produktionsbetrieb.

## Architektur

```
                    +-------------------+
                    |    Browser        |
                    |  (HTTPS :8443)    |
                    +--------+----------+
                             |
                    +--------v----------+
                    |   SSC Webapp      |
                    |   (Tomcat/8443)   |
                    +--------+----------+
                             |
                    +--------v----------+
                    |   MySQL 8.0       |
                    |   (Port 3306)     |
                    +-------------------+
```

## Voraussetzungen

| Software         | Version       | Hinweis                                  |
|------------------|---------------|------------------------------------------|
| Docker Desktop   | 24.0+         | [Download](https://docs.docker.com/get-docker/) |
| Docker Compose   | v2            | In Docker Desktop enthalten              |
| Java (keytool)   | JDK 17+       | Nur für SSL-Zertifikatserstellung        |
| Fortify-Lizenz   | 25.x          | Von OpenText erhalten                    |
| Docker Hub Login | -             | Zugang zu `fortifydocker` erforderlich (nicht öffentlich) |

> **Hinweis:** Das SSC Docker Image (`fortifydocker/ssc-webapp`) ist nicht öffentlich verfügbar.
> Du benötigst einen Docker Hub Account mit Zugang zum `fortifydocker`-Repository.
> Stelle sicher, dass du vor der Installation `docker login` ausführst.

## Schnellstart (Automatisch)

```bash
# 1. Repository klonen
git clone https://github.com/janwienand/fortify-ssc-docker-setup.git
cd fortify-ssc-docker-setup

# 2. Fortify-Lizenz bereitstellen
cp /pfad/zu/deiner/fortify.license ssc-webapp/secrets/fortify.license

# 3. Setup ausführen
./setup.sh
```

Das Setup-Script:
- Prüft alle Voraussetzungen (Docker, Compose, keytool)
- Erstellt die `.env` Konfiguration
- Generiert ein selbstsigniertes SSL-Zertifikat
- Erstellt die Datenbank-Konfiguration
- Startet alle Container

## Manuelle Installation (Schritt für Schritt)

### 1. Repository klonen

```bash
git clone https://github.com/janwienand/fortify-ssc-docker-setup.git
cd fortify-ssc-docker-setup
```

### 2. Umgebungsvariablen konfigurieren

```bash
cp .env.example .env
```

Passe bei Bedarf die Werte in `.env` an (Ports, Passwörter etc.).

### 3. Fortify-Lizenz bereitstellen

Kopiere deine Fortify-Lizenzdatei:

```bash
cp /pfad/zu/deiner/fortify.license ssc-webapp/secrets/fortify.license
```

### 4. SSL-Zertifikat erstellen

Generiere ein selbstsigniertes Zertifikat für den SSC-Webserver:

```bash
# Passwort generieren
openssl rand -base64 16 > ssc-webapp/secrets/keystore_password

# Keystore erstellen
keytool -genkeypair \
  -alias ssc \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365 \
  -storetype PKCS12 \
  -keystore ssc-webapp/secrets/ssc-keystore.pfx \
  -storepass "$(cat ssc-webapp/secrets/keystore_password)" \
  -keypass "$(cat ssc-webapp/secrets/keystore_password)" \
  -dname "CN=localhost, OU=Fortify, O=Demo, L=Berlin, ST=Berlin, C=DE" \
  -ext "SAN=dns:localhost,ip:127.0.0.1"
```

### 5. SSC Autoconfig erstellen

```bash
cp ssc-webapp/secrets/ssc.autoconfig.example ssc-webapp/secrets/ssc.autoconfig
```

Passe bei Bedarf die `host.url` in `ssc.autoconfig` an (Standard: `https://localhost:8443`).

### 6. Bei Docker Hub anmelden

```bash
docker login
```

### 7. Container starten

```bash
docker compose up -d
```

### 8. Installation prüfen

```bash
# Logs verfolgen
docker compose logs -f

# Warten bis SSC bereit ist (kann 2-5 Minuten dauern)
# Erfolgsmeldung: "Server startup in [xxx] milliseconds"
```

### 9. SSC aufrufen

Öffne im Browser: **https://localhost:8443**

> Der Browser zeigt eine Zertifikatswarnung, da ein selbstsigniertes Zertifikat verwendet wird.
> Das ist für eine Testumgebung normal – einfach fortfahren.

**Standard-Login:** `admin` / `admin` (muss beim ersten Login geändert werden)

## Nützliche Befehle

| Befehl                          | Beschreibung                    |
|---------------------------------|---------------------------------|
| `docker compose up -d`          | Container starten               |
| `docker compose down`           | Container stoppen und entfernen |
| `docker compose logs -f`        | Logs anzeigen                   |
| `docker compose ps`             | Status der Container anzeigen   |
| `docker compose restart`        | Container neustarten            |
| `docker exec -it ssc-webapp bash` | Shell im SSC Container        |
| `docker exec -it ssc-mysql bash`  | Shell im MySQL Container      |

## Dateistruktur

```
fortify-ssc-docker-setup/
├── docker-compose.yml              # Container-Konfiguration (SSC + MySQL)
├── .env.example                    # Umgebungsvariablen-Vorlage
├── setup.sh                        # Automatisches Setup-Script
├── ssc-webapp/
│   ├── secrets/                    # Zertifikate, Lizenzen, Konfiguration
│   │   ├── ssc.autoconfig.example  # Datenbank-Konfigurationsvorlage
│   │   ├── fortify.license         # (von dir bereitgestellt)
│   │   ├── ssc-keystore.pfx        # (wird generiert)
│   │   └── keystore_password       # (wird generiert)
│   └── data/                       # SSC-Anwendungsdaten (persistent)
└── ssc-mysql/
    ├── config/
    │   └── config-file.cnf         # MySQL-Konfiguration
    └── data/                       # MySQL-Datenbankdaten (persistent)
```

## Systemanforderungen

| Komponente | Minimum       | Empfohlen     |
|------------|---------------|---------------|
| RAM        | 8 GB          | 16 GB         |
| CPU        | 4 Kerne       | 8 Kerne       |
| Festplatte | 10 GB frei    | 20 GB frei    |

## Fehlerbehebung

### SSC startet nicht / bleibt hängen

```bash
# Prüfe ob MySQL bereit ist
docker compose logs ssc-mysql | tail -20

# Prüfe SSC Logs
docker compose logs ssc-webapp | tail -50
```

### "Access Denied" beim Image-Pull

Stelle sicher, dass du bei Docker Hub angemeldet bist (`docker login`) und Zugang zum `fortifydocker`-Repository hast.

### Datenbank-Verbindungsfehler

Prüfe ob der MySQL-Container läuft und gesund ist:

```bash
docker compose ps
```

Falls MySQL nicht startet, lösche das Datenverzeichnis und starte neu:

```bash
docker compose down
rm -rf ssc-mysql/data
docker compose up -d
```

### Alles zurücksetzen

```bash
docker compose down
rm -rf ssc-mysql/data ssc-webapp/data
# Anschließend: ./setup.sh oder manuell neu starten
```

## Weiterführende Dokumentation

- [SSC 25.4 Benutzerhandbuch](https://www.microfocus.com/documentation/fortify-software-security-center/2540/ssc-ugd-html-25.4.0/index.html)
- [SSC Kubernetes Deployment Guide](https://www.microfocus.com/documentation/fortify-software-security-center/2540/Deploying_SSC_in_Kubernetes_25.4.0.html)

---

> **Disclaimer:** Dieses Setup wird auf Community-Basis bereitgestellt und ist nicht offiziell von OpenText unterstützt.
> Für produktive Umgebungen empfehlen wir die offizielle Kubernetes-basierte Deployment-Methode.
