# eDIM — Electronic Dispensing and Inventory Management

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

## Quick start — (Ruby 3.2.1 / Rails 7.0.8)

These are steps for the upgraded environment.

### Prerequisites
- Ruby 3.2.1
- MySQL/MariaDB database server
- Git

### Setup Instructions

1. **Clone the repository:**
   ```bash
   git clone git@github.com:global-health-informatics-institute/eDIM-2.0.git
   cd eDIM-2.0
   ```

2. **Install Ruby (3.2.1) and Bundler:**
   ```bash
   rbenv install 3.2.1 
   rbenv local 3.2.1
   gem install bundler
   ```

3. **Install gems:**
   ```bash
   bundle install
   ```

4. **Configure application files (IMPORTANT - copy examples):**
   ```bash
   cp config/database.yml.example config/database.yml
   cp config/application.yml.example config/application.yml
   cp config/secrets.yml.example config/secrets.yml
   ```
   
   **Edit these files with your specific configuration:**
   - `config/database.yml` - Add your database credentials
   - `config/application.yml` - Add any application-specific settings
   - `config/secrets.yml` - Add secret keys (generate with `rake secret`)

5. **Create and migrate the database:**
   ```bash
   bundle exec rake db:create
   bundle exec rake db:migrate
   ```

6. **Seed the database (optional but recommended):**
   ```bash
   bundle exec rake db:seed
   ```

7. **Precompile assets (for production-like setup):**
   ```bash
   bundle exec rake assets:precompile
   ```

8. **Run the server:**
   ```bash
   bundle exec rails s
   ```

### Troubleshooting Common Issues

**Missing assets:**
- Run `bundle exec rake assets:precompile`
- Check that asset files are committed to the repository
- Ensure `public/assets/` directory exists

**Database connection errors:**
- Verify `config/database.yml` has correct credentials
- Ensure MySQL/MariaDB server is running
- Create the database user and grant permissions

**Buttons not showing up:**
- This is usually due to missing translation files
- Check `config/locales/en.yml` and `config/locales/es.yml` exist
- Verify these files contain the required translation keys

### Development Notes

- The `.ruby-version` file should be committed for consistency
- Configuration examples (`.example` files) are provided for sensitive files
- Always copy example files and customize them for your environment
---
