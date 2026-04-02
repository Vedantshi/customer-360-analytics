# =============================================================================
# Customer 360: Exploratory Data Analysis
# Script: 09_visualization_eda.py
# Purpose: Generate visual summaries of the cleaned dataset
# =============================================================================

import pandas as pd
import matplotlib.pyplot as plt
import seaborn as sns

# Load cleaned data
df = pd.read_csv('../data/online_retail_cleaned.csv')
df['InvoiceDate'] = pd.to_datetime(df['InvoiceDate'])

# Set style
sns.set_style('whitegrid')
plt.rcParams['figure.figsize'] = (10, 6)

# Chart 1: Monthly Revenue Trend
monthly = df.groupby(df['InvoiceDate'].dt.to_period('M'))['Revenue'].sum()
monthly.index = monthly.index.to_timestamp()
plt.figure()
plt.plot(monthly.index, monthly.values, marker='o', linewidth=2)
plt.title('Monthly Revenue Trend (Dec 2009 - Dec 2011)')
plt.xlabel('Month')
plt.ylabel('Revenue (GBP)')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('../screenshots/eda_monthly_revenue.png', dpi=150)
plt.close()
print('Chart 1 saved: eda_monthly_revenue.png')

# Chart 2: Top 10 Countries by Revenue
country_rev = df.groupby('Country')['Revenue'].sum().nlargest(10)
plt.figure()
country_rev.plot(kind='barh', color='steelblue')
plt.title('Top 10 Countries by Revenue')
plt.xlabel('Revenue (GBP)')
plt.tight_layout()
plt.savefig('../screenshots/eda_top_countries.png', dpi=150)
plt.close()
print('Chart 2 saved: eda_top_countries.png')

# Chart 3: Orders by Day of Week
dow_order = ['Monday','Tuesday','Wednesday','Thursday','Friday','Sunday']
dow = df['DayOfWeek'].value_counts().reindex(dow_order)
plt.figure()
dow.plot(kind='bar', color='steelblue')
plt.title('Transaction Count by Day of Week')
plt.ylabel('Number of Transactions')
plt.xticks(rotation=45)
plt.tight_layout()
plt.savefig('../screenshots/eda_day_of_week.png', dpi=150)
plt.close()
print('Chart 3 saved: eda_day_of_week.png')

# Chart 4: Revenue Distribution (Histogram)
plt.figure()
df[df['Revenue'] < 100]['Revenue'].hist(bins=50, color='steelblue', edgecolor='white')
plt.title('Revenue Distribution per Line Item (< 100 GBP)')
plt.xlabel('Revenue (GBP)')
plt.ylabel('Frequency')
plt.tight_layout()
plt.savefig('../screenshots/eda_revenue_distribution.png', dpi=150)
plt.close()
print('Chart 4 saved: eda_revenue_distribution.png')

print('\nAll EDA charts saved to screenshots/ folder.')
