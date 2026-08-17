# Unterrichtsbeobachtung – Supabase Multi-User Version

This package converts the existing local HTML questionnaire into a shared online system.

## What is included

- `index.html` – public/teacher questionnaire. Anonymous users can submit observations but cannot read the shared database.
- `admin.html` – password-protected administrator dashboard with combined evaluation, filters, CSV/JSON export, legacy JSON import and deletion.
- `config.js` – the only file where the Supabase Project URL and **publishable** key must be pasted.
- `database/setup.sql` – creates the database table, indexes, RLS policies and helper functions.
- `database/make-admin.sql` – grants admin access to a Supabase Auth user.
- `start-local.bat` / `start-local.sh` – optional local test server; no Node/npm/build step is required.

The application loads the pinned browser build of `@supabase/supabase-js` 2.112.3 directly from jsDelivr. There is no package manager, bundler, or compilation step.

## Security model

### Teachers / anonymous visitors

They can:
- open `index.html`;
- fill the questionnaire;
- submit a new observation.

They cannot, through the Supabase Data API:
- list observations;
- read another teacher's submission;
- update observations;
- delete observations.

### Administrators

Administrators authenticate through Supabase Auth on `admin.html`. Only user IDs explicitly present in `public.admin_users` can read/delete the dataset and use the combined evaluation dashboard.

**Important:** `config.js` must contain only the Supabase **Publishable key** (`sb_publishable_...`). Never place an `sb_secret_...` key or a legacy `service_role` key in the website files.

---

# Setup – approximately five steps

## 1. Create a Supabase project

Create a new project in Supabase. When it is ready, keep the project dashboard open.

## 2. Create the database and security policies

In Supabase:

1. Open **SQL Editor**.
2. Create a new query.
3. Copy the complete contents of `database/setup.sql`.
4. Run it once.

This creates `public.observations`, turns on Row Level Security, allows anonymous INSERT only, and limits SELECT/DELETE to approved administrators.

## 3. Create the administrator account

In Supabase:

1. Open **Authentication -> Users**.
2. Add a user with your administrator email and a strong password.
3. Open `database/make-admin.sql`.
4. Replace `ADMIN_EMAIL_HERE` with exactly that email address.
5. Run the SQL in **SQL Editor**.

You may repeat this for additional administrators.

## 4. Configure the website

In Supabase, obtain:

- Project URL, e.g. `https://abcxyz.supabase.co`
- Publishable key, beginning with `sb_publishable_`

Edit `config.js`:

```js
window.PEER_REVIEW_CONFIG = {
  supabaseUrl: "https://abcxyz.supabase.co",
  supabasePublishableKey: "sb_publishable_..."
};
```

Do not use a secret/service-role key.

## 5. Test locally

On Windows, double-click `start-local.bat`, then open:

- Teacher form: `http://localhost:8080/`
- Administrator: `http://localhost:8080/admin.html`

On macOS/Linux:

```bash
chmod +x start-local.sh
./start-local.sh
```

The form should display `✓ Online · bereit zum sicheren Übermitteln` near the top.

Submit one test observation. Then sign into `admin.html`; the observation should appear immediately after loading/refreshing.

---

# Put it online

This is a static website, so it can be hosted by GitHub Pages, Cloudflare Pages, Netlify, an existing school web server, or similar static hosting.

Upload all files in this folder while preserving the folder structure. The public URL should normally point to `index.html`. Keep `admin.html` at a known administrator URL such as:

`https://your-domain.example/peer-review/admin.html`

The admin URL itself does not need to be secret; authorization is enforced in Supabase RLS, not by hiding the page.

Use HTTPS for production.

---

# Daily workflow

## Teacher

1. Open the public URL.
2. Complete the questionnaire.
3. Press **Beobachtung speichern**.
4. Wait for the green success message.
5. The form resets for another observation.

An unfinished questionnaire is still autosaved locally in that teacher's browser. If a network submission fails, the form is not cleared and the draft remains available.

## Administrator

1. Open `admin.html`.
2. Sign in with the Supabase administrator account.
3. The combined dataset is loaded automatically.
4. Filter by beginning/end, grade, subject, and date range.
5. Export the filtered selection to CSV or JSON, or copy the aggregate table.

The **Beobachtungen** tab contains individual records and a permanent delete button.

---

# Migrating old JSON files

If colleagues already exported JSON from the old local version:

1. Sign into `admin.html`.
2. Click **Alte JSON-Daten importieren**.
3. Select one old `peer-review_beobachtungen.json` file.
4. Repeat for the other files.

The admin page assigns a UUID where an old record does not already have one. Duplicate submission UUIDs are skipped by the database's unique constraint.

---

# Backups

The administrator can click **JSON sichern** for a portable backup of the currently filtered dataset and **CSV für Excel** for analysis/reporting.

For institutional use, also configure regular Supabase project/database backups according to the plan and retention policy chosen by the organization.

---

# Privacy notes

The original questionnaire states that teacher names should not be entered. This version preserves that design. Nevertheless, free-text evidence and notes can accidentally contain personal data. Decide internally:

- who is allowed to receive the public submission URL;
- who may be an administrator;
- how long observations should be retained;
- whether peer codes are considered identifiable within your organization;
- what teachers must avoid putting into free-text fields.

The database stores server submission timestamps in addition to the questionnaire's observation date.

---

# Troubleshooting

### `Supabase ist noch nicht konfiguriert`
Fill in `config.js` with the project URL and publishable key.

### Public form says submitting is not enabled / permission denied
Run `database/setup.sql` again and check that `config.js` points to the same Supabase project.

### Admin login succeeds but the page says the account is not authorized
Run `database/make-admin.sql` with the exact email used in Authentication -> Users.

### Admin sees zero records
First submit a test questionnaire using `index.html`, then click **Aktualisieren** in the admin page.

### CDN blocked by a school firewall
The only external JavaScript dependency is the pinned Supabase browser SDK from jsDelivr. If the school blocks jsDelivr, self-host that one UMD file and change the `<script src=...>` in `index.html` and `admin.html` to the local path.

---

# Files that are safe to publish

These are designed to be public:

- `index.html`
- `admin.html`
- `config.js` containing a **publishable** key

These SQL files are setup documentation and may be kept private if desired, but they contain no credentials by default.

Never publish a Supabase secret key, legacy service-role key, database password, or administrator password.
