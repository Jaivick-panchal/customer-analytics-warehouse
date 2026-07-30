from faker import Faker
import pandas as pd
import random
from datetime import date

fake = Faker('en_IN')
random.seed(42)
Faker.seed(42)

cities = ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Pune', 'Kolkata', 'Ahmedabad']
age_groups = ['18-25', '26-35', '36-45', '46-60']
channels = ['Organic', 'Referral', 'Google Ads', 'Social Media', 'App Store']

customers = []
for i in range(1, 5001):
    customers.append({
        'customer_id': i,
        'name': fake.name(),
        'city': random.choice(cities),
        'age_group': random.choice(age_groups),
        'acquisition_channel': random.choice(channels)
    })

df_customer = pd.DataFrame(customers)

cities = ['Mumbai', 'Delhi', 'Bangalore', 'Hyderabad', 'Chennai', 'Pune', 'Kolkata', 'Ahmedabad']
age_groups = ['18-25', '26-35', '36-45', '46-60']
channels = ['Organic', 'Referral', 'Google Ads', 'Social Media', 'App Store']

customers = []
for i in range(1, 5001):
    customers.append({
        'customer_id': i,
        'name': fake.name(),
        'city': random.choice(cities),
        'age_group': random.choice(age_groups),
        'acquisition_channel': random.choice(channels)
    })

df_customer = pd.DataFrame(customers)

products_data = [
    ('Smartphone', 'Electronics', 15000), ('Laptop', 'Electronics', 55000),
    ('Earbuds', 'Electronics', 3000), ('Smartwatch', 'Electronics', 8000),
    ('T-Shirt', 'Fashion', 500), ('Jeans', 'Fashion', 1500),
    ('Sneakers', 'Fashion', 3000), ('Kurta', 'Fashion', 800),
    ('Rice 5kg', 'Groceries', 300), ('Cooking Oil', 'Groceries', 200),
    ('Protein Powder', 'Health', 2000), ('Yoga Mat', 'Health', 800),
    ('Novel', 'Books', 400), ('Textbook', 'Books', 600),
    ('Face Wash', 'Beauty', 300), ('Moisturizer', 'Beauty', 500)
]

products = []
for i, (name, cat, price) in enumerate(products_data, start=1):
    products.append({
        'product_id': i,
        'product_name': name,
        'category': cat,
        'price': price
    })

df_product = pd.DataFrame(products)

merchant_categories = ['Electronics Store', 'Fashion Outlet', 'Grocery Store', 'Pharmacy', 'Bookstore']

merchants = []
for i in range(1, 101):
    merchants.append({
        'merchant_id': i,
        'merchant_name': fake.company(),
        'city': random.choice(cities),
        'category': random.choice(merchant_categories)
    })

df_merchant = pd.DataFrame(merchants)

dates = []
date_id = 1
for year in [2023, 2024]:
    for month in range(1, 13):
        for day in range(1, 32):
            try:
                d = date(year, month, day)
                dates.append({
                    'date_id': date_id,
                    'date': d,
                    'day': d.day,
                    'month': d.month,
                    'quarter': (d.month - 1) // 3 + 1,
                    'year': d.year,
                    'is_weekend': d.weekday() >= 5
                })
                date_id += 1
            except ValueError:
                pass

df_date = pd.DataFrame(dates)

payment_methods = ['UPI', 'Credit Card', 'Debit Card', 'Net Banking', 'Wallet']
statuses = ['Success', 'Success', 'Success', 'Failed', 'Refunded']
# Success appears 3x so it's more likely — realistic distribution

transactions = []
for i in range(1, 50001):
    cust_id = random.randint(1, 5000)
    prod_id = random.randint(1, 16)
    merch_id = random.randint(1, 100)
    date_id = random.randint(1, len(df_date))
    base_price = df_product.loc[df_product['product_id'] == prod_id, 'price'].values[0]
    amount = round(base_price * random.uniform(0.9, 1.1), 2)  # slight price variation

    transactions.append({
        'transaction_id': i,
        'customer_id': cust_id,
        'product_id': prod_id,
        'merchant_id': merch_id,
        'date_id': date_id,
        'amount': amount,
        'payment_method': random.choice(payment_methods),
        'status': random.choice(statuses)
    })

df_transaction = pd.DataFrame(transactions)

from sqlalchemy import create_engine

engine = create_engine('postgresql://postgres:Jaivick%402204@localhost:5432/Customer_Analytics')

df_customer.to_sql('dim_customer', engine, if_exists='append', index=False)
print("✅ dim_customer loaded")

df_product.to_sql('dim_product', engine, if_exists='append', index=False)
print("✅ dim_product loaded")

df_merchant.to_sql('dim_merchant', engine, if_exists='append', index=False)
print("✅ dim_merchant loaded")

df_date.to_sql('dim_date', engine, if_exists='append', index=False)
print("✅ dim_date loaded")

df_transaction.to_sql('fact_transactions', engine, if_exists='append', index=False)
print("✅ fact_transactions loaded")

print("\n🎉 All data loaded successfully!")