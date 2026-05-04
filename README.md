# NetworkWise

NetworkWise is a **Flutter desktop application** (Windows-first) backed by **Supabase**. It gives a small IT team or CA firm a **single place to see enrolled Windows PCs**: who is online, recent heartbeats, network adapters, security posture, and alerts—with **Row Level Security (RLS)** so each organisation only ever sees its own fleet.

The same codebase supports two **roles**, chosen at build/runtime via environment:

| Role | Typical install | What it does |
|------|-----------------|--------------|
| **`endpoint`** | Agent on each monitored Windows machine | Enrols with an **enrollment code**, keeps a stable device identity, and **pushes** heartbeats, network/security snapshots, and optional alerts to Supabase via **Edge Functions**. |
| **`admin`** | Operator dashboard on a trusted machine | **Signs in** with Supabase Auth, reads the whole tenant fleet over PostgREST (scoped by org), and can acknowledge alerts, rotate enrollment codes, invite admins, and manage device labels / archive state. |

---

## Why it exists

- **Tenant isolation**: Data is partitioned by organisation; clients send an org context header on reads; writes go through **Edge Functions** that validate **registration secrets** and business rules.
- **Resilient endpoints**: A **sync queue** buffers writes when offline and replays them after registration or when connectivity returns.
- **Observable fleet**: Dashboard areas cover **devices**, **alerts**, **security**, **reports**, and **settings** (theme, heartbeat cadence, enrollment, admins, shortcuts, etc.—see the app’s navigation).

---

## Tech stack

- **Client**: [Flutter](https://flutter.dev/) 3.x, [Riverpod](https://riverpod.dev/) for state, [supabase_flutter](https://pub.dev/packages/supabase_flutter) for Auth, PostgREST, Realtime, and Functions.
- **Config**: [flutter_dotenv](https://pub.dev/packages/flutter_dotenv) — `.env` is a **bundled asset** locally; only `.env.example` is tracked in git.
- **Secrets on device**: [flutter_secure_storage](https://pub.dev/packages/flutter_secure_storage) (Windows Credential Manager / DPAPI) for registration material; [shared_preferences](https://pub.dev/packages/shared_preferences) for queue and prefs.
- **Backend**: Supabase **Postgres** (RLS), **Edge Functions** (Deno), optional **Realtime** subscriptions for live UI.

---

## Repository layout

```
lib/                    # Flutter UI + domain logic
  core/                 # Env, auth, bootstrap, repositories, services, sync
  features/             # Screens (devices, alerts, security, settings, …)
  shared/               # Shared widgets
supabase/               # SQL migrations (run in order) + Edge Functions
  README.md             # Authoritative backend setup, deploy, and test checklist
  functions/            # register-device, report-*, update-alert-status, …
```

For **database migration order**, Edge Function deploy commands, secrets (`ALLOWED_ORG_SLUGS`, service role), and integration testing, use **[`supabase/README.md`](supabase/README.md)**.

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (this repo targets Dart **^3.5.2**).
- A Supabase project with schema and functions deployed (see `supabase/README.md`).
- For Windows endpoint builds: a machine where **Windows Security Center** style probes are meaningful (the admin role skips local security probing by design).

---

## Quick start (Flutter)

1. **Clone** the repository.

2. **Create `.env`** in the project root (next to `pubspec.yaml`):

   ```bash
   cp .env.example .env
   ```

   Fill in at least:

   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`

   Set **`APP_ROLE`** to `endpoint` or `admin` depending on the build you are running. Other keys are documented in `.env.example` and in [`supabase/README.md`](supabase/README.md).

3. **Install dependencies**:

   ```bash
   flutter pub get
   ```

4. **Run** (example: Windows):

   ```bash
   flutter run -d windows
   ```

   On first launch in **Supabase mode**, the app runs **device bootstrap** (enrollment + registration) and then starts the **heartbeat** loop; the splash / bootstrap gate surfaces progress and errors.

---

## Security notes

- **Never commit** `.env` — it is listed in `.gitignore`. The app expects it as a **local** asset for development builds.
- **Never put the service role key** in the Flutter app. It belongs in **Supabase Edge Function secrets** or server-side automation only.
- The Supabase CLI may create a local cache under `supabase/.temp/`; that directory is **ignored** by git.

---

## Contributing / deployment

- **Database & functions**: Follow the numbered SQL files and deploy steps in [`supabase/README.md`](supabase/README.md).
- **App releases**: Use your normal Flutter build pipeline (`flutter build windows`, etc.) with the correct `.env` for each role and environment.

---

## License

This project is configured as a **private** application (`publish_to: 'none'` in `pubspec.yaml`). Add a `LICENSE` file if you intend to open-source or redistribute.
