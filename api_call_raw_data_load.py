"""
Databricks Community notebook: ingest_steamspy_detailed
Fetches FULL app details from SteamSpy including languages and tags.
"""

import requests
import sys
import time
from pyspark.sql import SparkSession,functions as F
from pyspark.sql.types import StructType, StructField, LongType, StringType, IntegerType, DoubleType
from datetime import datetime, timezone


# ── Configuration ─────────────────────────────────────────────────────────────

STEAMSPY_BASE = "https://steamspy.com/api.php"
TARGET_TABLE = "raw_steam.raw_apps"
REQUEST_TIMEOUT = 30
MAX_APPS = 100  # Reduced due to per-app API calls (rate limit: 1 sec between calls)


# ── Schema with 17 columns ───────────────────────────────────────────────────

APP_SCHEMA = StructType([
    StructField("appid", LongType(), True),
    StructField("name", StringType(), True),
    StructField("developer", StringType(), True),
    StructField("publisher", StringType(), True),
    StructField("score_rank", IntegerType(), True),
    StructField("owners", StringType(), True),
    StructField("average_forever", IntegerType(), True),
    StructField("average_2weeks", IntegerType(), True),
    StructField("median_forever", IntegerType(), True),
    StructField("median_2weeks", IntegerType(), True),
    StructField("ccu", IntegerType(), True),
    StructField("price", DoubleType(), True),
    StructField("initialprice", DoubleType(), True),
    StructField("discount", IntegerType(), True),
    StructField("tags", StringType(), True),
    StructField("languages", StringType(), True),
    StructField("genre", StringType(), True)
])


# ── Helper: Safe conversion ─────────────────────────────────────────────────

def safe_int(value, default=0):
    if value is None:
        return default
    try:
        return int(value)
    except (ValueError, TypeError):
        return default


def safe_float_cents_to_dollars(value, default=0.0):
    if value is None:
        return default
    try:
        cents = int(value)
        return round(cents / 100, 2)
    except (ValueError, TypeError):
        return default


# ── Functions ─────────────────────────────────────────────────────────────────

def fetch_app_list():
    """
    Fetch list of all app IDs (lightweight).
    """
    table_exists = spark.catalog.tableExists(TARGET_TABLE)
    if table_exists:
        existing_ids_df = spark.sql(f"SELECT DISTINCT appid FROM {TARGET_TABLE}")
        existing_ids = set(row['appid'] for row in existing_ids_df.collect())
    else:
        existing_ids = set()

    new_ids = []
    page = 0
    while len(new_ids) < MAX_APPS:
        url = f"{STEAMSPY_BASE}?request=all&page={page}"
        try:
            response = requests.get(url, timeout=REQUEST_TIMEOUT)
            response.raise_for_status()
            data = response.json()
        except Exception as e:
            print(f"ERROR fetching page {page}: {e}")
            break

        if not data:  # empty page = no more data
            break

        page_ids = [aid for aid in data.keys() if int(aid) not in existing_ids]
        new_ids.extend(page_ids)
        page += 1
        time.sleep(1)  # be polite between page requests too

    return new_ids[:MAX_APPS]


def fetch_app_details(appid):
    """
    Fetch FULL details for a single app including languages and tags.
    """
    url = f"{STEAMSPY_BASE}?request=appdetails&appid={appid}"
    
    try:
        response = requests.get(url, timeout=REQUEST_TIMEOUT)
        response.raise_for_status()
        app_data = response.json()
        
        # Extract tags as comma-separated string
        tags_dict = app_data.get("tags", {})
        if isinstance(tags_dict, dict):
            top_tags = sorted(tags_dict.items(), key=lambda x: x[1], reverse=True)[:5]
            tags_str = ", ".join([tag for tag, _ in top_tags])
        else:
            tags_str = ""
        
        # Extract languages (comes as string like "English, French, German")
        languages_str = str(app_data.get("languages", ""))
        
        return {
            "appid": safe_int(appid),
            "name": str(app_data.get("name", "")),
            "developer": str(app_data.get("developer", "")),
            "publisher": str(app_data.get("publisher", "")),
            "score_rank": safe_int(app_data.get("score_rank")),
            "owners": str(app_data.get("owners", "0")),
            "average_forever": safe_int(app_data.get("average_forever")),
            "average_2weeks": safe_int(app_data.get("average_2weeks")),
            "median_forever": safe_int(app_data.get("median_forever")),
            "median_2weeks": safe_int(app_data.get("median_2weeks")),
            "ccu": safe_int(app_data.get("ccu")),
            "price": safe_float_cents_to_dollars(app_data.get("price")),
            "initialprice": safe_float_cents_to_dollars(app_data.get("initialprice")),
            "discount": safe_int(app_data.get("discount")),
            "tags": tags_str,
            "languages": languages_str,
            "genre": str(app_data.get("genre", ""))
        }
        
    except Exception as e:
        print(f"  ERROR fetching app {appid}: {e}")
        return None


