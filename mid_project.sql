-- ASSIGNMENT --
use mavenfuzzyfactory;

-- --------------------------------------------------------------------------
-- Question 1: pull monthly trends for gsearch sessions and orders since '2012-11-27'

select
	year(website_sessions.created_at) as yr,
    month(website_sessions.created_at) as mo,
    count(distinct website_sessions.website_session_id) as total_sessions,
    count(distinct orders.order_id) as total_orders
from website_sessions
left join orders
	on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-11-27'
and website_sessions.utm_source = 'gsearch'
group by 
	year(website_sessions.created_at),
    month(website_sessions.created_at)
;

-- --------------------------------------------------------------------------
/*Question 2:  Next, it would be greate to see a similar monthly trend for Gsearch, but this time splittng out nonbrand 
and brand campaigns seperately. I am wondering if brand is picking up att all. If so this is a good story to tell
*/
create temporary table monthly_trend_gsearch_splited_by_campaign
select
	min(date(website_sessions.created_at)) as created_at,
    year(website_sessions.created_at) as yr,
    month(website_sessions.created_at) as mo,
    count(case when website_sessions.utm_campaign = 'brand' then website_sessions.website_session_id else null end) as brand_campaign_sessions,
    count(case when website_sessions.utm_campaign = 'nonbrand' then website_sessions.website_session_id else null end) as non_brand_campaign_sessions,
    count(case when website_sessions.utm_campaign = 'brand' then orders.order_id else null end) as brand_campaign_orders,
	count(case when website_sessions.utm_campaign = 'nonbrand' then orders.order_id else null end) as nonbrand_campaign_orders,
    count(distinct orders.order_id) as total_orders
from website_sessions
left join orders
	on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-11-27'
	and website_sessions.utm_source = 'gsearch'
group by 
	year(website_sessions.created_at),
    month(website_sessions.created_at)
    
-- --------------------------------------------------------------------------
-- Question 3: Pull monthly sessions and orders split by device on nonbrand campaign
;
select
	device_type
from website_sessions
group by 1
;

select 
	year(website_sessions.created_at) as yr,
    month(website_sessions.created_at) as mo,
    count(case when website_sessions.device_type ='mobile' then website_sessions.website_session_id else null end) as mobile_sessions,
    count(case when website_sessions.device_type = 'desktop' then website_sessions.website_session_id else null end) as desktop_sessions,
    count(case when website_sessions.device_type = 'mobile' then orders.order_id else null end) as mobile_orders,
    count(case when website_sessions.device_type ='desktop' then orders.order_id else null end) as desktop_orders
from website_sessions
left join orders 
	on website_sessions.website_session_id = orders.website_session_id
where website_sessions.utm_source = 'gsearch'
	and website_sessions.created_at < '2012-11-27'
group by 1,2
;

-- --------------------------------------------------------------------------    
-- Question 4: pull monthly trends for gsearch sessions alongside with other source    
select
	utm_source
from website_sessions
where website_sessions.created_at < '2012-11-27'
group by 1
;

select
	year(website_sessions.created_at) as yr,
    month(website_sessions.created_at) as mo,
    count(case when utm_source = 'gsearch' then website_sessions.website_session_id else null end) as gsearch_sessions,
	count(case when utm_source = 'bsearch' then website_sessions.website_session_id else null end) as bsearch_sessions,
	count(case when utm_source is null and http_referer is not null then website_sessions.website_session_id else null end) as organic_sessions,
	count(case when utm_source is null and http_referer is null then website_sessions.website_session_id else null end) as direct_sessions

from website_sessions
left join orders
	on orders.website_session_id = website_sessions.website_session_id
where website_sessions.created_at <  '2012-11-27'
group by 1,2

-- --------------------------------------------------------------------------
-- Question 5 : Pull session to order conversion rate by month 
;
use mavenfuzzyfactory;
select 
	year(website_sessions.created_at) as yr,
    month(website_sessions.created_at) as mo,
    count(distinct website_sessions.website_session_id) as total_sessions,
    count(distinct orders.order_id) as orders,
    count(distinct orders.order_id)/count(distinct website_sessions.website_session_id) as conversion_rate
