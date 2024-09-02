-- Active: 1702121381996@@127.0.0.1@5432@sql_info21@public

CREATE DATABASE sql_info21;

-- Экспорт csv
CREATE OR REPLACE PROCEDURE export_table(IN name_table VARCHAR, IN file_path VARCHAR, IN separ VARCHAR) AS $$
DECLARE
    copy_command VARCHAR;
BEGIN
    copy_command = 'COPY ' || name_table || ' TO ' || quote_literal(file_path) || ' DELIMIT' || 'ER' || quote_literal(separ) || ' CSV HEADER';
    EXECUTE copy_command; 
END;
$$ LANGUAGE plpgsql;

-- Создание перечисления
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'check_status') THEN
        CREATE TYPE check_status AS ENUM ('Start', 'Success', 'Failure');
    END IF;
END
$$;

-- Импорт csv
CREATE OR REPLACE PROCEDURE import_table(IN name_table VARCHAR, IN file_path VARCHAR, IN separ VARCHAR) AS $$
DECLARE
    copy_command VARCHAR;
    del_command VARCHAR;
BEGIN
    del_command = 'DELETE FROM ' || name_table;
    EXECUTE del_command;
    copy_command = 'COPY ' || name_table || ' FROM ' || quote_literal(file_path) || ' DELIMIT' || 'ER' || quote_literal(separ) || ' CSV HEADER';
    EXECUTE copy_command; 
END;
$$ LANGUAGE plpgsql;

-- Создание таблиц
CREATE TABLE IF NOT EXISTS Peers (
  Nickname VARCHAR PRIMARY KEY NOT NULL,
  Birthday DATE NOT NULL DEFAULT CURRENT_DATE
);

COMMENT ON COLUMN Peers.Nickname IS 'Ник пира';
COMMENT ON COLUMN Peers.Birthday IS 'День рождения';

