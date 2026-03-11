import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // --- CONFIGURATION ---
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    // Detect where we are (Panel vs Desktop) to switch views
    preferredRepresentation: (Plasmoid.formFactor === PlasmaCore.Types.Horizontal || Plasmoid.formFactor === PlasmaCore.Types.Vertical)
    ? Plasmoid.CompactRepresentation
    : Plasmoid.FullRepresentation






    property string singleTicker: Plasmoid.configuration.ticker
    property bool isMultiMode: Plasmoid.configuration.isMultiMode
    property string multiTickers: Plasmoid.configuration.multiTickers
    property string chartRange: Plasmoid.configuration.chartRange
    property string chartType: Plasmoid.configuration.chartType || "candlestick"

    // Time Limits Config
    property bool limitHours: Plasmoid.configuration.limitHours
    property int startHour: Plasmoid.configuration.startHour
    property int startMinute: Plasmoid.configuration.startMinute
    property int endHour: Plasmoid.configuration.endHour
    property int endMinute: Plasmoid.configuration.endMinute

    // Internal Properties for Single View
    property string singleCompanyName: "Loading..."
    property string currentPrice: "---"
    property double currentRawPrice: 0.0
    property string priceChange: "+0.00"
    property string percentChange: "+0.00%"
    property var chartDataPoints: []
    property double previousClose: 0.0
    property bool isPositive: true
    property string currencySym: ""

    property color positiveColor: Plasmoid.configuration.positiveColor
    property color negativeColor: Plasmoid.configuration.negativeColor
    property bool hideChangePercentage: Plasmoid.configuration.hideChangePercentage
    property string lastUpdated: ""
    property string nextUpdate: ""
    property color bgColor: "#1a1a1a"
    property int widgetTransparency: Plasmoid.configuration.widgetTransparency
    property bool chartHoverActive: false
    property int chartHoverIndex: -1
    property real chartHoverX: 0
    property string chartHoverText: ""

    ListModel { id: stockModel }

    function getCurrencySymbol(code) {
        // Fix: Return empty string if code is missing or literal "null"
        if (!code || code === "null") return "";

        const symbols = {
            "USD": "$", "EUR": "€", "GBP": "£", "INR": "₹", "JPY": "¥",
            "CNY": "¥", "KRW": "₩", "RUB": "₽", "TRY": "₺"
        };
        return symbols[code] || code + " ";
    }

    function isCandlestickRange() {
        return root.chartRange === "15D" || root.chartRange === "30D";
    }

    function getDailyPointLimit() {
        if (root.chartRange === "15D") return 15;
        if (root.chartRange === "30D") return 30;
        return 0;
    }

    function formatHoverValue(value) {
        if (value === undefined || value === null || isNaN(value)) return "--";
        return root.currencySym + Number(value).toFixed(2);
    }

    function formatHoverTimestamp(ts) {
        if (!ts) return "";
        var d = new Date(ts * 1000);
        if (root.chartRange === "1D" || root.chartRange === "5D" || root.chartRange === "1M") {
            return Qt.formatDateTime(d, "dd/MM HH:mm");
        }
        return Qt.formatDate(d, "dd/MM/yyyy");
    }

    function clearChartHover() {
        root.chartHoverActive = false;
        root.chartHoverIndex = -1;
        root.chartHoverText = "";
    }

    function updateChartHover(mouseX, chartWidth) {
        if (!root.chartDataPoints || root.chartDataPoints.length < 1 || chartWidth <= 0) {
            clearChartHover();
            return;
        }

        var len = root.chartDataPoints.length;
        var isCandle = root.chartType === "candlestick" && root.isCandlestickRange();
        var idx = 0;

        if (isCandle) {
            var candleStep = chartWidth / len;
            idx = Math.floor(mouseX / candleStep);
        } else {
            var stepX = (len > 1) ? chartWidth / (len - 1) : chartWidth;
            idx = Math.round(mouseX / stepX);
        }

        idx = Math.max(0, Math.min(len - 1, idx));
        var p = root.chartDataPoints[idx];
        var ts = formatHoverTimestamp(p.timestamp);

        root.chartHoverIndex = idx;
        root.chartHoverX = Math.max(0, Math.min(chartWidth, mouseX));
        if (isCandle) {
            root.chartHoverText = (ts ? ts + "\n" : "")
                + "O: " + formatHoverValue(p.open)
                + "  H: " + formatHoverValue(p.high)
                + "  L: " + formatHoverValue(p.low)
                + "  C: " + formatHoverValue(p.close);
        } else {
            root.chartHoverText = (ts ? ts + "\n" : "") + "Close: " + formatHoverValue(p.close);
        }
        root.chartHoverActive = true;
    }

    // --- NEW HELPER: GET API PARAMETERS BASED ON CONFIG ---
    function getApiParams() {
        // Yahoo Finance requires specific intervals for specific ranges
        // to return valid data and look good.
        switch (root.chartRange) {
            case "1D":  return "range=2d&interval=2m"; // Use 2d to get reliable previous close for indices
            case "5D":  return "range=5d&interval=15m";
            case "15D": return "range=1mo&interval=1d";
            case "30D": return "range=3mo&interval=1d";
            case "1M":  return "range=1mo&interval=60m"; // '1mo' is Yahoo syntax
            case "6M":  return "range=6mo&interval=1d";
            case "YTD": return "range=ytd&interval=1d";
            case "1Y":  return "range=1y&interval=1d";
            case "5Y":  return "range=5y&interval=1wk";
            case "Max": return "range=max&interval=1mo";
            default:    return "range=1d&interval=2m";
        }
    }

    function refreshData() {
        if (root.isMultiMode) {
            fetchMultiStocks();
        } else {
            fetchSingleStock(root.singleTicker);
        }
    }

    // --- NEW CHECK: IS MARKET OPEN? ---
    function checkTimeAndRefresh() {
        // 1. Always check weekend first (optional, but saves battery)
        var d = new Date();
        var day = d.getDay();
        // 0=Sun, 6=Sat. Crypto (BTC) runs 24/7, so you might want to skip this check for crypto.
        // Assuming stocks for now:
        if (day === 0 || day === 6) {
            // Optional: Allow update if ticker contains "-USD" (crypto)?
            // For now, let's strictly follow the rule:
            // return;
        }

        // 2. Check Time Window if enabled
        if (root.limitHours) {
            var nowHour = d.getHours();
            var nowMin = d.getMinutes();
            var currentTimeVal = nowHour * 60 + nowMin;

            var startTimeVal = root.startHour * 60 + root.startMinute;
            var endTimeVal = root.endHour * 60 + root.endMinute;

            // If we are BEFORE start OR AFTER end, stop.
            if (currentTimeVal < startTimeVal || currentTimeVal >= endTimeVal) {
                return; // Do not fetch
            }
        }

        // 3. If passed, refresh
        refreshData();
    }

    function fetchSingleStock(symbol) {
        var xhr = new XMLHttpRequest();
        var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + symbol + "?" + getApiParams();
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                var response = JSON.parse(xhr.responseText);
                processSingleData(response);
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    function fetchMultiStocks() {
        var tickers = root.multiTickers.split(",");
        tickers.forEach(function(tickerSymbol) {
            var cleanSymbol = tickerSymbol.trim();
            if(cleanSymbol === "") return;

            var xhr = new XMLHttpRequest();
            var url = "https://query1.finance.yahoo.com/v8/finance/chart/" + cleanSymbol + "?" + getApiParams();
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    var response = JSON.parse(xhr.responseText);
                    processListRow(cleanSymbol, response);
                }
            }
            xhr.open("GET", url);
            xhr.send();
        });
    }

    function processSingleData(json) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            var quoteData = result.indicators.quote[0];
            var opens = quoteData.open || [];
            var highs = quoteData.high || [];
            var lows = quoteData.low || [];
            var closes = quoteData.close || [];
            var timestamps = result.timestamp;

            root.singleCompanyName = meta.shortName || meta.longName || root.singleTicker;
            // For indices with 2d range, chartPreviousClose is the correct baseline (yesterday's close)
            // regularMarketPreviousClose and previousClose can be unreliable or point to 2 days ago.
            root.previousClose = meta.chartPreviousClose || meta.regularMarketPreviousClose || meta.previousClose;
            
            root.currencySym = getCurrencySymbol(meta.currency);
            root.currentPrice = root.currencySym + meta.regularMarketPrice.toFixed(2);
            root.currentRawPrice = meta.regularMarketPrice;

            var change = meta.regularMarketPrice - root.previousClose;
            root.isPositive = change >= 0;
            root.priceChange = (change > 0 ? "+" : "") + change.toFixed(2);
            root.percentChange = (change > 0 ? "+" : "") + ((change / root.previousClose) * 100).toFixed(2) + "%";

            var cleanData = [];
            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            
            for (var i = 0; i < closes.length; i++) {
                if (opens[i] !== null && highs[i] !== null && lows[i] !== null && closes[i] !== null) {
                    // Only show today's data if in 1D mode (2d range used for baseline)
                    if (root.chartRange === "1D" && startTime > 0) {
                        if (timestamps[i] >= startTime) {
                            cleanData.push({ "open": opens[i], "high": highs[i], "low": lows[i], "close": closes[i], "timestamp": timestamps[i] });
                        }
                    } else {
                        cleanData.push({ "open": opens[i], "high": highs[i], "low": lows[i], "close": closes[i], "timestamp": timestamps[i] });
                    }
                }
            }
            var dailyLimit = getDailyPointLimit();
            if (dailyLimit > 0 && cleanData.length > dailyLimit) {
                cleanData = cleanData.slice(cleanData.length - dailyLimit);
            }
            root.chartDataPoints = cleanData;
            var now = new Date();
            root.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (Plasmoid.configuration.refreshInterval * 60000));
            root.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");
        } catch (e) { console.log("Error parsing single: " + e); }
    }

    function processListRow(symbol, json) {
        try {
            var result = json.chart.result[0];
            var meta = result.meta;
            var quoteData = result.indicators.quote[0];
            var opens = quoteData.open || [];
            var highs = quoteData.high || [];
            var lows = quoteData.low || [];
            var closes = quoteData.close || [];
            var timestamps = result.timestamp;

            var current = meta.regularMarketPrice;
            var prev = meta.chartPreviousClose || meta.regularMarketPreviousClose || meta.previousClose;
            
            var change = current - prev;
            var pct = (change / prev) * 100;
            var curSym = getCurrencySymbol(meta.currency);

            var cleanData = [];
            var startTime = (meta.currentTradingPeriod && meta.currentTradingPeriod.regular) ? meta.currentTradingPeriod.regular.start : 0;
            
            for (var i = 0; i < closes.length; i++) {
                if (opens[i] !== null && highs[i] !== null && lows[i] !== null && closes[i] !== null) {
                    if (root.chartRange === "1D" && startTime > 0) {
                        if (timestamps[i] >= startTime) {
                            cleanData.push({ "open": opens[i], "high": highs[i], "low": lows[i], "close": closes[i], "timestamp": timestamps[i] });
                        }
                    } else {
                        cleanData.push({ "open": opens[i], "high": highs[i], "low": lows[i], "close": closes[i], "timestamp": timestamps[i] });
                    }
                }
            }
            var dailyLimit = getDailyPointLimit();
            if (dailyLimit > 0 && cleanData.length > dailyLimit) {
                cleanData = cleanData.slice(cleanData.length - dailyLimit);
            }

            var itemData = {
                "ticker": symbol,
                "name": meta.shortName || meta.longName || symbol,
                "price": curSym + current.toFixed(2),
                "change": (change > 0 ? "+" : "") + change.toFixed(2),
                "pct": (change > 0 ? "+" : "") + pct.toFixed(2) + "%",
                "isPos": change >= 0,
                "chartPoints": cleanData,
                "prevClose": prev
            };

            var found = false;
            for(var k=0; k<stockModel.count; k++) {
                if(stockModel.get(k).ticker === symbol) {
                    stockModel.set(k, itemData);
                    found = true;
                    break;
                }
            }
            if(!found) stockModel.append(itemData);

            var now = new Date();
            root.lastUpdated = now.toLocaleTimeString(Qt.locale(), "HH:mm");
            var next = new Date(now.getTime() + (Plasmoid.configuration.refreshInterval * 60000));
            root.nextUpdate = next.toLocaleTimeString(Qt.locale(), "HH:mm");

        } catch (e) { console.log("Error parsing multi: " + e); }
    }

    // Force commas manually (e.g. 1234567 -> "1,234,567")
    function formatWithCommas(amount) {
        // Round to integer first, then add commas
        return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    onSingleTickerChanged: refreshData()
    onIsMultiModeChanged: { stockModel.clear(); refreshData(); }
    onMultiTickersChanged: { stockModel.clear(); refreshData(); }
    // CHANGED: Update when range changes
    onChartRangeChanged: { stockModel.clear(); refreshData(); }
    onChartTypeChanged: clearChartHover()
    onChartDataPointsChanged: clearChartHover()

    // --- CUSTOM TOOLTIP ---
    // Tooltip removed due to compatibility issues across some Plasma 6 versions

    Timer {
        interval: Plasmoid.configuration.refreshInterval * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        // CHANGED: Call checkTimeAndRefresh instead of refreshData directly
        onTriggered: root.checkTimeAndRefresh()
    }

    // --- PANEL VIEW (Compact Representation) ---
    compactRepresentation: MouseArea {
        id: compactRoot
        implicitWidth: panelRow.implicitWidth + (Kirigami.Units.smallSpacing * 4)
        implicitHeight: panelRow.implicitHeight
        width: implicitWidth
        height: implicitHeight
        
        // Essential for Plasma to allocate space and prevent overlap
        Layout.minimumWidth: implicitWidth
        Layout.preferredWidth: implicitWidth
        
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        onClicked: (mouse) => {
            if (mouse.button === Qt.MiddleButton) {
                // Visual feedback: brief flicker
                if (priceText) priceText.opacity = 0.3;
                root.refreshData();
                timerFlicker.restart();
            } else {
                root.expanded = !root.expanded;
            }
        }

        Timer {
            id: timerFlicker
            interval: 300
            onTriggered: if (priceText) priceText.opacity = 1.0;
        }

        RowLayout {
            id: panelRow
            anchors.centerIn: parent
            spacing: 8
            
            ColumnLayout {
                spacing: -2
                Layout.alignment: Qt.AlignVCenter

                RowLayout {
                    spacing: 4
                    Text {
                        text: root.singleTicker.toUpperCase() + " (" + root.chartRange + ")"
                        color: PlasmaCore.Theme.textColor
                        font.pixelSize: 9
                        font.weight: Font.Bold
                        opacity: 0.6
                        Layout.alignment: Qt.AlignBottom
                    }
                    Text {
                        text: root.isPositive ? "▲" : "▼"
                        color: root.isPositive ? root.positiveColor : root.negativeColor
                        font.pixelSize: 8
                        font.weight: Font.Bold
                    }
                }

                RowLayout {
                    spacing: 6
                    Layout.alignment: Qt.AlignLeft
                    
                    Text {
                        text: root.currencySym + formatWithCommas(root.currentRawPrice)
                        color: root.isPositive ? root.positiveColor : root.negativeColor
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        // Ensure the price text is fully opaque; color is controlled by the line above
                        opacity: 1.0
                    }

                    Rectangle {
                        radius: 4
                        // Vertical Panel Support: Hide badge in vertical panels to avoid overlap
                        visible: Plasmoid.formFactor !== PlasmaCore.Types.Vertical && !root.hideChangePercentage
                        // Background: translucent tint of the positive/negative color for theme independence
                        color: root.isPositive
                               ? Qt.rgba(root.positiveColor.r, root.positiveColor.g, root.positiveColor.b, 0.18)
                               : Qt.rgba(root.negativeColor.r, root.negativeColor.g, root.negativeColor.b, 0.18)
                        border.color: root.isPositive ? root.positiveColor : root.negativeColor
                        border.width: 1
                        Layout.preferredWidth: pctText2.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                        Layout.preferredHeight: pctText2.implicitHeight + (Kirigami.Units.smallSpacing / 2)
                        
                        Text {
                            id: pctText2
                            anchors.centerIn: parent
                            text: root.percentChange
                            color: root.isPositive ? root.positiveColor : root.negativeColor
                            font.pixelSize: 10
                            font.weight: Font.Black
                        }
                    }
                }
            }
        }
    }

    // --- DESKTOP VIEW (Full Representation) ---

    fullRepresentation: Item {
        Layout.minimumWidth: 190
        Layout.minimumHeight: 170
        // Layout.preferredWidth: 260
        // Layout.preferredHeight: 300

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(
                root.bgColor.r,
                root.bgColor.g,
                root.bgColor.b,
                1 - (Math.max(0, Math.min(root.widgetTransparency, 100)) / 100.0)
            )
            anchors.margins: 10
            radius: 22

            Text {
                anchors.centerIn: parent
                text: "Loading..."
                color: "#888888"
                font.pixelSize: 14
                visible: root.isMultiMode && stockModel.count === 0
            }

            Item {
                id: singleView
                visible: !root.isMultiMode
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.topMargin: 16
                anchors.bottomMargin: 10

                MouseArea {
                    anchors.fill: parent
                    z: 100 // Ensure it's on top of everything
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    onClicked: (mouse) => {
                        if (mouse.button === Qt.MiddleButton) {
                            if (priceText) priceText.opacity = 0.3;
                            root.refreshData();
                            timerFullFlicker.restart();
                        } else {
                            console.log("Opening URL: " + root.singleTicker);
                            Qt.openUrlExternally("https://finance.yahoo.com/quote/" + root.singleTicker);
                        }
                    }

                    Timer {
                        id: timerFullFlicker
                        interval: 300
                        onTriggered: if (priceText) priceText.opacity = 1.0;
                    }
                }

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        ColumnLayout {
                            spacing: 2
                            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
                            RowLayout {
                                spacing: 5
                                Text {
                                    text: root.isPositive ? "▲" : "▼"
                                    color: root.isPositive ? root.positiveColor : root.negativeColor
                                    font.pixelSize: 12
                                    Layout.alignment: Qt.AlignVCenter
                                }
                                Text {
                                    text: root.singleTicker + " (" + root.chartRange + ")"
                                    color: "white"
                                    font.bold: true
                                    font.pixelSize: 15
                                    font.family: "Arial"
                                    Layout.alignment: Qt.AlignVCenter
                                    elide: Text.ElideRight
                                    Layout.fillWidth: true
                                }
                            }
                            Text {
                                text: root.singleCompanyName
                                color: "#888888"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                            Text {
                                text: (lastUpdated && nextUpdate) ? "Updated: " + lastUpdated + " • Next: " + nextUpdate : ""
                                color: "#666666" // Slightly brighter
                                font.pixelSize: 9
                                visible: lastUpdated !== "" && !root.isMultiMode
                            }
                        }
                        Item { Layout.fillWidth: true }
                        ColumnLayout {
                            spacing: 0
                            Layout.alignment: Qt.AlignRight | Qt.AlignTop
                            Text {
                                text: root.percentChange
                                color: root.isPositive ? root.positiveColor : root.negativeColor
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignRight
                                font.bold: true
                            }
                            Text {
                                text: root.priceChange
                                color: root.isPositive ? root.positiveColor : root.negativeColor
                                font.pixelSize: 13
                                Layout.alignment: Qt.AlignRight
                                font.bold: true
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.topMargin: 10
                        Layout.bottomMargin: 5
                        Canvas {
                            id: singleCanvas
                            anchors.fill: parent
                            renderStrategy: Canvas.Threaded
                            renderTarget: Canvas.Image
                            onPaint: { drawChart(getContext("2d"), width, height, root.chartDataPoints, root.previousClose, root.isPositive, true); }
                            Connections {
                                target: root
                                function onChartDataPointsChanged() { singleCanvas.requestPaint(); }
                                function onChartTypeChanged() { singleCanvas.requestPaint(); }
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            z: 220
                            acceptedButtons: Qt.NoButton
                            hoverEnabled: true
                            onPositionChanged: (mouse) => root.updateChartHover(mouse.x, width)
                            onEntered: (mouse) => root.updateChartHover(mouse.x, width)
                            onExited: root.clearChartHover()
                        }
                        Rectangle {
                            visible: root.chartHoverActive
                            z: 221
                            x: Math.max(0, Math.min(parent.width - width, root.chartHoverX - (width / 2)))
                            y: 4
                            radius: 6
                            color: "#1f1f1f"
                            border.color: "#4a4a4a"
                            border.width: 1
                            opacity: 0.96
                            width: hoverText.implicitWidth + 12
                            height: hoverText.implicitHeight + 8

                            Text {
                                id: hoverText
                                anchors.centerIn: parent
                                text: root.chartHoverText
                                color: "#f0f0f0"
                                font.pixelSize: 10
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }
                    }
                    Text {
                        id: priceText
                        Layout.alignment: Qt.AlignHCenter
                        text: root.currentPrice
                        color: "white"
                        font.pixelSize: 26
                        font.weight: Font.bold

                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                }
            }

            ListView {
                id: multiView
                visible: root.isMultiMode
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                anchors.bottomMargin: 16
                anchors.topMargin: 0

                clip: true
                model: stockModel
                spacing: 0

                delegate: Item {
                    width: multiView.width
                    height: 60

                    MouseArea {
                        anchors.fill: parent
                        z: 100 // Above the row layout
                        cursorShape: Qt.PointingHandCursor
                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.MiddleButton) {
                                parent.opacity = 0.4;
                                root.refreshData();
                                timerListFlicker.restart();
                            } else {
                                console.log("Opening URL: " + model.ticker);
                                Qt.openUrlExternally("https://finance.yahoo.com/quote/" + model.ticker);
                            }
                        }
                        Timer {
                            id: timerListFlicker
                            interval: 300
                            onTriggered: parent.opacity = 1.0;
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        spacing: 10
                        ColumnLayout {
                            Layout.preferredWidth: parent.width * 0.35
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2
                            RowLayout {
                                spacing: 4
                                Text {
                                    text: model.isPos ? "▲" : "▼"
                                    color: model.isPos ? root.positiveColor : root.negativeColor
                                    font.pixelSize: 10
                                }
                                Text {
                                    text: model.ticker + " (" + root.chartRange + ")"
                                    color: "white"
                                    // font.bold: true
                                    font.pixelSize: 14
                                }
                            }
                            Text {
                                text: model.name
                                color: "#888888"
                                font.pixelSize: 10
                                elide: Text.ElideRight
                                Layout.fillWidth: true
                            }
                        }
                        Item {
                            visible: parent.width > 220
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Canvas {
                                id: sparkLine
                                anchors.fill: parent
                                renderStrategy: Canvas.Threaded
                                renderTarget: Canvas.Image
                                onPaint: { drawChart(getContext("2d"), width, height, model.chartPoints, model.prevClose, model.isPos, false); }
                                Component.onCompleted: sparkLine.requestPaint()
                                Connections {
                                    target: root
                                    function onChartTypeChanged() { sparkLine.requestPaint(); }
                                }
                                Connections {
                                    target: stockModel
                                    function onDataChanged() { sparkLine.requestPaint() }
                                }
                            }
                        }
                        ColumnLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: 2
                            Text {
                                text: model.price
                                color: "white"
                                // font.bold: true
                                font.pixelSize: 14
                                Layout.alignment: Qt.AlignRight
                            }
                            Rectangle {
                                radius: 4
                                // Background: translucent tint of the color for theme independence
                                color: model.isPos
                                       ? Qt.rgba(root.positiveColor.r, root.positiveColor.g, root.positiveColor.b, 0.15)
                                       : Qt.rgba(root.negativeColor.r, root.negativeColor.g, root.negativeColor.b, 0.15)
                                border.color: model.isPos ? root.positiveColor : root.negativeColor
                                border.width: 1
                                Layout.preferredWidth: pctTextL.implicitWidth + (Kirigami.Units.smallSpacing * 2)
                                Layout.preferredHeight: pctTextL.implicitHeight + (Kirigami.Units.smallSpacing / 2)
                                Layout.alignment: Qt.AlignRight

                                Text {
                                    id: pctTextL
                                    anchors.centerIn: parent
                                    text: model.change + " (" + model.pct + ")"
                                    color: model.isPos ? root.positiveColor : root.negativeColor
                                    font.pixelSize: 11
                                    font.weight: Font.Black
                                }
                            }
                        }
                    }
                    Rectangle {
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: "#333333"
                        visible: index < multiView.count - 1
                    }
                }
            }
            Text {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottomMargin: 8
                text: (lastUpdated && nextUpdate) ? "Updated: " + lastUpdated + " • Next: " + nextUpdate : ""
                color: "#777777"
                font.pixelSize: 10
                visible: lastUpdated !== "" && root.isMultiMode
            }
        }
    }

    function drawChart(ctx, w, h, data, prevClose, isPos, drawBackground) {
        ctx.clearRect(0, 0, w, h);
        if (!data || data.length < 2) return;
        var isCandlestick = root.chartType === "candlestick" && root.isCandlestickRange();
        var closes = data.map(function(point) {
            return (typeof point === "number") ? point : point.close;
        });
        var minVal;
        var maxVal;
        if (isCandlestick) {
            minVal = Math.min(...data.map(function(point) {
                return (typeof point === "number") ? point : point.low;
            }));
            maxVal = Math.max(...data.map(function(point) {
                return (typeof point === "number") ? point : point.high;
            }));
        } else {
            minVal = Math.min(...closes);
            maxVal = Math.max(...closes);
        }
        var range = maxVal - minVal;
        if (range === 0) range = 1;
        var padding = range * (drawBackground ? 0.1 : 0.05);
        minVal -= padding;
        maxVal += padding;
        range = maxVal - minVal;
        function getY(val) { return h - ((val - minVal) / range * h); }

        if (drawBackground) {
            var prevY = getY(prevClose);
            ctx.beginPath();
            ctx.strokeStyle = "#333333";
            ctx.lineWidth = 1;
            ctx.setLineDash([4, 4]);
            ctx.moveTo(0, prevY);
            ctx.lineTo(w, prevY);
            ctx.stroke();
            ctx.setLineDash([]);
        }

        if (isCandlestick) {
            var candleStep = w / data.length;
            var candleWidth = Math.max(2, candleStep * 0.6);
            for (var j = 0; j < data.length; j++) {
                var point = data[j];
                var open = (typeof point === "number") ? point : point.open;
                var high = (typeof point === "number") ? point : point.high;
                var low = (typeof point === "number") ? point : point.low;
                var close = (typeof point === "number") ? point : point.close;
                var x = j * candleStep + (candleStep / 2);
                var yOpen = getY(open);
                var yClose = getY(close);
                var yHigh = getY(high);
                var yLow = getY(low);
                var up = close >= open;
                var candleColor = up ? root.positiveColor : root.negativeColor;

                ctx.beginPath();
                ctx.strokeStyle = candleColor;
                ctx.lineWidth = 1;
                ctx.moveTo(x, yHigh);
                ctx.lineTo(x, yLow);
                ctx.stroke();

                var bodyTop = Math.min(yOpen, yClose);
                var bodyHeight = Math.max(1, Math.abs(yClose - yOpen));
                ctx.fillStyle = candleColor;
                ctx.fillRect(x - (candleWidth / 2), bodyTop, candleWidth, bodyHeight);
            }
        } else {
            ctx.beginPath();
            var stepX = w / (closes.length - 1);
            ctx.moveTo(0, getY(closes[0]));
            for (var i = 1; i < closes.length; i++) {
                ctx.lineTo(i * stepX, getY(closes[i]));
            }

            ctx.lineJoin = "round";
            ctx.lineWidth = 2;
            ctx.strokeStyle = isPos ? root.positiveColor : root.negativeColor;
            ctx.stroke();

            if (drawBackground && root.chartType === "area") {
                ctx.lineTo(w, h);
                ctx.lineTo(0, h);
                ctx.closePath();
                var gradient = ctx.createLinearGradient(0, 0, 0, h);
                var baseColor = isPos ? root.positiveColor : root.negativeColor;
                gradient.addColorStop(0.0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.3));
                gradient.addColorStop(1.0, Qt.rgba(baseColor.r, baseColor.g, baseColor.b, 0.0));
                ctx.fillStyle = gradient;
                ctx.fill();
            }
        }
    }
}
