# FOSS Create — Action Plan & Timeline

> **Project**: dbt-iterative-snapshot  
> **Owner**: Amin Siddique  
> **Goal**: Publish under github.com/mercedes-benz  
> **Started**: 2026-06-30

---

## What's Already Done

- [x] All compulsory files (README, LICENSE, CONTRIBUTING, CODE_OF_CONDUCT, SECURITY, PROVIDER_INFORMATION, MAINTAINERS)
- [x] SPDX headers + copyright in all source files
- [x] DCO check GitHub Action added
- [x] CI/CD pipeline (compile, integration tests, functional tests)
- [x] No secrets/internal references in code
- [x] FOSS trainings completed (Awareness, Use, Contribute, Create)
- [x] FOSS Coordinator identified
- [x] Business Feasibility document drafted on Confluence
- [x] Black Duck access requested (waiting)
- [x] LeanIX ID known

---

## What I Need To Do

### This Week (Week 1)

| # | Task | Send To | What I Do | What They Do | Done? |
|---|------|---------|-----------|--------------|-------|
| 1 | Get Business Feasibility signed | Line Manager (E4) | Send Confluence page link, schedule 30-min meeting | Reviews doc, replies "Approved" or signs in the approvals table | [ ] |
| 2 | Get second signature on Business Feasibility | FOSS Coordinator OR another E4 | Send same Confluence page link | Reviews, adds their name + date in approvals table | [ ] |
| 3 | Get Information Classification approval | Information Owner (E3/E4) | Send email (template below) | Replies "Confirmed as Public" | [ ] |
| 4 | Get patent/IP clearance | Mercedes-Benz IP team | Send email (template below) | Replies "No patent concerns" | [ ] |

### Week 2

| # | Task | Send To | What I Do | What They Do | Done? |
|---|------|---------|-----------|--------------|-------|
| 5 | Run Black Duck scan | Self (once access granted) | Create project, run scan on repo (see detailed steps below) | — | [ ] |
| 6 | Add Black Duck SCA to CI | Self | Add GitHub Action for rapid scan on PRs + full scan on main | — | [ ] |
| 7 | Create FOSS ticket | FOSS Team | Submit at go.mercedes-benz.com/create_foss_tickets | They create repo at github.com/mercedes-benz | [ ] |
| 8 | Identify second maintainer | Team colleague | Ask who wants to co-maintain | They agree + start FOSS trainings | [ ] |

### Week 3 (Publish)

| # | Task | What I Do | Done? |
|---|------|-----------|-------|
| 9 | Migrate code to github.com/mercedes-benz repo | Push clean code, update CODEOWNERS | [ ] |
| 10 | Configure repo (branch protection, secret scanning) | GitHub settings | [ ] |
| 11 | Internal peer review | Ask colleague outside team to review | [ ] |
| 12 | Set repo to public | Flip visibility switch | [ ] |
| 13 | Tag v1.0.0 release | `git tag v1.0.0 && git push --tags` | [ ] |
| 14 | Submit to dbt Hub | PR to github.com/dbt-labs/hubcap | [ ] |

---

## What I Expect From Each Party

### Line Manager (E4)

**What they provide**: Written approval of Business Feasibility  
**Acceptable formats**:
- Fill in their name + date in the approvals table on the Confluence page, OR
- Reply to your email with "I approve the publication of dbt-iterative-snapshot as open source under MIT license", OR
- Sign a printed/PDF version of the Business Feasibility doc

**What they're confirming**:
- Resources are available for ongoing maintenance (2-4 hrs/week)
- No business objection to publishing this code
- No competitive USPs are being exposed

---

### Second Signatory (FOSS Coordinator or another E4)

**What they provide**: Second signature on Business Feasibility (four-eyes principle)  
**Acceptable formats**: Same as above — name + date in approvals table, email, or signed PDF  
**What they're confirming**: Same as line manager — independent verification

---

### Information Owner (E3/E4)

**What they provide**: One-line confirmation that code is classified as "Public"  
**Acceptable format**: Email reply  
**What they're confirming**: Disclosing this source code to anyone does not harm MB, customers, or partners

