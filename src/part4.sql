-- Active: 1702121381996@@127.0.0.1@5432@part4

CREATE DATABASE part4;

CREATE TABLE IF NOT EXISTS TableName_1 (
    id BIGINT PRIMARY KEY,
    col_name_1 VARCHAR,
    col_name_2 BIGINT
);

CREATE TABLE IF NOT EXISTS TableName_2 (
    id BIGINT PRIMARY KEY,
    col_name_1 VARCHAR,
    col_name_2 DATE,
    col_name_3 TIME
);

CREATE TABLE IF NOT EXISTS TableName_3 (
    id BIGINT PRIMARY KEY,
    col_name_1 VARCHAR,
    col_name_2 BIGINT,
    col_name_3 BIGINT
);

CREATE OR REPLACE FUNCTION empty_func1() RETURNS trigger AS $$
    BEGIN
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION empty_func2() RETURNS trigger AS $$
    BEGIN
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION empty_func3(param1 VARCHAR, param2 INT) RETURNS void AS $$
    BEGIN
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION empty_func4(param3 VARCHAR, param4 DATE) RETURNS INT AS $$
    BEGIN
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE empty_proc1() AS $$
    BEGIN
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE empty_proc2() AS $$
    BEGIN
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE TRIGGER trg_empty_1 
    AFTER UPDATE ON TableName_1 FOR EACH ROW
    EXECUTE FUNCTION empty_func1();

CREATE OR REPLACE TRIGGER trg_empty_2 
    AFTER UPDATE ON TableName_2 FOR EACH ROW
    EXECUTE FUNCTION empty_func2();

-- Задание №1 Создать хранимую процедуру, которая, не уничтожая базу данных, уничтожает все те таблицы текущей базы данных, имена которых начинаются с фразы 'TableName'.

CREATE OR REPLACE PROCEDURE drop_table(IN tablename VARCHAR) AS $$
DECLARE
    drop_command VARCHAR;
BEGIN
FOR tablename IN (
    SELECT table_name FROM information_schema.tables
    WHERE table_name SIMILAR TO CONCAT('tabl', '%') AND table_schema = 'public'
    ) LOOP
    drop_command = 'DROP TABLE ' || tablename;
    EXECUTE drop_command;
END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL drop_table(tablename := 'tabl');

-- Задание №2 Создать хранимую процедуру с выходным параметром, которая выводит список имен и параметров всех скалярных SQL функций пользователя в текущей базе данных. 
-- Имена функций без параметров не выводить. 
-- Имена и список параметров должны выводиться в одну строку. Выходной параметр возвращает количество найденных функций.

CREATE OR REPLACE PROCEDURE funcs_with_param(OUT countt int, result_1 refcursor) AS $$
BEGIN

countt = (WITH param_aggregated AS (
SELECT func_name, string_agg(func_param, ', ') AS param_agg FROM (
SELECT is_r.routine_name AS func_name, concat(is_p.parameter_name,' ', is_p.data_type) AS func_param FROM information_schema.routines is_r
INNER JOIN information_schema.parameters is_p ON is_r.specific_name = is_p.specific_name
WHERE is_r.specific_schema='public' and is_r.routine_type = 'FUNCTION' AND is_p.parameter_name IS NOT NULL
) q_1
GROUP BY 1
)
SELECT count(concat(func_name, ' (', param_agg, ')')) FROM param_aggregated);

OPEN result_1 FOR
WITH param_aggregated AS (
SELECT func_name, string_agg(func_param, ', ') AS param_agg FROM (
SELECT is_r.routine_name AS func_name, concat(is_p.parameter_name,' ', is_p.data_type) AS func_param FROM information_schema.routines is_r
INNER JOIN information_schema.parameters is_p ON is_r.specific_name = is_p.specific_name
WHERE is_r.specific_schema='public' and is_r.routine_type = 'FUNCTION' AND is_p.parameter_name IS NOT NULL
) q_1
GROUP BY 1
)
SELECT concat(func_name, ' (', param_agg, ')') FROM param_aggregated;

END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL funcs_with_param(null, 'res');
FETCH ALL in res;
COMMIT;

-- Задание №3 Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в текущей базе данных. 
-- Выходной параметр возвращает количество уничтоженных триггеров.

CREATE OR REPLACE PROCEDURE drop_triggers(INOUT count_trig BIGINT) AS $$
DECLARE
    drop_command VARCHAR;
    triggername VARCHAR;
    tablename VARCHAR;
BEGIN
count_trig =  (SELECT count(trigger_name) FROM information_schema.triggers
            WHERE trigger_schema = 'public');
FOR triggername, tablename IN (
    SELECT trigger_name, event_object_table  FROM information_schema.triggers
    WHERE trigger_schema = 'public'
    ) LOOP
    drop_command = 'DROP TRIGGER ' || triggername || ' ON ' || tablename;
    EXECUTE drop_command;
    -- count_trig = count_trig + 1;
END LOOP;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL drop_triggers(null);
COMMIT;

-- костыль для вывода, так как в vs code не видно raise notice (тоже работает)
-- DO language plpgsql $$
-- DECLARE counter_trig BIGINT := 0;
-- BEGIN
--   CALL drop_triggers(counter_trig);
--   RAISE EXCEPTION  '%', counter_trig;
-- END
-- $$;

-- Задание №4  Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов (только хранимых процедур и скалярных функций), 
-- в тексте которых на языке SQL встречается строка, задаваемая параметром процедуры.

CREATE OR REPLACE PROCEDURE proc_and_funcs(IN word VARCHAR, result_1 refcursor) AS
$$
BEGIN
OPEN result_1 FOR
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_definition SIMILAR TO concat('%', word, '%') AND routine_schema = 'public';
END;
$$ LANGUAGE plpgsql;

BEGIN;
    CALL proc_and_funcs(word := 'open', result_1 := 'res');
    FETCH ALL res;
commit;