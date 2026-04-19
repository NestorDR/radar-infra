-- database/init/02_radar_views.sql

-- Connect to the database defined in the environment or created by previous scripts
\connect radar

-- Ratios Dashboard: view for BI
CREATE OR REPLACE VIEW public.ratios_dashboard AS
WITH ratios_cte AS (
    -- CTE (Common Table Expression)
    SELECT ratios.*,
           securities.description                                 AS security_description,
           strategies.acronym                                     AS strategy_acronym,
           securities.is_bear                                     AS security_is_bear,
           CASE ratios.timeframe
               WHEN 3 THEN ratios.last_input_date + ((12 - EXTRACT(dow FROM ratios.last_input_date)::int) % 7)::int
               ELSE ratios.last_input_date
               END                                                AS input_date,
           CASE ratios.timeframe
               WHEN 3 THEN ratios.last_output_date + ((12 - EXTRACT(dow FROM ratios.last_output_date)::int) % 7)::int
               ELSE ratios.last_output_date
               END                                                AS output_date,
           COALESCE(ratios.last_output_price, ratios.final_price) AS output_price,
           CASE
               WHEN strategies.acronym LIKE '%(14)%' THEN
                   -- Strategy acronym contains '(14)', remove substring 'period: 14, '
                   REPLACE(
                           REPLACE(TRIM(BOTH '{}' FROM ratios.inputs), '"', ''),
                           'period: 14, ', ''
                   )
               ELSE
                   -- Strategy does not contain '(14)'
                   REPLACE(TRIM(BOTH '{}' FROM ratios.inputs), '"', '')
               END                                                AS inputs_clean
    FROM public.ratios
             INNER JOIN public.securities ON securities.symbol = ratios.symbol
             INNER JOIN public.strategies ON strategies.id = ratios.strategy_id)
SELECT ratios_cte.id                                     AS "Ratio ID",
       ratios_cte.symbol                                 AS "Symbol",
       ratios_cte.strategy_acronym                       AS "Strategy",
       ratios_cte.inputs_clean                           AS "Inputs",
       CASE
           WHEN ratios_cte.security_is_bear THEN
               CASE ratios_cte.is_long_position WHEN TRUE THEN 'Bear' ELSE 'Bull' END
           ELSE
               CASE ratios_cte.is_long_position WHEN TRUE THEN 'Bull' ELSE 'Bear' END
           END                                           AS "Market",
       CASE ratios_cte.is_long_position
           WHEN TRUE THEN 'Buy'
           ELSE 'Sell'
           END                                           AS "Recommendation",
       CASE ratios_cte.timeframe
           WHEN 1 THEN 'Intra'
           WHEN 2 THEN 'Day'
           WHEN 3 THEN 'Week'
           WHEN 4 THEN 'Month'
           ELSE '???'
           END                                           AS "Frame",
       ratios_cte.input_date                             AS "Input Date",
       ratios_cte.last_input_price                       AS "Input Price",
       ratios_cte.last_stop_loss                         AS "Stop Loss",
       ratios_cte.last_output_price                      AS "Output Price",
       ratios_cte.output_date                            AS "Output Date",
       ROUND(CASE ratios_cte.is_long_position
                 WHEN TRUE THEN (ratios_cte.output_price - ratios_cte.last_input_price) / ratios_cte.last_input_price
                 ELSE (ratios_cte.last_input_price - ratios_cte.output_price) / ratios_cte.last_input_price
                 END::numeric, 4)                        AS "Last result",
       ROUND((ratios_cte.net_profit / (CURRENT_DATE - ratios_cte.from_date))::numeric,
             4)                                          AS "NP per Day",
       ROUND(ratios_cte.win_probability::numeric, 4)     AS "Gain Prob",
       ratios_cte.final_price                            AS "Last Price",
       ROUND(ratios_cte.net_change::numeric, 2)          AS "Net Change",
       ROUND(ratios_cte.net_profit::numeric, 2)          AS "Net Profit",
       ROUND(((ratios_cte.net_profit - ratios_cte.net_change) / ABS(ratios_cte.net_change))::numeric,
             2)                                          AS "Profit vs Change",
       ratios_cte.signals                                AS "Signals",
       ratios_cte.from_date                              AS "From Date",
       ratios_cte.to_date                                AS "To Date",
       ratios_cte.initial_price                          AS "Initial Price",
       ROUND(ratios_cte.winnings::numeric, 2)            AS "Gains",
       ROUND(ratios_cte.losses::numeric, 2)              AS "Losses",
       ROUND(ratios_cte.expected_value::numeric, 2)      AS "Expected Value",
       ROUND(ratios_cte.loss_probability::numeric, 4)    AS "Loss Prob",
       ROUND(ratios_cte.average_win::numeric, 2)         AS "Average Gain",
       ROUND(ratios_cte.average_loss::numeric, 2)        AS "Average Loss",
       ratios_cte.min_percentage_change_to_win / 100     AS "Min % to Gain",
       ratios_cte.max_percentage_change_to_win / 100     AS "MAX % to Gain",
       ratios_cte.total_sessions                         AS "Total Sessions",
       ratios_cte.winning_sessions                       AS "Gains Sessions",
       ratios_cte.losing_sessions                        AS "Losses Sessions",
       ROUND(ratios_cte.percentage_exposure::numeric, 4) AS "% Exposure"
FROM ratios_cte;
