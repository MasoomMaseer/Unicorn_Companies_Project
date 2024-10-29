create database unicorns;
use unicorns;

-- Data Cleaning 
-- Date joined column from dd-mm-yy to yyyy-mm-d

set sql_safe_updates = 0;

ALTER TABLE Unicorn
CHANGE COLUMN `Select_Investors` `Investors` text;

ALTER TABLE Unicorn
CHANGE COLUMN `date joined` `date_joined` text;

UPDATE Unicorn
SET Date_Joined = STR_TO_DATE(Date_Joined, '%Y-%m-%d');


-- Changing the format of valuation from text to Integer

-- Step 1 
-- Remove the '$' sign and 'B' from the cells of Valuation column 

 update unicorn
set Valuation = replace(replace(Valuation, '$', ''), 'B', '');

-- Step 2 
-- Now convert the text data into integer

ALTER TABLE Unicorn
CHANGE COLUMN Valuation `Valuation_InBillion` INT;


-- Changing the format of Funding from text to Integer

-- Step 1
-- Remove the '$' sign, 'M' and 'B' from the cells of Funding column and convert the Millions into Billions format

Update unicorn 
set Funding = Case
              when funding like '%M%' then replace(replace(Funding, '$', ''), 'M', '') / 1000    -- converting Millions into Billions format 
              when funding like '%B%' then replace(replace(Funding, '$', ''), 'B', '')        -- converting billions as it is into integer format
              else replace (funding, '$', '')
end;

-- Step 2
-- Funding column has some nonnumeric values. So first we should find out and remove them from the table

SELECT * FROM Unicorn
WHERE Funding NOT REGEXP '^[0-9.]+$';

UPDATE Unicorn
SET Funding = REGEXP_REPLACE(Funding, '[^0-9.]', '');

-- Identify rows where Funding is empty or null
SELECT * FROM Unicorn
WHERE Funding = '' OR Funding IS NULL;

-- Delete rows where Funding is blank or null
DELETE FROM Unicorn
WHERE Funding = '' OR Funding IS NULL;

SELECT * FROM Unicorn;

-- Step 3
-- Change the column type to 2 decimal places and change the column name 

alter table unicorn
change column funding `Funding_InBillion` decimal(10,2);

-- Year_Founded Column from Integer to Date format

ALTER TABLE Unicorn
CHANGE COLUMN `Year_Founded` `Year_Founded` year;


-- Make new column of ROI
-- Find ROI by valuation/funding * 100

alter table unicorn
add column ROI decimal(10,2);

update unicorn
set ROI = (Valuation_Inbillion / Funding_InBillion) * 100
where Funding_InBillion > 0.00;

UPDATE Unicorn
SET ROI = ROI / 100;

-- Identify rows where ROI is empty or null
SELECT * FROM Unicorn
WHERE ROI = '' OR ROI IS NULL;

-- Delete rows where ROI is blank or null
DELETE FROM Unicorn
WHERE ROI IS NULL OR ROI = 0;



/* Business Questions
1. Find the industries which are in trend from the last 10 years? 
2. Find the industries which have got the maximum amount of fundings? 
3. Find out if there are any emerging industries with relatively few unicorns but showing high fundings?
4. Which industries have seen funding growth over the years?
5. Which industries have the highest average ROI for investors?
6. Find out the most active investors?
7. Find out which country has produced the most unicorns in the last 10 yrs (and find out the factors for each country for being the most popular)
8. Find the top 5 industries in the top 3 coutnries?
*/

-- 1
select Industry, count(Company) as NumberOfCompanies, 
       avg(ROI) as AvgROI
from unicorn 
WHERE year_founded >= DATE_SUB(CURDATE(), INTERVAL 10 YEAR)
group by industry
order by AvgROI desc;

-- 2
select industry, sum(Funding_InBillion) as TotalFundings
from unicorn
group by industry 
order by TotalFundings desc;

-- 3
select Industry, sum(Funding_InBillion) as TotalFundings, 
       count(company) as NumberOfCompanies, avg(ROI) as ROI
