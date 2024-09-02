-- Active: 1702121381996@@127.0.0.1@5432@sql_info21@public

-- Задание №1 Написать функцию, возвращающую таблицу TransferredPoints в более человекочитаемом виде
-- Ник пира 1, ник пира 2, количество переданных пир поинтов. 
-- Количество отрицательное, если пир 2 получил от пира 1 больше поинтов

CREATE OR REPLACE FUNCTION human_readable_trans_points()
RETURNS TABLE(Peer1 VARCHAR, Peer2 VARCHAR, PointsAmount BIGINT) AS $human_read$
    SELECT t1.CheckingPeer, t1.checkedpeer, SUM(t1.pointsamount) FROM  (
(SELECT CheckingPeer, CheckedPeer, PointsAmount 
FROM TransferredPoints)
UNION
(
SELECT CheckedPeer, CheckingPeer, PointsAmount * (-1) AS pointsamount 
FROM TransferredPoints
)
) t1
WHERE t1.checkingpeer < t1.checkedpeer
GROUP BY t1.CheckingPeer, t1.CheckedPeer
ORDER BY 1;
$human_read$ LANGUAGE sql;

SELECT *
FROM human_readable_trans_points();

-- Задание №2 Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
-- В таблицу включать только задания, успешно прошедшие проверку (определять по таблице Checks). 
-- Одна задача может быть успешно выполнена несколько раз. В таком случае в таблицу включать все успешные проверки.

CREATE OR REPLACE FUNCTION fnc_peer_tasks_succes()
RETURNS TABLE(Peer Peers.Nickname%TYPE,
			Task Tasks.Title%TYPE,
			XP XP.XPAmount%TYPE) AS $peer_tasks_succes$
	SELECT Checks.Peer,
		Checks.Task,
		XP.XPAmount AS XP
	FROM Checks
	INNER JOIN P2P
	ON P2P."Check" = Checks.ID
	INNER JOIN Verter
	ON Checks.ID = Verter."Check"
	INNER JOIN XP
	ON Checks.ID = XP."Check"
	WHERE Verter.State = 'Success' AND P2P.State = 'Success'
$peer_tasks_succes$ LANGUAGE sql;

-- -- Задание №3 Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня
-- Параметры функции: день, например 12.05.2022. 
-- Функция возвращает только список пиров.

create or replace function fnc_3_3(check_date date) returns table 
	(Peer varchar)
as
$$
select t.peer
from timetracking t
where t."date" = check_date
group by t.peer
having count(state) < 2
order by 1;
$$
language sql;

--insert into timetracking(peer, "Date", "Time", state) values ('Cosmic', '2022-06-23', '09:22:33', 1);
select * from fnc_3_3('2022-06-23');

-- -- Задание №4 Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
-- Результат вывести отсортированным по изменению числа поинтов. 
-- Формат вывода: ник пира, изменение в количество пир поинтов

SELECT checkingpeer AS Peer, SUM(pointsamount) AS PointsChange FROM
((SELECT CheckingPeer, CheckedPeer, PointsAmount 
FROM TransferredPoints)
UNION
(
SELECT CheckedPeer, CheckingPeer, PointsAmount * (-1) AS pointsamount 
FROM TransferredPoints
)
ORDER BY 1) t1
GROUP BY peer;

-- Задание №5 Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
-- Результат вывести отсортированным по изменению числа поинтов. 
-- Формат вывода: ник пира, изменение в количество пир поинтов

CREATE OR REPLACE FUNCTION fnc_points_change()
RETURNS TABLE(Peer Peers.Nickname%TYPE,
			PointsChange TransferredPoints.PointsAmount%TYPE) AS $points_change$
	WITH TP AS
		(SELECT t1.CheckingPeer, t1.checkedpeer, SUM(t1.pointsamount) AS sumpoints
		FROM  ((SELECT CheckingPeer,
					CheckedPeer,
					PointsAmount 
				FROM TransferredPoints)
			UNION
				(SELECT CheckedPeer,
					CheckingPeer,
					PointsAmount * (-1) AS pointsamount 
				FROM TransferredPoints)) t1
	WHERE t1.checkingpeer < t1.checkedpeer
	GROUP BY t1.CheckingPeer, t1.CheckedPeer
	ORDER BY 1)

	SELECT CheckingPeer,
			Sum(sumpoints)
	FROM TP
	GROUP BY CheckingPeer
	ORDER BY 1
