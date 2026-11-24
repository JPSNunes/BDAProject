
-- ==================================================
-- Goal 3 — Consultas em MySQL
-- ==================================================

USE bda_movielens;


-- ==================================================
-- Q1 — Filtragem e projeção simples
-- Consultar os filmes lançados após 2010.
-- ==================================================

SELECT movieId, title, year
FROM movies
WHERE year > 2010
ORDER BY movieId ASC;


-- ==================================================
-- Q2 — Ordenação
-- Consultar os 20 filmes mais recentes.
-- ==================================================

SELECT movieId, title, year
FROM movies
WHERE year IS NOT NULL
ORDER BY year DESC, movieId ASC
LIMIT 20;


-- ==================================================
-- Q3 — Agregação
-- Calcular a média global das avaliações.
-- ==================================================

SELECT ROUND(AVG(rating), 4) AS averageRating
FROM ratings;


-- ==================================================
-- Q4 — Agrupamento
-- Contar o número de utilizadores por país.
-- ==================================================

SELECT country, COUNT(*) AS totalUsers
FROM users
GROUP BY country
ORDER BY totalUsers DESC, country ASC;


-- ==================================================
-- Q5 — Agregação e agrupamento
-- Calcular a média e o número de avaliações
-- de cada filme.
-- ==================================================

SELECT
    movieId,
    ROUND(AVG(rating), 4) AS averageRating,
    COUNT(*) AS totalRatings
FROM ratings
GROUP BY movieId
ORDER BY movieId ASC;


-- ==================================================
-- Q6 — Junção de tabelas
-- Consultar os filmes avaliados pelo utilizador 1,
-- incluindo o título e a respetiva avaliação.
-- ==================================================

SELECT
    u.userId,
    m.movieId,
    m.title,
    r.rating
FROM users AS u
INNER JOIN ratings AS r
    ON u.userId = r.userId
INNER JOIN movies AS m
    ON r.movieId = m.movieId
WHERE u.userId = 1
ORDER BY r.rating DESC, m.movieId ASC;


-- ==================================================
-- Q7 — Junção e agrupamento
-- Contar o número de filmes por género.
-- ==================================================

SELECT
    g.genre,
    COUNT(DISTINCT m.movieId) AS totalMovies
FROM genres AS g
INNER JOIN movie_genres AS mg
    ON g.genreId = mg.genreId
INNER JOIN movies AS m
    ON mg.movieId = m.movieId
GROUP BY g.genreId, g.genre
ORDER BY totalMovies DESC, g.genre ASC;


-- ==================================================
-- Q8 — Consulta complexa
-- Consultar os 10 filmes de comédia com melhor
-- classificação média e pelo menos 100 avaliações.
-- ==================================================

SELECT
    m.movieId,
    m.title,
    ROUND(AVG(r.rating), 4) AS averageRating,
    COUNT(*) AS totalRatings
FROM movies AS m
INNER JOIN ratings AS r
    ON m.movieId = r.movieId
INNER JOIN movie_genres AS mg
    ON m.movieId = mg.movieId
INNER JOIN genres AS g
    ON mg.genreId = g.genreId
WHERE g.genre = 'Comedy'
GROUP BY m.movieId, m.title
HAVING COUNT(*) >= 100
ORDER BY averageRating DESC, m.movieId ASC
LIMIT 10;
