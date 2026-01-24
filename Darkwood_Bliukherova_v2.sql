/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Блюхерова Оксана
 * Дата: 21.11.2025
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Для расчетов в блоке SELECT использована условная конструкция CASE для вычисления количества платящих пользователей (считаем, если поле payer = 1)
--(Использовала условую конструкцию, чтобы избежать 2 CTE или 2 подзапросов с расчетом сначала для всех данных, а потом отфильтрованных (двойное сканирование таблицы))
-- Результат подзапроса явно приведен к дробному числу с фиксированной точностью, чтобы исключить ошибки при делении и сразу округлить результат до 2 знаков после запятой

SELECT  
	COUNT(CASE WHEN payer = 1 THEN 1 END) AS payer_amount,
	COUNT(*) AS total_player_amount,
  	(COUNT(CASE WHEN payer = 1 THEN 1 END) / COUNT(*):: NUMERIC)::NUMERIC(9, 4) AS payer_share --поменяла способ округления
FROM fantasy.users;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- К таблице users присоединена таблица race: чтобы можно было отобразить название расыБ данные сгруппированы по расе
-- В запросе расчитано общее кол-во пользователей каждой расы, кол-во платящих игроков кажой рассы (сумма признака 1),
-- А также среднее кол-во платящих пользователей как среднее значение (то есть доля от 1)

SELECT 
	r.race,
	COUNT(id) AS total_players_amount_by_race,
	SUM(payer) AS payer_amount_by_race,
	AVG(payer):: NUMERIC(5 ,4) AS payer_race_share --поменяла способ округления
FROM fantasy.users u
LEFT JOIN fantasy.race r ON u.race_id = r.race_id
GROUP BY r.race
ORDER BY payer_race_share DESC;



-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- В запросе расчитаны основные показатели по полю amount
-- Для нецелочисленных значений (среднее арифметическое и стандартное отклонение) проведено округление до 2 знаков
SELECT 
	COUNT(amount) AS purchases_count,
	SUM(amount) AS purchases_sum,
	MIN(amount) AS min_purchase,
	MAX(amount) AS max_purchase,
	AVG(amount):: NUMERIC(10, 2) AS avg_purchase_amount,-- Поменяла способ округления
	PERCENTILE_CONT(0.5)WITHIN GROUP ( ORDER BY amount):: NUMERIC(8, 2)  AS median_purchase_amount, -- Поменяла способ округления
	stddev(amount)::NUMERIC(10, 2) AS stdev -- Поменяла способ округления
FROM fantasy.events
UNION --добавила строку с расчетом тех же показателей без чета покупок на сумму 0
SELECT 
	COUNT(amount) AS purchases_count,
	SUM(amount) AS purchases_sum,
	MIN(amount) AS min_purchase,
	MAX(amount) AS max_purchase,
	AVG(amount):: NUMERIC(10, 2) AS avg_purchase_amount, 
	PERCENTILE_CONT(0.5) WITHIN GROUP ( ORDER BY amount):: NUMERIC(8, 2) AS median_purchase_amount,
	stddev(amount):: NUMERIC(10, 2) AS stdev
FROM fantasy.events
WHERE amount > 0; 


-- 2.2: Аномальные нулевые покупки:
-- Через CASE отобраны покупки с суммой 0 и высчитано их количество, далее расчитана доля от все покупок (первое решение)
-- Исправила на FILTER после рекомендаций и добавила округления
SELECT 
	COUNT(*) FILTER (WHERE amount = 0) AS zero_purchases_count,
	(COUNT(*) FILTER (WHERE amount = 0) / COUNT(*)::NUMERIC)::NUMERIC(7,6) AS zero_purchases_share
FROM fantasy.events;


-- 2.3: Популярные эпические предметы:
-- В первом CTE total_purchases_stat расчитано общее кол-во покупок и общее число пользователей с предварительной фильтрацией по сумме > 0
-- Во втором CTE items_and_users_purchases_stat после фильтрации суммы покупок > 0 собрана статистика по количеству покупок и количеству уникальных пользователей в разрезе товара
-- (Предполагала, все считать сначала оконной функцие, обожглась на пользователях и решила, что раз все равно делать CTЕ, то логично все общие в 1 месте собрать)
-- В основном запросе к результатам CTE со статистикой по товарам и пользователям в разрезе категорий писоединена таблица items, чтобы вывести более понятные газвания товаров 
-- Через CROSS JOIN размножена информация об общей сумме продаж и количестве пользователей
-- В основном запросе выведены поля с кодом товара, названием, количеством покупок этого товара, количество пользователей, купивших этот товар
-- Также расчитаны доли кол-ва покупок от общего числа покупок и доля пользователей, купивших конкретный товар от общего числа пользователей 
-- (при делении знаменатель явно приведен к нецелочисленному значению). Округление не использовалось, чтобы не потерять информацию о совсем маленьких долях
WITH total_purchases_stat AS (
	SELECT 
		COUNT(*) AS total_purchases_count,
		COUNT(DISTINCT id) AS total_users_count
	FROM fantasy.events e
	WHERE amount > 0),
