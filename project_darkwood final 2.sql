/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Хромов Денис
 * Дата: 06.04.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков


-- 1.1. Доля платящих пользователей по всем данным:
SELECT DISTINCT COUNT(id) AS total_users,
       (SELECT COUNT(id) FROM fantasy.users WHERE payer = 1) AS donuted_users,
       AVG(payer) AS users_share
FROM fantasy.users


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
SELECT race_id,
       SUM(payer) AS payer_by_race,
       COUNT(id) AS user_count_by_race,
       AVG(payer) AS payer_ratio_by_race
FROM fantasy.users
GROUP BY race_id
ORDER BY race_id

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
SELECT COUNT(amount) AS total_buys,
       SUM(amount) AS total_amount,
       MIN(amount) AS min_buy,
       MAX(amount) AS max_buy,
       AVG(amount) AS avg_buy,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY amount) AS buys_median,
       STDDEV(amount) AS stand_dev
FROM fantasy.events
WHERE amount > 0

-- 2.2: Аномальные нулевые покупки:
SELECT (SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount = 0) AS zero_cost_buys, 
       COUNT(transaction_id) AS total_buys,
       (SELECT COUNT(transaction_id) FROM fantasy.events WHERE amount = 0)/COUNT(transaction_id)::real AS zero_buys_share
FROM fantasy.events


-- 2.3: Популярные эпические предметы:
WITH total_users_count AS (
    SELECT COUNT(DISTINCT id) AS all_users FROM fantasy.events WHERE amount > 0
),
total_buys_count AS (
    SELECT COUNT(transaction_id) AS total_buys FROM fantasy.events WHERE amount > 0
)
SELECT 
    e.item_code, i.game_items,
    COUNT(e.transaction_id) AS item_buys,
    (SELECT total_buys FROM total_buys_count) AS total_buys,
    COUNT(DISTINCT e.id) AS users_purchased,
    COUNT(e.transaction_id)::numeric / (SELECT total_buys FROM total_buys_count) AS buys_share,
    COUNT(DISTINCT e.id)::numeric / (SELECT all_users FROM total_users_count) AS user_purchased_share
FROM fantasy.events AS e
LEFT JOIN fantasy.items AS i ON e.item_code = i.item_code
WHERE amount > 0
GROUP BY e.item_code, i.game_items
ORDER BY item_buys DESC



-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
WITH users_by_race AS (
     SELECT race_id,
            COUNT(id) AS total_users
     FROM fantasy.users 
     GROUP BY race_id
), payers_by_race AS (
     SELECT race_id, 
            COUNT(id) AS buyer_count, -- количество игроков, которые совершают внутриигровые покупки
            AVG(payer) AS avg_payers
     FROM fantasy.users
     WHERE id in (SELECT id FROM fantasy.events WHERE amount!=0)
     GROUP BY race_id
     ), payers_activity_by_race AS ( 
     SELECT users.race_id AS race_id,
            COUNT(events.transaction_id)::real/COUNT(DISTINCT events.id) AS avg_buys_per_user,
            AVG(events.amount) AS avg_cost_per_user,
            SUM(events.amount)/COUNT(DISTINCT events.id) AS avg_sum_cost
     FROM fantasy.events
     LEFT JOIN fantasy.users ON events.id = users.id
     WHERE amount > 0
     GROUP BY users.race_id)
SELECT ubr.race_id,
       r.race, 
       ubr.total_users,
       pbr.buyer_count,
       ROUND(pbr.buyer_count::numeric / total_users, 2) AS total_share,
       ROUND(AVG(pbr.avg_payers)::numeric, 2) AS payers_share,
       pabr.avg_buys_per_user,
       ROUND(pabr.avg_cost_per_user::numeric, 2) AS avg_cost_per_user,
       ROUND(pabr.avg_sum_cost::numeric, 2) AS avg_sum_cost
FROM payers_activity_by_race AS pabr
JOIN payers_by_race AS pbr ON pabr.race_id = pbr.race_id
JOIN users_by_race AS ubr ON pbr.race_id = ubr.race_id
JOIN fantasy.race r ON ubr.race_id = r.race_id
GROUP BY ubr.race_id, r.race, ubr.total_users, pbr.buyer_count, pabr.avg_buys_per_user, pabr.avg_cost_per_user, pabr.avg_sum_cost
ORDER BY race

     
     
     
     
     
     
