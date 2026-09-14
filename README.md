# Steam Data Pipeline: Databricks + dbt + Power BI

An end-to-end analytics pipeline that ingests data from Steam, lands it in Databricks, transforms it with dbt, and visualizes the results in Power BI.

## Architecture Overview

```
Steam API  -->  Python Ingestion Script  -->  Databricks (Raw Table)
                                                     |
                                                     v
                                              dbt Models (Transform)
                                                     |
                                                     v
                                              Power BI (Reporting)
```

## Prerequisites

1. **Databricks Free Edition account** — Sign up and set up a workspace, including a SQL Warehouse (or cluster) and at least one catalog/schema to land raw and transformed data.
2. **dbt installed locally, with VS Code for terminal access** — Install `dbt-core` in a Python virtual environment and use VS Code's integrated terminal to run dbt commands.
3. **`dbt-databricks` adapter installed in dbt** — This adapter lets dbt connect to and run models against your Databricks workspace.
4. **Power BI Desktop** — Installed locally for building and publishing reports, with the ability to connect to Databricks via ODBC/native connector.

## Steps

### 1. Retrieve Data from Steam

Pull data directly from Steam's available endpoints (e.g., the Steam Web API or Steamspy, depending on what data you need — player counts, app/game metadata, pricing, reviews, etc.). Review Steam's API documentation and terms of use before pulling data, and note any authentication or rate-limit requirements for the specific endpoint you use.

### 2. Develop and run a Python Ingestion Script

Using an AI coding tool of your choice (e.g., Claude, GitHub Copilot, ChatGPT), develop a Python script that:
- Calls the Steam endpoint(s) and retrieves the desired data (handle pagination and rate limits as needed).
- Performs light validation/cleaning if necessary (e.g., type casting, handling nulls).
- Pushes the resulting data into a **raw table** in a Databricks schema, using a library such as `databricks-sql-connector` or the Databricks SDK to write directly, or by staging the data as a file (CSV/Parquet) and loading it via a Databricks notebook or SQL `COPY INTO` command.

Recommended raw table naming convention: `raw.steam_<entity_name>` (e.g., `raw.steam_games`, `raw.steam_player_counts`).
This script has to be run as a Databricks job.

### 3. Develop dbt Models

Set up a dbt project locally (`dbt init`) and build your transformation layer on top of the raw table(s):
- **Staging models** — Clean and standardize column names/types from the raw source.
- **Intermediate/mart models** — Apply business logic, joins, and aggregations needed for reporting.
- Follow standard dbt project structure (`models/staging`, `models/marts`, etc.) and add `sources.yml` to document the raw table(s) as a dbt source.

### 4. Configure `profiles.yml` for Databricks

In your local dbt `profiles.yml` (typically located at `~/.dbt/profiles.yml`), configure a target that connects to your Databricks Free Edition workspace. You will need:
- **Hostname** — Your Databricks workspace URL (found under workspace settings or the SQL Warehouse connection details).
- **HTTP Path** — The path to your SQL Warehouse or cluster (also found in the connection details page).
- **Access Token** — A personal access token generated from Databricks (User Settings → Developer → Access Tokens).

Example structure (adapt values to your environment):

```yaml
your_profile_name:
  target: dev
  outputs:
    dev:
      type: databricks
      catalog: your_catalog
      schema: your_schema
      host: your-databricks-hostname
      http_path: your-http-path
      token: your-access-token
      threads: 4
```

### 5. Run dbt and Verify Output

Run your dbt models:

```bash
dbt run
```

Then log in to your Databricks workspace and verify that the expected tables/views have been created in the target schema, with the correct row counts and transformations applied. Use `dbt test` to run any data quality tests you've defined.

### Note : The Steps 2,3,4 and 5 can be automated as a Github Actions workflow.

### 6. Connect Power BI to Databricks

In Power BI Desktop:
1. Go to **Get Data** → search for **Databricks** (or Azure Databricks, depending on your Power BI version).
2. Enter your Databricks **hostname** and **HTTP path**.
3. Authenticate using your Databricks personal access token.
4. Select the schema/tables produced by your dbt models and load them into Power BI.
5. Build your reports and visuals on top of the loaded data.

## Notes

- Keep your Databricks access token and any Steam API credentials out of source control — use environment variables or a secrets manager instead of hardcoding them in scripts or `profiles.yml`.
- Re-run `dbt run` whenever the raw data is refreshed, and consider scheduling the Python ingestion script (e.g., via a cron job or Databricks job) for recurring updates.
