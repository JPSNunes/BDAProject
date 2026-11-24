
-- ==================================================
-- Goal 3 — Operações CRUD em MySQL
-- ==================================================

USE bda_movielens;


-- ==================================================
-- Identificadores reservados para os testes
-- ==================================================

SET @testUserId = 999999;
SET @testMovieId = 999999;


-- ==================================================
-- Verificar se os identificadores estão disponíveis
-- ==================================================

SELECT * FROM users
WHERE userId = @testUserId;

SELECT * FROM movies
WHERE movieId = @testMovieId;


-- ==================================================
-- I1 — Inserção de um utilizador
-- ==================================================

INSERT INTO users (userId, country)
VALUES (@testUserId, 'Portugal');

-- Verificação
SELECT * FROM users
WHERE userId = @testUserId;


-- ==================================================
-- I2 — Inserção de um filme
-- ==================================================

INSERT INTO movies (
    movieId,
    title,
    year,
    imdbId,
    tmdbId
)
VALUES (
    @testMovieId,
    'Test Movie',
    2026,
    999999,
    999999
);

-- Verificação
SELECT * FROM movies
WHERE movieId = @testMovieId;


-- ==================================================
-- I3 — Inserção de uma avaliação
-- ==================================================

INSERT INTO ratings (
    userId,
    movieId,
    rating,
    timestamp
)
VALUES (
    @testUserId,
    @testMovieId,
    3.5,
    NOW()
);

-- Verificação
SELECT * FROM ratings
WHERE userId = @testUserId
  AND movieId = @testMovieId;


-- ==================================================
-- U1 — Atualização do título de um filme
-- ==================================================

UPDATE movies
SET title = 'Test Movie Updated'
WHERE movieId = @testMovieId;

-- Verificação
SELECT * FROM movies
WHERE movieId = @testMovieId;


-- ==================================================
-- U2 — Atualização de uma avaliação
-- ==================================================

UPDATE ratings
SET rating = 4.5
WHERE userId = @testUserId
  AND movieId = @testMovieId;

-- Verificação
SELECT * FROM ratings
WHERE userId = @testUserId
  AND movieId = @testMovieId;


-- ==================================================
-- D1 — Eliminação de uma avaliação
-- ==================================================

DELETE FROM ratings
WHERE userId = @testUserId
  AND movieId = @testMovieId;

-- Verificação
SELECT * FROM ratings
WHERE userId = @testUserId
  AND movieId = @testMovieId;


-- ==================================================
-- D2 — Eliminação de um filme
-- ==================================================

DELETE FROM movies
WHERE movieId = @testMovieId;

-- Verificação
SELECT * FROM movies
WHERE movieId = @testMovieId;


-- ==================================================
-- D3 — Eliminação de um utilizador
-- ==================================================

DELETE FROM users
WHERE userId = @testUserId;

-- Verificação
SELECT * FROM users
WHERE userId = @testUserId;
