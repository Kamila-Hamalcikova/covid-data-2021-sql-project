

-- Focus only on data from year 2021 and countries with population bigger than 1 million
SELECT *
FROM covid_project..virus
WHERE date > '2020-12-31' AND continent IS NOT NULL AND population > 1000000
ORDER BY 1

--Which countries had the most new covid cases per thousand in 2021?
SELECT location, ROUND((SUM(new_cases)/population*1000000), 0) as Covid_Cases_2021_per_1_mil
FROM covid_project..virus
WHERE date > '2020-12-31' AND continent IS NOT NULL AND population > 1000000
GROUP BY location, population
ORDER BY 2 DESC

--Which countries had the most covid cases per million since the pandemic started?
SELECT location, ROUND((MAX(total_cases)/population*1000000), 0) as Covid_Cases_All_Time_per_1_mil
FROM covid_project..virus
WHERE continent IS NOT NULL AND population > 1000000
GROUP BY location, population
ORDER BY 2 DESC

--Which countries had the most covid deaths per million in 2021?
SELECT location, ROUND(((SUM(CAST(new_deaths AS float))/population)*1000000), 0) as Deaths_2021_per_1_mil
FROM covid_project..virus
WHERE date > '2020-12-31' AND continent IS NOT NULL AND population > 1000000
GROUP BY location, population
ORDER BY 2 DESC

--What share of population is vaccinated in different countries?
SELECT location, ROUND((MAX(CAST(REPLACE(people_vaccinated, ',', '.') AS FLOAT)))/population*100, 2) AS Percentage_vac, 
ROUND((MAX(CAST(REPLACE(people_fully_vaccinated, ',', '.') AS FLOAT)))/population*100, 2) AS Percentage_vac_fully
FROM covid_project..reaction
WHERE date > '2020-12-31' AND continent IS NOT NULL AND population > 1000000
GROUP BY location, population
ORDER BY 3 DESC, 2


--Can we observe some relationship between covid spread (cases and deaths) and share of vaccinated population in Europe?

;WITH vac_table AS
	(SELECT location, ROUND((MAX(CAST(REPLACE(people_vaccinated, ',', '.') AS FLOAT)))/population*100, 2) AS Percentage_vac, 
	ROUND((MAX(CAST(REPLACE(people_fully_vaccinated, ',', '.') AS FLOAT)))/population*100, 2) AS Percentage_vac_fully
	FROM covid_project..reaction
	WHERE date > '2020-12-31' AND continent = 'Europe' AND population > 1000000
	GROUP BY location, population),
	covid_table AS 
	(SELECT location, ROUND(((SUM(CAST(new_deaths AS float))/population)*1000000), 3) as Deaths_2021_per_1_mil,
	ROUND((SUM(new_cases)/population*1000000), 2) as Covid_Cases_2021_per_1_mil
	FROM covid_project..virus
	WHERE date > '2020-12-31' AND continent = 'Europe' AND population > 1000000
	GROUP BY location, population)

SELECT vac.location, vac.Percentage_vac, vac.Percentage_vac_fully, cov.Covid_Cases_2021_per_1_mil, cov.Deaths_2021_per_1_mil,
RANK() OVER (ORDER BY cov.Covid_Cases_2021_per_1_mil) AS covid_case_rank,
RANK() OVER (ORDER BY cov.Deaths_2021_per_1_mil) AS death_covid_rank,
RANK() OVER (ORDER BY vac.Percentage_vac desc) AS vac_rank,
RANK() OVER (ORDER BY vac.Percentage_vac_fully desc) AS vac_rank_fully
FROM vac_table vac
INNER JOIN covid_table cov
ON vac.location = cov.location
ORDER BY 5 desc


-- How are Covid deaths in 2021 related to age of population in different countries?

SELECT
    location, 
	ROUND(((SUM(CAST(new_deaths AS float))/population)*1000000), 3) as Deaths_2021_per_1_mil,
	ROUND((SUM(new_cases)/population*1000000), 0) as Covid_Cases_2021_per_1_mil
