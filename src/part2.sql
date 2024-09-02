-- Active: 1702121381996@@127.0.0.1@5432

-- Задание №1 Написать процедуру добавления P2P проверки
-- Параметры: ник проверяемого, ник проверяющего, название задания, статус P2P проверки, время. 
-- Если задан статус "начало", добавить запись в таблицу Checks (в качестве даты использовать сегодняшнюю). 
-- Добавить запись в таблицу P2P. 
-- Если задан статус "начало", в качестве проверки указать только что добавленную запись, иначе указать проверку с незавершенным P2P этапом.

CREATE OR REPLACE PROCEDURE insert_p2p(peer_p2p varchar, сhecking_peer_p2p varchar, task_p2p varchar, 
									   status_p2p check_status, time_p2p TIME) 
LANGUAGE plpgsql
AS $$
BEGIN
	IF status_p2p = 'Start' THEN
		INSERT INTO Checks (Peer, Task, Date)
		VALUES (peer_p2p, task_p2p, CURRENT_DATE);
		INSERT INTO P2P ("Check", CheckingPeer, State, Time)
		VALUES ((SELECT MAX(id) FROM Checks), сhecking_peer_p2p, status_p2p, time_p2p);
	ELSE
		INSERT INTO P2P ("Check", CheckingPeer, State, Time)
		VALUES ((SELECT MAX(id) FROM Checks), сhecking_peer_p2p, status_p2p, time_p2p);
	END IF;
END;
$$; 

-- Задание №2 Написать процедуру добавления проверки Verter'ом
-- Параметры: ник проверяемого, название задания, статус проверки Verter'ом, время. 
-- Добавить запись в таблицу Verter (в качестве проверки указать проверку соответствующего задания с самым поздним (по времени) успешным P2P этапом)

create or replace function fnx_is_verter_check_valid(
													checked_peer_ VARCHAR, 
											   		task_ VARCHAR, 
											   		status_ check_status)
returns boolean as $$
begin 
		if ((select count(*) from p2p
				join checks on p2p."Check" = checks.id 
				where checks.peer  = checked_peer_
				and checks.task = task_
				and p2p.state = 'Success') = 0) then 
				return false;
			else
			return true;
		end if;
end;
$$ LANGUAGE plpgsql;


create or replace procedure fnc_add_verter_check (
											   checked_peer_ VARCHAR, 
											   task_ VARCHAR, 
											   status_ check_status,
											   time_ time without time zone)
as $$
begin 
	if (fnx_is_verter_check_valid($1, $2, $3)) then
	insert into verter ("Check", state, "Time")
	values ((select checks.id from checks
			join p2p on p2p."Check" = checks.id 
			where p2p.state = 'Success'
			and checks.peer = checked_peer_
			and checks.task = task_
			order by p2p."Time" desc, checks.id desc
			limit 1), status_, time_);
end if;
end;
$$ language plpgsql;

-- Задание №3 Написать триггер: после добавления записи со статутом "начало" в таблицу P2P, изменить соответствующую запись в таблице TransferredPoints

CREATE OR REPLACE FUNCTION fnc_TransferredPoints_insert()
RETURNS trigger AS $TransferredPoints_insert$
DECLARE 
peer_checking VARCHAR;
BEGIN
	SELECT Peer INTO peer_checking
	FROM Checks
	WHERE Checks.ID = NEW."Check"
	LIMIT 1;
	IF NEW.State = 'Success' OR NEW.State = 'Failure' THEN
        UPDATE TransferredPoints
    	SET PointsAmount = PointsAmount + 1
    	WHERE NEW.CheckingPeer = TransferredPoints.CheckingPeer 
		AND peer_checking = TransferredPoints.CheckedPeer;
	ELSE
		IF NOT EXISTS (
			SELECT *
			FROM TransferredPoints
			WHERE NEW.CheckingPeer = TransferredPoints.CheckingPeer 
			AND peer_checking = TransferredPoints.CheckedPeer) THEN
				INSERT INTO TransferredPoints(CheckingPeer, CheckedPeer)
				VALUES(NEW.CheckingPeer, (SELECT Peer
									FROM Checks
									WHERE Checks.ID = NEW."Check"
									LIMIT 1));
		END IF;
	END IF;
	RETURN NEW;
END;
$TransferredPoints_insert$ LANGUAGE plpgsql;


CREATE OR REPLACE TRIGGER trg_TransferredPoints_insert
AFTER INSERT ON P2P
FOR EACH ROW
EXECUTE FUNCTION fnc_TransferredPoints_insert();


-- Задание №4 Написать триггер: перед добавлением записи в таблицу XP, проверить корректность добавляемой записи
-- Запись считается корректной, если:
-- Количество XP не превышает максимальное доступное для проверяемой задачи
-- Поле Check ссылается на успешную проверку
-- Если запись не прошла проверку, не добавлять её в таблицу.

create or replace function fnc_check_insert_xp_trigger()
returns trigger as $$
begin 
	if ((select maxxp from checks c
		join tasks t on t.title = c.task
		where c.id = new."Check") >= new.xpamount and 
		(select state from p2p
		where p2p."Check" = new."Check"
		and p2p.state in ('Success', 'Failure')) = 'Success' and
		(select state from verter v
		where v."Check" = new."Check"
		and v.state in ('Success', 'Failure')
		order by v."Time" desc
		limit 1) = 'Success') then 
		return (new.id, new."Check", new.xpamount);
	else 
		return NULL;
	end if;

end; $$ language plpgsql;

create  or replace trigger  trg_check_xp
before insert on xp
for each row execute function  fnc_check_insert_xp_trigger();
