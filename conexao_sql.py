import pandas as pd
from sqlalchemy import create_engine

df = pd.read_csv("online_retail_cleaned.csv")

df = df.rename(columns={"Customer ID": "CustomerID"})
df["InvoiceDate"] = pd.to_datetime(df["InvoiceDate"])
df["CustomerID"] = df["CustomerID"].astype("Int64")

# Troque SUA_SENHA pela senha do seu MySQL local
engine = create_engine("mysql+pymysql://root:SUA_SENHA@localhost:3306/online_retail")
df.to_sql("vendas", engine, if_exists="append", index=False, chunksize=10000)

print("Linhas enviadas:", len(df))