/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Смирнова Анастасия
 * Дата: 14.11.2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков.

-- 1.1. Доля платящих пользователей по всем данным:
--Подсчет общего количества игроков
WITH users_count AS
     (SELECT 1 AS key_id,
            COUNT(users.id) AS total_users
       FROM fantasy.users),
--Подсчет платящих игроков
     payers_count AS 
     (SELECT 1 AS key_id,
             COUNT(users.id) AS total_payer_users 
       FROM fantasy.users
      WHERE payer = 1)
--Соединение подсчитанных показателей в одну таблицу и нахождение доли платящих игроков
SELECT users_count.total_users,
       payers_count.total_payer_users,
       ROUND(CAST(payers_count.total_payer_users AS numeric) / CAST(users_count.total_users AS numeric),2) AS users_payers_share
  FROM users_count
       JOIN payers_count 
       ON users_count.key_id = payers_count.key_id;
      
-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
--Присоединяем к талблице users данные из даблицы race по полю race_id.
WITH stats_by_race AS
     (SELECT id,
             payer,
             race.race
       FROM fantasy.users AS users
            JOIN fantasy.race AS race 
            ON users.race_id = race.race_id),
--Находим общее количество игроков в разрезе каждой расы.
     total_users_by_race AS
     (SELECT race,
             COUNT(stats_by_race.id) AS users_by_race_count
       FROM stats_by_race
      GROUP BY race),
--Находим количество платящих игроков для каждой расы.
     total_payers_users_by_race AS 
     (SELECT race,
             COUNT(stats_by_race.id) AS payers_users_by_race_count
       FROM stats_by_race
      WHERE payer = 1
      GROUP BY race)
--Соединяем результаты двух предыдущих запросов в одну таблицу и находим долю платящих игроков от общего количества игроков для каждой расы. 
--Сортируем по убыванию общего количества игроков и количества платящих игроков.
SELECT total_users_by_race.race,
       total_users_by_race.users_by_race_count,
       total_payers_users_by_race.payers_users_by_race_count,
       ROUND(CAST(total_payers_users_by_race.payers_users_by_race_count AS numeric) / CAST(total_users_by_race.users_by_race_count AS numeric),2) AS users_payers_by_race_share
  FROM total_users_by_race
       JOIN total_payers_users_by_race 
       ON total_users_by_race.race = total_payers_users_by_race.race
 ORDER BY total_users_by_race.users_by_race_count DESC, total_payers_users_by_race.payers_users_by_race_count DESC;

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(*) AS transactions_count,
       SUM(amount) AS trasactions_sum,
       MIN(amount) AS min_transaction,
       MAX(amount) AS max_transaction,
       AVG(amount) AS avg_transaction,
       (PERCENTILE_DISC(0.50)
        WITHIN GROUP (ORDER BY amount)) AS median,
       STDDEV(amount) AS stand_dev
  FROM fantasy.events;

-- 2.2: Аномальные нулевые покупки:
SELECT COUNT(amount) AS transactions_count, --Рассчитываем общее количество транзакций
       (SELECT COUNT(amount) --Находим количество "нулевых" транзакций
          FROM fantasy.events
         WHERE amount = 0) AS zero_value_transactions_count,  --Рассчитываем долю нулевых транзакций от общего количества
       (SELECT CAST (COUNT(amount) AS float)
          FROM fantasy.events
         WHERE amount = 0) / 
       (SELECT COUNT(amount)
          FROM fantasy.events) AS zero_value_transactions_share
  FROM fantasy.events; 
-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
--Рассчитываем общее количество транзакций на игрока, а также сумму всех транзакци на одного игрока, исключая из расчета те записи, где значение amount = 0
WITH total_ts_amount AS
     (SELECT id,
             COUNT(transaction_id) AS transaction_per_user,
             SUM(amount) AS sum_of_ts_per_user
       FROM fantasy.events
      WHERE amount <> 0
      GROUP BY id
      ORDER BY id),
--Присоединяем данные по рассчитанными транзакциям из таблицы events к данным по всем пользователям в таблице users.
     stats_by_both_groups AS
     (SELECT users.id,
             users.payer,
             total_ts_amount.sum_of_ts_per_user,
             total_ts_amount.transaction_per_user
       FROM fantasy.users AS users
            LEFT JOIN total_ts_amount 
            ON users.id = total_ts_amount.id),