$points_change$ LANGUAGE sql;

-- Задание №6 Определить самое часто проверяемое задание за каждый день
-- При одинаковом количестве проверок каких-то заданий в определенный день, вывести их все. 
-- Формат вывода: день, название задания

create or replace procedure fnc3_6(in curs1 refcursor)
as
$$
begin
	open curs1 for (with t as (select "date" as "day", Task, count(task) as "count"
								from checks
								group by "date", Task
								order by 1 desc),
						t2 as (select t."day", max(t."count") over (partition by t."day") as "count"
								from t)
								
					select distinct t."day", t.task
					from t
						join t2 on t."day" = t2."day" and t."count" = t2."count"
					order by 1 desc);
end;
$$
language plpgsql;

begin;
	call fnc3_6('result');
	fetch all in "result";
end;

-- Задание №7 Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
-- Параметры процедуры: название блока, например "CPP". 
-- Результат вывести отсортированным по дате завершения. 
-- Формат вывода: ник пира, дата завершения блока (т.е. последнего выполненного задания из этого блока)

CREATE OR REPLACE PROCEDURE block_finished(IN block_name VARCHAR, result_1 refcursor) AS $$
DECLARE
BEGIN
OPEN result_1 FOR 
    SELECT peer, date FROM Checks ch
    FULL JOIN p2p ON p2p."Check" = ch.id
    FULL JOIN verter v ON v."Check" = ch.id
    WHERE p2p.state = 'Success'::check_status AND (v.state = 'Success'::check_status OR v.state IS NULL) AND 
    task = 
    (SELECT title FROM tasks t
    WHERE title SIMILAR TO CONCAT(block_name, '[0-9]%')
    ORDER BY 1 DESC
    LIMIT 1)
    ORDER BY 1, 2;
END;
$$ LANGUAGE plpgsql;

BEGIN;
CALL block_finished(block_name:='C', result_1:= 'res');
FETCH ALL IN res;
END;

-- Задание №8 Определить, к какому пиру стоит идти на проверку каждому обучающемуся
-- Определять нужно исходя из рекомендаций друзей пира, т.е. нужно найти пира, проверяться у которого рекомендует наибольшее число друзей. 
-- Формат вывода: ник пира, ник найденного проверяющего

CREATE OR REPLACE FUNCTION fnc_recommended_peer()
RETURNS TABLE(Peer Peers.Nickname%TYPE,
			 RecommendedPeer Peers.Nickname%TYPE) AS $recommended_peer$
	WITH recom_friends AS
		(SELECT Recommendations.Peer, 
			Recommendations.RecommendedPeer,
			COUNT(Recommendations.RecommendedPeer) AS recom
		FROM Recommendations
		GROUP BY Recommendations.Peer, Recommendations.RecommendedPeer),
	
	recom_counts AS 
		(SELECT recom_friends.RecommendedPeer,
		 	COUNT(recom_friends.RecommendedPeer) AS total_recom,
		 	Friends.Peer1 AS Peer
		FROM recom_friends
		LEFT JOIN Friends
		ON recom_friends.Peer = Friends.Peer2
		WHERE Friends.Peer1 != recom_friends.RecommendedPeer
		GROUP BY recom_friends.RecommendedPeer, recom_friends.Peer, Friends.Peer1),

	final_table AS 
		(SELECT recom_counts.Peer,
		 recom_counts.RecommendedPeer,
		 total_recom, 
			ROW_NUMBER() OVER (PARTITION BY recom_counts.Peer ORDER BY COUNT(*) DESC) AS rating
		FROM recom_counts
		WHERE total_recom = (SELECT MAX(total_recom) 
							FROM recom_counts) AND recom_counts.Peer != recom_counts.RecommendedPeer
		GROUP BY recom_counts.Peer, recom_counts.RecommendedPeer, total_recom
		ORDER BY recom_counts.Peer ASC)

	SELECT final_table.Peer,
	final_table.RecommendedPeer
	FROM final_table
	WHERE rating = 1