from website_sessions
left join orders
	on website_sessions.website_session_id = orders.website_session_id
where website_sessions.created_at < '2012-11-27'
group by 1,2
;
-- conclusion: there is an improvement of month by month conversion_rate

-- --------------------------------------------------------------------------
-- Question 6: - Estimate the revenue(orders) generated from the last home sessions until November 27 for gsearch nonbrand channel
-- hint(find the increasing CRV from june 19 - jul 28 and the incremental sessions since last home sessions to November 27 

-- 6.1 find when the first lander test pageviwe id exists (the first session of lander-1)
;
select 
	min(website_pageview_id) as first_test_pv
from website_pageviews
where website_pageviews.pageview_url = '/lander-1'
;
-- answer : website_pageview_id = 23504

-- 6.2 create temporary table consist of gsearch nonbrand sessions and first pageview id
drop temporary table if exists sessions_with_first_pageview_id;
create temporary table sessions_with_first_pageview_id
select
	website_pageviews.website_session_id,
    min(website_pageviews.website_pageview_id) as first_pv,
    website_pageviews.pageview_url as landing_page
from website_pageviews
inner join website_sessions
	on website_pageviews.website_session_id = website_sessions.website_session_id
where website_pageviews.website_pageview_id >= 23504
	and website_sessions.created_at < '2012-07-29'
    and website_sessions.utm_source = 'gsearch'
    and website_sessions.utm_campaign = 'nonbrand'
group by website_pageviews.website_session_id;

-- 6.3 identify the increasing conversion rate first test lander-1 vs home
select
	landing_page,
    count(distinct sessions_with_first_pageview_id.website_session_id) as total_session,
    count(distinct orders.order_id) orders,
    count(distinct orders.order_id)/count(distinct sessions_with_first_pageview_id.website_session_id) as conv_rate
from sessions_with_first_pageview_id
left join orders
	on sessions_with_first_pageview_id.website_session_id = orders.website_session_id
group by 1
-- answer : home: 0.0317 of conv_rate, lader-: 0.0403 of conv_rate, incremental conv_rate = 0.0403 - 0.0317 = 0.0086
;

-- 6.4 calculating revenue from sessions with first pageview
-- 6.4.1. find the last gsearch nonbrand sessions where direct to home page
select
	max(website_pageviews.website_session_id) as last_home
from website_pageviews
left join website_sessions
	on website_pageviews.website_session_id = website_sessions.website_session_id
where 
	website_sessions.utm_source = 'gsearch'
	and website_sessions.utm_campaign = 'nonbrand'
    and website_pageviews.pageview_url = '/home'
    and website_pageviews.created_at < '2012-11-27'
;
-- answer : last website session id which directed to home page is 17145
 
-- 6.4.2. determine how many website session are occured during the last home sessions until November 27 
-- the revenue(order) = the incremental conversion rate x number of website session during specific time

select 
	count(website_sessions.website_session_id) as total_gsearch_nonbrand_sessions,
    count(website_sessions.website_session_id)* 0.0086 as estimated_incremental_orders
from website_sessions
where website_sessions.utm_source = 'gsearch'
    and website_sessions.utm_campaign = 'nonbrand'
    and website_sessions.created_at < '2012-11-27'
    and website_sessions.website_session_id > 17145
-- answer: there are 21838 website sessions during that time
;
-- --------------------------------------------------------------------------
-- Question 7 : show the full conversion funnel of home and lander-1 page to order from (june 19 - july 28) 
-- 7.1 Identify what are the pageview_url
select
    website_pageviews.pageview_url
from website_pageviews
group by 1
-- there are -- landing page (/home,lander1,lander2,lander3,lander4,lander5)
			 -- /products 
			 -- from product to (/the-original-mr-fuzzy, the-forever-love-bear, the-birthday-sugar-panda, the-hudson-river-mini-bear)
			 -- /cart
             -- /billing
             -- /shipping
             -- /thank-you-for-your-order
;

-- 7.2 since the company only have first product which is the original mr fuzzy, 
-- the funnle for gsearch nonbrand sessions directed to a home page is:

-- 7.2.1 create a websitesessions id coresspond to a pageview id where the home page occured
create temporary table website_session_with_pageview_on_home_and_time_range
select
	website_pageviews.website_session_id,
    website_pageviews.website_pageview_id as home_pv_id
from website_pageviews
left join website_sessions
on website_pageviews.website_session_id = website_sessions.website_session_id
where website_pageviews.created_at < '2012-07-28'
    and website_pageviews.created_at > '2012-06-19'
    and website_sessions.utm_source = 'gsearch'
    and website_sessions.utm_campaign = 'nonbrand'
    and website_pageviews.pageview_url = '/home'
;
-- drop temporary table if exists home_session_funnle;
-- 7.2.1 create a table for home sessions funnle
create temporary table home_session_funnle
select
	website_session_id,
    max(product_flag) as product_made_it,
    max(the_original_mr_fuzzy_flag) as the_original_mr_fuzzy_made_it,
	max(cart_flag) as cart_made_it,
    -- max(billing_flag) as billing_made_it,
    max(shipping_flag) as shipping_made_it,
    max(thank_you_for_your_order_flag) as thank_you_for_your_order_made_it,
    pageview_url as landing_page
from (
select
	website_session_with_pageview_on_home_and_time_range.website_session_id,
	case when website_pageviews.pageview_url = '/products' then 1 else 0 end as product_flag,
    case when website_pageviews.pageview_url = '/the-original-mr-fuzzy' then 1 else 0 end as the_original_mr_fuzzy_flag,
    case when website_pageviews.pageview_url = '/cart' then 1 else 0 end as cart_flag,
	-- case when website_pageviews.pageview_url = '/billing' then 1 else 0 end as billing_flag,
	case when website_pageviews.pageview_url = '/shipping' then 1 else 0 end as shipping_flag,
	case when website_pageviews.pageview_url = '/thank-you-for-your-order' then 1 else 0 end as thank_you_for_your_order_flag,
    website_pageviews.pageview_url
from website_session_with_pageview_on_home_and_time_range
left join website_pageviews
	on website_session_with_pageview_on_home_and_time_range.website_session_id = website_pageviews.website_session_id
) as pageview_level
group by website_session_id
;  
select*from home_session_funnle;
-- 7.2.1 calculate funnle rate
create temporary table home_session_funnle_sum
select
	sum(product_made_it) as product_made_it_flag,
    sum(the_original_mr_fuzzy_made_it) as the_original_mr_fuzzy_made_it_flag,
    sum(cart_made_it) as cart_made_it_flag,
	sum(shipping_made_it) as shipping_made_it_flag,
	sum(thank_you_for_your_order_made_it) as thank_you_for_your_order_made_it_flag,
    landing_page
from home_session_funnle
;

create temporary table home_session_funnle_sum_2 like home_session_funnle_sum;
insert into home_session_funnle_sum_2 select * from home_session_funnle_sum;
create temporary table home_session_funnle_sum_3 like home_session_funnle_sum;
insert into home_session_funnle_sum_3 select * from home_session_funnle_sum;
create temporary table home_session_funnle_sum_4 like home_session_funnle_sum;
insert into home_session_funnle_sum_4 select * from home_session_funnle_sum;
create temporary table home_session_funnle_sum_5 like home_session_funnle_sum;
insert into home_session_funnle_sum_5 select * from home_session_funnle_sum;

create temporary table home_session_funnle_sessions_amount
select 
	'product_made_it_flag' pageview,
    product_made_it_flag sessions_amount,
    landing_page landing_page
from home_session_funnle_sum
union all
select 
	'the_original_mr_fuzzy_made_it_flag' pageview,
    the_original_mr_fuzzy_made_it_flag sessions_amount,
    landing_page landing_page
from home_session_funnle_sum_2
union all
select 
	'cart_made_it_flag' pageview,
    cart_made_it_flag sessions_amount,
    landing_page landing_page
from home_session_funnle_sum_3
union all
select 
	'shipping_made_it_flag' pageview,
    shipping_made_it_flag sessions_amount,
    landing_page landing_page
from home_session_funnle_sum_4	
union all
select 
	'thank_you_for_your_order_made_it_flag' pageview,
    thank_you_for_your_order_made_it_flag sessions_amount,
    landing_page landing_page
from home_session_funnle_sum_5
;
-- create temp table home funnle rate

create temporary table home_session_funnle_rate
select
	sum(product_made_it)/count(website_session_id) as product_made_it_flag,
    sum(the_original_mr_fuzzy_made_it)/sum(product_made_it) as the_original_mr_fuzzy_made_it_flag,
    sum(cart_made_it)/sum(the_original_mr_fuzzy_made_it) as cart_made_it_flag,
	sum(shipping_made_it)/sum(cart_made_it) as shipping_made_it_flag,
	sum(thank_you_for_your_order_made_it)/sum(shipping_made_it) as thank_you_for_your_order_made_it_flag,
    landing_page
from home_session_funnle
;
create temporary table home_session_funnle_rate_2 like home_session_funnle_rate;
insert into home_session_funnle_rate_2 select * from home_session_funnle_rate;
create temporary table home_session_funnle_rate_3 like home_session_funnle_rate;
insert into home_session_funnle_rate_3 select * from home_session_funnle_rate;
create temporary table home_session_funnle_rate_4 like home_session_funnle_rate;
insert into home_session_funnle_rate_4 select * from home_session_funnle_rate;
create temporary table home_session_funnle_rate_5 like home_session_funnle_rate;
insert into home_session_funnle_rate_5 select * from home_session_funnle_rate;

create temporary table home_session_funnle_click_rate
select 
	'product_made_it_flag' pageview,
    product_made_it_flag click_rate,
    landing_page landing_page
from home_session_funnle_rate
union all
select 
	'the_original_mr_fuzzy_made_it_flag' pageview,
    the_original_mr_fuzzy_made_it_flag click_rate,
    landing_page landing_page
from home_session_funnle_rate_2
union all
select 
	'cart_made_it_flag' pageview,
    cart_made_it_flag click_rate,
    landing_page landing_page
from home_session_funnle_rate_3
union all
select 
	'shipping_made_it_flag' pageview,
    shipping_made_it_flag click_rate,
    landing_page landing_page
from home_session_funnle_rate_4	
union all
select 
	'thank_you_for_your_order_made_it_flag' pageview,
    thank_you_for_your_order_made_it_flag click_rate,
    landing_page landing_page
from home_session_funnle_rate_5
;

-- left join table
create temporary table home_session_funnle_amount_and_click_rate
select 
	home_session_funnle_sessions_amount.pageview,
    home_session_funnle_sessions_amount.sessions_amount,
    home_session_funnle_click_rate.click_rate,
    home_session_funnle_sessions_amount.landing_page
from home_session_funnle_sessions_amount
inner join home_session_funnle_click_rate
	on home_session_funnle_sessions_amount.pageview = home_session_funnle_click_rate.pageview
;
-- select * from home_session_funnle_amount_and_click_rate

-- 7.3 the funnle for gsearch nonbrand sessions directed to a lander page is:
-- 7.3.1 create a websitesessions id coresspond to a pageview id where the home page occured
create temporary table website_session_with_pageview_on_lander_1_and_time_range
select
	website_pageviews.website_session_id,
    website_pageviews.website_pageview_id as home_pv_id
from website_pageviews
left join website_sessions
on website_pageviews.website_session_id = website_sessions.website_session_id
where website_pageviews.created_at < '2012-07-28'
    and website_pageviews.created_at > '2012-06-19'
    and website_sessions.utm_source = 'gsearch'
    and website_sessions.utm_campaign = 'nonbrand'
    and website_pageviews.pageview_url = '/lander-1'
;

-- 7.2.1 create a table for home sessions funnle
create temporary table lander_1_session_funnle
select
	website_session_id,
    max(product_flag) as product_made_it,
    max(the_original_mr_fuzzy_flag) as the_original_mr_fuzzy_made_it,
	max(cart_flag) as cart_made_it,
    -- max(billing_flag) as billing_made_it,
    max(shipping_flag) as shipping_made_it,
    max(thank_you_for_your_order_flag) as thank_you_for_your_order_made_it,
    pageview_url as landing_page
from (
select
	website_session_with_pageview_on_lander_1_and_time_range.website_session_id,
	case when website_pageviews.pageview_url = '/products' then 1 else 0 end as product_flag,
    case when website_pageviews.pageview_url = '/the-original-mr-fuzzy' then 1 else 0 end as the_original_mr_fuzzy_flag,
    case when website_pageviews.pageview_url = '/cart' then 1 else 0 end as cart_flag,
	-- case when website_pageviews.pageview_url = '/billing' then 1 else 0 end as billing_flag,
	case when website_pageviews.pageview_url = '/shipping' then 1 else 0 end as shipping_flag,
	case when website_pageviews.pageview_url = '/thank-you-for-your-order' then 1 else 0 end as thank_you_for_your_order_flag,
    website_pageviews.pageview_url
from website_session_with_pageview_on_lander_1_and_time_range
left join website_pageviews
	on website_session_with_pageview_on_lander_1_and_time_range.website_session_id = website_pageviews.website_session_id
) as pageview_level
group by website_session_id
;  
select*from lander_1_session_funnle
;
-- 7.2.1 calculate funnle rate

create temporary table lander_1_session_funnle_sum
select
	sum(product_made_it) as product_made_it_flag,
    sum(the_original_mr_fuzzy_made_it) as the_original_mr_fuzzy_made_it_flag,
    sum(cart_made_it) as cart_made_it_flag,
	sum(shipping_made_it) as shipping_made_it_flag,
	sum(thank_you_for_your_order_made_it) as thank_you_for_your_order_made_it_flag,
    landing_page
from lander_1_session_funnle
;

create temporary table lander_1_session_funnle_sum_2 like lander_1_session_funnle_sum;
insert into lander_1_session_funnle_sum_2 select * from lander_1_session_funnle_sum;
create temporary table lander_1_session_funnle_sum_3 like lander_1_session_funnle_sum;
insert into lander_1_session_funnle_sum_3 select * from lander_1_session_funnle_sum;
create temporary table lander_1_session_funnle_sum_4 like lander_1_session_funnle_sum;
insert into lander_1_session_funnle_sum_4 select * from lander_1_session_funnle_sum;
create temporary table lander_1_session_funnle_sum_5 like lander_1_session_funnle_sum;
insert into lander_1_session_funnle_sum_5 select * from lander_1_session_funnle_sum;

create temporary table lander_1_session_funnle_sessions_amount
select 
	'product_made_it_flag' pageview,
    product_made_it_flag sessions_amount,
    landing_page landing_page
from lander_1_session_funnle_sum
union all
select 
	'the_original_mr_fuzzy_made_it_flag' pageview,
    the_original_mr_fuzzy_made_it_flag sessions_amount,
    landing_page landing_page
from lander_1_session_funnle_sum_2
union all
select 
	'cart_made_it_flag' pageview,
    cart_made_it_flag sessions_amount,
    landing_page landing_page
from lander_1_session_funnle_sum_3
union all
select 
	'shipping_made_it_flag' pageview,
    shipping_made_it_flag sessions_amount,
    landing_page landing_page
from lander_1_session_funnle_sum_4	
union all
select 
	'thank_you_for_your_order_made_it_flag' pageview,
    thank_you_for_your_order_made_it_flag sessions_amount,
    landing_page landing_page
from lander_1_session_funnle_sum_5
;
-- create temp table home funnle rate

create temporary table lander_1_session_funnle_rate
select
	sum(product_made_it)/count(website_session_id) as product_made_it_flag,
    sum(the_original_mr_fuzzy_made_it)/sum(product_made_it) as the_original_mr_fuzzy_made_it_flag,
    sum(cart_made_it)/sum(the_original_mr_fuzzy_made_it) as cart_made_it_flag,
	sum(shipping_made_it)/sum(cart_made_it) as shipping_made_it_flag,
	sum(thank_you_for_your_order_made_it)/sum(shipping_made_it) as thank_you_for_your_order_made_it_flag,
    landing_page
from lander_1_session_funnle
;
create temporary table lander_1_session_funnle_rate_2 like lander_1_session_funnle_rate;
insert into lander_1_session_funnle_rate_2 select * from lander_1_session_funnle_rate;
create temporary table lander_1_session_funnle_rate_3 like lander_1_session_funnle_rate;
insert into lander_1_session_funnle_rate_3 select * from lander_1_session_funnle_rate;
create temporary table lander_1_session_funnle_rate_4 like lander_1_session_funnle_rate;
insert into lander_1_session_funnle_rate_4 select * from lander_1_session_funnle_rate;
create temporary table lander_1_session_funnle_rate_5 like lander_1_session_funnle_rate;
insert into lander_1_session_funnle_rate_5 select * from lander_1_session_funnle_rate;

create temporary table lander_1_session_funnle_click_rate
select 
	'product_made_it_flag' pageview,
    product_made_it_flag click_rate,
    landing_page landing_page
from lander_1_session_funnle_rate
union all
select 
	'the_original_mr_fuzzy_made_it_flag' pageview,
    the_original_mr_fuzzy_made_it_flag click_rate,
    landing_page landing_page
from lander_1_session_funnle_rate_2
union all
select 
	'cart_made_it_flag' pageview,
    cart_made_it_flag click_rate,
    landing_page landing_page
from lander_1_session_funnle_rate_3
union all
select 
	'shipping_made_it_flag' pageview,
    shipping_made_it_flag click_rate,
    landing_page landing_page
from lander_1_session_funnle_rate_4	
union all
select 
	'thank_you_for_your_order_made_it_flag' pageview,
    thank_you_for_your_order_made_it_flag click_rate,
    landing_page landing_page
from lander_1_session_funnle_rate_5
;

-- left join table
-- select* from lander_1_session_funnle_click_rate;

create temporary table lander_1_session_funnle_amount_and_click_rate
select 
	lander_1_session_funnle_sessions_amount.pageview,
    lander_1_session_funnle_sessions_amount.sessions_amount,
    lander_1_session_funnle_click_rate.click_rate,
    lander_1_session_funnle_sessions_amount.landing_page
from lander_1_session_funnle_sessions_amount
inner join lander_1_session_funnle_click_rate
	on lander_1_session_funnle_sessions_amount.pageview = lander_1_session_funnle_click_rate.pageview
;

-- joining home and lander sessions
create temporary table home_and_lander_1_conversion_funnle
select *
from home_session_funnle_amount_and_click_rate
union
select *
from lander_1_session_funnle_amount_and_click_rate
;
select * from home_and_lander_1_conversion_funnle;

-- Question 8: How much revenue per biing page sessions generated from billing test from 2012-10-27; and '2012-11-27'. 
-- and pull the number of billing page sessions for the past month to understand monthly impact
select
	billing_version_seen,
    count(billing_pageviews_and_order_data.website_session_id) as sessions,
    sum(billing_pageviews_and_order_data.price_usd)/count(billing_pageviews_and_order_data.website_session_id) as revenue_per_billing_session
from(
select 
	website_pageviews.website_session_id,
    website_pageviews.pageview_url as billing_version_seen,
    orders.order_id,
    orders.price_usd
from website_pageviews
left join orders
	on website_pageviews.website_session_id = orders.website_session_id
where 
	website_pageviews.created_at > '2012-09-10'
    and website_pageviews.created_at < '2012-11-10' 
    and website_pageviews.pageview_url IN ('/billing','/billing-2')
) as billing_pageviews_and_order_data
group by 1
;

-- pull the number of billing page sessions for the past month to understand monthly impact
select
min(date(website_pageviews.created_at)) as created_at,
count(case when website_pageviews.pageview_url ='/billing' then website_pageviews.website_session_id else null end) as billing_sessions,
count(case when website_pageviews.pageview_url ='/billing-2' then website_pageviews.website_session_id else null end) as billing_2_sessions,
count(website_pageviews.website_session_id) as total_session
from website_pageviews
where 
	website_pageviews.created_at > '2012-09-01'
    and website_pageviews.created_at < '2012-11-01'
   -- and website_pageviews.pageview_url in('/billing','/billing-2')
group by 
	year(website_pageviews.created_at),
    month(website_pageviews.created_at)
