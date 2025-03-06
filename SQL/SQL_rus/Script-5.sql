-- Задача 1: Время активности объявлений
--Избавляемся от выбросов.
WITH limitations AS (
     SELECT 
         1 AS key_id,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_upper_limit,
         percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) AS rooms_lower_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_upper_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_upper_limit,
         percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_lower_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_upper_limit 
     FROM real_estate.flats
),
--Создаем фильтр по id квартир, в которых аномальные значения отсутствуют
filter_by_id AS(
     SELECT id
     FROM real_estate.flats
     WHERE 
         total_area < (SELECT total_area_upper_limit FROM limitations)
         AND rooms > (SELECT rooms_lower_limit FROM limitations)
         AND rooms < (SELECT rooms_upper_limit FROM limitations)
         AND balcony < (SELECT balcony_upper_limit FROM limitations)
         AND ceiling_height > (SELECT ceiling_height_lower_limit FROM limitations)
         AND ceiling_height < (SELECT ceiling_height_upper_limit FROM limitations)
 ),
 --Отбираем только нужные значения из таблицы flats
cleared_data AS(
     SELECT *
     FROM real_estate.flats
     WHERE id IN (SELECT * FROM filter_by_id)
),
--Подгатавливаем данные для расчета. Оставляем информацию только по населенным пунктам ЛО.
data_for_calculation AS(
     SELECT 
         cleared_data.id,
         CASE
         	WHEN city = 'Санкт-Петербург'
         	  THEN 'Санкт-Петербург'
         	ELSE 'Лен.область'
         END AS area_location,
         total_area,
         days_exposition,
         floor,
         rooms,
         balcony,
         CASE 
	       WHEN days_exposition >= 1 AND days_exposition <= 30
	         THEN 'В пределах одного месяца'
	       WHEN days_exposition >= 31 AND days_exposition <= 90
	         THEN 'В пределах одного квартала'
	       WHEN days_exposition >= 91 AND days_exposition <= 180
	         THEN 'В пределах полугода'
	       WHEN days_exposition >= 181 AND days_exposition <= 365
	         THEN  'В пределах года'
	       ELSE 'Более года'
         END AS category_days_exposition,
         ROUND(CAST(CAST (last_price AS NUMERIC) / total_area AS NUMERIC),2) AS price_per_meter,
         floors_total
     FROM cleared_data
     JOIN real_estate.advertisement AS ads
     ON cleared_data.id = ads.id
     JOIN real_estate.city AS city
     ON cleared_data.city_id = city.city_id
     JOIN real_estate.type AS type_area
     ON cleared_data.type_id = type_area.type_id
     WHERE type = 'город'
 ),
 --Вычисляем общее количество объявлений для Санкт-Петербурга и Ленинградской области
 calculation_totals_by_location AS (
     SELECT
          *,
          COUNT(id) OVER(PARTITION BY area_location) AS total_ads_by_location
     FROM data_for_calculation
)
--Вычисляем необходимые параметры. Находим долю квартир по длительности размещения объявлений от общего количества объявлений для каждого типа месторасположения.
--Находим средннюю площаь, средннюю стоимость одного квадратного метра, медианное количество комнат, балконов, медианный этаж, а также среднюю этажность.
SELECT
    area_location,
    category_days_exposition,
    total_ads_by_location,
    COUNT(id) AS total_ads,
    ROUND(CAST(CAST(COUNT(id) AS NUMERIC) / total_ads_by_location *  100 AS NUMERIC),2) AS ads_by_durations_share,
    ROUND(CAST(AVG(total_area) AS NUMERIC),2) AS avg_total_area,
    ROUND(CAST(AVG(price_per_meter) AS NUMERIC),2) AS avg_priсe_per_meter,
    ROUND(CAST(AVG(floors_total) AS NUMERIC)) AS avg_floors,
    PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY rooms) AS median_rooms,
    PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY floor) AS median_floor,
    PERCENTILE_DISC(0.50) WITHIN GROUP(ORDER BY balcony) AS median_balcony
FROM calculation_totals_by_location
GROUP BY
    area_location,
    category_days_exposition,
    total_ads_by_location
ORDER BY area_location DESC,ROUND(CAST(CAST(COUNT(id) AS NUMERIC) / total_ads_by_location *  100 AS NUMERIC),2) DESC;
-- Задача 2: Сезонность объявлений
--Избавляемся от выбросов.
WITH limitations AS (
     SELECT 
         1 AS key_id,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_upper_limit,
         percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) AS rooms_lower_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_upper_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_upper_limit,
         percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_lower_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_upper_limit 
     FROM real_estate.flats
),
--Создаем фильтр по id квартир, в которых аномальные значения отсутствуют
filter_by_id AS(
     SELECT id
     FROM real_estate.flats
     WHERE 
         total_area < (SELECT total_area_upper_limit FROM limitations)
         AND rooms > (SELECT rooms_lower_limit FROM limitations)
         AND rooms < (SELECT rooms_upper_limit FROM limitations)
         AND balcony < (SELECT balcony_upper_limit FROM limitations)
         AND ceiling_height > (SELECT ceiling_height_lower_limit FROM limitations)
         AND ceiling_height < (SELECT ceiling_height_upper_limit FROM limitations)
 ),
 --Отбираем только нужные значения из таблицы flats