$recommended_peer$ LANGUAGE sql;

-- Задание №9 Определить процент пиров, которые:
--Приступили только к блоку 1
--Приступили только к блоку 2
--Приступили к обоим
--Не приступили ни к одному

create or replace procedure fnc3_9(in block1 varchar, in block2 varchar, in curs1 refcursor)
as
$$
declare 
	all_peers integer := (select count(*) from peers);
begin 
	open curs1 for (with b1 as (select peer 
								from checks 
								where task similar to block1 || '\d'
								group by peer),
						b2 as (select peer 
								from checks
								where task similar to block2 || '\d'
								group by peer),
						only1 as (select b1.peer
									from b1
										left join b2 on b1.peer = b2.peer
									where b2.peer is null),
						only2 as (select b2.peer
									from b2
										left join b1 on b2.peer = b1.peer
									where b1.peer is null),
						both_b as ((select * from b1)
									intersect
									(select * from b2)),
						no_one as (select nickname from peers
									except
									((select * from b1)
									union
									(select * from b2)))
																	
						select
							 (select count(*) from only1) * 100 / all_peers as StartedBlock1,
							 (select count(*) from only2) * 100 / all_peers as StartedBlock2,
							 (select count(*) from both_b) * 100 / all_peers as StartedBothBlocks,
							 (select count(*) from no_one) * 100 / all_peers as DidntStartAnyBlock
						);
					
end;
$$
language plpgsql;

begin;
	call fnc3_9('C', 'CPP', 'result');
	fetch all in "result";
end;

-- Задание №10 Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
-- Также определите процент пиров, которые хоть раз проваливали проверку в свой день рождения. 
-- Формат вывода: процент пиров, успешно прошедших проверку в день рождения, процент пиров, проваливших проверку в день рождения

WITH dates_bdays_checks (Nickname, p2p_res, ver_res, b_mon, b_day, ch_mon, ch_day) AS (
SELECT Nickname, 
p2p.state, v.state,
EXTRACT(MONTH FROM Birthday),
EXTRACT(DAY FROM Birthday),
EXTRACT(MONTH FROM ch.date),
EXTRACT(DAY FROM ch.date) 
FROM Peers pe
INNER JOIN checks ch ON pe.nickname = ch.peer
FULL JOIN P2P ON p2p."Check" = ch.id
FULL JOIN Verter v ON v."Check" = ch.id
WHERE p2p.state != 'Start'::check_status AND 
(v.state != 'Start'::check_status OR v.state IS NULL)
)
SELECT ROUND(sum(resulting)::NUMERIC/count(resulting)::NUMERIC * 100) AS SuccessfulChecks,
ROUND(100 - sum(resulting)::NUMERIC/count(resulting)::NUMERIC * 100) AS UnsuccessfulChecks
FROM (
SELECT Nickname,
       CASE WHEN (p2p_res = 'Success'::check_status AND 
(ver_res = 'Success'::check_status OR ver_res IS NULL)) THEN 1
            WHEN (p2p_res = 'Failure'::check_status OR 
(ver_res = 'Failure'::check_status OR ver_res IS NULL)) THEN 0
       END AS resulting
FROM dates_bdays_checks
WHERE b_mon = ch_mon AND b_day = ch_day
) res;

-- Задание №11 Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
-- Параметры процедуры: названия заданий 1, 2 и 3. 
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE task_123(task_1 varchar, task_2 varchar, task_3 varchar, result_2 refcursor) AS $$
BEGIN
OPEN result_2 FOR 
	WITH t1 AS
		(SELECT Peer
		FROM Checks
		INNER JOIN P2P
		ON P2P."Check" = Checks.ID
		INNER JOIN Verter
		ON Checks.ID = Verter."Check"
		WHERE Verter.State = 'Success' AND P2P.State = 'Success' AND Checks.Task = task_1),

	t2 AS
		(SELECT Peer
		FROM Checks
		INNER JOIN P2P
		ON P2P."Check" = Checks.ID
		INNER JOIN Verter
		ON Checks.ID = Verter."Check"
		WHERE Verter.State = 'Success' AND P2P.State = 'Success' AND Checks.Task = task_2),

	t3 AS
		(SELECT Peer
		FROM Checks
		INNER JOIN P2P
		ON P2P."Check" = Checks.ID
		INNER JOIN Verter
		ON Checks.ID = Verter."Check"
		WHERE (Verter.State = 'Failure' OR P2P.State = 'Failure') AND Checks.Task = task_3)
		
		(SELECT * 
		FROM t1
		 
		INTERSECT
		 
		SELECT * 
		FROM t2)
		
		EXCEPT
		
		SELECT * 
		FROM t3;
