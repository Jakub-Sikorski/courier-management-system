# Courier Logistics Management System

## Project Overview
This project is a full-stack relational database application designed to manage the end-to-end logistics of a courier company. It features a PostgreSQL backend with automated triggers and a dynamic Python frontend equipped with role-based access control.

## Tech Stack
* **Database:** PostgreSQL (PL/pgSQL, Triggers, Views, Constraints)
* **Frontend/Backend Logic:** Python (Streamlit, Pandas, Psycopg2)

## Key Features
* **Role-Based Access Control:** Dedicated interactive dashboards for Clients, Couriers, Warehouse Workers, and Sorters.
* **Automated Package Tracking:** Custom PostgreSQL triggers (e.g., `trg_historia_paczki`) automatically log every status change and location update into the history table.
* **Smart Routing System:** SQL Views (`widok_sugerowane_oddzialy`) dynamically assign packages to correct delivery branches based on postal code ranges.
* **Data Integrity Validation:** Strict database-level constraints ensure that package dimensions (length <= 64cm, mass, etc.) and phone numbers meet business rules.
* **Courier Assignment Logic:** Triggers validate if a courier belongs to the correct branch before assigning a package, automatically updating the package status to "Przekazana kurierowi".

## Database Architecture Highlights
The PostgreSQL schema is highly normalized and relies heavily on database-side logic to ensure performance and data consistency:
* **Views:** Simplifies complex joins for the frontend (e.g., `widok_klienta`, `widok_kuriera`).
* **Triggers & Functions:** `log_historia_paczki` and `trg_przypisanie_kuriera` handle business logic directly within the database engine.
* **Cascading Relations:** Managed foreign keys (`ON UPDATE CASCADE ON DELETE RESTRICT`) ensure safe data operations across Users, Addresses, Branches, and Packages tables.

## How to run locally
1. Execute `schema.sql` in your PostgreSQL environment to build tables, views, and triggers.
2. Execute `inserts.sql` to populate the database with initial infrastructure and test scenarios.
3. Update the database connection credentials in `app.py`.
4. Run the app using: `streamlit run app.py`
