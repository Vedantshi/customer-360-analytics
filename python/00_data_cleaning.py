# =============================================================================
# Customer 360: Data Cleaning Pipeline
# Script: 00_data_cleaning.py
# Purpose: Clean raw Online Retail II dataset for downstream SQL and Power BI
# Input:  ../data/online_retail_raw.csv (1,067,371 rows)
# Output: ../data/online_retail_cleaned.csv (~400K rows)
# =============================================================================

import pandas as pd
import numpy as np

# --- LOAD RAW DATA ---
# encoding='latin-1' handles special characters in product descriptions
# If your file is named differently, change the path below
df = pd.read_csv(r'D:\Projects\Customer 360\customer-360-analytics\data\online_retail_raw.csv', encoding='latin-1')
print(f'Raw dataset: {len(df):,} rows, {df.shape[1]} columns')
print(f'Columns found: {list(df.columns)}')

rename_map = {
    'Invoice': 'InvoiceNo',
    'Price': 'UnitPrice',
    'Customer ID': 'CustomerID'
}
# Only rename columns that actually exist in the dataframe
rename_map = {k: v for k, v in rename_map.items() if k in df.columns}
df.rename(columns=rename_map, inplace=True)
print(f'Columns after rename: {list(df.columns)}')

# --- CLEANING LOG ---
# Track row count after each cleaning step for documentation
log = {}
log['raw_rows'] = len(df)

# Step 1: Remove null CustomerIDs
# ~24% of rows have no CustomerID. Without an identifier,
# we cannot perform any customer-level analysis.
null_count = df['CustomerID'].isna().sum()
print(f'Null CustomerIDs found: {null_count:,} ({null_count/len(df)*100:.1f}%)')
df = df.dropna(subset=['CustomerID'])
df['CustomerID'] = df['CustomerID'].astype(int)  # Convert from float to int
log['after_null_removal'] = len(df)

# Step 2: Remove cancellations (C-prefix invoices)
# Cancelled orders start with 'C'. They inflate revenue and order counts.
cancel_count = df[df['InvoiceNo'].astype(str).str.startswith('C')].shape[0]
print(f'Cancellation rows found: {cancel_count:,}')
df = df[~df['InvoiceNo'].astype(str).str.startswith('C')]
log['after_cancellation_removal'] = len(df)

# Step 3: Remove negative/zero quantities and prices
# Negative quantities = returns. Zero prices = free samples or data entry errors.
neg_qty = (df['Quantity'] <= 0).sum()
zero_price = (df['UnitPrice'] <= 0).sum()
print(f'Negative/zero quantity rows: {neg_qty:,}')
print(f'Zero/negative price rows: {zero_price:,}')
df = df[(df['Quantity'] > 0) & (df['UnitPrice'] > 0)]
log['after_qty_price_filter'] = len(df)

# Step 4: Standardise dates to datetime format
# errors='coerce' converts any unparseable dates to NaT (null)
df['InvoiceDate'] = pd.to_datetime(df['InvoiceDate'], errors='coerce')
bad_dates = df['InvoiceDate'].isna().sum()
print(f'Unparseable dates: {bad_dates}')
df = df.dropna(subset=['InvoiceDate'])

# Step 5: Create Revenue column
# Revenue = Quantity x UnitPrice (per line item)
df['Revenue'] = df['Quantity'] * df['UnitPrice']

# Step 6: Cap outliers (Revenue > 99.5th percentile)
# Extreme outliers distort averages and visualisations
cap = df['Revenue'].quantile(0.995)
print(f'Revenue cap at 99.5th percentile: {cap:.2f}')
df['Revenue_Capped'] = df['Revenue'].clip(upper=cap)

# Step 7: Add derived columns for downstream analysis
df['InvoiceMonth'] = df['InvoiceDate'].dt.to_period('M')
df['DayOfWeek'] = df['InvoiceDate'].dt.day_name()
df['Hour'] = df['InvoiceDate'].dt.hour

# --- EXPORT CLEANED DATA ---
df.to_csv('../data/online_retail_cleaned.csv', index=False)
print(f'\nCleaned file saved to: ../data/online_retail_cleaned.csv')

# --- VALIDATION LOG ---
print('\n' + '='*50)
print('CLEANING SUMMARY')
print('='*50)
for step_name, count in log.items():
    print(f'  {step_name}: {count:,} rows')
print(f'\nFinal cleaned dataset: {len(df):,} rows, {df.shape[1]} columns')
print(f'Unique customers: {df["CustomerID"].nunique():,}')
print(f'Unique invoices: {df["InvoiceNo"].nunique():,}')
print(f'Date range: {df["InvoiceDate"].min()} to {df["InvoiceDate"].max()}')
print(f'Countries: {df["Country"].nunique()}')
print(f'Total revenue: {df["Revenue"].sum():,.2f}')