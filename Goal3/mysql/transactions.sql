
-- ==================================================
-- Goal 3 — Transações em MySQL
-- ==================================================

USE bda_movielens;


-- ==================================================
-- T1 — Transação com sucesso
-- ==================================================

START TRANSACTION;

-- Inserir um utilizador
INSERT INTO users (userId, country)
VALUES (999991, 'Portugal');

-- Inserir um filme
INSERT INTO movies (movieId, title, year, imdbId, tmdbId)
VALUES (999991, 'Transaction Test Movie', 2026, 999991, 999991);

-- Inserir uma avaliação
INSERT INTO ratings (userId, movieId, rating, timestamp)
VALUES (999991, 999991, 4.5, NOW());

-- Confirmar a transação
COMMIT;


-- Verificar os resultados após COMMIT

SELECT * FROM users
WHERE userId = 999991;

SELECT * FROM movies
WHERE movieId = 999991;

SELECT * FROM ratings
WHERE userId = 999991 AND movieId = 999991;


-- ==================================================
-- Remover os dados do primeiro teste
-- ==================================================

START TRANSACTION;

DELETE FROM ratings
WHERE userId = 999991 AND movieId = 999991;

DELETE FROM movies
WHERE movieId = 999991;

DELETE FROM users
WHERE userId = 999991;

COMMIT;


-- ==================================================
-- T2 — Transação com falha e rollback automático
-- ==================================================

DROP PROCEDURE IF EXISTS test_rollback;

DELIMITER $$

CREATE PROCEDURE test_rollback()
BEGIN

    -- Executar rollback em caso de erro
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;

        SELECT 'ROLLBACK executado devido a um erro.'
            AS resultado;
    END;

    START TRANSACTION;

    -- Inserir um utilizador
    INSERT INTO users (userId, country)
    VALUES (999992, 'Portugal');

    -- Inserir um filme
    INSERT INTO movies (movieId, title, year, imdbId, tmdbId)
    VALUES (999992, 'Rollback Test Movie', 2026, 999992, 999992);

    -- Inserir uma avaliação válida
    INSERT INTO ratings (userId, movieId, rating, timestamp)
    VALUES (999992, 999992, 3.5, NOW());

    -- Provocar um erro de chave primária duplicada
    INSERT INTO ratings (userId, movieId, rating, timestamp)
    VALUES (999992, 999992, 4.5, NOW());

    COMMIT;

    SELECT 'COMMIT executado.' AS resultado;

END$$

DELIMITER ;

-- Executar o teste
CALL test_rollback();


-- ==================================================
-- Verificar os resultados após ROLLBACK
-- ==================================================

SELECT * FROM users
WHERE userId = 999992;

SELECT * FROM movies
WHERE movieId = 999992;

SELECT * FROM ratings
WHERE userId = 999992 AND movieId = 999992;


-- Remover o procedimento de teste
DROP PROCEDURE IF EXISTS test_rollback;