**Email to send**:
> Subject: Information Classification Request — dbt-iterative-snapshot (FOSS Create)
>
> Hi [Name],
>
> We are publishing `dbt-iterative-snapshot` as open source. Per A 22.0, I need classification approval.
>
> **Proposed classification**: Public  
> **Content**: Generic SQL/Jinja macros for SCD2 snapshot processing  
> **Contains NO**: internal URLs, credentials, personal data, proprietary algorithms, internal system names  
>
> Could you confirm this classification as Public?
>
> Thanks, Amin

---

### Mercedes-Benz IP Team

**What they provide**: Confirmation that no patent issues exist  
**Acceptable format**: Email reply  
**What they're confirming**: No MB patents are exposed, no invention report needed, MIT license is acceptable

**Email to send**:
> Subject: Patent/IP Check — dbt-iterative-snapshot (FOSS Create, MIT License)
>
> Hi,
>
> We plan to publish a dbt package as open source under MIT license at github.com/mercedes-benz.
>
> **Package**: dbt-iterative-snapshot  
> **What it does**: SCD2 (Slowly Changing Dimension Type 2) snapshot processing for Databricks  
> **Algorithms**: Standard SCD2 patterns (Ralph Kimball, 1990s) — no novel inventions  
> **License**: MIT (no explicit patent grant clause)  
>
> Please confirm:
> 1. No MB patents are affected
> 2. No invention report is required
> 3. MIT license is acceptable from IP perspective
>
> Happy to provide the source code for review if needed.
>
> Thanks, Amin

---

### FOSS Coordinator

**What they provide**: Process compliance confirmation + potentially second signature  
**Acceptable format**: Email or comment on FOSS ticket  
**What they're confirming**: You followed the FOSS Create process correctly

---

### FOSS Team (via ticket)

**What they provide**: Repository creation at github.com/mercedes-benz  
**What you submit**: FOSS ticket with: project name, license, platform, maintainers, link to signed Business Feasibility  
**What they do**: Create the repo, add you as admin, configure org-level settings

---

## Timeline Summary

```
Week 1 (now)     → Send emails, get sign-offs (all async, parallel)
Week 2           → Black Duck scan + FOSS ticket
Week 3           → Migrate, configure, publish
```

**Critical path**: Business Feasibility sign-off → FOSS ticket → repo creation → publish

Everything else (IP check, classification, Black Duck) runs in parallel and just needs to complete before the final publish step.

---

## Black Duck Scan — Detailed Steps

