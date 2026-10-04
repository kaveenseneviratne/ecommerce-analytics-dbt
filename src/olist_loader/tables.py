"""The raw tables we land, and the Kaggle file each one comes from.

Table names drop the `olist_` prefix and `_dataset` suffix so the raw layer reads cleanly
in SQL. The CSV headers are kept exactly as published, typos included; staging fixes them.
"""

from __future__ import annotations

from types import MappingProxyType

RAW_TABLES = MappingProxyType(
    {
        "customers": "olist_customers_dataset.csv",
        "geolocation": "olist_geolocation_dataset.csv",
        "order_items": "olist_order_items_dataset.csv",
        "order_payments": "olist_order_payments_dataset.csv",
        "order_reviews": "olist_order_reviews_dataset.csv",
        "orders": "olist_orders_dataset.csv",
        "products": "olist_products_dataset.csv",
        "sellers": "olist_sellers_dataset.csv",
        "product_category_name_translation": "product_category_name_translation.csv",
    }
)

# Published column order for each file. The sample-data generator writes these headers,
# and the loader checks real files against them so a changed export fails loudly.
EXPECTED_COLUMNS = MappingProxyType(
    {
        "customers": (
            "customer_id",
            "customer_unique_id",
            "customer_zip_code_prefix",
            "customer_city",
            "customer_state",
        ),
        "geolocation": (
            "geolocation_zip_code_prefix",
            "geolocation_lat",
            "geolocation_lng",
            "geolocation_city",
            "geolocation_state",
        ),
        "order_items": (
            "order_id",
            "order_item_id",
            "product_id",
            "seller_id",
            "shipping_limit_date",
            "price",
            "freight_value",
        ),
        "order_payments": (
            "order_id",
            "payment_sequential",
            "payment_type",
            "payment_installments",
            "payment_value",
        ),
        "order_reviews": (
            "review_id",
            "order_id",
            "review_score",
            "review_comment_title",
            "review_comment_message",
            "review_creation_date",
            "review_answer_timestamp",
        ),
        "orders": (
            "order_id",
            "customer_id",
            "order_status",
            "order_purchase_timestamp",
            "order_approved_at",
            "order_delivered_carrier_date",
            "order_delivered_customer_date",
            "order_estimated_delivery_date",
        ),
        "products": (
            "product_id",
            "product_category_name",
            "product_name_lenght",
            "product_description_lenght",
            "product_photos_qty",
            "product_weight_g",
            "product_length_cm",
            "product_height_cm",
            "product_width_cm",
        ),
        "sellers": (
            "seller_id",
            "seller_zip_code_prefix",
            "seller_city",
            "seller_state",
        ),
        "product_category_name_translation": (
            "product_category_name",
            "product_category_name_english",
        ),
    }
)
