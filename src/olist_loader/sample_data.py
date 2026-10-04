"""Generate a small synthetic dataset with the same files, columns and quirks as Olist.

CI and the test suite run on this, so the pipeline can be built and tested anywhere without
downloading or committing the real data. It deliberately reproduces the messiness the dbt
models have to handle:

- zip prefixes written as integers (leading zeros lost)
- city names with inconsistent case and stray whitespace
- several coordinates per zip, plus a few that land outside Brazil
- products with no category, and categories missing from the translation file
- orders with more than one review, and review ids reused across orders
- review comments containing commas, quotes and line breaks
- a few "delivered" orders with no delivery date
- thin months at both ends of the date range
"""

from __future__ import annotations

import csv
import random
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from pathlib import Path

from olist_loader.tables import EXPECTED_COLUMNS, RAW_TABLES

TIMESTAMP_FMT = "%Y-%m-%d %H:%M:%S"

CATEGORIES = {
    "beleza_saude": "health_beauty",
    "cama_mesa_banho": "bed_bath_table",
    "esporte_lazer": "sports_leisure",
    "moveis_decoracao": "furniture_decor",
    "informatica_acessorios": "computers_accessories",
    "utilidades_domesticas": "housewares",
    "relogios_presentes": "watches_gifts",
    "telefonia": "telephony",
    "ferramentas_jardim": "garden_tools",
    "automotivo": "auto",
    "brinquedos": "toys",
    "cool_stuff": "cool_stuff",
    "perfumaria": "perfumery",
    "bebes": "baby",
    "eletronicos": "electronics",
}
# These two exist in the real product file but not in the translation file.
UNTRANSLATED = ("pc_gamer", "portateis_cozinha_e_preparadores_de_alimentos")

# (weight, approx centroid lat, lng, main city, zip range)
STATES = {
    "SP": (0.42, -23.5, -46.6, "sao paulo", (1000, 19999)),
    "RJ": (0.13, -22.9, -43.2, "rio de janeiro", (20000, 28999)),
    "MG": (0.12, -19.9, -43.9, "belo horizonte", (30000, 39999)),
    "RS": (0.055, -30.0, -51.2, "porto alegre", (90000, 99999)),
    "PR": (0.05, -25.4, -49.3, "curitiba", (80000, 87999)),
    "SC": (0.037, -27.6, -48.5, "florianopolis", (88000, 89999)),
    "BA": (0.034, -12.9, -38.5, "salvador", (40000, 48999)),
    "DF": (0.021, -15.8, -47.9, "brasilia", (70000, 73699)),
    "ES": (0.02, -20.3, -40.3, "vitoria", (29000, 29999)),
    "GO": (0.02, -16.7, -49.3, "goiania", (72800, 76799)),
    "PE": (0.017, -8.05, -34.9, "recife", (50000, 56999)),
    "CE": (0.013, -3.73, -38.5, "fortaleza", (60000, 63999)),
    "PA": (0.01, -1.45, -48.5, "belem", (66000, 68899)),
    "MT": (0.009, -15.6, -56.1, "cuiaba", (78000, 78899)),
    "MA": (0.007, -2.53, -44.3, "sao luis", (65000, 65999)),
    "AM": (0.005, -3.1, -60.0, "manaus", (69000, 69299)),
    "RR": (0.002, 2.82, -60.7, "boa vista", (69300, 69399)),
}

ORDER_STATUSES = {
    "delivered": 0.965,
    "shipped": 0.011,
    "canceled": 0.007,
    "unavailable": 0.006,
    "invoiced": 0.004,
    "processing": 0.004,
    "created": 0.002,
    "approved": 0.001,
}

COMMENTS = (
    "",
    "",
    "",
    "Recebi bem antes do prazo, recomendo.",
    'Produto ótimo, mas a embalagem veio "amassada".',
    "Não recebi o produto até agora,\nquero meu dinheiro de volta.",
    "Chegou certinho, obrigado!",
    "Demorou muito, mas o produto é bom, gostei.",
)


