# Stock Market Monitor for KDE Plasma 6

A modern stock market widget for KDE Plasma 6. It pulls data from Yahoo Finance and supports stocks, crypto, indices, and FX pairs.

<p align="center">
    <a href="https://www.pling.com/p/2332661/">
        <img src="https://img.shields.io/badge/KDE_Store-Download-blue?style=for-the-badge&logo=kde" alt="KDE Store Collection">
    </a>
    <a href="https://ko-fi.com/vsh07">
        <img src="https://img.shields.io/badge/Buy_me_a_Kofi-donate-blue?style=for-the-badge&logo=kofi&color=%23FF6433" alt="Support on Ko-fi">
    </a>
</p>

![Widget Preview](screenshots/main.png)

## Features

- Single-stock and multi-stock display modes.
- Multiple chart ranges: `1D`, `5D`, `1M`, `6M`, `YTD`, `1Y`, `5Y`, `Max`.
- Multiple chart types: `Candlestick (Vela)`, `Line`, and `Area`.
- Custom positive/negative colors.
- Optional hide/show percentage change in panel view.
- Widget background transparency control.
- Optional active-hours update window (battery/network friendly).
- Dashed previous-close reference line in detailed view.

## Configuration

Right-click the widget and open **Configure...**.

- `Display Mode`: single ticker or multi-ticker list.
- `Single Ticker`: one symbol (example: `AAPL`).
- `Ticker List`: comma-separated symbols (example: `AAPL, TSLA, BTC-USD`).
- `Data Range`: history window for chart data.
- `Chart Type`: candlestick, line, or area.
- `Refresh Interval`: update frequency in minutes.
- `Widget Transparency (%)`: background transparency from `0` (opaque) to `100` (fully transparent).
- `Only update during market hours`: restrict updates to a custom time window.
- `Positive/Negative Color (Hex)`: custom gain/loss colors.
- `Stock Change Percentage`: toggle visibility in panel mode.

![Config 1](screenshots/config1.png)
![Config 2](screenshots/config2.png)

## How to Find Symbols

This widget uses Yahoo Finance symbols.

1. Open [finance.yahoo.com](https://finance.yahoo.com).
2. Search for the asset.
3. Copy the exact symbol.

Examples:

- US Stocks: `AAPL`, `TSLA`, `MSFT`
- Crypto: `BTC-USD`, `ETH-USD`
- Indices: `^GSPC`, `^IXIC`
- FX: `EURUSD=X`, `USDJPY=X`

## Install

### KDE Store

1. Right-click desktop or panel and choose **Add Widgets**.
2. Click **Get New Widgets**.
3. Search for **Stock Monitor** and install.
