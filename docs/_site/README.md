# OpsFlux Site — docs/

Jekyll site for opsflux.in. Lives in the `docs/` folder of the `opsflux-app` repo.

## Setup (one time, on your GCP VM)

```bash
sudo apt update && sudo apt install -y ruby-full build-essential zlib1g-dev
echo 'export GEM_HOME="$HOME/gems"' >> ~/.bashrc
echo 'export PATH="$HOME/gems/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
gem install bundler jekyll
cd docs/
bundle install
```

## Preview locally

```bash
cd docs/
bundle exec jekyll serve --host 0.0.0.0 --port 4000
# Open http://<vm-external-ip>:4000
```

## Adding a new lab (daily)

```bash
cd docs/
chmod +x new-lab.sh          # first time only
./new-lab.sh "Your Lab Title Here"
# Edit the file it creates in _labs/
# Then:
git add .
git commit -m "lab: your lab title"
git push
```

## Lab frontmatter reference

```yaml
---
title: "Your Lab Title"
date: 2026-05-27
summary: "Short description shown on the labs index."
difficulty: beginner        # beginner | intermediate | advanced
duration: 30 mins
tags: [kubernetes, debugging, terraform]
github_link: https://github.com/opsflux-labs/opsflux-app/tree/main/kubernetes/your-lab
---
```

## GitHub Pages setup

- Repo: `opsflux-labs/opsflux-app`
- Settings → Pages → Source: `main` branch → `/docs` folder
- Custom domain: `opsflux.in` (CNAME file already included)

## DNS records for opsflux.in

```
A    @    185.199.108.153
A    @    185.199.109.153
A    @    185.199.110.153
A    @    185.199.111.153
CNAME www opsflux-labs.github.io
```

## Folder structure

```
docs/
├── _config.yml          # Site config
├── _layouts/
│   ├── default.html     # Nav + footer wrapper
│   └── lab.html         # Individual lab page
├── _labs/               # ← YOUR DAILY LABS GO HERE
│   └── YYYY-MM-DD-*.md
├── assets/css/main.css  # All styles
├── index.html           # Home page
├── labs/index.html      # Labs listing page
├── new-lab.sh           # Script to create new lab
├── CNAME                # opsflux.in
└── Gemfile
```
