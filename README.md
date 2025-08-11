# eDIM 2.0 — Electronic Dispensing and Inventory Management

**eDIM** (Electronic Dispensing and Inventory Management) is an open-source system to help low-resource health facilities manage pharmaceutical supply chains at dispensary level. eDIM improves visibility of consumption, stock levels, expiries, and supports dispensary workflows.

---

## Project summary

Supply chain management for pharmaceuticals is one area of concern for low-resource settings. Most health facilities in this setting struggle with quantifying consumption, availability, and demand of pharmaceuticals. This affects the availability of these resources which are critical for the delivery of effective health care.

**Goal:** help pharmacists manage resources efficiently while improving medication management processes through an electronic dispensary system.

---

## Versions / Compatibility

> **eDIM 1.x** was developed with Ruby **2.4.1** and Rails **4.2.x**  
> **eDIM 2.0 (this fork/upgrade)** has been tested on Ruby **3.2.1** and Rails **7.0.8**.

---
### Get the eDIM application

You can get a copy of the eDIM software from GitHub by running the following command from your terminal:

```bash
git clone git@github.com:global-health-informatics-institute/eDIM-2.0.git

```

## Quick start — modern (Ruby 3.2.1 / Rails 7.0.8)

These are steps for the upgraded environment you’ve migrated to.

1. Install Ruby (3.2.1) and Bundler:
   ```bash
   rbenv install 3.2.1 
   rbenv local 3.2.1
   gem install bundler
   ```

2. Install gems:
   ```bash
   bundle install
   ```

3. Configure application files (copy examples):
   ```bash
   cp config/database.yml.example config/database.yml
   cp config/application.yml.example config/application.yml
   cp config/secrets.yml.example config/secrets.yml
   # Edit them to add your DB credentials and any secrets / properties
   ```

4. Create and migrate the database:
   ```bash
   bundle exec rake db:create
   bundle exec rake db:migrate
   ```

5. Run the server:
   ```bash
   bundle exec rails s
   ```
---
