import streamlit as st
import pandas as pd
import altair as alt
from snowflake.snowpark.context import get_active_session

st.set_page_config(
    page_title="Zepto Revenue Dashboard",
    page_icon="⚡",
    layout="wide",
    initial_sidebar_state="expanded",
)

session = get_active_session()

ACCENT = "#8025FB"
ACCENT_SOFT = "#f1e6ff"

st.markdown(
    f"""
    <style>
        .block-container {{
            padding-top: 1.5rem;
            padding-bottom: 3rem;
        }}
        [data-testid="stMetric"] {{
            background: rgba(128,37,251,0.05);
            border: 1px solid rgba(128,37,251,0.18);
            border-radius: 14px;
            padding: 1rem 1.1rem 0.8rem 1.1rem;
        }}
        [data-testid="stMetricLabel"] {{
            font-weight: 600;
            opacity: 0.75;
        }}
        [data-testid="stMetricValue"] {{
            font-size: 1.6rem;
        }}
        h1, h2, h3 {{
            letter-spacing: -0.02em;
        }}
        .app-header {{
            display: flex;
            align-items: center;
            gap: 0.6rem;
            margin-bottom: 0.2rem;
        }}
        .app-header .badge {{
            background: {ACCENT_SOFT};
            color: {ACCENT};
            font-weight: 700;
            font-size: 0.72rem;
            padding: 0.15rem 0.55rem;
            border-radius: 999px;
            text-transform: uppercase;
            letter-spacing: 0.04em;
        }}
        .section-caption {{
            opacity: 0.65;
            font-size: 0.9rem;
            margin-top: -0.4rem;
        }}
        div[data-testid="stDataFrame"] {{
            border-radius: 12px;
            overflow: hidden;
        }}
        button[kind="primary"] {{
            background-color: {ACCENT} !important;
            border-color: {ACCENT} !important;
        }}
    </style>
    """,
    unsafe_allow_html=True,
)

@st.cache_data(ttl=600, show_spinner=False)
def fetch_kpi_data():
    query = """
        SELECT year, total_revenue, total_orders, avg_revenue_per_order,
               avg_revenue_per_item, max_order_value
        FROM sandbox.consumption_sch.vw_yearly_revenue_kpis
        ORDER BY year;
    """
    rows = session.sql(query).collect()
    return pd.DataFrame(
        rows,
        columns=[
            "YEAR",
            "TOTAL_REVENUE",
            "TOTAL_ORDERS",
            "AVG_REVENUE_PER_ORDER",
            "AVG_REVENUE_PER_ITEM",
            "MAX_ORDER_VALUE",
        ],
    )


@st.cache_data(ttl=600, show_spinner=False)
def fetch_monthly_kpi_data(year: int):
    query = f"""
        SELECT month::number(2) AS month, total_revenue::number(10) AS total_revenue
        FROM sandbox.consumption_sch.vw_monthly_revenue_kpis
        WHERE year = {year}
        ORDER BY month;
    """
    rows = session.sql(query).collect()
    return pd.DataFrame(rows, columns=["MONTH", "TOTAL_REVENUE"])


@st.cache_data(ttl=600, show_spinner=False)
def fetch_unique_months(year: int):
    query = f"""
        SELECT DISTINCT month
        FROM sandbox.consumption_sch.vw_monthly_revenue_by_restaurant
        WHERE year = {year}
        ORDER BY month;
    """
    rows = session.sql(query).collect()
    return pd.DataFrame(rows, columns=["MONTH"])


@st.cache_data(ttl=600, show_spinner=False)
def fetch_top_stores(year: int, month: int, limit: int = 10):
    query = f"""
        SELECT restaurant_name AS store_name, total_revenue, total_orders,
               avg_revenue_per_order, avg_revenue_per_item, max_order_value
        FROM sandbox.consumption_sch.vw_monthly_revenue_by_restaurant
        WHERE year = {year} AND month = {month}
        ORDER BY total_revenue DESC
        LIMIT {limit};
    """
    rows = session.sql(query).collect()
    return pd.DataFrame(
        rows,
        columns=[
            "Dark Store",
            "Total Revenue (₹)",
            "Total Orders",
            "Avg Revenue per Order (₹)",
            "Avg Revenue per Item (₹)",
            "Max Order Value (₹)",
        ],
    )


def fmt_inr(value, decimals=0):
    if value is None or pd.isna(value):
        return "—"
    return f"₹{value:,.{decimals}f}"


def month_name(m):
    names = {
        1: "Jan",
        2: "Feb",
        3: "Mar",
        4: "Apr",
        5: "May",
        6: "Jun",
        7: "Jul",
        8: "Aug",
        9: "Sep",
        10: "Oct",
        11: "Nov",
        12: "Dec",
    }
    return names.get(int(m), str(m))