--Рассчитыываем статистические показатели для платящих пользователей, использующих внутриигровую валюту.
     stats_by_payers_using_currency AS
     (SELECT 1 AS key_id,
             COUNT(id) AS payers_using_currency_amount,
             AVG(transaction_per_user) AS avg_transactions_payers,
             AVG(sum_of_ts_per_user) AS avg_sum_payers
       FROM stats_by_both_groups 
      WHERE payer = 1 AND sum_of_ts_per_user IS NOT NULL),
 --Рассчитываем статистические показатели для платящих пользователей, не осуществляющих транзакции во внутриигровой валюте.
     stats_by_payers_not_using_currency AS
     (SELECT 1 AS key_id,
             COUNT(id) AS payers_not_using_currency_amount
       FROM stats_by_both_groups 
      WHERE payer = 1 AND sum_of_ts_per_user IS NULL),
 --Рассчитываем общую статистику по платящим игрокам, соединяя ранее расссчитанные показатели.
     stats_by_payers_final AS
     (SELECT stats_by_payers_using_currency.key_id,
             payers_not_using_currency_amount,
             payers_using_currency_amount,
             avg_transactions_payers,
             avg_sum_payers
       FROM stats_by_payers_using_currency
       JOIN stats_by_payers_not_using_currency 
       ON stats_by_payers_using_currency.key_id = stats_by_payers_not_using_currency.key_id),
 --Рассчитываем статистические показатели по неплатящим пользователям, использующим внутриигровую валюту.
      stats_by_non_payers_using_currency AS
      (SELECT 1 AS key_id,
              COUNT(id) AS non_payers_using_currency_amount,
              AVG(transaction_per_user) AS avg_transactions_non_payers,
              AVG(sum_of_ts_per_user) AS avg_sum_non_payers
        FROM stats_by_both_groups 
       WHERE payer = 0 AND sum_of_ts_per_user IS NOT NULL),
 --Рассчитываем статистические показатели по неплатящим пользователям, которые не используют внутриигровую валюту.
     stats_by_non_payers_not_using_currency AS
     (SELECT 1 AS key_id,
             COUNT(id) AS non_payers_not_using_currency_amount
       FROM stats_by_both_groups 
      WHERE payer = 0 AND sum_of_ts_per_user IS NULL),
 --Рассчитываем общую статистику по неплатящим игрокам, соединяя ранее расссчитанные показатели.
     stats_by_non_payers_final AS
     (SELECT stats_by_non_payers_using_currency.key_id,
             non_payers_using_currency_amount,
             avg_transactions_non_payers,
             avg_sum_non_payers,
             non_payers_not_using_currency_amount
      FROM stats_by_non_payers_using_currency
           JOIN stats_by_non_payers_not_using_currency 
           ON stats_by_non_payers_using_currency.key_id = stats_by_non_payers_not_using_currency.key_id)
--И наконец соединяем все рассчитанные ранее показатели по всем группам пользователей в один запрос :)
SELECT payers_using_currency_amount,
      payers_not_using_currency_amount,
      ROUND(CAST(payers_using_currency_amount AS numeric) / (payers_using_currency_amount + payers_not_using_currency_amount),2) AS payers_using_currency_share,
      avg_transactions_payers,
      avg_sum_payers,
      non_payers_using_currency_amount,
      non_payers_not_using_currency_amount,
      ROUND(CAST(non_payers_using_currency_amount AS numeric) / (non_payers_not_using_currency_amount + non_payers_using_currency_amount),2) AS non_payers_using_currency_share,
      avg_transactions_non_payers,
      avg_sum_non_payers
  FROM stats_by_payers_final
       JOIN stats_by_non_payers_final 
       ON stats_by_payers_final.key_id = stats_by_non_payers_final.key_id;
      
--Альтернативное решение:
SELECT CASE 
	    WHEN payer = 0
	     THEN 'non-payer'
	    ELSE 'payer'
       END AS player_category,
       COUNT(DISTINCT users.id) AS total_players_by_category,
       CAST (COUNT(transaction_id) AS float) / COUNT(DISTINCT users.id) AS avg_transactions_per_user,
       CAST(SUM(amount) AS float) / COUNT(DISTINCT users.id) AS avg_sum_per_player
  FROM fantasy.users AS users
       JOIN fantasy.events AS events
       ON users.id = events.id
 GROUP BY payer;

-- 2.4: Популярные эпические предметы:
--Рассчитываем общее количество пользователей, которые осуществляли транзакции
WITH total_users AS
     (SELECT 1 AS key_id,
             COUNT(DISTINCT events.id) AS total_users_count
        FROM fantasy.events AS events),