@dataclass
class _Ctx:
    rng: random.Random
    zips_by_state: dict[str, set[int]] = field(default_factory=dict)

    def hex_id(self) -> str:
        return f"{self.rng.getrandbits(128):032x}"

    def choice_weighted(self, options: dict[str, float]) -> str:
        return self.rng.choices(list(options), weights=list(options.values()))[0]

    def location(self, state: str | None = None) -> tuple[str, int, str]:
        if state is None:
            state = self.choice_weighted({s: v[0] for s, v in STATES.items()})
        _, _, _, city, (lo, hi) = STATES[state]
        zip_prefix = self.rng.randint(lo, hi)
        self.zips_by_state.setdefault(state, set()).add(zip_prefix)
        # same city written several ways, the way free-text fields come out of real systems
        city = self.rng.choice([city, city.title(), f" {city}", f"{city} "])
        return state, zip_prefix, city


def _fmt(ts: datetime | None) -> str:
    return ts.strftime(TIMESTAMP_FMT) if ts else ""


def _write(out_dir: Path, table: str, rows: list[tuple[object, ...]], bom: bool = False) -> None:
    path = out_dir / RAW_TABLES[table]
    with path.open("w", encoding="utf-8-sig" if bom else "utf-8", newline="") as fh:
        writer = csv.writer(fh)
        writer.writerow(EXPECTED_COLUMNS[table])
        writer.writerows(rows)


