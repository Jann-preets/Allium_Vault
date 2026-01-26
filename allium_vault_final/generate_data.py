import pandas as pd
import numpy as np
from datetime import datetime, timedelta

print("Generating synthetic onion spoilage data...")

# Configuration
num_records = 5000
start_date = datetime(2024, 1, 1)

# Generate a time series of hourly data
timestamps = [start_date + timedelta(hours=i) for i in range(num_records)]

# Generate sensor data with seasonal patterns and random noise
# Temperature is higher in the middle of the year (summer)
temperatures = 25 + 5 * np.sin(np.arange(num_records) * 2 * np.pi / (365 * 24)) + np.random.normal(0, 1.5, num_records)
# Humidity is lower when temperature is higher
humidities = 70 + 10 * np.sin(np.arange(num_records) * 2 * np.pi / (365 * 24) + np.pi) + np.random.normal(0, 3, num_records)
gas_levels = 20 + 15 * np.random.rand(num_records)

# Create a Pandas DataFrame to organize the data
df = pd.DataFrame({
    'timestamp': timestamps,
    'temperature': temperatures,
    'humidity': humidities,
    'gas_level': gas_levels
})

# --- Feature Engineering ---
# The AI doesn't look at single readings, it looks at 24-hour trends.
df['avg_temp_24h'] = df['temperature'].rolling(window=24).mean()
df['avg_humidity_24h'] = df['humidity'].rolling(window=24).mean()
df['peak_gas_24h'] = df['gas_level'].rolling(window=24).max()

# Remove initial rows that don't have a full 24-hour window
df.dropna(inplace=True)

# --- Create the Target Variable ---
# We define the rules for what causes spoilage in our synthetic world.
df['spoilage_risk'] = 0
# High humidity AND high temperature is a major risk factor
df.loc[(df['avg_humidity_24h'] > 78) & (df['avg_temp_24h'] > 28), 'spoilage_risk'] = 1
# Very high humidity alone is also a strong indicator
df.loc[(df['avg_humidity_24h'] > 82), 'spoilage_risk'] = 1

# Add some randomness to make the data more realistic
random_spoilage_indices = df.sample(frac=0.05).index
df.loc[random_spoilage_indices, 'spoilage_risk'] = 1

# Select the final columns for our training dataset
final_df = df[['avg_temp_24h', 'avg_humidity_24h', 'peak_gas_24h', 'spoilage_risk']]

# Save the final dataset to a CSV file
output_path = 'synthetic_onion_data.csv'
final_df.to_csv(output_path, index=False)

print(f"\nSuccessfully generated {len(final_df)} records.")
print(f"Data saved to {output_path}")
print("\nNext step: Upload this CSV file to your Google Colab notebook.")