CREATE TABLE IF NOT EXISTS Tasks (
  Title VARCHAR PRIMARY KEY NOT NULL,
  ParentTask VARCHAR,
  MaxXP BIGINT NOT NULL,
  CONSTRAINT fk_tasks_parenttask_tasks_title FOREIGN KEY (ParentTask) REFERENCES Tasks(Title) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN Tasks.Title IS 'Название задания';
COMMENT ON COLUMN Tasks.ParentTask IS 'Название задания, являющегося условием входа';
COMMENT ON COLUMN Tasks.MaxXP IS 'Максимальное количество XP';

CREATE TABLE IF NOT EXISTS Checks ( 
  ID BIGINT PRIMARY KEY NOT NULL,
  Peer VARCHAR NOT NULL,
  Task VARCHAR NOT NULL,
  Date DATE NOT NULL,
  CONSTRAINT fk_checks_peers_peers_nickname FOREIGN KEY (Peer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_checks_task_tasks_title FOREIGN KEY (Task) REFERENCES Tasks(Title) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN Checks.Peer IS 'Ник пира';
COMMENT ON COLUMN Checks.Task IS 'Название задания';
COMMENT ON COLUMN Checks.Date IS 'Дата проверки';

CREATE TABLE IF NOT EXISTS P2P (
  ID BIGINT PRIMARY KEY,
  "Check" BIGINT NOT NULL,
  CheckingPeer VARCHAR NOT NULL,
  State check_status NOT NULL,
  Time TIME NOT NULL,
  CONSTRAINT fk_p2p_check_checks_id FOREIGN KEY ("Check") REFERENCES Checks(ID) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_p2p_checkingpeer_peers_nickname FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN P2P."Check" IS 'ID проверки';
COMMENT ON COLUMN P2P.CheckingPeer IS 'Ник проверяющего пира';
COMMENT ON COLUMN P2P.State IS 'Статус P2P проверки';
COMMENT ON COLUMN P2P.Time IS 'Время';

CREATE TABLE IF NOT EXISTS Verter ( 
  ID BIGINT PRIMARY KEY NOT NULL,
  "Check" BIGINT NOT NULL,
  State check_status NOT NULL,
  Time TIME NOT NULL,
  CONSTRAINT fk_verter_check_checks_id FOREIGN KEY ("Check") REFERENCES Checks(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN Verter."Check" IS 'ID проверки';
COMMENT ON COLUMN Verter.State IS 'Статус P2P проверки';
COMMENT ON COLUMN Verter.Time IS 'Время';

CREATE TABLE IF NOT EXISTS TransferredPoints ( 
  ID BIGINT PRIMARY KEY,
  CheckingPeer VARCHAR,
  CheckedPeer VARCHAR,
  PointsAmount BIGINT,
  CONSTRAINT fk_transferredpoints_checkingpeer_peers_nickname FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_transferredpoints_checkedpeer_peers_nickname FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN TransferredPoints.CheckingPeer IS 'Ник проверяЮЩЕГО пира';
COMMENT ON COLUMN TransferredPoints.CheckedPeer IS 'Ник проверяЕМОГО пира';
COMMENT ON COLUMN TransferredPoints.PointsAmount IS 'Количество переданных пир поинтов за всё время';

CREATE TABLE IF NOT EXISTS Friends ( 
  ID BIGINT PRIMARY KEY,
  Peer1 VARCHAR,
  Peer2 VARCHAR,
  CONSTRAINT fk_friends_peer1_peers_nickname FOREIGN KEY (Peer1) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_friends_peer2_peers_nickname FOREIGN KEY (Peer2) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN Friends.Peer1 IS 'Ник первого пира';
COMMENT ON COLUMN Friends.Peer2 IS 'Ник второго пира';

CREATE TABLE IF NOT EXISTS Recommendations ( 
  ID BIGINT PRIMARY KEY NOT NULL,
  Peer VARCHAR NOT NULL,
  RecommendedPeer VARCHAR NOT NULL,
  CONSTRAINT fk_recommendations_peer_peers_nickname FOREIGN KEY (Peer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT fk_recommendations_recommendedpeer_peers_nickname FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN Recommendations.Peer IS 'Ник пира';
COMMENT ON COLUMN Recommendations.RecommendedPeer IS 'Ник пира, к которому рекомендуют идти на проверку';

CREATE TABLE IF NOT EXISTS XP ( 
  ID BIGINT PRIMARY KEY NOT NULL,
  "Check" BIGINT NOT NULL,
  XPAmount BIGINT NOT NULL,
  CONSTRAINT fk_xp_check_checks_id FOREIGN KEY ("Check") REFERENCES Checks(ID) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN XP."Check" IS 'ID проверки';
COMMENT ON COLUMN XP.XPAmount IS 'Количество полученного XP';

CREATE TABLE IF NOT EXISTS TimeTracking ( 
  ID BIGINT PRIMARY KEY NOT NULL,
  Peer VARCHAR NOT NULL,
  Date DATE NOT NULL,
  Time TIME NOT NULL,
  State INT NOT NULL 
  CHECK (State = '1' OR State = '2'),
  CONSTRAINT fk_timetracking_peer_peers_nickname FOREIGN KEY (Peer) REFERENCES Peers(Nickname) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON COLUMN TimeTracking.Peer IS 'Ник пира';
COMMENT ON COLUMN TimeTracking.Date IS 'Дата';
COMMENT ON COLUMN TimeTracking.Time IS 'Время';
COMMENT ON COLUMN TimeTracking.State IS 'Состояние (1 - пришел, 2 - вышел)';

-- ЗАПОЛНЕНИЕ
SET datestyle = 'ISO,DMY';

CALL import_table(name_table:='Peers', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/peers.csv', separ:=';');
CALL import_table(name_table:='Friends', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/friends.csv', separ:=';');
CALL import_table(name_table:='Recommendations', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/recommendations.csv', separ:=';');
CALL import_table(name_table:='TimeTracking', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/time_tracking.csv', separ:=';');
CALL import_table(name_table:='TransferredPoints', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/transferred_points.csv', separ:=';');
CALL import_table(name_table:='Tasks', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/tasks.csv', separ:=';');
CALL import_table(name_table:='Checks', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/checks.csv', separ:=';');
CALL import_table(name_table:='P2P', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/P2P.csv', separ:=';');
CALL import_table(name_table:='Verter', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/verter.csv', separ:=';');
CALL import_table(name_table:='XP', file_path:='/Users/ivan-khavricev/code/school21/sql/SQL2_Info21_v1.0-1/src/dataset/xp.csv', separ:=';');


INSERT INTO Peers (Nickname, Birthday)
VALUES ('steffani', '1996-04-11'),
  ('timberly', '1998-03-25'),
  ('evelinaj', '1998-11-01'),
  ('shontagr', '1996-02-02'),
  ('garroshm', '1996-01-21'),
  ('melonywa', '2005-05-09'),
  ('fixierad', '1999-03-23');

INSERT INTO Tasks (Title, ParentTask, MaxXP)
VALUES ('C2_SimpleBashUtils', NULL, 250),
  ('C4_s21_math', 'C2_SimpleBashUtils', 300),
  ('C3_s21_string+', 'C2_SimpleBashUtils', 500),
  ('C5_s21_decimal', 'C4_s21_math', 350),
  ('C6_s21_matrix', 'C5_s21_decimal', 200),
  ('C7_SmartCalc_v1.0', 'C6_s21_matrix', 500),
  ('C8_3DViewer_v1.0', 'C7_SmartCalc_v1.0', 750),
  ('DO1_Linux', 'C3_s21_string+', 300),
  ('DO2_Linux_Network', 'DO1_Linux', 250),
  ('DO3_LinuxMonitoring v1.0', 'DO2_Linux_Network', 350),
  ('DO4_LinuxMonitoring v2.0', 'DO3_LinuxMonitoring v1.0', 350),
  ('DO5_SimpleDocker', 'DO3_LinuxMonitoring v1.0', 300),
  ('DO6_CICD', 'DO5_SimpleDocker', 300),
  ('CPP1_s21_matrix+', 'C8_3DViewer_v1.0', 300),
  ('CPP2_s21_containers', 'CPP1_s21_matrix+', 350);

INSERT INTO Checks (id, Peer, Task, Date)
VALUES ((SELECT max(id) FROM Checks) + 1, 'steffani', 'C2_SimpleBashUtils', '2023-02-02'),
  ((SELECT max(id) FROM Checks) + 2, 'timberly', 'C3_s21_string+', '2023-03-25'),
  ((SELECT max(id) FROM Checks) + 3, 'timberly', 'C5_s21_decimal', '2023-04-26'),
  ((SELECT max(id) FROM Checks) + 4, 'evelinaj', 'C3_s21_string+', '2022-02-02'),
  ((SELECT max(id) FROM Checks) + 5, 'shontagr', 'C4_s21_math', '2023-02-02'),
  ((SELECT max(id) FROM Checks) + 6, 'garroshm', 'C7_SmartCalc_v1.0', '2023-04-26'),
  ((SELECT max(id) FROM Checks) + 7, 'melonywa', 'DO1_Linux', '2023-03-08'),
  ((SELECT max(id) FROM Checks) + 8, 'fixierad', 'C8_3DViewer_v1.0', '2023-03-25'),
  ((SELECT max(id) FROM Checks) + 9, 'shontagr', 'CPP1_s21_matrix+', '2023-09-20'),
  ((SELECT max(id) FROM Checks) + 10, 'steffani', 'DO2_Linux_Network', '2023-07-31'),
  ((SELECT max(id) FROM Checks) + 11, 'fixierad', 'CPP2_s21_containers', '2023-07-31'),
  ((SELECT max(id) FROM Checks) + 12, 'evelinaj', 'DO3_LinuxMonitoring v1.0', '2022-10-23'),
  ((SELECT max(id) FROM Checks) + 13, 'shontagr', 'C6_s21_matrix', '2023-03-02'),
  ((SELECT max(id) FROM Checks) + 14, 'steffani', 'C3_s21_string+', '2023-02-21'),
  ((SELECT max(id) FROM Checks) + 15, 'steffani', 'C4_s21_math', '2023-03-04'),
  ((SELECT max(id) FROM Checks) + 16, 'steffani', 'C5_s21_decimal', '2023-03-25'),
  ((SELECT max(id) FROM Checks) + 17, 'steffani', 'C6_s21_matrix', '2023-04-11'),
  ((SELECT max(id) FROM Checks) + 18, 'steffani', 'C7_SmartCalc_v1.0', '2023-04-26'),
  ((SELECT max(id) FROM Checks) + 19, 'steffani', 'C8_3DViewer_v1.0', '2023-05-07'),
  ((SELECT max(id) FROM Checks) + 20, 'fixierad', 'DO1_Linux', '2023-01-09'),
  ((SELECT max(id) FROM Checks) + 21, 'fixierad', 'DO2_Linux_Network', '2023-02-10'),
  ((SELECT max(id) FROM Checks) + 22, 'fixierad', 'DO3_LinuxMonitoring v1.0', '2023-02-15'),
  ((SELECT max(id) FROM Checks) + 23, 'fixierad', 'DO4_LinuxMonitoring v2.0', '2023-03-25'),
  ((SELECT max(id) FROM Checks) + 24, 'fixierad', 'DO5_SimpleDocker', '2023-04-26'),
  ((SELECT max(id) FROM Checks) + 25, 'fixierad', 'DO6_CICD', '2023-05-17');

INSERT INTO P2P (id, "Check", CheckingPeer, State, Time)
VALUES ((SELECT max(id) FROM P2P) + 1, (SELECT max(id) FROM Checks) - 24, 'shontagr', 'Start', '08:00:00'),
  ((SELECT max(id) FROM P2P) + 2, (SELECT max(id) FROM Checks) - 24, 'shontagr', 'Success', '08:30:00'),
  ((SELECT max(id) FROM P2P) + 3, (SELECT max(id) FROM Checks) - 23, 'evelinaj', 'Start', '09:10:00'),
  ((SELECT max(id) FROM P2P) + 4, (SELECT max(id) FROM Checks) - 23, 'evelinaj', 'Success', '09:35:00'),
  ((SELECT max(id) FROM P2P) + 5, (SELECT max(id) FROM Checks) - 22, 'melonywa', 'Start', '19:00:00'),
  ((SELECT max(id) FROM P2P) + 6, (SELECT max(id) FROM Checks) - 22, 'melonywa', 'Success', '19:35:00'),
  ((SELECT max(id) FROM P2P) + 7, (SELECT max(id) FROM Checks) - 21, 'steffani', 'Start', '12:17:00'),
  ((SELECT max(id) FROM P2P) + 8, (SELECT max(id) FROM Checks) - 21, 'steffani', 'Success', '12:38:00'),
  ((SELECT max(id) FROM P2P) + 9, (SELECT max(id) FROM Checks) - 20, 'steffani', 'Start', '13:02:00'),
  ((SELECT max(id) FROM P2P) + 10, (SELECT max(id) FROM Checks) - 20, 'steffani', 'Failure', '13:23:00'),
  ((SELECT max(id) FROM P2P) + 11, (SELECT max(id) FROM Checks) - 19, 'shontagr', 'Start', '09:00:00'),
  ((SELECT max(id) FROM P2P) + 12, (SELECT max(id) FROM Checks) - 19, 'shontagr', 'Success', '09:29:00'),
  ((SELECT max(id) FROM P2P) + 13, (SELECT max(id) FROM Checks) - 18, 'evelinaj', 'Start', '15:45:00'),
  ((SELECT max(id) FROM P2P) + 14, (SELECT max(id) FROM Checks) - 18, 'evelinaj', 'Success', '15:58:00'),
  ((SELECT max(id) FROM P2P) + 15, (SELECT max(id) FROM Checks) - 17, 'steffani', 'Start', '17:08:00'),
  ((SELECT max(id) FROM P2P) + 16, (SELECT max(id) FROM Checks) - 17, 'steffani', 'Failure', '17:20:00'),
  ((SELECT max(id) FROM P2P) + 17, (SELECT max(id) FROM Checks) - 16, 'steffani', 'Start', '14:31:00'),
  ((SELECT max(id) FROM P2P) + 18, (SELECT max(id) FROM Checks) - 16, 'steffani', 'Failure', '14:53:00'),
  ((SELECT max(id) FROM P2P) + 19, (SELECT max(id) FROM Checks) - 15, 'timberly', 'Start', '17:12:00'),
  ((SELECT max(id) FROM P2P) + 20, (SELECT max(id) FROM Checks) - 15, 'timberly', 'Success', '17:39:00'),
  ((SELECT max(id) FROM P2P) + 21, (SELECT max(id) FROM Checks) - 14, 'evelinaj', 'Start', '21:17:00'),
  ((SELECT max(id) FROM P2P) + 22, (SELECT max(id) FROM Checks) - 14, 'evelinaj', 'Success', '21:29:00'),
  ((SELECT max(id) FROM P2P) + 23, (SELECT max(id) FROM Checks) - 13, 'melonywa', 'Start', '20:17:00'),
  ((SELECT max(id) FROM P2P) + 24, (SELECT max(id) FROM Checks) - 13, 'melonywa', 'Success', '20:34:00'),
  ((SELECT max(id) FROM P2P) + 25, (SELECT max(id) FROM Checks) - 12, 'garroshm', 'Start', '11:02:00'),
  ((SELECT max(id) FROM P2P) + 26, (SELECT max(id) FROM Checks) - 12, 'garroshm', 'Success', '11:13:00'),
  ((SELECT max(id) FROM P2P) + 27, (SELECT max(id) FROM Checks) - 11, 'garroshm', 'Start', '12:02:00'),
  ((SELECT max(id) FROM P2P) + 28, (SELECT max(id) FROM Checks) - 11, 'garroshm', 'Success', '12:34:00'),
  ((SELECT max(id) FROM P2P) + 29, (SELECT max(id) FROM Checks) - 10, 'timberly', 'Start', '08:30:00'),
  ((SELECT max(id) FROM P2P) + 30, (SELECT max(id) FROM Checks) - 10, 'timberly', 'Success', '09:10:00'),
  ((SELECT max(id) FROM P2P) + 31, (SELECT max(id) FROM Checks) - 9, 'melonywa', 'Start', '09:35:00'),
  ((SELECT max(id) FROM P2P) + 32, (SELECT max(id) FROM Checks) - 9, 'melonywa', 'Success', '19:00:00'),
  ((SELECT max(id) FROM P2P) + 33, (SELECT max(id) FROM Checks) - 8, 'garroshm', 'Start', '19:35:00'),
  ((SELECT max(id) FROM P2P) + 34, (SELECT max(id) FROM Checks) - 8, 'garroshm', 'Success', '12:17:00'),
  ((SELECT max(id) FROM P2P) + 35, (SELECT max(id) FROM Checks) - 7, 'evelinaj', 'Start', '12:38:00'),
  ((SELECT max(id) FROM P2P) + 36, (SELECT max(id) FROM Checks) - 7, 'evelinaj', 'Success', '13:02:00'),
  ((SELECT max(id) FROM P2P) + 37, (SELECT max(id) FROM Checks) - 6, 'steffani', 'Start', '13:23:00'),
  ((SELECT max(id) FROM P2P) + 38, (SELECT max(id) FROM Checks) - 6, 'steffani', 'Success', '09:00:00'),
  ((SELECT max(id) FROM P2P) + 39, (SELECT max(id) FROM Checks) - 5, 'shontagr', 'Start', '09:29:00'),
  ((SELECT max(id) FROM P2P) + 40, (SELECT max(id) FROM Checks) - 5, 'shontagr', 'Success', '15:45:00'),
  ((SELECT max(id) FROM P2P) + 41, (SELECT max(id) FROM Checks) - 4, 'shontagr', 'Start', '09:00:00'),
  ((SELECT max(id) FROM P2P) + 42, (SELECT max(id) FROM Checks) - 4, 'shontagr', 'Success', '09:29:00'),
  ((SELECT max(id) FROM P2P) + 43, (SELECT max(id) FROM Checks) - 3, 'evelinaj', 'Start', '15:45:00'),
  ((SELECT max(id) FROM P2P) + 44, (SELECT max(id) FROM Checks) - 3, 'evelinaj', 'Success', '15:58:00'),
  ((SELECT max(id) FROM P2P) + 45, (SELECT max(id) FROM Checks) - 2, 'steffani', 'Start', '17:08:00'),
  ((SELECT max(id) FROM P2P) + 46, (SELECT max(id) FROM Checks) - 2, 'steffani', 'Success', '17:18:00'),
  ((SELECT max(id) FROM P2P) + 47, (SELECT max(id) FROM Checks) - 1, 'steffani', 'Start', '17:08:00'),
  ((SELECT max(id) FROM P2P) + 48, (SELECT max(id) FROM Checks) - 1, 'steffani', 'Success', '17:18:00'),
  ((SELECT max(id) FROM P2P) + 49, (SELECT max(id) FROM Checks), 'melonywa', 'Start', '09:35:00'),
  ((SELECT max(id) FROM P2P) + 50, (SELECT max(id) FROM Checks), 'melonywa', 'Success', '19:00:00');

INSERT INTO Verter (id, "Check", State, Time)
VALUES ((SELECT max(id) FROM Verter) + 1, (SELECT max(id) FROM Checks) - 24, 'Start', '09:12:00'),
  ((SELECT max(id) FROM Verter) + 2, (SELECT max(id) FROM Checks) - 24, 'Success', '09:13:00'),
  ((SELECT max(id) FROM Verter) + 3, (SELECT max(id) FROM Checks) - 23, 'Start', '10:40:00'),
  ((SELECT max(id) FROM Verter) + 4, (SELECT max(id) FROM Checks) - 23, 'Success', '10:41:00'),
  ((SELECT max(id) FROM Verter) + 5, (SELECT max(id) FROM Checks) - 22, 'Start', '14:29:00'),
  ((SELECT max(id) FROM Verter) + 6, (SELECT max(id) FROM Checks) - 22, 'Success', '14:30:00'),
  ((SELECT max(id) FROM Verter) + 7, (SELECT max(id) FROM Checks) - 21, 'Start', '12:50:00'),
  ((SELECT max(id) FROM Verter) + 8, (SELECT max(id) FROM Checks) - 21, 'Success', '12:51:00'),
  ((SELECT max(id) FROM Verter) + 9, (SELECT max(id) FROM Checks) - 20, 'Start', '14:10:00'),
  ((SELECT max(id) FROM Verter) + 10, (SELECT max(id) FROM Checks) - 20, 'Failure', '14:11:00'),
  ((SELECT max(id) FROM Verter) + 11, (SELECT max(id) FROM Checks) - 19, 'Start', '10:00:00'),
  ((SELECT max(id) FROM Verter) + 12, (SELECT max(id) FROM Checks) - 19, 'Success', '10:01:00'),
  ((SELECT max(id) FROM Verter) + 13, (SELECT max(id) FROM Checks) - 17, 'Start', '17:30:00'),
  ((SELECT max(id) FROM Verter) + 14, (SELECT max(id) FROM Checks) - 17, 'Success', '17:31:00'), -- 8
  ((SELECT max(id) FROM Verter) + 15, (SELECT max(id) FROM Checks) - 14, 'Start', '21:15:00'),
  ((SELECT max(id) FROM Verter) + 16, (SELECT max(id) FROM Checks) - 14, 'Failure', '21:16:00'),
  ((SELECT max(id) FROM Verter) + 17, (SELECT max(id) FROM Checks) - 13, 'Start', '22:13:00'),
  ((SELECT max(id) FROM Verter) + 18, (SELECT max(id) FROM Checks) - 13, 'Success', '22:14:00'),
  ((SELECT max(id) FROM Verter) + 19, (SELECT max(id) FROM Checks) - 12, 'Start', '23:41:00'),
  ((SELECT max(id) FROM Verter) + 20, (SELECT max(id) FROM Checks) - 12, 'Success', '23:42:00'), 
  ((SELECT max(id) FROM Verter) + 21, (SELECT max(id) FROM Checks) - 11, 'Start', '22:30:00'),
  ((SELECT max(id) FROM Verter) + 22, (SELECT max(id) FROM Checks) - 11, 'Success', '22:31:00'),
  ((SELECT max(id) FROM Verter) + 23, (SELECT max(id) FROM Checks) - 10, 'Start', '21:51:00'),
  ((SELECT max(id) FROM Verter) + 24, (SELECT max(id) FROM Checks) - 10, 'Success', '21:52:00'),
  ((SELECT max(id) FROM Verter) + 25, (SELECT max(id) FROM Checks) - 9, 'Start', '21:51:00'),
  ((SELECT max(id) FROM Verter) + 26, (SELECT max(id) FROM Checks) - 9, 'Success', '21:52:00');

INSERT INTO Friends (id, Peer1, Peer2)
VALUES ((SELECT max(id) FROM Friends) + 1, 'steffani', 'timberly'),
  ((SELECT max(id) FROM Friends) + 2, 'steffani', 'shontagr'),
  ((SELECT max(id) FROM Friends) + 3, 'steffani', 'garroshm'),
  ((SELECT max(id) FROM Friends) + 4, 'steffani', 'melonywa'),
  ((SELECT max(id) FROM Friends) + 5, 'steffani', 'evelinaj'),
  ((SELECT max(id) FROM Friends) + 6, 'steffani', 'fixierad'),
  ((SELECT max(id) FROM Friends) + 7, 'timberly', 'steffani'),
  ((SELECT max(id) FROM Friends) + 8, 'timberly', 'garroshm'),
  ((SELECT max(id) FROM Friends) + 9, 'timberly', 'melonywa'),
  ((SELECT max(id) FROM Friends) + 10, 'timberly', 'evelinaj'),
  ((SELECT max(id) FROM Friends) + 11, 'timberly', 'fixierad'),
  ((SELECT max(id) FROM Friends) + 12, 'timberly', 'shontagr'),
  ((SELECT max(id) FROM Friends) + 13, 'evelinaj', 'steffani'),
  ((SELECT max(id) FROM Friends) + 14, 'evelinaj', 'timberly'),
  ((SELECT max(id) FROM Friends) + 15, 'shontagr', 'steffani'),
  ((SELECT max(id) FROM Friends) + 16, 'shontagr', 'garroshm'),
  ((SELECT max(id) FROM Friends) + 17, 'shontagr', 'melonywa'),
  ((SELECT max(id) FROM Friends) + 18, 'shontagr', 'fixierad'),
  ((SELECT max(id) FROM Friends) + 19, 'shontagr', 'timberly'),
  ((SELECT max(id) FROM Friends) + 20, 'garroshm', 'steffani'),
  ((SELECT max(id) FROM Friends) + 21, 'garroshm', 'melonywa'),
  ((SELECT max(id) FROM Friends) + 22, 'garroshm', 'fixierad'),
  ((SELECT max(id) FROM Friends) + 23, 'garroshm', 'shontagr'),
  ((SELECT max(id) FROM Friends) + 24, 'garroshm', 'timberly'),
  ((SELECT max(id) FROM Friends) + 25, 'melonywa', 'steffani'),
  ((SELECT max(id) FROM Friends) + 26, 'melonywa', 'garroshm'),
  ((SELECT max(id) FROM Friends) + 27, 'melonywa', 'timberly'),
  ((SELECT max(id) FROM Friends) + 28, 'melonywa', 'fixierad'),
  ((SELECT max(id) FROM Friends) + 29, 'melonywa', 'shontagr'),
  ((SELECT max(id) FROM Friends) + 30, 'fixierad', 'steffani'),
  ((SELECT max(id) FROM Friends) + 31, 'fixierad', 'garroshm'),
  ((SELECT max(id) FROM Friends) + 32, 'fixierad', 'timberly'),
  ((SELECT max(id) FROM Friends) + 33, 'fixierad', 'melonywa'),
  ((SELECT max(id) FROM Friends) + 34, 'fixierad', 'shontagr');
  
INSERT INTO Recommendations (id, Peer, RecommendedPeer)
VALUES ((SELECT max(id) FROM Recommendations) + 1, 'steffani', 'garroshm'),
  ((SELECT max(id) FROM Recommendations) + 2, 'timberly', 'garroshm'),
  ((SELECT max(id) FROM Recommendations) + 3, 'shontagr', 'garroshm'),
  ((SELECT max(id) FROM Recommendations) + 4, 'fixierad', 'garroshm'),
  ((SELECT max(id) FROM Recommendations) + 5, 'timberly', 'garroshm'),
  ((SELECT max(id) FROM Recommendations) + 6, 'timberly', 'steffani'),
  ((SELECT max(id) FROM Recommendations) + 7, 'shontagr', 'steffani'),
  ((SELECT max(id) FROM Recommendations) + 8, 'fixierad', 'steffani'),
  ((SELECT max(id) FROM Recommendations) + 9, 'garroshm', 'steffani'),
  ((SELECT max(id) FROM Recommendations) + 10, 'timberly', 'fixierad'),
  ((SELECT max(id) FROM Recommendations) + 11, 'shontagr', 'fixierad'),
  ((SELECT max(id) FROM Recommendations) + 12, 'steffani', 'fixierad'),
  ((SELECT max(id) FROM Recommendations) + 13, 'garroshm', 'fixierad'),
  ((SELECT max(id) FROM Recommendations) + 14, 'steffani', 'shontagr');

INSERT INTO TimeTracking (id, Peer, Date, Time, State)
VALUES ((SELECT max(id) FROM TimeTracking) + 1, 'steffani', '2023-12-02', '12:16', 1),
  ((SELECT max(id) FROM TimeTracking) + 2, 'steffani', '2023-12-02', '14:52', 2),
  ((SELECT max(id) FROM TimeTracking) + 3, 'steffani', '2023-12-01', '09:53', 1),
  ((SELECT max(id) FROM TimeTracking) + 4, 'steffani', '2023-12-01', '20:11', 2),
  ((SELECT max(id) FROM TimeTracking) + 5, 'timberly', '2023-09-25', '09:11', 1),
  ((SELECT max(id) FROM TimeTracking) + 6, 'timberly', '2023-09-25', '19:11', 2),
  ((SELECT max(id) FROM TimeTracking) + 7, 'garroshm', '2023-11-12', '07:52', 1),
  ((SELECT max(id) FROM TimeTracking) + 8, 'garroshm', '2023-11-12', '17:53', 2),
  ((SELECT max(id) FROM TimeTracking) + 9, 'evelinaj', '2023-10-16', '09:11', 1),
  ((SELECT max(id) FROM TimeTracking) + 10, 'evelinaj', '2023-10-16', '16:11', 2),
  ((SELECT max(id) FROM TimeTracking) + 11, 'timberly', '2023-11-28', '09:11', 1),
  ((SELECT max(id) FROM TimeTracking) + 12, 'timberly', '2023-11-28', '19:11', 2),
  ((SELECT max(id) FROM TimeTracking) + 13, 'garroshm', '2023-11-30', '14:52', 1),
  ((SELECT max(id) FROM TimeTracking) + 14, 'garroshm', '2023-11-30', '20:53', 2),
  ((SELECT max(id) FROM TimeTracking) + 15, 'evelinaj', '2023-10-16', '20:11', 1),
  ((SELECT max(id) FROM TimeTracking) + 16, 'evelinaj', '2023-10-16', '09:11', 2),
  ((SELECT max(id) FROM TimeTracking) + 17, 'timberly', '2023-10-28', '09:11', 1),
  ((SELECT max(id) FROM TimeTracking) + 18, 'timberly', '2023-10-28', '19:11', 2),
  ((SELECT max(id) FROM TimeTracking) + 19, 'garroshm', '2023-11-15', '08:52', 1),
  ((SELECT max(id) FROM TimeTracking) + 20, 'garroshm', '2023-11-15', '22:53', 2),
  ((SELECT max(id) FROM TimeTracking) + 21, 'fixierad', '2023-11-04', '12:11', 1),
  ((SELECT max(id) FROM TimeTracking) + 22, 'fixierad', '2023-11-04', '21:11', 2);

INSERT INTO TransferredPoints (id, CheckingPeer, CheckedPeer, PointsAmount)
VALUES ((SELECT max(id) FROM TransferredPoints) + 1, 'shontagr', 'steffani', 1),
  ((SELECT max(id) FROM TransferredPoints) + 2, 'garroshm', 'steffani', 1),
  ((SELECT max(id) FROM TransferredPoints) + 3, 'timberly', 'steffani', 1),
  ((SELECT max(id) FROM TransferredPoints) + 4, 'evelinaj', 'timberly', 1),
  ((SELECT max(id) FROM TransferredPoints) + 5, 'melonywa', 'timberly', 1),
  ((SELECT max(id) FROM TransferredPoints) + 6, 'steffani', 'evelinaj', 1),
  ((SELECT max(id) FROM TransferredPoints) + 7, 'melonywa', 'evelinaj', 1),
  ((SELECT max(id) FROM TransferredPoints) + 8, 'steffani', 'shontagr', 2),
  ((SELECT max(id) FROM TransferredPoints) + 9, 'garroshm', 'shontagr', 1),
  ((SELECT max(id) FROM TransferredPoints) + 10, 'shontagr', 'garroshm', 1),
  ((SELECT max(id) FROM TransferredPoints) + 11, 'evelinaj', 'melonywa', 1),
  ((SELECT max(id) FROM TransferredPoints) + 12, 'steffani', 'fixierad', 1),
  ((SELECT max(id) FROM TransferredPoints) + 13, 'evelinaj', 'fixierad', 1);

INSERT INTO XP (id, "Check", xpamount)
VALUES ((SELECT max(id) FROM XP) + 1, (SELECT max(id) FROM Checks) - 24, 250),
  ((SELECT max(id) FROM XP) + 2, (SELECT max(id) FROM Checks) - 23, 500),
  ((SELECT max(id) FROM XP) + 3, (SELECT max(id) FROM Checks) - 22, 350),
  ((SELECT max(id) FROM XP) + 4, (SELECT max(id) FROM Checks) - 21, 500),
  ((SELECT max(id) FROM XP) + 5, (SELECT max(id) FROM Checks) - 19, 500),
  ((SELECT max(id) FROM XP) + 6, (SELECT max(id) FROM Checks) - 18, 300),
  ((SELECT max(id) FROM XP) + 7, (SELECT max(id) FROM Checks) - 15, 250),
  ((SELECT max(id) FROM XP) + 8, (SELECT max(id) FROM Checks) - 13, 350),
  ((SELECT max(id) FROM XP) + 9, (SELECT max(id) FROM Checks) - 12, 200),
  ((SELECT max(id) FROM XP) + 10, (SELECT max(id) FROM Checks) - 11, 500),
  ((SELECT max(id) FROM XP) + 11, (SELECT max(id) FROM Checks) - 10, 300),
  ((SELECT max(id) FROM XP) + 12, (SELECT max(id) FROM Checks) - 9, 500),
  ((SELECT max(id) FROM XP) + 13, (SELECT max(id) FROM Checks) - 8, 300),
  ((SELECT max(id) FROM XP) + 14, (SELECT max(id) FROM Checks) - 7, 500),
  ((SELECT max(id) FROM XP) + 15, (SELECT max(id) FROM Checks) - 6, 350),
  ((SELECT max(id) FROM XP) + 16, (SELECT max(id) FROM Checks) - 5, 300),
  ((SELECT max(id) FROM XP) + 17, (SELECT max(id) FROM Checks) - 4, 250),
  ((SELECT max(id) FROM XP) + 18, (SELECT max(id) FROM Checks) - 3, 350),
  ((SELECT max(id) FROM XP) + 19, (SELECT max(id) FROM Checks) - 2, 350),
  ((SELECT max(id) FROM XP) + 20, (SELECT max(id) FROM Checks) - 1, 300),
  ((SELECT max(id) FROM XP) + 21, (SELECT max(id) FROM Checks), 300);


-- вызов экспорта
CALL export_table(name_table:='Peers', file_path:='/home/ipakin/SQL2_Info21_v1.0-1/src/dataset/export_examples/peers_exported.csv', separ:=';');
CALL export_table(name_table:='Checks', file_path:='/home/ipakin/SQL2_Info21_v1.0-1/src/dataset/export_examples/checks_exported.csv', separ:=';');

-- -- Для удаления БД
-- SELECT pg_terminate_backend(pg_stat_activity.pid)
-- FROM pg_stat_activity
-- WHERE pg_stat_activity.datname = 'sql_info21'
--   AND pid <> pg_backend_pid();
-- DROP DATABASE sql_info21;