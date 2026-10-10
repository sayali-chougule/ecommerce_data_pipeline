from pathlib import Path
import pandas as pd

RAW_DIR = Path("data/extracted")

csv_files = sorted(RAW_DIR.glob("*.csv"))

if not csv_files:
    raise FileNotFoundError("No CSV files found in data/")

for file_path in csv_files:
    print("\n" + "=" * 60)
    print(f"FILE: {file_path.name}")
    print("=" * 60)

    df = pd.read_csv(file_path)

    print(f"Rows: {df.shape[0]}")
    print(f"Columns: {df.shape[1]}")

    print("\nColumn names and data types:")
    print(df.dtypes.to_string())

    print("\nMissing values:")
    print(df.isnull().sum().to_string())

    print("\nDuplicate rows:")
    print(df.duplicated().sum())

    print("\nFirst 5 records:")
    print(df.head().to_string(index=False))