def fetch_all_app_details(app_ids):
    """
    Fetch details for all apps with rate limiting.
    """
    apps = []
    
    for i, appid in enumerate(app_ids):
        print(f"Fetching {i+1}/{len(app_ids)}: appid {appid}...")
        
        details = fetch_app_details(appid)
        if details:
            apps.append(details)
        
        # Rate limit: 1 second between calls (SteamSpy limit)
        time.sleep(1)
    
    return apps


# ── DataFrame and Save Functions ──────────────────────────────────────────────

def create_dataframe(spark, apps):
    if not apps:
        print("WARNING: No apps to load")
        return None

    try:
        df = spark.createDataFrame(apps, schema=APP_SCHEMA)
        print(f"Created DataFrame: {df.count()} rows, {len(df.columns)} columns")
        return df
        
    except Exception as e:
        print(f"ERROR: Failed to create DataFrame: {e}")
        return None


def save_to_delta(df, table_name):
    try:
        schema_name = table_name.split(".")[0]
        spark.sql(f"CREATE SCHEMA IF NOT EXISTS {schema_name}")
        
        df.write \
            .mode("append") \
            .option("mergeSchema", "true") \
            .format("delta") \
            .saveAsTable(table_name)
            
        print(f"Saved to {table_name}")
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to write Delta table: {e}")
        return False


def verify_table(spark, table_name):
    try:
        count = spark.table(table_name).count()
        print(f"\nTable {table_name}: {count:,} rows")
        
        print("\nSample data (first 3 rows):")
        spark.table(table_name).show(3, truncate=False)
        
        # Check null percentages
        print("\nNull check for languages and tags:")
        spark.sql(f"""
            SELECT 
                COUNT(*) as total,
                SUM(CASE WHEN languages IS NULL OR languages = '' THEN 1 ELSE 0 END) as null_languages,
                SUM(CASE WHEN tags IS NULL OR tags = '' THEN 1 ELSE 0 END) as null_tags
            FROM {table_name}
        """).show()
        
        return True
        
    except Exception as e:
        print(f"ERROR: Failed to verify table: {e}")
        return False


# ── Main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print("SteamSpy Detailed App Ingestion")
    print("=" * 55)
    
    spark = SparkSession.builder.getOrCreate()
    
    # Step 1: Fetch app IDs
    print("\nFetching app list...")
    app_ids = fetch_app_list()
    if not app_ids:
        print("Failed to fetch app list")
        sys.exit(1)
    print(f"Found {len(app_ids)} apps to fetch")
    
    # Step 2: Fetch detailed data for each app
    print(f"\nFetching details for {len(app_ids)} apps (this will take ~{len(app_ids)} seconds)...")
    apps = fetch_all_app_details(app_ids)
    
    if not apps:
        print("No app details fetched")
        sys.exit(1)
    
    # Step 3: Create DataFrame
    df = create_dataframe(spark, apps)
    # Add ingestion timestamp - same value for every row in this batch
    df = df.withColumn('loaded_at', F.current_timestamp())
    if df is None:
        sys.exit(1)
    
    # Step 4: Save to Delta
    success = save_to_delta(df, TARGET_TABLE)
    if not success:
        sys.exit(1)
    
    # Step 5: Verify
    verify_table(spark, TARGET_TABLE)
    
    print("\nPipeline completed successfully.")
    return 0


if __name__ == "__main__":
    main()
