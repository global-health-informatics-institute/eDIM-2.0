# eDIM 2.0 Setup Checklist

Use this checklist to ensure your development environment is properly configured.

## For Repository Maintainers

### Before Pushing Changes
- [ ] Ensure translation files (`config/locales/*.yml`) are committed
- [ ] Verify `.ruby-version` is committed for consistency
- [ ] Check that `Gemfile.lock` is committed
- [ ] Ensure example configuration files (`.example`) are up to date
- [ ] Test that assets compile correctly (`rake assets:precompile`)
- [ ] Verify no sensitive data is committed (check `.gitignore`)

### Files That Should Be Committed
- [ ] `config/locales/en.yml` - English translations
- [ ] `config/locales/es.yml` - Spanish translations  
- [ ] `.ruby-version` - Ruby version specification
- [ ] `Gemfile.lock` - Gem version lock file
- [ ] All asset files in `app/assets/`
- [ ] Example configuration files (`*.example`)

### Files That Should NOT Be Committed
- [ ] `config/database.yml` - Database credentials
- [ ] `config/application.yml` - Application secrets
- [ ] `config/secrets.yml` - Secret keys
- [ ] `log/*.log` - Log files
- [ ] `tmp/` - Temporary files

## For New Developers

### Quick Setup (Automated)
```bash
git clone <repository-url>
cd eDIM-2.0
./setup.sh
```

### Manual Setup Steps
- [ ] Clone the repository
- [ ] Install Ruby 3.2.1 (`rbenv install 3.2.1`)
- [ ] Install bundler (`gem install bundler`)
- [ ] Install gems (`bundle install`)
- [ ] Copy configuration files:
  - [ ] `cp config/database.yml.example config/database.yml`
  - [ ] `cp config/application.yml.example config/application.yml`
  - [ ] `cp config/secrets.yml.example config/secrets.yml`
- [ ] Edit configuration files with your settings
- [ ] Create database (`rake db:create`)
- [ ] Run migrations (`rake db:migrate`)
- [ ] Seed database (`rake db:seed`) - optional
- [ ] Precompile assets (`rake assets:precompile`)
- [ ] Start server (`rails server`)

### Troubleshooting Common Issues

#### "Missing translation" errors
- [ ] Check if `config/locales/en.yml` exists
- [ ] Check if `config/locales/es.yml` exists
- [ ] Verify translation files have content
- [ ] Restart the Rails server

#### "Missing assets" errors
- [ ] Run `rake assets:precompile`
- [ ] Check if asset files exist in `app/assets/`
- [ ] Verify `public/assets/` directory exists
- [ ] Clear browser cache

#### "Buttons not showing up"
- [ ] This is usually due to missing translations
- [ ] Check translation files exist and have required keys
- [ ] Restart Rails server after adding translations

#### Database connection errors
- [ ] Verify MySQL/MariaDB is running
- [ ] Check `config/database.yml` has correct credentials
- [ ] Ensure database user has proper permissions
- [ ] Try creating database manually

### Environment Verification
Run these commands to verify your setup:

```bash
# Check Ruby version
ruby -v  # Should show 3.2.1

# Check if gems are installed
bundle check

# Check if database is accessible
rake db:version

# Check if translations are loaded
rails console
> I18n.t('forms.buttons.next')  # Should not show "translation missing"

# Check if assets compile
rake assets:precompile

# Start server
rails server
```

### Getting Help
If you encounter issues not covered here:
1. Check the main README.md for detailed instructions
2. Verify all files in this checklist are properly set up
3. Check the Rails logs (`log/development.log`) for error details
4. Ensure your Ruby and Rails versions match the requirements