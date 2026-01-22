#!/bin/bash

# eDIM Setup Script
# This script helps set up the project
# Do manual setup in READM.md or carefully read this script first for safety

echo "Setting up eDIM"

# Check if Ruby is installed
if ! command -v ruby &> /dev/null; then
    echo "Ruby is not installed. Please install Ruby 3.2.1 first."
    exit 1
fi

# Check Ruby version
RUBY_VERSION=$(ruby -v | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
if [[ "$RUBY_VERSION" != "3.2.1" ]]; then
    echo "Warning: Expected Ruby 3.2.1, found $RUBY_VERSION"
    echo "   Consider using rbenv to install the correct version:"
    echo "   rbenv install 3.2.1 && rbenv local 3.2.1"
fi

# Install bundler if not present
if ! command -v bundle &> /dev/null; then
    echo "Installing Bundler..."
    gem install bundler
fi

# Install gems
echo "Installing gems..."
bundle install

# Copy configuration files
echo "Setting up configuration files..."

if [ ! -f "config/database.yml" ]; then
    cp config/database.yml.example config/database.yml
    echo "Created config/database.yml (please edit with your database credentials)"
else
    echo "config/database.yml already exists"
fi

if [ ! -f "config/application.yml" ]; then
    cp config/application.yml.example config/application.yml
    echo "Created config/application.yml"
else
    echo "config/application.yml already exists"
fi

if [ ! -f "config/secrets.yml" ]; then
    cp config/secrets.yml.example config/secrets.yml
    echo "Created config/secrets.yml (please add your secret keys)"
else
    echo "Config/secrets.yml already exists"
fi

# Check if database exists
echo "Setting up database..."
if bundle exec rake db:version &> /dev/null; then
    echo "Database already exists"
else
    echo "Creating database..."
    bundle exec rake db:create
    echo "Running migrations..."
    bundle exec rake db:migrate
    
    read -p "Would you like to seed the database with sample data? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        bundle exec rake db:seed
        echo "Database seeded"
    fi
fi

# Precompile assets
echo "Precompiling assets..."
bundle exec rake assets:precompile

echo ""
echo "Setup complete!"
echo "Next steps:"
echo "1. Edit config/database.yml with your database credentials"
echo "2. Edit config/secrets.yml and add secret keys (generate with: bundle exec rake secret)"
echo "3. Start the server: bundle exec rails server"
echo ""
echo "The application will be available at: http://localhost:3000"