END;
$$ LANGUAGE plpgsql;

-- Задание №12 Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей. 
-- Формат вывода: название задачи, количество предшествующих

create or replace procedure fnc3_12(in curs1 refcursor) as $$
begin 
	open curs1 for (with recursive tbl as (select (select t.title 
											from tasks t 
											where t.parenttask is null LIMIT 1) as Task,
											0 as PrevCount
								union
								select t.title as Task,
								PrevCount + 1 as PrevCount
								from tbl
									join tasks t on tbl.task = t.parenttask)
									
								select * from tbl
								order by 1
					);
end;
$$
language plpgsql;

begin;
	call fnc3_12('result');
	fetch all in "result";
end;

-- можно добавить проектов для проверки разных ветвлений проектов
insert into Tasks(Title, ParentTask, MaxXP) values ('D01', 'C8', 300);
insert into Tasks(Title, ParentTask, MaxXP) values ('D02', 'D01', 350);
insert into Tasks(Title, ParentTask, MaxXP) values ('D03', 'D02', 350);


-- Задание №13 Найти "удачные" для проверок дни. День считается "удачным", если в нем есть хотя бы N идущих подряд успешных проверки
-- Параметры процедуры: количество идущих подряд успешных проверок N. 
-- Временем проверки считать время начала P2P этапа. 
-- Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных. 
-- При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального. 
-- Формат вывода: список дней

CREATE OR REPLACE PROCEDURE pr_lucky_days(amount BIGINT, rc refcursor = 'rc') 
AS
$$
DECLARE
	lucky_counter	BIGINT := 0;
    lucky_days		DATE[]  := '{}';
    current_day     DATE;
    state_value     VARCHAR;
    row_data        record;
BEGIN
    FOR row_data IN SELECT * FROM (
(SELECT ch.id, ch.peer, ch.task, "date", p2p."time", p2p.state FROM checks ch
INNER JOIN P2P ON p2p."Check" = ch.id
FULL JOIN Verter v ON v."Check" = ch.id
INNER JOIN tasks t ON ch.task = t.title
INNER JOIN xp ON ch.id = xp."Check" AND xp.xpamount >= t.maxxp * 0.8
WHERE p2p.state = 'Success'::check_status AND (v.state = 'Success'::check_status OR v.state IS NULL))
UNION
(SELECT ch.id, ch.peer, ch.task, "date", p2p."time", p2p.state FROM checks ch
INNER JOIN P2P ON p2p."Check" = ch.id
WHERE p2p.state = 'Failure'::check_status)
ORDER BY "date", "time"
    ) AS base
        LOOP
            IF current_day IS NULL THEN                
           		current_day := row_data."date";
            ELSE
                IF current_day <> row_data."date" THEN
                    current_day = row_data."date";
                    lucky_counter := 0;
                END IF;
            END IF;
            state_value := row_data.State;
            IF state_value = 'Success' THEN
                lucky_counter:= lucky_counter + 1;
                IF lucky_counter = $1 THEN
                    lucky_days := lucky_days || current_day;
                END IF;
            ELSE
                lucky_counter := 0;
            END IF;
        END LOOP;

    CREATE TEMPORARY TABLE tmp (
    value VARCHAR
    ) ON COMMIT DROP;

INSERT INTO tmp (value)
SELECT unnest(lucky_days);

OPEN rc FOR
SELECT value AS Lucky_days FROM tmp
ORDER BY 1;

END;
$$ LANGUAGE plpgsql;

begin;
    call pr_lucky_days(amount := 2);
    fetch all rc;
commit;

-- Задание №14 Определить пира с наибольшим количеством XP
-- Формат вывода: ник пира, количество XP

