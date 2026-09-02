# IPO Allotment Backend V1

Current scope: FastAPI + KFin only + Playwright/Chromium. Stateless; no DB and no PAN persistence.

## Setup

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
playwright install chromium
```

## Run

```powershell
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

Swagger: `http://127.0.0.1:8000/docs`

## Request

`POST /v1/allotment/check`

```json
{
  "ipoId": "optional-upstox-id",
  "ipoName": "CALIBER MINING AND LOGISTICS LIMITED IPO",
  "registrar": "KFIN",
  "pan": "ABCDE1234F"
}
```

Possible statuses: `ALLOTTED`, `NOT_ALLOTTED`, `NOT_LIVE`, `HUMAN_REQUIRED`, `TEMPORARY_ERROR`, `UNKNOWN`, `UNSUPPORTED_REGISTRAR`.

## Real Android phone

Run FastAPI on `0.0.0.0`, find PC IPv4 using `ipconfig`, and call e.g. `http://192.168.1.20:8000/v1/allotment/check` while phone and PC are on the same network.

For local HTTP Android testing you may need cleartext traffic enabled. Production should use HTTPS.

## Visible Chromium for debugging

```powershell
$env:KFIN_HEADLESS="false"
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The result parser is intentionally conservative. If KFin changes wording, it returns `UNKNOWN` instead of guessing.
