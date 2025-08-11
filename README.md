<<<<<<< HEAD
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

## Quick start — (Ruby 3.2.1 / Rails 7.0.8)

These are steps for the upgraded environment.

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
=======
# eDIM : Electronic Dispensing and Inventory Management

Supply chain management for pharmaceuticals is one area of concern for low-resource settings. Most health facilities in this setting struggle with quantifying consumption, availability, and demand of pharmaceuticals. This affects the availability of these resources which are critical for the delivery of effective health care. 
 
 Our goal is to help pharmacists effectively and efficiently manage their resources 
  while providing quality pharmaceutical services. We believe an information
  system at the dispensary level will mitigate workflow challenges, improve provider communication, and enhance the process of medication 
  management. Therefore, we created a system for electronic dispensation and Inventory Management (eDIM) as an open source software 
  platform that is designed to facilitate dispensary workflow and improve medication and inventory management.
  
###   How to set up eDIM
  
  eDIM was developed with ruby 2.4.1 and rails 4. It is therefore required that before the application is deployed on a particular machine, Ruby 2.4.1 be installed.
  
  For users with a Linux-based operating system or Mac, instructions on how to install ruby can be found at https://gorails.com under the guides section.
  
  Once you have ruby installed, you can get a copy of the eDIM software from github.This can be achieved by running the following command from your terminal:
  
         git clone https://github.com/BaobabHealthTrust/eDIM.git
  
  Alternatively, you can download the application as a compressed Zip folder. 
  
  Now that you have the application on your computer, the following steps will help you configure the environment to run the application.
  
  1. Set up the gems utilized by the eDIM application. These are bundled together with the application and can be installed by running the following command: 
  
         bundle install
  
  2. Copy config/database.yml.example to config/database.yml
  
  3. Set up database details in config/database.yml
  
  4. Copy config/secrets.yml.example to config/secrets.yml
  
  5. Copy config/application.yml.example to config/application.yml
  
  6. Edit the config/application.yml file to reflect your configuration preferences. 
  
  7. Create the eDIM database. This is done by running the command:
  
         rake db:create db:migrate
        
  8. Pre-populate the database with pharmaceutical items:
     
         rake cmst:load

If all these steps have be run successfully, you should now have a fully functional instance of eDIM. You can start your application with the following command: rails s
>>>>>>> 92fd9b6 (Initial commit after resetting repository)