items_and_users_purchases_stat AS( 
	SELECT 
		item_code,
		COUNT(amount) AS purcased_item_count,
		COUNT(DISTINCT id) AS users_bought_count
	FROM fantasy.events
	WHERE amount > 0 
	GROUP BY item_code)
SELECT
	i.game_items,
	ips.purcased_item_count, 
	ips.users_bought_count,
	(ips.purcased_item_count / tps.total_purchases_count::NUMERIC):: NUMERIC(10, 9) AS items_purchases_total_share, -- додавила по комментариям округление
	(ips.users_bought_count / tps.total_users_count::NUMERIC):: NUMERIC(9, 8) AS users_share -- додавила по комментариям округление
FROM items_and_users_purchases_stat ips
LEFT JOIN fantasy.items i ON ips.item_code = i.item_code
CROSS JOIN total_purchases_stat tps
ORDER BY ips.users_bought_count DESC;

--доп выгрузка товаров без продаж 
SELECT i.game_items
FROM fantasy.items i 
LEFT JOIN fantasy.events e ON i.item_code = e.item_code 
WHERE e.transaction_id IS NULL;


-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- В первом CTE users_stat расчитаны количество платящих (признак payer = 1) и всех пользователей по таблице users,данные сгруппированы по расе
-- Во втором CTE высчитано кол-во пользователей с ненулевыми суммами, кол-во платящих польщователй среди них и расчетана доля платящих среди пользователей с транзакциями в разрезе расы
-- Во тертьем CTE purchases_race_stat после фильтрации по полю amount > 0 расчитаны кол-во покупок,сумма покупок, и количество уникальных пользователей, соверщивших покупку в разрезе расы
-- В основном запросе к таблице с данными о пользователях по рассам присоединена итоговая таблица из CTE с данными по покупкам, а также присоединена таблицы с расами и расчетами доли платящих среди пользователей с транзакциями
-- Выведены поля расы, кол-во зарегистрированных игроков в разрезе расы, кол-во пользователей совершивших транзации
-- Расчитаны доля игроков, совершавих транзакции среди всех зарегистрированных пользователей
-- Доля платящих игроков, среди пользователй соврнавших транзации
-- Среднее кол-во покупок на 1 пользователя, совершавшего транзакции
-- Средняя стоимость покупки на пользователя, совершавшиго транзакцию
-- Средняя общая стоимость всех покупок на пользователя
WITH total_rase_stat AS(
	SELECT 
		race_id,
		COUNT(*) AS total_race_player --количество зарегистрированных пользователей в разрезе расы
	FROM fantasy.users
	GROUP BY race_id),
users_stat AS( -- добавила по замечанию
	SELECT
		race_id,
		COUNT(*) AS users_with_transactions_count, --кол-во пользователей с транзакциями
		COUNT(*) FILTER (WHERE payer = 1) AS payer_with_transaction_count, -- кол-во платящих пользователей совершавших транзакции
		(COUNT(*) FILTER (WHERE payer = 1) / COUNT(*):: float)::NUMERIC(5,4) AS users_with_transactions_by_payers_share -- доля платящих среди пользоателей с транзакциями
	FROM fantasy.users 
	WHERE id IN (SELECT 
					id 
				FROM fantasy.events
				WHERE amount > 0)
	GROUP BY race_id),
purchases_race_stat AS (
	SELECT 
		u.race_id,
		COUNT(e.transaction_id ) AS user_transaction_amount, -- кол-во покупок в разрезе расы 
		SUM(amount) AS users_purchasing_sum, --сумма покупок в разрезе расы
		COUNT(DISTINCT e.id) AS users_amount_with_purchases --кол-во пользователей с покупками
	FROM fantasy.users u
	LEFT JOIN fantasy.events e USING (id)
	WHERE amount > 0
	GROUP BY u.race_id)
SELECT 
	r.race, 
	rs.total_race_player, --общее количество зарегистрированных игроков
	u.users_with_transactions_count, -- количество игроков, которые совершают внутриигровые покупки
	(u.users_with_transactions_count / rs.total_race_player:: NUMERIC):: NUMERIC(8, 4) AS users_with_transaction_share, -- доля игроков, которые совершают внутриигровые покупки от общего количества зарегистрированных игроков 
	u.users_with_transactions_by_payers_share, -- доля платящих игроков среди игроков, которые совершили внутриигровые покупки
	(p.user_transaction_amount / u.users_with_transactions_count:: NUMERIC)::NUMERIC(8,2) AS avg_amount_of_purchases_per_users_with_transacrions, --среднее количество покупок на одного игрока, совершившего внутриигровые покупки
	(p.users_purchasing_sum / p.user_transaction_amount::NUMERIC)::NUMERIC (6,2) AS avg_sum_of_purchases_per_users_with_transacrions, -- cредняя стоимость одной покупки на одного игрока, совершившего внутриигровые покупки
	(p.users_purchasing_sum / u.users_with_transactions_count::NUMERIC)::NUMERIC (9,2) AS avg_sum_per_user_with_transaction --средняя суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки
FROM total_rase_stat rs
LEFT JOIN fantasy.race r USING(race_id)
LEFT JOIN purchases_race_stat p USING(race_id)
LEFT JOIN users_stat u USING(race_id)
ORDER BY u.users_with_transactions_count DESC;