**Reference repo**: [git.i.mercedes-benz.com/foss/BlackDuckSupport](https://git.i.mercedes-benz.com/foss/BlackDuckSupport)  
**Black Duck URL**: [mercedes-benz.app.blackduck.com](https://mercedes-benz.app.blackduck.com/)  
**Project request tool**: [bdscan-request.app.corpintra.net](https://bdscan-request.app.corpintra.net/)

### Step 1: Create Black Duck Project

1. Login to [mercedes-benz.app.blackduck.com](https://mercedes-benz.app.blackduck.com/) with your MB UserID (NOT AD EMEA) — this auto-creates your user
2. Go to [bdscan-request.app.corpintra.net](https://bdscan-request.app.corpintra.net/) to create the project
3. Use case answers for `dbt-iterative-snapshot`:
   - **Target Platform**: Enterprise IT
   - **Target Users**: External (open source)
   - **Layer**: Backend
   - **Distribution Target**: External (open source = distributed)
4. Enter your LeanIX / PlanningIT ID when prompted
5. This grants you _Project Manager_ role + scanning rights

### Step 2: Generate Access Token

1. Login → User dropdown (top right) → "My Access Token"
2. Create New Token → scope: **read and write**
3. Copy and save in KeePass — **token is shown only once!**
4. Store as `BLACKDUCK_API_TOKEN` in your GitHub repo secrets (for CI)

### Step 3: Run Full Scan (one-time, from your machine)

```bash
bash <(curl -s https://detect.blackduck.com/detect10.sh) \
--blackduck.url="https://mercedes-benz.app.blackduck.com/" \
--blackduck.api.token="YOUR_TOKEN" \
--blackduck.timeout="300" \
--detect.project.name="dbt-iterative-snapshot" \
--detect.project.version.name="1.0.0" \
--detect.code.location.name="dbt-iterative-snapshot-1.0.0"
```

Run from the repo root. Results appear in the Black Duck UI.

### Step 4: Review Results

- Check for policy violations in Black Duck UI
- For your dbt package: expect **zero/minimal violations** (all deps are Apache-2.0/MIT)
- If any false positives, follow: [How to handle False Positives](https://git.i.mercedes-benz.com/foss/BlackDuckSupport/blob/master/8.%20False%20Positives.md)
- Export compliance report for your FOSS ticket

### Step 5: CI Integration (automated, ongoing)

Added to `.github/workflows/ci.yml`:
- **On PRs**: Rapid scan — fast, doesn't persist, catches new violations before merge
- **On push to main**: Full scan — persists to Black Duck UI, keeps compliance record updated

### Black Duck Support

For issues: create a ticket at [git.i.mercedes-benz.com/foss/BlackDuckSupport/issues](https://git.i.mercedes-benz.com/foss/BlackDuckSupport/issues)

---

## Publishing to dbt Hub

Once the repo is public at `github.com/mercedes-benz/dbt-iterative-snapshot`, we register it on [hub.getdbt.com](https://hub.getdbt.com) so users can install via `packages.yml`.

### How It Works

1. The dbt Hub index is maintained at: **https://github.com/dbt-labs/hubcap**
2. A script (`hubcap.py`) runs hourly on Heroku and auto-generates PRs for new package versions
3. To register a new package, you add your org + repo to `hub.json`

### What To Do

**Step 1**: Fork `https://github.com/dbt-labs/hubcap`

**Step 2**: Edit `hub.json` — add this entry (alphabetical order by org name):

```json
"mercedes-benz": [
    "dbt-iterative-snapshot"
]
```

**Step 3**: Open a PR to `dbt-labs/hubcap` with:
- **Title**: `Add mercedes-benz/dbt-iterative-snapshot`
- **Body**:
  ```
  Adding dbt-iterative-snapshot to the hub index.
  
  - Package: https://github.com/mercedes-benz/dbt-iterative-snapshot
  - License: MIT
  - Description: SCD2 snapshots with out-of-order batch processing support for Databricks
  - dbt version: >=1.6.0, <2.0.0
  ```

**Step 4**: Wait for PR review/merge by dbt Labs team

**Step 5**: Once merged, the hourly hubcap job will pick up your package. It reads your `dbt_project.yml` for version info and git tags for releases.

### Prerequisites for dbt Hub

Before submitting, your repo MUST have:

| Requirement | Status | Notes |
|-------------|--------|-------|
| Public repo on GitHub | Required | Must be at `github.com/mercedes-benz/dbt-iterative-snapshot` |
| `dbt_project.yml` with `name` and `version` | :white_check_mark: | Already has `name: 'dbt_iterative_snapshot'`, `version: '1.0.0'` |
| Git tag matching version | Needed | Tag `v1.0.0` after publishing |
| Valid `packages.yml` in any dependent test projects | :white_check_mark: | Integration tests reference the package correctly |

### After Submission

Once on dbt Hub, users install with:

```yaml
# packages.yml
packages:
  - package: mercedes-benz/dbt_iterative_snapshot
    version: [">=1.0.0", "<2.0.0"]
```

Note: dbt Hub uses **underscores** in package names (from `dbt_project.yml` `name` field), while the GitHub repo uses **hyphens**. This is standard dbt convention.

### Future Releases

After initial registration, you don't need to submit PRs for new versions. Just:
1. Update `version` in `dbt_project.yml`
2. Tag the release: `git tag v1.1.0 && git push --tags`
3. Hubcap picks it up automatically within ~1 hour

---

## FOSS Training Path (Required for All Maintainers)

All maintainers must complete the full training path **in order** before the project can be published. Each course has a certification at the end.

```
┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐    ┌─────────────┐    ┌─────────────┐
│   FOSS      │    │   FOSS      │    │   FOSS Use          │    │   FOSS      │    │   FOSS      │
│  Awareness  │───▶│    Use      │───▶│  Certification      │───▶│ Contribute  │───▶│   Create    │
│             │    │  Driver's   │    │  Enterprise IT &    │    │  Driver's   │    │  Driver's   │
│             │    │  License    │    │  Apps               │    │  License    │    │  License    │
└─────────────┘    └─────────────┘    └─────────────────────┘    └─────────────┘    └─────────────┘
  Step 1             Step 2             Step 3 (IT path)           Step 4             Step 5
  General            For Product        Certification for          For FOSS           For FOSS
  FOSS concepts      Owners & devs      IT/Apps teams              Contributors       Maintainers
```

### Course Links (SABA)

Complete in this order:

| # | Course | Purpose | Link |
|---|--------|---------|------|
| 1 | **FOSS Awareness** | General concepts of the FOSS world | [Open in SABA](https://daimler.sabacloud.com/Saba/Web_spf/EU1PRD0023/app/me/learningeventdetail/cours000000000140901?regId=regdw000000005113004&context=user&learnerId=emplo000000001450479&returnPage=MyPlan) |
| 2 | **FOSS Use Driver's License** | For Product Owners, dev teams, and employees who use FOSS | [Open in SABA](https://daimler.sabacloud.com/Saba/Web_spf/EU1PRD0023/app/me/learningeventdetail;spf-url=common%2Fledetail%2Fcours000000000145762%3Freturnurl%3Dcatalog%252Fsearch%253FsearchText%253DFOSS%252520USE%2526selectedTab%253DLEARNINGEVENT%2526filter%253D%25257B%25257D&context%3Duser&learnerId%3Demplo000000001450479) |
| 3 | **FOSS Use Certification — Enterprise IT & Apps** | Certification for IT/Apps path (our path) | [Open in SABA](https://daimler.sabacloud.com/Saba/Web_spf/EU1PRD0023/app/me/learningeventdetail;spf-url=common%2Fledetail%2Fcours000000003244818%3Freturnurl%3Dcatalog%252Fsearch%253FsearchText%253DFOSS%252520USE%2526selectedTab%253DLEARNINGEVENT%2526filter%253D%25257B%25257D&context%3Duser&learnerId%3Demplo000000001450479) |
| 4 | **FOSS Contribute Driver's License** | For contributors who want to use the CONTRIBUTE process | [Open in SABA](https://daimler.sabacloud.com/Saba/Web_spf/EU1PRD0023/app/me/learningeventdetail/cours000000000148357?regId=regdw000000006361424&context=user&learnerId=emplo000000001450479&returnPage=ProfilePlan) |
| 5 | **FOSS Create Driver's License** | For maintainers who want to use the CREATE process | [Open in SABA](https://daimler.sabacloud.com/Saba/Web_spf/EU1PRD0023/app/me/learningeventdetail;spf-url=common%2Fledetail%2Fcours000000000150043%3FfromAutoSuggest%3Dtrue) |

### Notes

- **Our path is IT** (not Vehicle/RD) — so take "FOSS Use Certification Enterprise IT & Apps" at step 3
- Each course must be **completed and certified** before starting the next
- Save your SABA certificates — you'll need them for the compliance documentation package
- If the SABA links don't work, search for "FOSS" in the SABA learning catalog

### Training Tracker

| Maintainer | Step 1 | Step 2 | Step 3 | Step 4 | Step 5 | All Done? |
|------------|:------:|:------:|:------:|:------:|:------:|:---------:|
| Amin Siddique | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | :white_check_mark: | Yes |
| Maintainer 2 (TBD) | | | | | | |

---

## Where Everything Lives

| Artifact | Location |
|----------|----------|
| Business Feasibility doc | [Confluence page](https://mercedes-benz.atlassian.net/wiki/spaces/~71202063def22ed7f64107a467d675bf7abb2f/pages/2986384633) |
| Source code (current) | mercedes-benz.ghe.com/hrdf/dbt-iterative-snapshot |
| Source code (target) | github.com/mercedes-benz/dbt-iterative-snapshot |
| FOSS ticket | go.mercedes-benz.com/create_foss_tickets |
| Black Duck | mercedes-benz.app.blackduck.com |
| dbt Hub registration | github.com/dbt-labs/hubcap (PR to hub.json) |
| FOSS Handbook | mercedes-benz.atlassian.net/wiki/spaces/FOSSHANDBK |
