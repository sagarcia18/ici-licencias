# ICI-licencias
Repositorio para controlar las licencias de la revit en ICI_Capacitacion


Signed revocation list for the ICI_capacitacion Revit add-in. The add-in downloads
`revoked.json`, checks its signature with the embedded list public key, and refuses any license
whose fingerprint is listed. It contains no names or machine IDs, only SHA-256 fingerprints of
license data, so it is safe to be public.

## Revoke a license

1. Get its fingerprint (on the issuer's PC, in the ICI_capacitacion repo):
   `dotnet run --project ICI_LicenseTool -- fingerprint <file.lic>`
   (`sign` also prints it when the license is issued.)
2. Add it as a new line to `revoked.txt`, with a `#` comment saying who and why, and push.
3. The **Sign revocation list** Action re-signs `revoked.json` within a minute. Users pick it up
   the next time Revit starts online.

## How it stays valid

`revoked.json` expires 14 days after it is signed (`validUntil`), so an old list from before a
revocation can't be replayed forever. The Action re-signs it every Monday; if it stops running,
**every user is locked out once the list expires**. Check the Actions tab if in doubt, or run the
workflow by hand (Actions > Sign revocation list > Run workflow).

GitHub disables scheduled workflows in a public repo after 60 days without activity. The weekly
commit is meant to count as activity, but if GitHub ever shows the workflow as disabled,
re-enable it from the Actions tab.

## Setup (once)

- Settings > Environments > New environment `licencias`
  - Deployment branches and tags: **Selected branches** > `main`
  - Environment secrets > `LIST_PRIVATE_KEY` = full contents of `list_private_key.xml`
- Do **not** add required reviewers: the weekly run would wait for approval and the list would
  expire.
