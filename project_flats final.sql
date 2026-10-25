/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 * 
 * Автор: Хромов Денис
 * Дата: 29.04.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:
filtered_id AS(
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
 ), 
categories AS (                                                                 -- Продолжите запрос здесь
                                                                                -- Используйте id объявлений (СТЕ filtered_id), которые не содержат выбросы при анализе данных
    SELECT fid.id,
    CASE
        WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'  
        ELSE 'ЛенОбл'
    END AS region,
    CASE
        WHEN days_exposition IS NULL THEN 'non category'  -- активные объявления
        WHEN days_exposition <= 30 THEN 'до одного месяца'    
        WHEN days_exposition BETWEEN 31 AND 90 THEN 'до трёх месяцев'
        WHEN days_exposition BETWEEN 91 AND 180 THEN 'до полугода'
        ELSE 'более полугода'
    END AS activity_length,
     a.last_price,
     f.total_area,
     a.last_price / f.total_area AS qm_price,              -- цена за кв. метр
     f.rooms,
     f.balcony,
     f.floors_total
FROM real_estate.city AS c
LEFT JOIN real_estate.flats AS f USING(city_id)
LEFT JOIN real_estate.advertisement AS a USING(id)
LEFT JOIN real_estate.type AS t USING(type_id)
INNER JOIN filtered_id AS fid ON fid.id = f.id
WHERE t.type = 'город' AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-31'
)
SELECT region,
       activity_length,
       COUNT(id) AS total_adv,                                                                    --  количество объявлений
       ROUND(COUNT(*)/(SUM(COUNT(*)) OVER(PARTITION BY region))::NUMERIC, 2) AS perc_adv,   --  доля объявлений
       ROUND(AVG(qm_price)::NUMERIC, 2) AS avg_qm_price,                                          --  средняя цена за м.кв.
       ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area,                                            --  средняя площадь
       ROUND(AVG(rooms)::NUMERIC, 2) AS avg_rooms,                                                --  среднее кол-во комнат
       ROUND(AVG(balcony)::NUMERIC, 2) AS avg_balcony,                                            --  среднее кол-во балконов
       ROUND(AVG(floors_total)::NUMERIC, 2) AS avg_housefloors                                    --  средняя этажность дома
FROM categories
GROUP BY region, activity_length
ORDER BY region DESC, activity_length 
       




-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_CONT(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_CONT(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы, также оставим пропущенные данные:  
--При агрегации данных посчитайте количество объявлений для каждого периода, среднюю стоимость квадратного метра и среднюю площадь недвижимости.
filtered_id AS (
    SELECT id
    FROM real_estate.flats
    WHERE
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
 ),
months AS (
     SELECT fid.id,
            EXTRACT(MONTH FROM a.first_day_exposition) AS first_month,
            EXTRACT(MONTH FROM (a.first_day_exposition + a.days_exposition::int)) AS last_month,
            f.total_area,
            a.last_price / f.total_area AS qm_price
     FROM real_estate.advertisement AS a 
     LEFT JOIN real_estate.flats AS f USING(id)
     LEFT JOIN real_estate.type AS t USING(type_id)
     INNER JOIN filtered_id AS fid ON fid.id = f.id
     WHERE t.type = 'город' 
           AND a.first_day_exposition BETWEEN '2015-01-01' AND '2018-12-01'
           AND (a.first_day_exposition + a.days_exposition::int) BETWEEN '2015-01-01' AND '2018-12-01'
 ),
 first_month AS (
     SELECT  first_month,
            COUNT(id) AS total_adv,
            ROUND(AVG(qm_price)::NUMERIC, 2) AS avg_qm_price,
            ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area
     FROM months
     GROUP BY first_month
     ORDER BY first_month ASC
),
last_month AS (
     SELECT last_month,
            COUNT(id) AS total_sold,
            ROUND(AVG(qm_price)::NUMERIC, 2) AS avg_qm_price,
            ROUND(AVG(total_area)::NUMERIC, 2) AS avg_area
     FROM months
     GROUP BY last_month
     ORDER BY last_month ASC
)
     SELECT *
     FROM first_month AS fm
     FULL JOIN last_month AS lm ON fm.first_month = lm.last_month
     ORDER BY first_month ASC;
            

 
    