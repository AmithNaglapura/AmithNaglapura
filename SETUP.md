# Portfolio backend setup

About 15 minutes. You need two free accounts: **Supabase** (database, owner sign-in) and **Web3Forms** (emails each message to your Gmail).

| File | What it is |
|---|---|
| `index.html` | The portfolio. Sends contact messages and anonymous page views. |
| `admin.html` | Your private dashboard: inbox and visitor analytics. Not linked from the site. |
| `supabase-setup.sql` | Creates the tables and the security rules. |

## 1. Supabase (database and private sign-in)

1. Sign up at **supabase.com** and create a new project (any name, a strong database password, region: London).
2. Open **SQL Editor → New query**, paste all of `supabase-setup.sql`, and click **Run**.
3. **Authentication → Users → Add user → Create new user**: email `amithnaglapura@gmail.com`, tick *Auto confirm user*.
4. **Authentication → Sign In / Providers**: keep **Email** on, and turn **off** *Allow new users to sign up*. Nobody else can then create an account.
5. **Authentication → Emails → Magic Link** template: make sure the body contains `{{ .Token }}` (for example: `Your sign-in code is {{ .Token }}`). That is the 6-digit code the admin page asks for.
6. **Project Settings → API Keys**: copy the **Project URL** and the **publishable** key (`sb_publishable_…`; on older projects, the `anon public` key).
   **Never** copy the `secret` / `service_role` key into any file.

## 2. Web3Forms (email to your Gmail)

1. Go to **web3forms.com**, enter `amithnaglapura@gmail.com`, and click *Create Access Key*. The key arrives by email.
2. Optional: in the Web3Forms dashboard, restrict the key to your site's domain.

## 3. Paste the keys

In **both** `index.html` and `admin.html`, find the block near the bottom that starts with `window.PORTFOLIO_CFG` and fill in:

```js
SUPABASE_URL:'https://YOURPROJECT.supabase.co',
SUPABASE_ANON:'sb_publishable_…',
WEB3FORMS_KEY:'…'          // index.html only
```

These values are designed to be public. The protection comes from the database rules, not from hiding them.

## 4. Publish on GitHub Pages

1. Upload `index.html` and `admin.html` to the repo (or merge the `portfolio-v2` branch).
2. **Settings → Pages → Build and deployment → Deploy from a branch → `main` / root → Save.**
3. The site will be at `https://amithnaglapura.github.io/AmithNaglapura/` and the dashboard at `…/AmithNaglapura/admin.html`.
   For the shorter `https://amithnaglapura.github.io/`, the repo has to be named `AmithNaglapura.github.io`.

## 5. Test it

1. Open the live site, go to **Contact**, and send yourself a message. It should arrive in Gmail and show in the dashboard inbox.
2. Open `admin.html`, enter your email, and type the code you receive.

The contact form and tracking only work on the live site. The claude.ai preview blocks calls to other websites, so there the form shows "email me directly" instead.

## How it is protected

- **Write-only public access.** Visitors can only add messages and page views. Reading, editing and deleting are allowed only for a signed-in user whose verified email is `amithnaglapura@gmail.com`. Supabase enforces this in the database (Row Level Security), so reading the page source doesn't help anyone.
- **Owner-only sign-in.** Sign-ups are disabled, and the code is emailed only to you. Sessions last for the open tab only and end after 30 minutes idle.
- **Input limits.** Every field has a length limit and email format checks in the database. A trigger rejects floods of more than 30 messages or 600 page views in 10 minutes.
- **Spam filtering.** A hidden honeypot field, a minimum fill time, and a one-message-per-minute limit per browser.
- **Safe display.** Message content is always shown as text, never as HTML, so a malicious message can't run code in your dashboard. The dashboard has a strict Content Security Policy and is marked `noindex`.
- **Privacy.** No cookies, no IP addresses stored, and Do Not Track / Global Privacy Control are respected. A notice is shown under the form.

No website is truly "hacker-proof", and browser code can never be completely hidden: anything that runs in a browser can be read. The minified code only makes it harder to read. The data stays safe because the rules live on Supabase's servers, not in the page.