--Соединяем данные из таблицы items и events для того, чтобы подтянуть названия эпических предметов к данным по транзакциям.
      data_items AS
      (SELECT 1 AS key_id,
              events.transaction_id,
              events.id,
              items.game_items,
              items.item_code
        FROM fantasy.events AS events
             JOIN fantasy.items AS items 
             ON events.item_code = items.item_code),
--Рассчитываем количество продаж по каждому предмету, общее количество продаж, а также находим долю продаж каждого предмета от общего количества продаж
       calculation_by_items AS
       (SELECT game_items,
               total_users_count,
               COUNT(transaction_id) OVER(PARTITION BY item_code) AS times_sold_by_item,
               COUNT(transaction_id) OVER() AS times_sold_total,
               CAST(COUNT(transaction_id) OVER(PARTITION BY item_code) AS float) / CAST(COUNT(transaction_id) OVER() AS float) AS sales_by_item_share
         FROM data_items
              JOIN total_users 
              ON total_users.key_id = data_items.key_id),
--Находим количество покупателей в разерезе каждого предмета
       users_by_items_count AS
       (SELECT game_items,
               COUNT(DISTINCT id) AS buyers_total
         FROM data_items
        GROUP BY game_items)
--Соединяем все данные в одну таблицу и рассчитываем долю пользователей, купивших предмет хотя бы единожды от общего количества активных пользователей
SELECT calculation_by_items.game_items,
       times_sold_by_item,
       times_sold_total,
       sales_by_item_share,
       CAST(buyers_total AS float) / CAST (total_users_count AS float) AS users_purchased_item_share
  FROM calculation_by_items
       JOIN users_by_items_count 
       ON calculation_by_items.game_items = users_by_items_count.game_items
 GROUP BY calculation_by_items.game_items, times_sold_by_item, times_sold_total,sales_by_item_share,total_users_count,buyers_total
 ORDER BY users_purchased_item_share DESC;

-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
--Рассчитываем количество игроков в разрезе каждой расы перед этим присоединив к таблице users названия раз из таблицы race
WITH users_by_race AS
     (SELECT race,
             COUNT(id) AS total_users_by_race
       FROM fantasy.users AS users
            JOIN fantasy.race AS race 
            ON users.race_id = race.race_id
      GROUP BY race),
--Рассчитываем активность пользователей по количеству сделанных внутриигровых покупок
     users_activity AS
     (SELECT id,
              COUNT(transaction_id) AS times_purchased
       FROM fantasy.events
      GROUP BY id),
 --Подгаталиваем данные для дальнешейго расчета статистических показателей по платящим игрокам, присоединяя к данным о пользователях рассчитанные данные по внутриигровым покупкам пользователей.
 --При это оставляем только данные по пользователям, совершавшим покупки(присоединенное поле с количеством покупок не будет пустым).
     data_for_calculation_by_payers AS
     (SELECT users.id,
             race.race,
             payer,
             times_purchased
      FROM fantasy.users AS users
           LEFT JOIN users_activity 
           ON users.id = users_activity.id
           JOIN fantasy.race AS race 
           ON users.race_id = race.race_id
     WHERE times_purchased IS NOT NULL),
 --Рассчитываем активность в разрезе рас по платящим игрокам.
    activity_by_purchasing_payers AS
    (SELECT race, 
            users_who_purchase_total,
            users_who_purchase_payers_non_payers AS users_who_purchase_payers,
            CAST(users_who_purchase_payers_non_payers AS float) / CAST(users_who_purchase_total AS float) AS users_who_purchase_payers_share
     FROM
     (SELECT *,
             COUNT(id) OVER(PARTITION BY race) AS users_who_purchase_total,
             COUNT(id) OVER(PARTITION BY race,payer) users_who_purchase_payers_non_payers
       FROM data_for_calculation_by_payers) AS subquery
      WHERE payer = 1
      GROUP BY race,users_who_purchase_total,users_who_purchase_payers_non_payers,payer
      ORDER BY race),
 --Подгатавливаем данные для дальнейших расчетов среднего количества покупок на одного игрока; средней стоимости одной покупки на одного игрока;
 -- средней суммарной стоимости всех покупок на одного игрока
     data_for_activity_by_players AS
     (SELECT events.id,
             amount,
             transaction_id,
             race.race
       FROM fantasy.events AS events
            JOIN fantasy.users AS users 
            ON events.id = users.id
            JOIN fantasy.race AS race 
            ON users.race_id = race.race_id),
 --Рассчитываем среднюю стоимость, среднее количество покупок и среднюю суммарную стоимость всех покупок на одного игрока.
     calculation_of_activity AS
     (SELECT race,
             CAST(COUNT(transaction_id) AS float) / COUNT(DISTINCT id) AS avg_purchases_per_user,
             CAST(SUM(amount) AS float) / COUNT(DISTINCT id) AS avg_sum_per_user,
             AVG(amount) AS avg_amount_per_user
       FROM data_for_activity_by_players
      GROUP BY data_for_activity_by_players.race)
