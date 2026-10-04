{% docs __overview__ %}

# E-commerce Analytics: Olist

An ELT pipeline and dimensional model for the
[Olist Brazilian e-commerce dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce):
around 100,000 orders placed between 2016 and 2018.

**Layers**

| Layer | Schema | Purpose |
|---|---|---|
| Staging | `*_staging` | One view per source table: rename, cast, tidy. No joins. |
| Intermediate | `*_intermediate` | Reusable reshaping: deduplication, rollups to order grain. |
| Core marts | `*_core` | Star schema: `fct_orders`, `fct_order_items` and four dimensions. |
| Reporting | `*_reporting` | Dashboard-ready aggregates, one per business question. |

**Questions this project answers**

1. How do revenue, orders and customers trend month to month?
2. How strongly does late delivery drive bad reviews?
3. Which sellers carry the business, and which need attention?
4. Which product categories perform best, and where does freight cost hurt?

Use the lineage graph (bottom-right icon) to trace any column back to its source.

{% enddocs %}
