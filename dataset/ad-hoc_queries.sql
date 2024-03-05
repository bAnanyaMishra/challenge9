use codebasic;
show tables;
select * from dim_campaigns;
select * from dim_products;
select * from dim_stores;
select * from fact_events;

/*
provide a list of products with a base price greater than 500 and that are featured in promotype of 'BOGOF'
This information will help us identify high-value products that are currently being heavily discounted,
which can be useful for evaluating pricing and promotion strategies */

select distinct dp.product_name as product_name, fe.base_price as base_price from fact_events fe
join dim_products dp on dp.product_code = fe.product_code where fe.promo_type = "BOGOF"
and fe.base_price > 500;

/* Generate a report that provides an overview of the number of stores in each city.
The result will be sorted in descending order of store counts.
The report includes two fields - city, store count */

select city,count(1) as stores from dim_stores
group by city order by stores desc;

/* Generate a report that displays each campaign alogn with total revenue generated before and after the campaign?
The report includes three key fields; campaign_name,total_revenue(Before_promotion), total_revenue(After_promotion).
This report should help in evaluating the financial impact of our campaigns ( display unit in millions)
*/

with cte1 as (     -- used to find out before_promo revenue
select concat(round(sum(base_price* `quantity_sold(before_promo)`)/1000000,2)," M") as `total_revenue(Before_promotion)`,dc.campaign_name
from fact_events fe join dim_campaigns dc on dc.campaign_id=fe.campaign_id
group by dc.campaign_id),

cte2 as (			-- used to find out after_promo revenue
select if(promo_type="BOGOF",`quantity_sold(after_promo)`*2,`quantity_sold(after_promo)`) as quantity, promo_type,campaign_id,
case
when promo_type = "25% OFF" then base_price*0.75
when promo_type = "33% OFF" then base_price*0.67
when promo_type = "50% OFF" then base_price*0.50
when promo_type = "BOGOF" then base_price*0.50
when promo_type = "500 Cashback" then base_price-500
end as adjusted_price
from fact_events
),
cte3 as(select concat(round(sum(adjusted_price*quantity)/1000000,2)," M") as `total_revenue(after_promotion)`,
campaign_name from cte2
join dim_campaigns dc on dc.campaign_id=cte2.campaign_id
group by dc.campaign_id)
select cte1.campaign_name,`total_revenue(Before_promotion)`,`total_revenue(after_promotion)`
from cte1 join cte3 on cte1.campaign_name=cte3.campaign_name;


/*
Produce a report that calculates the Incremental sold units(ISU%) for each category	during the diwali sale campaign,
Additionally, provide ranking for the categories based on ISU%. The report includes three key fields:
Category, ISU% , and rank order. This info will assist in assessing the category-wise success and impact of diwali campaign 
on incremental sales. */

with cte4 as(		-- used to find out before_promo sold units and after_promo sold units
select dp.category,sum(fe.`quantity_sold(before_promo)`) as before_promo,
sum(if(fe.promo_type="BOGOF",fe.`quantity_sold(after_promo)`*2,fe.`quantity_sold(after_promo)`)) as after_promo from fact_events fe join dim_campaigns dc
on fe.campaign_id = dc.campaign_id join
dim_products dp on fe.product_code = dp.product_code
where fe.campaign_id = 'CAMP_DIW_01'
group by dp.category
)
-- used to find out ISU % = ((after_promo sold units - before_promo sold units)/before_promo sold units)*100
select category,concat(round(((after_promo - before_promo)/before_promo)*100,2),"%") as `ISU%`,
dense_rank() over(order by round(((after_promo - before_promo)/before_promo)*100,2) desc) as rank_order from cte4;

/*
create a report featuring top 5 products, ranked by Incremental Revenue (IR%), across all campaigns.
The report will provide essential information including product name, category, and IR%. This Analysis
helps identify the most successful products in terms of incremetal revenue across our campaigns, assissting 
in product optimization */

with cte5 as(  		-- used to find out before_promo revenue and after_promo revenue per category,products
select dp.product_name,dp.category,fe.base_price*fe.`quantity_sold(before_promo)` as before_promo,
case
when fe.promo_type = "25% OFF" then fe.base_price*0.75*fe.`quantity_sold(after_promo)`
when fe.promo_type = "33% OFF" then fe.base_price*0.67*fe.`quantity_sold(after_promo)`
when fe.promo_type = "50% OFF" then fe.base_price*0.50*fe.`quantity_sold(after_promo)`
when fe.promo_type = "BOGOF" then fe.base_price*0.50*fe.`quantity_sold(after_promo)`*2
when fe.promo_type = "500 Cashback" then (fe.base_price-500)*fe.`quantity_sold(after_promo)`
end as after_promo
from fact_events fe join dim_products dp on dp.product_code = fe.product_code
),	
cte6 as (select product_name,category,sum(after_promo) as after_promo,sum(before_promo) as before_promo from cte5
group by product_name, category),

-- used to find out IR% = ((after_promo revenue - before_promo revenue)/before_promo revenue)*100
cte7 as (select substring(product_name,1,if(locate("(",product_name)=0,length(product_name),locate("(",product_name)-1)) as product_name,
category ,concat(round(((after_promo-before_promo)/before_promo)*100,2),"%") as `IR%`,
dense_rank() over(order by round(((after_promo-before_promo)/before_promo)*100,2) desc) as `Top`
from cte6)
select category, product_name, `IR%` from cte7 where `Top` <=5;