CREATE OR REPLACE FUNCTION fnc_peer_max_xp()
RETURNS TABLE(Peer Peers.Nickname%TYPE,
			XP XP.XPAmount%TYPE) AS $peer_max_xp$
	SELECT Checks.Peer,
		SUM(XP.XPAmount) AS XP
	FROM Checks
	INNER JOIN P2P
	ON P2P."Check" = Checks.ID
	INNER JOIN Verter
	ON Checks.ID = Verter."Check"
	INNER JOIN XP
	ON Checks.ID = XP."Check"
	WHERE Verter.State = 'Success' AND P2P.State = 'Success'
	GROUP BY 1
	ORDER BY 2 DESC
	LIMIT 1
$peer_max_xp$ LANGUAGE sql;

-- Задание №15 Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
-- Параметры процедуры: время, количество раз N. 
-- Формат вывода: список пиров

create or replace procedure fnc3_15(in check_time time, in N int, in curs1 refcursor)
as
$$
begin
	open curs1 for (with t as (select peer, count(state)
								from timetracking
								where state = 1 and "time" < check_time
								group by peer)
								
						select peer
						from t
						where "count" >= N );
end;
$$
language plpgsql;

begin;
	call fnc3_15('09:11:35', 1, 'result');
	fetch all in "result";
end;

-- Задание №16 Определить пиров, выходивших за последние N дней из кампуса больше M раз
-- Параметры процедуры: количество дней N, количество раз M. 
-- Формат вывода: список пиров

CREATE OR REPLACE PROCEDURE campus_leave(IN M INT, IN N INT, result_1 refcursor) AS
$$
begin
    OPEN result_1 FOR
        WITH time_tracking_exit (peer, "date", "time", "state") AS (
        SELECT peer, "date", "time", "state" FROM timetracking
        WHERE state = 2 AND 
        "date" >= (now()::date - N) AND 
        "date" <= now()::date
        )
        SELECT peer
        FROM time_tracking_exit
        GROUP BY peer
        HAVING count(state) >= M;
END;
$$
    LANGUAGE plpgsql;

BEGIN;
CALL campus_leave(M:= 3, N := 30, result_1:= 'res');
FETCH ALL IN res;
END;

-- Задание №17 Определить для каждого месяца процент ранних входов
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время (будем называть это общим числом входов). 
-- Для каждого месяца посчитать, сколько раз люди, родившиеся в этот месяц, приходили в кампус раньше 12:00 за всё время (будем называть это числом ранних входов). 
-- Для каждого месяца посчитать процент ранних входов в кампус относительно общего числа входов. 
-- Формат вывода: месяц, процент ранних входов

CREATE OR REPLACE PROCEDURE early_entrances(result_3 refcursor)
AS $$
BEGIN
	OPEN result_3 FOR 
	WITH tt_birthday AS
		(SELECT Peer, Date, Time, State
		FROM TimeTracking t
		JOIN Peers p 
		ON t.peer = p.nickname
		WHERE (SELECT EXTRACT(MONTH FROM Date) = (SELECT EXTRACT(MONTH FROM Birthday)) AND State = 1)),
					 
	months AS
		(SELECT generate_series('2022-01-01 00:00'::timestamp, '2022-12-01 12:00', '1 month') AS Month),
	
	total_entries AS
		(SELECT month, count("date")
		FROM months
		LEFT JOIN tt_birthday
	 	ON EXTRACT(MONTH FROM "month") = EXTRACT(MONTH FROM "date")
		GROUP BY "month"
		ORDER BY 1),
		
	early_entries AS
		(SELECT month, count("date")
		FROM months
		LEFT JOIN tt_birthday
		ON EXTRACT(MONTH FROM "month") = EXTRACT(MONTH FROM "date")
		WHERE "time" < '12:00:00'
		GROUP BY "month"
		ORDER BY 1)

		SELECT to_char(total_entries.month, 'month') AS "month",
			(CASE WHEN total_entries.count = 0 THEN 0
				ELSE early_entries.count * 100 / total_entries.count
			END) AS EarlyEntries
		FROM total_entries
		LEFT JOIN early_entries
		ON total_entries.month = early_entries.month;
END
$$ LANGUAGE plpgsql;


BEGIN;
	CALL early_entrances('result');
	FETCH ALL IN "result";
END;
