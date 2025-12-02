import pymysql
import random
from datetime import datetime, timedelta

# Database config
DB_HOST = "localhost"
DB_USER = "root"
DB_PASSWORD = "password"
DB_NAME = "billing_import"

conn = pymysql.connect(
    host=DB_HOST,
    user=DB_USER,
    password=DB_PASSWORD,
    database=DB_NAME,
    autocommit=True
)

cursor = conn.cursor()

# Settings
NUM_PREPACKS = 50        # number of prepacks to create
MAX_LABELS_PER_PREPACK = 5
BOTTLE_IDS = [80, 81, 82, 83, 84]  # example bottle ids
DRUG_IDS = [13, 41, 128, 121, 3063]  # example drug ids
LOCATION_IDS = [3]  # example location

# Generate prepacks for past 2 months
today = datetime.today()
start_date = today - timedelta(days=60)

for _ in range(NUM_PREPACKS):
    created_at = start_date + timedelta(days=random.randint(0, 60),
                                        hours=random.randint(0,23),
                                        minutes=random.randint(0,59))
    bottle_id = random.choice(BOTTLE_IDS)
    drug_id = random.choice(DRUG_IDS)
    quantity_per_pack = random.choice([30, 36, 60])
    num_packs = random.randint(5, 40)
    total_quantity = quantity_per_pack * num_packs
    location_id = random.choice(LOCATION_IDS)
    directions = "Take as prescribed"
    prepacked_by_id = 1
    status = "created"

    # Insert into prepacks
    cursor.execute("""
        INSERT INTO prepacks (bottle_id, drug_id, quantity_per_pack, num_packs, total_quantity,
                              directions, prepacked_by_id, status, created_at, updated_at, gn_identifier, location_id)
        VALUES (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)
    """, (
        bottle_id, drug_id, quantity_per_pack, num_packs, total_quantity,
        directions, prepacked_by_id, status, created_at, created_at, f"TEST-{random.randint(1000,9999)}", location_id
    ))

    prepack_id = cursor.lastrowid

    # Insert prepack_labels
    for i in range(1, random.randint(1, MAX_LABELS_PER_PREPACK)+1):
        dispensed = random.choice([0,1])
        label_identifier = f"PK-{bottle_id:03d}-{prepack_id}-{i}"
        cursor.execute("""
            INSERT INTO prepack_labels (prepack_id, bottle_id, label_identifier, dispensed, created_at, updated_at)
            VALUES (%s,%s,%s,%s,%s,%s)
        """, (
            prepack_id, bottle_id, label_identifier, dispensed, created_at, created_at
        ))

print("Done generating test prepacks and labels!")
cursor.close()
conn.close()