MONTH_ORDER = [
    "Jan",
    "Feb",
    "Mar",
    "Apr",
    "May",
    "Jun",
    "Jul",
    "Aug",
    "Sep",
    "Oct",
    "Nov",
    "Dec",
]


def altair_theme_chart(chart):
    """Apply a consistent, modern look to altair charts."""
    return chart.configure_axis(
        gridColor="rgba(128,128,128,0.15)",
        domainColor="rgba(128,128,128,0.3)",
        labelColor="#888",
        titleColor="#888",
    ).configure_view(strokeWidth=0)


st.markdown(
    """
    <div class="app-header">
        <h1 style="margin:0;">⚡ Zepto Revenue Dashboard</h1>
        <span class="badge">Live</span>
    </div>
    <p class="section-caption">End-to-end view of platform revenue, orders and top-performing dark stores.</p>
    """,
    unsafe_allow_html=True,
)

st.write("")

with st.spinner("Loading revenue data..."):
    df = fetch_kpi_data()

if df.empty:
    st.warning("No revenue data available yet.")
    st.stop()

years = sorted(df["YEAR"].unique())

with st.sidebar:
    st.header("⚙️ Filters")
    selected_year = st.selectbox("Year", years, index=len(years) - 1)
    top_n = st.slider("Top dark stores to show", 5, 25, 10)

    st.divider()

    st.caption(
        "Data refreshes every 10 minutes. Use the button below to force a refresh."
    )

    if st.button("🔄 Refresh data", use_container_width=True):
        st.cache_data.clear()
        st.rerun()

st.subheader("All-Time Performance")

c1, c2, c3 = st.columns(3)

c1.metric(
    "Total Revenue (All Years)",
    fmt_inr(df["TOTAL_REVENUE"].sum(), 1),
)

c2.metric(
    "Total Orders (All Years)",
    f"{df['TOTAL_ORDERS'].sum():,}",
)

c3.metric(
    "Max Order Value (Overall)",
    fmt_inr(df["MAX_ORDER_VALUE"].max()),
)

st.divider()

year_data = df[df["YEAR"] == selected_year].iloc[0]

prev = df[df["YEAR"] == selected_year - 1]
prev_row = prev.iloc[0] if not prev.empty else None


def delta(field, decimals=0, currency=True):
    if prev_row is None:
        return None

    d = year_data[field] - prev_row[field]

    return fmt_inr(d, decimals) if currency else f"{d:,.0f}"


st.subheader(f"{selected_year} Scorecard")

c1, c2, c3 = st.columns(3)

with c1:
    st.metric(
        "Total Revenue",
        fmt_inr(year_data["TOTAL_REVENUE"], 1),
        delta("TOTAL_REVENUE", 1),
    )

    st.metric(
        "Total Orders",
        f"{year_data['TOTAL_ORDERS']:,}",
        delta("TOTAL_ORDERS", currency=False),
    )

with c2:
    st.metric(
        "Avg Revenue / Order",
        fmt_inr(year_data["AVG_REVENUE_PER_ORDER"]),
        delta("AVG_REVENUE_PER_ORDER"),
    )

    st.metric(
        "Avg Revenue / Item",
        fmt_inr(year_data["AVG_REVENUE_PER_ITEM"]),
        delta("AVG_REVENUE_PER_ITEM"),
    )

with c3:
    st.metric(
        "Max Order Value",
        fmt_inr(year_data["MAX_ORDER_VALUE"]),
        delta("MAX_ORDER_VALUE"),
    )

st.divider()

month_df = fetch_monthly_kpi_data(selected_year)

if not month_df.empty:
    month_df["MONTH_NAME"] = month_df["MONTH"].apply(month_name)
    month_df["MONTH_NAME"] = pd.Categorical(
        month_df["MONTH_NAME"],
        categories=MONTH_ORDER,
        ordered=True,
    )
    month_df = month_df.sort_values("MONTH_NAME")
    month_df["CUMULATIVE_REVENUE"] = month_df["TOTAL_REVENUE"].cumsum()

st.subheader(f"{selected_year} — Monthly Revenue")

tab_bar, tab_trend, tab_cumulative = st.tabs(
    ["📊 Bar", "📈 Trend", "📉 Cumulative"]
)

if month_df.empty:
    for t in (tab_bar, tab_trend, tab_cumulative):
        with t:
            st.info("No monthly data available for this year.")