from unicorn
WHERE Year_Founded >= DATE_SUB(CURDATE(), INTERVAL 10 YEAR)
group by Industry
order by ROI Desc;

-- 4
WITH YearlyFunding AS (
    SELECT YEAR(Date_Joined) AS FundingYear, Industry, SUM(Funding_Inbillion) AS TotalFunding
    FROM Unicorn
    GROUP BY FundingYear, Industry
),
RankedIndustries AS (
    SELECT FundingYear, Industry, TotalFunding,
        ROW_NUMBER() OVER (PARTITION BY FundingYear ORDER BY TotalFunding DESC) AS IndustryRank
    FROM YearlyFunding
    WHERE TotalFunding > (SELECT AVG(TotalFunding) FROM YearlyFunding WHERE Industry = YearlyFunding.Industry)
)
SELECT FundingYear, Industry, TotalFunding
FROM RankedIndustries
WHERE IndustryRank <= 3
ORDER BY FundingYear, IndustryRank;


-- 5 

SELECT Industry, AVG(ROI) AS Avg_ROI
FROM Unicorn
GROUP BY Industry
ORDER BY Avg_ROI DESC;


-- 6

WITH InvestorSplit AS (
    SELECT Company, TRIM(SUBSTRING_INDEX(Investors, ',', 1)) AS Investor                               -- Split investors into separate rows using UNION ALL
    FROM Unicorn
    WHERE LENGTH(SUBSTRING_INDEX(Investors, ',', 1)) > 0
    UNION ALL
    SELECT Company, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(Investors, ',', 2), ',', -1)) AS Investor
    FROM Unicorn
    WHERE LENGTH(SUBSTRING_INDEX(Investors, ',', 2)) > LENGTH(SUBSTRING_INDEX(Investors, ',', 1))
    UNION ALL
    SELECT Company, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(Investors, ',', 3), ',', -1)) AS Investor
    FROM Unicorn
    WHERE LENGTH(SUBSTRING_INDEX(Investors, ',', 3)) > LENGTH(SUBSTRING_INDEX(Investors, ',', 2))
    UNION ALL
    SELECT Company, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(Investors, ',', 4), ',', -1)) AS Investor
    FROM Unicorn
    WHERE LENGTH(SUBSTRING_INDEX(Investors, ',', 4)) > LENGTH(SUBSTRING_INDEX(Investors, ',', 3))
    UNION ALL
    SELECT Company, TRIM(SUBSTRING_INDEX(SUBSTRING_INDEX(Investors, ',', 5), ',', -1)) AS Investor
    FROM Unicorn
    WHERE LENGTH(SUBSTRING_INDEX(Investors, ',', 5)) > LENGTH(SUBSTRING_INDEX(Investors, ',', 4)))
SELECT Investor, COUNT(DISTINCT Company) AS InvestmentCount                                            -- Aggregate the data to count the number of investments per investor
FROM InvestorSplit
WHERE Investor IS NOT NULL AND Investor != ''
GROUP BY Investor
ORDER BY InvestmentCount DESC
LIMIT 10;


-- 7

SELECT Country, COUNT(*) AS NumberOfUnicorns
FROM unicorn
WHERE date_joined >= DATE_SUB(CURDATE(), INTERVAL 10 YEAR) 
GROUP BY Country
ORDER BY NumberOfUnicorns DESC
limit 10;


-- 8
 
WITH IndustryCount AS (
    -- Step 1: Count the number of startups per industry in each of the top 3 countries
    SELECT Country, Industry, COUNT(*) AS StartupCount
    FROM Unicorn
    WHERE Country IN ('United States', 'China', 'India')  -- Filter for the top 3 countries
    GROUP BY Country, Industry
),
TopIndustries AS (
    -- Step 2: Rank industries within each country
    SELECT Country, Industry, StartupCount, 
    ROW_NUMBER() OVER (PARTITION BY Country ORDER BY StartupCount DESC) AS IndustryRank
    FROM IndustryCount
)
-- Step 3: Select the top 5 industries for each country
SELECT Country, Industry, StartupCount
FROM TopIndustries
WHERE IndustryRank <= 3
ORDER BY Country, StartupCount DESC;