cleared_data AS(
     SELECT *
     FROM real_estate.advertisement
     WHERE id IN (SELECT * FROM filter_by_id)
),
data_for_calculation AS (
     SELECT
     cleared_data.id,
     first_day_exposition,
     EXTRACT(MONTH FROM first_day_exposition) AS first_day_exposition_month_number,
     CASE
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 1
	    THEN 'Январь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 2
	    THEN 'Февраль'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 3
	    THEN 'Март'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 4
	    THEN 'Апрель'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 5
	    THEN 'Май'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 6
	    THEN 'Июнь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 7
	    THEN 'Июль'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 8
	    THEN 'Август'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 9
	    THEN 'Сентябрь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 10
	    THEN 'Октябрь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 11
	    THEN 'Ноябрь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition) = 12
	    THEN 'Декабрь'
     END AS month_published,
     first_day_exposition + CAST(days_exposition AS integer) AS last_day_exposition,
     EXTRACT (MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) AS last_day_exposition_month_number,
     CASE
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 1
	    THEN 'Январь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 2
	    THEN 'Февраль'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 3
	    THEN 'Март'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 4
	    THEN 'Апрель'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 5
	    THEN 'Май'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 6
	    THEN 'Июнь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 7
	    THEN 'Июль'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 8
	    THEN 'Август'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 9
	    THEN 'Сентябрь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 10
	    THEN 'Октябрь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 11
	    THEN 'Ноябрь'
	   WHEN EXTRACT(MONTH FROM first_day_exposition + CAST(days_exposition AS integer)) = 12
	    THEN 'Декабрь'    
     END AS month_sold,
     total_area,
     ROUND(CAST(CAST(last_price AS NUMERIC)/ total_area AS NUMERIC),2) AS price_per_meter
     FROM cleared_data
     JOIN real_estate.flats AS flats
     ON cleared_data.id = flats.id
),
--Вычисляем статистику по опубликованным объявлениям, здесь же можно посчитать среднюю площадь недвижимости и среднюю стоимость за метр.
calculation_by_published AS(
     SELECT
         month_published,
         first_day_exposition_month_number,
         COUNT(id) AS published_count,
         ROUND(CAST(avg(total_area) AS NUMERIC),2) AS avg_total_area,
         ROUND(CAST(avg(price_per_meter) AS NUMERIC),2) AS avg_price_per_meter
     FROM data_for_calculation
     GROUP BY 
         month_published,
         first_day_exposition_month_number
     ORDER BY first_day_exposition_month_number ASC
),
--Вычисляем статистику по снятым с публикации объявлениям, убирая из расчета значения, где отсуствует информация по дате снятия объявления.
calculation_by_sold AS(
     SELECT 
         month_sold,
         COUNT(id) AS sold_count
     FROM data_for_calculation
     WHERE month_sold IS NOT NULL
    GROUP BY 
         month_sold, 
         last_day_exposition_month_number
    ORDER BY last_day_exposition_month_number ASC
)
--Соединяем резульататы предыдущих запросов, выполняем ранжирование по активности для опубликованных и снятых объявлений.
SELECT
    month_published AS reposting_month,
    avg_price_per_meter,
    avg_total_area,
    published_count,
    sold_count,
    CASE 
	  WHEN NTILE(2) OVER(ORDER BY published_count DESC) = 1
	   THEN 'Высокая активность'
	  ELSE 'Низкая активность'
    END AS rank_published,
    CASE
	  WHEN NTILE(2) over(ORDER BY sold_count DESC) = 1
	   THEN 'Высокая активность'
	  ELSE 'Низкая активность'
    END AS sold_rank
