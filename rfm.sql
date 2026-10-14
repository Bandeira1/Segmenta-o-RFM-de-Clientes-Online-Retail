USE online_retail;

CREATE TABLE rfm AS
WITH base AS (
    SELECT
        CustomerID,
        DATEDIFF((SELECT MAX(InvoiceDate) FROM vendas) + INTERVAL 1 DAY, MAX(InvoiceDate)) AS recency,
        COUNT(DISTINCT Invoice) AS frequency,
        SUM(TotalPrice) AS monetary
    FROM vendas
    WHERE CustomerID IS NOT NULL
    GROUP BY CustomerID
),
scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency DESC)  AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC)  AS m_score
    FROM base
)
SELECT *,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2 AND f_score >= 4 THEN 'Cant Lose Them'
        WHEN r_score <= 2 AND f_score >= 2 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 1 THEN 'Lost'
        ELSE 'Potential'
    END AS segmento
FROM scores;

SELECT segmento, COUNT(*) AS clientes, ROUND(SUM(monetary),2) AS receita
FROM rfm
GROUP BY segmento
ORDER BY receita DESC;