else:
    with tab_bar:
        bar_chart = (
            alt.Chart(month_df)
            .mark_bar(
                color=ACCENT,
                cornerRadiusTopLeft=6,
                cornerRadiusTopRight=6,
            )
            .encode(
                x=alt.X(
                    "MONTH_NAME:N",
                    sort=MONTH_ORDER,
                    title="Month",
                ),
                y=alt.Y(
                    "TOTAL_REVENUE:Q",
                    title="Revenue (₹)",
                ),
                tooltip=[
                    alt.Tooltip("MONTH_NAME", title="Month"),
                    alt.Tooltip(
                        "TOTAL_REVENUE",
                        title="Revenue (₹)",
                        format=",.0f",
                    ),
                ],
            )
            .properties(height=380)
        )

        st.altair_chart(
            altair_theme_chart(bar_chart),
            use_container_width=True,
        )

    with tab_trend:
        trend_chart = (
            alt.Chart(month_df)
            .mark_line(
                color=ACCENT,
                point=alt.OverlayMarkDef(
                    color=ACCENT,
                    size=60,
                ),
            )
            .encode(
                x=alt.X(
                    "MONTH_NAME:N",
                    sort=MONTH_ORDER,
                    title="Month",
                ),
                y=alt.Y(
                    "TOTAL_REVENUE:Q",
                    title="Revenue (₹)",
                    scale=alt.Scale(
                        domain=[
                            0,
                            month_df["TOTAL_REVENUE"].max() * 1.1,
                        ]
                    ),
                ),
                tooltip=[
                    alt.Tooltip("MONTH_NAME", title="Month"),
                    alt.Tooltip(
                        "TOTAL_REVENUE",
                        title="Revenue (₹)",
                        format=",.0f",
                    ),
                ],
            )
            .properties(height=380)
        )

        st.altair_chart(
            altair_theme_chart(trend_chart),
            use_container_width=True,
        )

    with tab_cumulative:
        cum_chart = (
            alt.Chart(month_df)
            .mark_area(
                color=ACCENT,
                opacity=0.25,
                line={"color": ACCENT},
            )
            .encode(
                x=alt.X(
                    "MONTH_NAME:N",
                    sort=MONTH_ORDER,
                    title="Month",
                ),
                y=alt.Y(
                    "CUMULATIVE_REVENUE:Q",
                    title="Cumulative Revenue (₹)",
                ),
                tooltip=[
                    alt.Tooltip("MONTH_NAME", title="Month"),
                    alt.Tooltip(
                        "CUMULATIVE_REVENUE",
                        title="Cumulative (₹)",
                        format=",.0f",
                    ),
                ],
            )
            .properties(height=380)
        )

        st.altair_chart(
            altair_theme_chart(cum_chart),
            use_container_width=True,
        )

st.divider()

months_df = fetch_unique_months(selected_year)

if months_df.empty:
    st.info("No monthly dark store data available for this year.")
else:
    months_avail = sorted(months_df["MONTH"].unique())

    selected_month = st.selectbox(
        f"Select Month for {selected_year}",
        months_avail,
        index=len(months_avail) - 1,
        format_func=month_name,
    )

    top_df = fetch_top_stores(
        selected_year,
        selected_month,
        top_n,
    )

    st.subheader(
        f"🏆 Top {top_n} Dark Stores — "
        f"{month_name(selected_month)} {selected_year}"
    )

    if top_df.empty:
        st.warning("No data found for the selected year and month.")
    else:
        left, right = st.columns([3, 2])

        with left:
            st.dataframe(
                top_df,
                hide_index=True,
                use_container_width=True,
                column_config={
                    "Total Revenue (₹)": st.column_config.NumberColumn(
                        format="₹%d"
                    ),
                    "Avg Revenue per Order (₹)": st.column_config.NumberColumn(
                        format="₹%d"
                    ),
                    "Avg Revenue per Item (₹)": st.column_config.NumberColumn(
                        format="₹%d"
                    ),
                    "Max Order Value (₹)": st.column_config.NumberColumn(
                        format="₹%d"
                    ),
                    "Total Orders": st.column_config.NumberColumn(
                        format="%d"
                    ),
                },
            )

            st.download_button(
                "⬇️ Download as CSV",
                data=top_df.to_csv(index=False).encode("utf-8"),
                file_name=f"top_dark_stores_{selected_year}_{selected_month}.csv",
                mime="text/csv",
            )

        with right:
            rank_chart = (
                alt.Chart(top_df.sort_values("Total Revenue (₹)"))
                .mark_bar(
                    color=ACCENT,
                    cornerRadiusTopRight=6,
                    cornerRadiusBottomRight=6,
                )
                .encode(
                    x=alt.X(
                        "Total Revenue (₹):Q",
                        title="Revenue (₹)",
                    ),
                    y=alt.Y(
                        "Dark Store:N",
                        sort="-x",
                        title="",
                    ),
                    tooltip=[
                        "Dark Store",
                        alt.Tooltip(
                            "Total Revenue (₹)",
                            format=",.0f",
                        ),
                    ],
                )
                .properties(height=380)
            )

            st.altair_chart(
                altair_theme_chart(rank_chart),
                use_container_width=True,
            )

st.divider()

st.caption(
    "Built with Streamlit in Snowflake · Data reflects sandbox.consumption_sch views."
)