--Соединяем все расчеты в итоговом запросе :)
SELECT users_by_race.race,
       total_users_by_race,
       users_who_purchase_total,
       CAST(users_who_purchase_total AS float) / total_users_by_race AS purchasing_users_share,
       users_who_purchase_payers,
       users_who_purchase_payers_share,
       avg_purchases_per_user,
       avg_sum_per_user,
       avg_amount_per_user
  FROM users_by_race
       JOIN activity_by_purchasing_payers 
       ON activity_by_purchasing_payers.race = users_by_race.race
       JOIN calculation_of_activity 
       ON users_by_race.race = calculation_of_activity.race
 ORDER BY total_users_by_race DESC, avg_purchases_per_user DESC;
 
-- Задача 2.Частота покупок.
--Находим количество дней между транзакциями пользователей, предварительно отсеяв нулевые
WITH days_between AS
     (SELECT transaction_id,
             id,
             CAST(date AS date),
             CAST(LAG(date,1,NULL) OVER(PARTITION BY id ORDER BY CAST(date AS date)) AS date) AS previous_transaction_date,
             CAST(date AS date) - CAST(LAG(date,1,NULL) OVER(PARTITION BY id ORDER BY CAST(date AS date)) AS date) days_since_prev_transaction
       FROM fantasy.events
      WHERE amount <> 0
      ORDER BY id,date),
--Находим количество транзакций на ождно пользователя и среднее кроличество дней между транзакциями, оставляем для дальнейшего расчета только тех пользователей
--у которых 25 и более транзакций
     information_users AS(
     SELECT users.payer,
            days_between.id,
            COUNT(days_between.transaction_id) AS transactions_per_user,
            AVG(days_between.days_since_prev_transaction) AS avg_days_between_transcations
      FROM days_between
      JOIN fantasy.users AS users 
      ON days_between.id = users.id
     GROUP BY days_between.id,users.payer
     HAVING COUNT(days_between.transaction_id) >= 25),
--Делим пользователей на три группы в зависимиости от частоты совершаемых транзакций
    payers_activity AS
    (SELECT *,
            NTILE(3) OVER(ORDER BY transactions_per_user DESC) AS users_rank,
            CASE
      	     WHEN NTILE(3) OVER(ORDER BY transactions_per_user DESC) = 1
      	      THEN 'Высокая частота'
      	     WHEN NTILE(3) OVER(ORDER BY transactions_per_user DESC) = 2
      	      THEN 'Средняя частота'
      	     WHEN NTILE(3) OVER(ORDER BY transactions_per_user DESC) = 3
      	      THEN 'Низкая частота'
             ELSE NULL
            END AS user_category
       FROM information_users
      ORDER BY users_rank)
--Сводим данные и рассчитываем среднее количество покупок на игрока, среднее количество дней между покупками для игрока, а также долю платящих/неплатящих игроков,
--совершающих внутриигровые покупки
SELECT 
       user_category,
       CASE
       	WHEN payer = 0
       	 THEN 'non-payer'
       	ELSE 'payer'
       END AS users_status,   
       users_per_category,
       payers_per_category,
       CAST(payers_per_category AS float) / users_per_category AS payers_share,
       CAST(SUM(transactions_per_user) AS float) / COUNT(id) AS avg_transactions_per_user,
       CAST(SUM(avg_days_between_transcations) AS float) / COUNT(id) AS avg_days_between_transactions
  FROM
  (SELECT id,
          transactions_per_user,
          avg_days_between_transcations,
          payer,
          user_category,
          COUNT(id) OVER(PARTITION BY user_category) AS users_per_category,
          COUNT(id) OVER(PARTITION BY user_category,payer) AS payers_per_category
    FROM payers_activity) AS subquery
   GROUP BY user_category,
            users_per_category, 
            payers_per_category,
            payer
   ORDER BY avg_transactions_per_user DESC;
