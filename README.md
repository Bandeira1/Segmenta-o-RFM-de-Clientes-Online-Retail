# Análise RFM de Clientes — Online Retail II

Segmentação de clientes pela técnica **RFM** (Recência, Frequência e Valor) em uma varejista online do Reino Unido, com pipeline completo em **Python → MySQL → Power BI**.

![Dashboard RFM](Dashboard.png)

## Problema de negócio

Quem são os clientes que mais geram receita, quais estão deixando de comprar e onde vale a pena concentrar esforços de relacionamento? O projeto responde essas perguntas classificando cada cliente em segmentos de comportamento.

## Dataset

- **Fonte:** [Online Retail II](https://archive.ics.uci.edu/dataset/502/online+retail+ii) — UCI Machine Learning Repository (autor: Daqing Chen, licença CC BY 4.0).
- **Contexto:** transações de uma varejista online do Reino Unido, sem loja física, que vende presentes para todas as ocasiões. Muitos clientes são atacadistas.
- **Período:** 01/12/2009 a 09/12/2011.
- **Moeda:** libras esterlinas (£).
- **Base tratada:** 824.364 linhas, 5.942 clientes identificados.

> O arquivo CSV não está neste repositório. Baixe o original no link acima.

## Tecnologias

| Etapa | Ferramenta |
|---|---|
| Limpeza e tratamento | Python (pandas) |
| Carga no banco | Python (SQLAlchemy + PyMySQL) |
| Cálculo do RFM | MySQL (CTEs e window functions) |
| Visualização | Power BI |

## Etapas do projeto

1. **Limpeza em Python:** tratamento do dataset bruto e criação da coluna `TotalPrice` (quantidade × preço), gerando o `online_retail_cleaned.csv`.
2. **Modelagem no MySQL:** criação do banco `online_retail` e da tabela `vendas`, com tipos adequados (`DATETIME`, `DECIMAL`, `INT`).
3. **Carga:** envio dos dados do Python para o MySQL em blocos de 10 mil linhas, com validação da contagem (824.364 linhas no CSV e na tabela).
4. **Cálculo do RFM:** consulta SQL que gera a tabela `rfm`, com uma linha por cliente.
5. **Dashboard no Power BI:** conexão com o MySQL, relacionamento `rfm` → `vendas` por `CustomerID`, medidas em DAX e visuais.

## Metodologia RFM

Para cada cliente foram calculados:

- **Recência (R):** dias entre a última compra e a data mais recente da base.
- **Frequência (F):** número de faturas distintas.
- **Valor (M):** soma de `TotalPrice`.

Cada métrica recebe nota de 1 a 5 com `NTILE(5)` (na recência, a ordem é invertida, pois menos dias é melhor). Os segmentos são definidos pelas notas de R e F:

| Segmento | Regra |
|---|---|
| Champions | R ≥ 4 e F ≥ 4 |
| Loyal | R ≥ 3 e F ≥ 3 |
| New Customers | R ≥ 4 e F ≤ 2 |
| Cant Lose Them | R ≤ 2 e F ≥ 4 |
| At Risk | R ≤ 2 e F ≥ 2 |
| Lost | R ≤ 2 e F ≤ 1 |
| Potential | demais casos |

As regras são avaliadas na ordem da tabela e podem ser ajustadas conforme a estratégia do negócio.

```sql
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
```

## Resultados

| Segmento | Clientes | % dos clientes | Receita | % da receita |
|---|---|---|---|---|
| Champions | 1.420 | 23,9% | £ 11.781.226 | 70,8% |
| Loyal | 1.287 | 21,7% | £ 2.554.611 | 15,3% |
| Cant Lose Them | 401 | 6,7% | £ 1.001.017 | 6,0% |
| At Risk | 943 | 15,9% | £ 651.586 | 3,9% |
| Lost | 1.034 | 17,4% | £ 241.938 | 1,5% |
| New Customers | 480 | 8,1% | £ 239.092 | 1,4% |
| Potential | 377 | 6,3% | £ 178.822 | 1,1% |
| **Total** | **5.942** | 100% | **£ 16.648.292** | 100% |

Indicadores gerais: **receita total de £ 16,65 Mi**, **ticket médio de £ 370,98** e **5.942 clientes**.

## Principais conclusões

- **Concentração de receita:** os Champions são 24% dos clientes e geram cerca de 71% da receita. Champions e Loyal juntos passam de 86%. Perder esses clientes é o maior risco do negócio.
- **Oportunidade de reativação:** os 401 clientes *Cant Lose Them* já gastaram cerca de £ 1 Mi e pararam de comprar. Uma campanha de reativação direcionada é a ação de maior retorno potencial.
- **Baixo retorno em Lost:** 1.034 clientes geram só 1,5% da receita, então não compensa investir em ações para eles.
- **Sazonalidade:** a receita mensal tem picos no fim de cada ano (outubro a novembro), compatível com compras de presentes.

## Limitações

- O último mês (dezembro/2011) tem dados só até o dia 9, então a queda no fim da linha mensal **não** indica perda de vendas.
- A segmentação usa as notas de Recência e Frequência. O Valor (M) foi calculado, mas não entra nas regras dos segmentos.
- Transações sem `CustomerID` não entram no RFM.
- Os valores estão em libras, a moeda original do dataset.

## Como reproduzir

1. Baixe o dataset no link da UCI e faça a limpeza em Python.
2. Crie o banco e a tabela `vendas` no MySQL e carregue o CSV com o script de conexão. Troque `SUA_SENHA` pela sua senha:
   ```python
   engine = create_engine("mysql+pymysql://root:SUA_SENHA@localhost:3306/online_retail")
   df.to_sql("vendas", engine, if_exists="append", index=False, chunksize=10000)
   ```
3. Execute a consulta RFM acima no MySQL.
4. Abra o arquivo `.pbix`, conecte ao seu MySQL local e atualize os dados.

## Autor

**Victor** — [GitHub](https://github.com/Bandeira1)