FROM calculation_by_published
JOIN calculation_by_sold
ON calculation_by_published.month_published = calculation_by_sold.month_sold
ORDER BY first_day_exposition_month_number ASC;
-- Задача 3: Анализ рынка недвижимости Ленобласти
--Снова убираем аномальные значения.
WITH limitations AS (
     SELECT 
         1 AS key_id,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_upper_limit,
         percentile_disc(0.01) WITHIN GROUP (ORDER BY rooms) AS rooms_lower_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_upper_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_upper_limit,
         percentile_disc(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_lower_limit,
         percentile_disc(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_upper_limit 
     FROM real_estate.flats
),
--Создаем фильтр по id квартир, в которых аномальные значения отсутствуют
filter_by_id AS(
     SELECT id
     FROM real_estate.flats
     WHERE 
         total_area < (SELECT total_area_upper_limit FROM limitations)
         AND rooms > (SELECT rooms_lower_limit FROM limitations)
         AND rooms < (SELECT rooms_upper_limit FROM limitations)
         AND balcony < (SELECT balcony_upper_limit FROM limitations)
         AND ceiling_height > (SELECT ceiling_height_lower_limit FROM limitations)
         AND ceiling_height < (SELECT ceiling_height_upper_limit FROM limitations)
 ),
 --Отбираем только нужные значения из таблицы flats
cleared_data AS(
     SELECT *
     FROM real_estate.flats
     WHERE 
         id IN (SELECT * FROM filter_by_id)),
--Подгатавливаем данные для расчета. Оставляем информацию только по населенным пунктам ЛО.
data_for_calculation AS(
     SELECT 
         cleared_data.id,
         city,
         total_area,
         days_exposition,
         CASE 
	       WHEN days_exposition >= 1 AND days_exposition <= 30
	         THEN 'В пределах одного месяца'
	       WHEN days_exposition >= 31 AND days_exposition <= 90
	         THEN 'В пределах одного квартала'
	       WHEN days_exposition >= 91 AND days_exposition <= 180
	         THEN 'В пределах полугода'
	       WHEN days_exposition >= 181 AND days_exposition <= 365
	         THEN  'В пределах года'
	       ELSE 'Более года'
         END AS category_days_exposition,
         ROUND(CAST(CAST (last_price AS NUMERIC) / total_area AS NUMERIC),2) AS price_per_meter
     FROM cleared_data
     JOIN real_estate.advertisement AS ads
     ON cleared_data.id = ads.id
     JOIN real_estate.city AS city
     ON cleared_data.city_id = city.city_id
     JOIN real_estate.type AS type_area
     ON cleared_data.type_id = type_area.type_id
     WHERE city <> 'Санкт-Петербург'
),
--Отбираем данные для расчета, оставляя только те города, где количество опубликованных объявлений больше 15. Находим общее количество объявлений для
--каждого города, количество объявлений по городам внутри каждой группы по длительности публикации, среднюю стоимости за метр и среднюю площадь
--для каждого города.
filtered_by_ads_count AS (
     SELECT
         *
     FROM(
         SELECT 
              *,
              COUNT(id) OVER(PARTITION BY city) AS total_ads,
              COUNT(id) OVER (PARTITION BY city,category_days_exposition) AS ads_by_duration_category,
              AVG(price_per_meter) OVER(PARTITION BY city) AS avg_price_per_meter,
              AVG(total_area) OVER(PARTITION BY city) AS avg_total_area
         FROM data_for_calculation) AS subquery
         WHERE total_ads > 15),
--Вычисляем количество снятых с публикации объявлений для каждого населенного пункта.
sold_calculation AS(
     SELECT
         city,
         COUNT(id) AS sold_count
     FROM filtered_by_ads_count WHERE days_exposition IS NOT NULL
     GROUP BY 
         city
),
--Соединяем результаты вычислений двух предыдущих запросов. Находим процент проданных объявлений для каждого города,
--а также процент объявлений по длительности публикации от общего количества объявлений для каждого города.
calculations_with_devision_for_periods AS(
     SELECT 
         filtered_by_ads_count.city,
         category_days_exposition,
         total_ads,
         sold_count,
         ROUND(CAST(CAST(sold_count AS NUMERIC)  / total_ads  * 100 AS NUMERIC),2) AS sold_percentage,
         ads_by_duration_category,
         ROUND(CAST(CAST(ads_by_duration_category AS NUMERIC)/ total_ads * 100 AS NUMERIC),2) AS by_duration_percentage,
         ROUND(CAST(avg_price_per_meter AS NUMERIC),2) AS avg_price_per_meter_within_city,
         ROUND(CAST(avg_total_area AS NUMERIC),2) AS avg_total_area_within_city
     FROM filtered_by_ads_count
     JOIN sold_calculation
     ON filtered_by_ads_count.city = sold_calculation.city
     GROUP BY 
         filtered_by_ads_count.city,
         category_days_exposition,
         total_ads,
         ads_by_duration_category,
         ROUND(CAST(avg_price_per_meter AS NUMERIC),2),
         ROUND(CAST(avg_total_area AS NUMERIC),2),
         sold_count
     ORDER BY total_ads DESC
),
--Отдельно создадим CTE для вывода информации только по ТОП-15 населенных пунктов по общему количеству объявлений без деления на временные периоды.
--Так читать результат удобнее. Данные из предыдущего CTE можно использовать для ответа на четвертый вопрос задачи.
calculation_without_division AS(
     SELECT
         city,
         total_ads,
         sold_count,
         sold_percentage,
         avg_price_per_meter_within_city,
         avg_total_area_within_city
     FROM calculations_with_devision_for_periods
     GROUP BY 
         city,
         total_ads,
         sold_count,
         sold_percentage,
         avg_price_per_meter_within_city,
         avg_total_area_within_city
     ORDER BY total_ads DESC
 )
 --Выводим итоговый результат расчета ТОП-15 населенных пунктов ЛО
 SELECT *
 FROM calculation_without_division;