# Gromax marketing site

Static site for Netlify: landing, features, pricing, support (with a Netlify contact form), privacy policy, terms and a 404 page.

## Deploy on Netlify
1. Drag this folder onto app.netlify.com/drop, or connect the Git repo with publish directory `.` and no build command.
2. Netlify detects the `support` form automatically. Turn on email notifications under Site configuration > Forms.
3. Pretty URLs are on, so these work: `/privacy`, `/terms`, `/support`.

URLs for App Store Connect:
- Privacy Policy URL: https://YOUR-SITE.netlify.app/privacy
- Support URL: https://YOUR-SITE.netlify.app/support
- Marketing URL: https://YOUR-SITE.netlify.app/

## Change name, prices, emails or AI provider
Edit the settings at the top of `build/build.py`, then run `python3 build/build.py`. It rewrites every .html page.
Also update the domain in `robots.txt` and `sitemap.xml` once you know your Netlify URL.

## Before going live
- Set `STORE_URL` to the real App Store link.
- Set `EMAIL` at the top of `build/build.py` to an inbox you check, then run `python3 build/build.py`.
- `privacy.html` and `terms.html` use the same wording as the app (`site/privacy.html` and `site/terms.html` on the stature-app branch). If the app text changes, update the legal sections in `build/build.py` to match.
- Feature and Free-vs-Pro claims follow `docs/app-store-listing.md` in the app repo. Keep them in step with it.