def generate(out_dir: Path, n_orders: int = 3_000, seed: int = 7) -> dict[str, int]:
    """Write all nine CSVs to `out_dir` and return row counts per table."""
    out_dir.mkdir(parents=True, exist_ok=True)
    ctx = _Ctx(random.Random(seed))
    rng = ctx.rng

    sellers = []
    for _ in range(max(20, n_orders // 25)):
        state, zip_prefix, city = ctx.location(rng.choice(["SP", "SP", "SP", "MG", "PR", "RJ"]))
        sellers.append((ctx.hex_id(), zip_prefix, city, state))

    category_pool = [*CATEGORIES, *UNTRANSLATED]
    products = []
    for _ in range(max(50, n_orders // 7)):
        if rng.random() < 0.02:
            products.append((ctx.hex_id(), "", "", "", "", "", "", "", ""))
            continue
        products.append(
            (
                ctx.hex_id(),
                rng.choice(category_pool),
                rng.randint(10, 70),
                rng.randint(50, 2000),
                rng.randint(1, 6),
                rng.randint(100, 15000),
                rng.randint(10, 80),
                rng.randint(2, 60),
                rng.randint(10, 60),
            )
        )

    customers, orders, items, payments, reviews = [], [], [], [], []
    unique_customers: list[tuple[str, str, int, str]] = []
    start, end = datetime(2016, 10, 1), datetime(2018, 8, 31)
    span = (end - start).total_seconds()
    review_ids: list[str] = []

    for i in range(n_orders):
        # Order volume grows over time: sqrt skews draws towards later dates.
        if i < 3:
            purchased = datetime(2016, 9, 5) + timedelta(days=i)
        elif i >= n_orders - 3:
            purchased = datetime(2018, 9, 10) + timedelta(days=i % 3 * 12)
        else:
            purchased = start + timedelta(seconds=span * rng.random() ** 0.5)
        purchased = purchased.replace(microsecond=0)

        if unique_customers and rng.random() < 0.03:
            unique_id, state, zip_prefix, city = rng.choice(unique_customers)
        else:
            state, zip_prefix, city = ctx.location()
            unique_id = ctx.hex_id()
            unique_customers.append((unique_id, state, zip_prefix, city))
        customer_id = ctx.hex_id()
        customers.append((customer_id, unique_id, zip_prefix, city, state))

        status = ctx.choice_weighted(ORDER_STATUSES)
        approved = shipped = delivered = None
        if status != "created" and not (status == "canceled" and rng.random() < 0.5):
            approved = purchased + timedelta(minutes=rng.randint(5, 48 * 60))
        if status in ("shipped", "delivered") and approved:
            shipped = approved + timedelta(hours=rng.randint(12, 120))
        days_to_deliver = rng.gammavariate(3.0, 4.0) + 1
        if status == "delivered" and shipped and rng.random() > 0.003:
            delivered = max(
                purchased + timedelta(days=days_to_deliver), shipped + timedelta(hours=6)
            )
        estimated = (purchased + timedelta(days=rng.randint(18, 30))).replace(
            hour=0, minute=0, second=0
        )

        order_id = ctx.hex_id()
        orders.append(
            (order_id, customer_id, status, _fmt(purchased), _fmt(approved), _fmt(shipped),
             _fmt(delivered), _fmt(estimated))
        )  # fmt: skip

        order_total = 0.0
        if status != "unavailable" and not (status == "canceled" and rng.random() < 0.5):
            n_items = rng.choices([1, 2, 3, 4], weights=[0.87, 0.09, 0.03, 0.01])[0]
            product = rng.choice(products)
            seller = rng.choice(sellers)
            for n in range(1, n_items + 1):
                price = round(min(rng.lognormvariate(4.3, 0.9), 4000), 2)
                freight = round(rng.uniform(5, 40), 2)
                order_total += price + freight
                limit = (approved or purchased) + timedelta(days=6)
                items.append((order_id, n, product[0], seller[0], _fmt(limit), price, freight))

        order_total = round(order_total, 2)
        if order_total == 0:
            payments.append((order_id, 1, "not_defined", 1, 0))
        else:
            ptype = ctx.choice_weighted(
                {"credit_card": 0.74, "boleto": 0.19, "voucher": 0.055, "debit_card": 0.015}
            )
            if ptype == "voucher" and rng.random() < 0.5:
                voucher = round(min(order_total, rng.uniform(5, 50)), 2)
                payments.append((order_id, 1, "voucher", 1, voucher))
                payments.append((order_id, 2, "credit_card", 1, round(order_total - voucher, 2)))
            elif ptype == "credit_card":
                # a stray 0 mirrors the handful of zero-instalment rows in the real file
                installments = rng.choice([0, *[1] * 30, 2, 3, 4, 6, 8, 10])
                # card installments sometimes carry interest, so paid > order value
                paid = order_total * (1 + rng.uniform(0, 0.05)) if installments > 3 else order_total
                payments.append((order_id, 1, ptype, installments, round(paid, 2)))
            else:
                payments.append((order_id, 1, ptype, 1, order_total))

        if rng.random() < 0.99:
            late = bool(delivered and delivered.date() > estimated.date())
            if delivered is None:
                weights = [0.6, 0.1, 0.1, 0.05, 0.15]
            elif late:
                weights = [0.4, 0.11, 0.12, 0.12, 0.25]
            else:
                weights = [0.07, 0.03, 0.08, 0.2, 0.62]
            created = ((delivered or estimated) + timedelta(days=1)).replace(
                hour=0, minute=0, second=0
            )
            n_reviews = 2 if rng.random() < 0.005 else 1
            for r in range(n_reviews):
                created_r = created + timedelta(days=r * 3)
                answered = created_r + timedelta(hours=rng.randint(2, 120))
                reused = review_ids and rng.random() < 0.003
                review_id = rng.choice(review_ids) if reused else ctx.hex_id()
                review_ids.append(review_id)
                reviews.append(
                    (review_id, order_id, rng.choices([1, 2, 3, 4, 5], weights=weights)[0],
                     "", rng.choice(COMMENTS), _fmt(created_r), _fmt(answered))
                )  # fmt: skip

    geolocation = []
    for state, zips in ctx.zips_by_state.items():
        _, lat, lng, city, _ = STATES[state]
        for zip_prefix in zips:
            for _ in range(rng.randint(1, 6)):
                if rng.random() < 0.01:
                    # a handful of points in the real file land in Europe or the ocean
                    geolocation.append((zip_prefix, 41.6, -8.6, city, state))
                    continue
                geolocation.append(
                    (zip_prefix, round(lat + rng.uniform(-0.3, 0.3), 6),
                     round(lng + rng.uniform(-0.3, 0.3), 6), city, state)
                )  # fmt: skip

    translation = [(pt, en) for pt, en in CATEGORIES.items()]

    tables: dict[str, list[tuple[object, ...]]] = {
        "customers": customers,
        "geolocation": geolocation,
        "order_items": items,
        "order_payments": payments,
        "order_reviews": reviews,
        "orders": orders,
        "products": products,
        "sellers": sellers,
        "product_category_name_translation": translation,
    }
    for table, rows in tables.items():
        _write(out_dir, table, rows, bom=table == "product_category_name_translation")
    return {table: len(rows) for table, rows in tables.items()}
