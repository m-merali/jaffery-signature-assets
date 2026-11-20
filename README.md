# Jaffery signature assets

Image files for the staff email signatures of Jaffery Academy Mombasa, Jaffery Institute of Professional Studies (JIPS) and Jaffery Nursery & Primary School (JNPS): the school logos, the KEBS ISO 21001 mark and social media icons. Outlook fetches them from here whenever someone opens an email with one of these signatures, so every file in this repository is public.

The school logos belong to the schools and the KEBS ISO 21001 mark belongs to the Kenya Bureau of Standards. They are published here for the signatures only.

## Addresses

| | Base URL | Repository |
|---|---|---|
| Primary | `https://assets.jafferyacademy.org/` | [m-merali/jaffery-signature-assets](https://github.com/m-merali/jaffery-signature-assets) |
| Fallback | `https://m-merali.github.io/jaffery-signature-assets-fallback/` | [m-merali/jaffery-signature-assets-fallback](https://github.com/m-merali/jaffery-signature-assets-fallback) |

Signatures use the primary address. Both repositories hold the same commits. The fallback repository has no custom domain, so its address keeps serving the files if `assets.jafferyacademy.org` stops working. The primary repository's own github.io address redirects to `assets.jafferyacademy.org`, so it can't serve as a fallback.

## Layout

```
academy/v1/   Jaffery Academy logo, logo on a badge, social icons
jips/v1/      JIPS, same set
jnps/v1/      JNPS, same set
kebs/v1/      KEBS ISO 21001 mark
shared/v1/    reserved for files used by all four signatures (empty)
index.html    preview of every file, on white and on Outlook's dark background
404.html      page shown for an address that has no file
CNAME         the custom domain, kept as a record (see Publishing)
.github/      publish workflow, URL check and their scripts; not published
```

File names follow `<group>/<version>/<group>-<asset>-<display width>[@2x].png`, for example `academy/v1/academy-logo-80@2x.png`. Signatures link the `@2x` file and set `width` and `height` to the display width, so the image stays sharp on high-density screens.

## Rules

1. **Never rename, move, overwrite or delete a file in a version folder once it is published.** Emails that were already sent link to it by its full address. Changing the file changes those emails; removing it breaks them.
2. A corrected or new design goes into the next version folder (`v2/`, then `v3/`) under the same file name. Then update the signature templates to the new path. The old version stays where it is.
3. Adding a new file to an existing version folder is allowed, as long as no existing file changes.
4. Only logos, icons and the two pages above go here. No staff data, no M365 or HR exports, no passwords, keys or certificates. `.gitignore` blocks the common file types as a safety net.

The publish workflow enforces rule 1. Before every deploy, `.github/scripts/check-immutable.sh` compares every file in a version folder with the version first committed, and stops the deploy if one differs or is missing. Reverting the change clears the block. If a file was added to a version folder by mistake and its deploy was blocked, so it never went live, remove it and list its path in `.github/never-published.txt` with a comment saying why.

## Publishing

The files are built in the project's private repository by `brand/scripts/build_assets.py`, then committed here.

One-time set-up of a clone that pushes to both repositories:

```sh
git clone https://github.com/m-merali/jaffery-signature-assets.git
cd jaffery-signature-assets
git remote set-url --add --push origin https://github.com/m-merali/jaffery-signature-assets.git
git remote set-url --add --push origin https://github.com/m-merali/jaffery-signature-assets-fallback.git
```

After that, `git push origin main` updates both. In each repository the push runs `.github/workflows/pages.yml`, which publishes the files with GitHub Pages.

The custom domain is set in the primary repository's Pages settings, not by the `CNAME` file: GitHub ignores that file when Pages is published by a workflow. The file records the domain and must contain only `assets.jafferyacademy.org`.

## Checking

Actions tab > **Check asset URLs** > **Run workflow**. The check runs on a GitHub server, outside the school network. It requests every PNG and the index page on both addresses and checks for status 200 with no redirect, the right content type and the same bytes as the repository. It also checks the 404 page, the redirects from http to https, and the redirect from the primary github.io address to the custom domain. The report appears on the run's summary page.

To run it on your own machine, with names resolved over public DNS:

```sh
DOH_URL=https://cloudflare-dns.com/dns-query bash .github/scripts/check-urls.sh report.md
```

## If the custom domain fails

Change the base URL in the signatures from `https://assets.jafferyacademy.org` to `https://m-merali.github.io/jaffery-signature-assets-fallback` and push them again. The file paths after the base stay the same. Emails sent before the switch keep pointing at the custom domain and show their images again once the domain is back.

## Versions

| Version | Published | Contents |
|---|---|---|
| v1 | November 2026 | 102 PNG files: school logos and logo badges at 64, 80 and 96 px, KEBS mark at 56, 64 and 72 px, five social icons per school at 20 px (plain and on a white disc), each at 1x and @2x |
