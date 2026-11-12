import json
import time
import pandas as pd
import pymongo

print("A ler os CSV de data/processed/ ...")
df_movies = pd.read_csv("data/processed/movies.csv")
df_genres = pd.read_csv("data/processed/genres.csv")
df_movie_genres = pd.read_csv("data/processed/movie_genres.csv")
df_ratings = pd.read_csv("data/processed/ratings.csv")
df_tags = pd.read_csv("data/processed/tags.csv")
df_users = pd.read_csv("data/processed/users.csv")

if len(df_ratings) > 100000:
    df_ratings = df_ratings.sample(n=100000, random_state=42).reset_index(drop=True)

df_ratings["timestamp"] = pd.to_datetime(df_ratings["timestamp"])
df_tags["timestamp"] = pd.to_datetime(df_tags["timestamp"])


def valor_ou_none(v):
    return None if pd.isna(v) else int(v)


mg_merged = df_movie_genres.merge(df_genres, on="genreId", how="left")
genres_by_movie = mg_merged.groupby("movieId")["genre"].apply(list).to_dict()

rating_stats = df_ratings.groupby("movieId")["rating"].agg(
    ratingCount="count",
    avgRating=lambda s: round(float(s.mean()), 2)
).to_dict(orient="index")

movies_docs = []
for _, row in df_movies.iterrows():
    m_id = int(row["movieId"])
    stats = rating_stats.get(m_id, {"ratingCount": 0, "avgRating": 0.0})

    doc = {
        "_id": m_id,
        "title": str(row["title"]).strip(),
        "year": valor_ou_none(row["year"]),
        "imdbId": valor_ou_none(row["imdbId"]),
        "tmdbId": valor_ou_none(row["tmdbId"]),
        "genres": genres_by_movie.get(m_id, []),
        "ratingStats": {
            "ratingCount": int(stats["ratingCount"]),
            "avgRating": float(stats["avgRating"])
        }
    }
    movies_docs.append(doc)

with open("data/processed/movies_mongo.json", "w", encoding="utf-8") as f:
    json.dump(movies_docs, f, indent=2, ensure_ascii=False)

ratings_docs = []
for _, row in df_ratings.iterrows():
    u_id = int(row["userId"])
    m_id = int(row["movieId"])
    ratings_docs.append({
        "_id": f"{u_id}_{m_id}",
        "userId": u_id,
        "movieId": m_id,
        "rating": float(row["rating"]),
        "timestamp": row["timestamp"].to_pydatetime()
    })

tags_by_user = {}
for _, row in df_tags.iterrows():
    u_id = int(row["userId"])
    tags_by_user.setdefault(u_id, []).append({
        "movieId": int(row["movieId"]),
        "tag": str(row["tag"]),
        "timestamp": row["timestamp"].to_pydatetime()
    })

user_rating_counts = df_ratings.groupby("userId").size().to_dict()
users_docs = []
for _, row in df_users.iterrows():
    u_id = int(row["userId"])
    users_docs.append({
        "_id": u_id,
        "userId": u_id,
        "totalRatingsGiven": int(user_rating_counts.get(u_id, 0)),
        "tags": tags_by_user.get(u_id, [])
    })

print(f"Documentos construídos: movies={len(movies_docs)}, "
      f"ratings={len(ratings_docs)}, users={len(users_docs)}")


client = pymongo.MongoClient("mongodb://localhost:27017/")
db = client["bda_movielens"]

db["movies"].drop()
db["ratings"].drop()
db["users"].drop()

movies_validator = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "title", "genres", "ratingStats"],
        "properties": {
            "_id": {"bsonType": "int"},
            "title": {"bsonType": "string", "minLength": 1},
            "year": {"bsonType": ["int", "null"]},
            "imdbId": {"bsonType": ["int", "null"]},
            "tmdbId": {"bsonType": ["int", "null"]},
            "genres": {
                "bsonType": "array",
                "items": {"bsonType": "string"}
            },
            "ratingStats": {
                "bsonType": "object",
                "required": ["ratingCount", "avgRating"],
                "properties": {
                    "ratingCount": {"bsonType": "int", "minimum": 0},
                    "avgRating": {"bsonType": ["double", "int"], "minimum": 0.0, "maximum": 5.0}
                }
            }
        }
    }
}
db.create_collection("movies", validator=movies_validator)

ratings_validator = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "userId", "movieId", "rating", "timestamp"],
        "properties": {
            "_id": {"bsonType": "string"},
            "userId": {"bsonType": "int"},
            "movieId": {"bsonType": "int"},
            "rating": {"bsonType": ["double", "int"], "minimum": 0.5, "maximum": 5.0},
            "timestamp": {"bsonType": "date"}
        }
    }
}
db.create_collection("ratings", validator=ratings_validator)

users_validator = {
    "$jsonSchema": {
        "bsonType": "object",
        "required": ["_id", "userId", "totalRatingsGiven", "tags"],
        "properties": {
            "_id": {"bsonType": "int"},
            "userId": {"bsonType": "int"},
            "totalRatingsGiven": {"bsonType": "int", "minimum": 0},
            "tags": {
                "bsonType": "array",
                "items": {
                    "bsonType": "object",
                    "required": ["movieId", "tag", "timestamp"],
                    "properties": {
                        "movieId": {"bsonType": "int"},
                        "tag": {"bsonType": "string"},
                        "timestamp": {"bsonType": "date"}
                    }
                }
            }
        }
    }
}
db.create_collection("users", validator=users_validator)
print("3 coleções MongoDB criadas com validação $jsonSchema.")


start_time = time.perf_counter()

t0 = time.perf_counter()
db["movies"].insert_many(movies_docs, ordered=False)
t_movies = time.perf_counter() - t0

t0 = time.perf_counter()
db["users"].insert_many(users_docs, ordered=False)
t_users = time.perf_counter() - t0

t0 = time.perf_counter()
db["ratings"].insert_many(ratings_docs, ordered=False)
t_ratings = time.perf_counter() - t0

total_ingestion_time = time.perf_counter() - start_time

print("\n=== Tempos de ingestão no MongoDB (Data Ingestion Time) ===")
print(f"- movies  ({db['movies'].count_documents({})} docs): {t_movies:.4f} s")
print(f"- users   ({db['users'].count_documents({})} docs): {t_users:.4f} s")
print(f"- ratings ({db['ratings'].count_documents({})} docs): {t_ratings:.4f} s")
print(f"=> Tempo total: {total_ingestion_time:.4f} s")

tag_count_pipeline = [
    {"$unwind": "$tags"},
    {"$count": "total_tags"}
]
tag_res = list(db["users"].aggregate(tag_count_pipeline))
mongo_total_tags = tag_res[0]["total_tags"] if tag_res else 0

print("\n=== Verificação de consistência ===")
print(f"- Filmes:      CSV={len(df_movies)} vs MongoDB={db['movies'].count_documents({})}")
print(f"- Utilizadores: CSV={len(df_users)} vs MongoDB={db['users'].count_documents({})}")
print(f"- Ratings:     CSV={len(df_ratings)} vs MongoDB={db['ratings'].count_documents({})}")
print(f"- Tags:        CSV={len(df_tags)} vs MongoDB (embebidas)={mongo_total_tags}")