INTO #cov_temp
FROM covid_project..virus
WHERE date > '2020-12-31' AND population > 1000000 AND continent IS NOT NULL
GROUP BY location, population

SELECT covt.location, covt.Deaths_2021_per_1_mil, rec.aged_65_older, rec.aged_70_older, rec.median_age
FROM #cov_temp covt
LEFT JOIN covid_project..reaction rec
ON covt.location = rec.location
WHERE covt.Deaths_2021_per_1_mil > 0
GROUP BY covt.location, covt.Deaths_2021_per_1_mil, rec.aged_65_older, rec.aged_70_older, rec.median_age
ORDER BY 2 desc

--Show 3 countries with highest percetange of fully vaccinated people for each continent

;WITH vac_pop AS
	(SELECT location, continent,
	(MAX(CAST(REPLACE(people_fully_vaccinated_per_hundred, ',', '.') AS FLOAT))) AS Pop_vac_fully
	FROM covid_project..reaction
	WHERE continent IS NOT NULL AND population > 1000000
	GROUP BY location, population, continent),

vac_pop_rank AS 
(SELECT continent, location, Pop_vac_fully,
RANK() OVER(PARTITION BY continent ORDER BY Pop_vac_fully DESC) AS vac_rank_continent
FROM vac_pop)

SELECT *
FROM vac_pop_rank
WHERE vac_rank_continent <= 3
ORDER BY 1, 3 desc, 4

-- Which 10 countries in second to last week received the most icu covid pacients in the world in relation to their population?
-- (Second to last week was chosen because data from last week are not available yet for many countries)

SELECT TOP 10 (SUM(CAST(REPLACE(icu_patients_per_million, ',', '.') AS FLOAT))) AS icu_pacients_sum_per_pop, location
FROM covid_project..reaction
WHERE date >= DATEADD(day,-14, GETDATE()) AND date <= DATEADD(day,-7, GETDATE()) AND continent IS NOT NULL AND population > 1000000
GROUP BY location
ORDER BY 1 desc

-- Which 10 countries in second to last week received the most icu covid pacients in the world in relation to their population?

SELECT TOP 10 (SUM(CAST(REPLACE(hosp_patients_per_million, ',', '.') AS FLOAT))) AS hosp_pacients_sum_per_pop, location
FROM covid_project..reaction
WHERE date >= DATEADD(day,-14, GETDATE()) AND date <= DATEADD(day,-7, GETDATE()) AND continent IS NOT NULL AND population > 1000000
GROUP BY location
ORDER BY 1 desc

--Create view of vaccination rate groups in the world for later visualization

GO

CREATE VIEW vac_rates AS

WITH vac_pop_world AS
	(SELECT location,
	(MAX(CAST(REPLACE(people_fully_vaccinated_per_hundred, ',', '.') AS FLOAT))) AS Pop_vac_fully
	FROM covid_project..reaction
	WHERE continent IS NOT NULL AND population > 1000000
	GROUP BY location, population),

vac_pop_ntile AS 
(SELECT location, Pop_vac_fully,
NTILE(5) OVER(ORDER BY Pop_vac_fully DESC) AS vac_ntile_world
FROM vac_pop_world
WHERE Pop_vac_fully IS NOT NULL)

SELECT location, Pop_vac_fully, 
CASE
    WHEN vac_ntile_world = 1 THEN 'Very high vaccination rate'
    WHEN vac_ntile_world = 2 THEN 'High vaccination rate'
	WHEN vac_ntile_world = 3 THEN 'Medium vaccination rate'
	WHEN vac_ntile_world = 4 THEN 'Low vaccination rate'
    ELSE 'Very low vaccination rate'
END AS vac_ntile_text
FROM vac_pop_ntile

GO

SELECT * 
FROM vac_rates



