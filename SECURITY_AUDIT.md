# Security Audit Report – Hubstinger

Datum: 2026-04-26 (UTC)

## Scope

- Backend (FastAPI): `backend/*.py`, `backend/plugins/*.py`, `backend/templates/admin.html`
- Mobile App (Flutter): `lib/**/*.dart`
- Dependency-Metadaten: `backend/requirements.txt`, `pubspec.yaml`

## Methodik

1. Manuelle Code-Review für typische API/Auth/OIDC/Token-Risiken.
2. Pattern-basierte Suche für unsichere Konstrukte (Secrets, Token-Handling, Signature-Bypass, etc.).
3. Grundlegender Python-Syntax-Check des Backends.

## Executive Summary

- **Kritisch behoben:** OIDC-Authentifizierung hat vorher unvalidierte ID-Token-Claims akzeptiert (`verify_signature=False`).
- **Mittel behoben:** JWT-Weitergabe an die App erfolgte als URL-Query (`?token=...`), jetzt als URL-Fragment (`#token=...`).
- **Hoch (offen):** Kein CSRF-Schutz auf mehreren state-changing Endpoints, wenn Browser-Clients mit Bearer Tokens genutzt werden.
- **Mittel (offen):** Fehlende harte Security Header (`Content-Security-Policy`, `Strict-Transport-Security`).
- **Niedrig (offen):** Einige Dependencies sind fest gepinnt, aber ohne automatisierten Vulnerability-Scan dokumentiert.

## Findings

## 1) Kritisch – OIDC Claims ohne Signaturprüfung (BEHOBEN)

**Vorher:** In `backend/main.py` wurden ID-Token-Claims per `jwt.decode(..., options={"verify_signature": False})` gelesen.

**Risiko:** Ein manipuliertes Token konnte ggf. unzuverlässige Identitätsdaten liefern (je nach Angriffsoberfläche/Transport).

**Fix:** Umgestellt auf `userinfo`-Abruf über Access Token gegen Authentik (`/application/o/userinfo/`) und Validierung des HTTP-Responses.

## 2) Mittel – JWT in URL Query bei Deep-Link Redirect (BEHOBEN)

**Vorher:** Redirect auf `hubstinger://auth?token=<jwt>`.

**Risiko:** Query-Parameter können leichter in Logs/History/Referrer-Ketten landen.

**Fix:** Redirect verwendet jetzt URL-Fragment `hubstinger://auth#token=<jwt>`. Die Flutter-App akzeptiert nun Query **und** Fragment.

## 3) Hoch – Fehlender CSRF-Schutz auf mutierenden Endpoints (OFFEN)

**Beobachtung:** Mehrere `POST/PUT`-Endpoints verlassen sich ausschließlich auf Bearer-Token.

**Risiko:** Bei Browser-Szenarien mit kompromittierter Token-Exfiltration kann Missbrauch schneller eskalieren.

**Empfehlung:** Optionalen CSRF-Schutz für Web-Admin-Flows ergänzen (Double Submit Cookie / Origin-Checks), Token-Lebensdauer reduzieren, Refresh-Token-Rotation überlegen.

## 4) Mittel – Security Header unvollständig (OFFEN)

**Beobachtung:** Gute Baseline vorhanden (`X-Frame-Options`, etc.), aber keine strikte CSP/HSTS.

**Empfehlung:**
- `Strict-Transport-Security` bei HTTPS-Termination aktivieren.
- `Content-Security-Policy` für Admin-UI definieren (inkl. nonce/hash für Inline-Scripts).

## 5) Niedrig – Dependency Security Prozess (OFFEN)

**Beobachtung:** Pinnings sind vorhanden (`backend/requirements.txt`), aber keine dokumentierte regelmäßige CVE-Prüfung.

**Empfehlung:** CI-Job mit `pip-audit` (Python) und `flutter pub outdated` / `dart pub` Security-Review etablieren.

## Quick Wins (Priorisiert)

1. **Sofort:** OIDC-Härtung und token transport fix (bereits umgesetzt).
2. **Kurzfristig:** CSP/HSTS-Konfiguration für produktive Deployments.
3. **Kurzfristig:** Automatisierter Dependency-Audit in CI.
4. **Mittelfristig:** CSRF/Origin-Härtung für Admin-Webflows.

## Durchgeführte Änderungen in diesem Audit

- OIDC Callback auf verifizierbares `userinfo`-Pattern umgestellt.
- Deep-Link Token von Query auf Fragment umgestellt.
- Flutter Deep-Link Parser kompatibel erweitert.
- Fehlenden `BaseModel` Import ergänzt (Stabilitätsfix).

