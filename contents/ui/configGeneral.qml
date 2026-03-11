import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami

Item {
    id: configPage

    property alias cfg_ticker: tickerField.text
    property alias cfg_refreshInterval: intervalSpin.value
    property alias cfg_isMultiMode: modeSwitch.checked
    property alias cfg_multiTickers: multiListField.text

    // Aliases for new settings
    property alias cfg_limitHours: limitHoursSwitch.checked
    property alias cfg_startHour: startHourSpin.value
    property alias cfg_startMinute: startMinuteSpin.value
    property alias cfg_endHour: endHourSpin.value
    property alias cfg_endMinute: endMinuteSpin.value
    property alias cfg_positiveColor: posColorButton.text
    property alias cfg_negativeColor: negColorButton.text
    property alias cfg_hideChangePercentage: hidePercentSwitch.checked
    property alias cfg_widgetTransparency: widgetOpacitySpin.value

    property string cfg_chartRange
    property string cfg_chartType

    function rangeSupportsCandlestick(rangeValue) {
        return rangeValue === "15D" || rangeValue === "30D";
    }

    function enforceChartTypeForRange() {
        if (cfg_chartType === "candlestick" && !rangeSupportsCandlestick(cfg_chartRange)) {
            cfg_chartType = "line";
        }
    }

    onCfg_chartRangeChanged: {
        var idx = rangeCombo.indexOfValue(cfg_chartRange)
        if (idx >= 0) rangeCombo.currentIndex = idx
        enforceChartTypeForRange()
    }

    onCfg_chartTypeChanged: {
        if (cfg_chartType === "line") {
            chartTypeCombo.currentIndex = 1
        } else if (cfg_chartType === "area") {
            chartTypeCombo.currentIndex = 2
        } else {
            chartTypeCombo.currentIndex = 0
        }
    }

    function searchSymbols(query) {
        if (query.length < 2) {
            searchHelpText.text = "Type at least 2 characters...";
            return;
        }
        var xhr = new XMLHttpRequest();
        // Use query2 for search
        var url = "https://query2.finance.yahoo.com/v1/finance/search?q=" + encodeURIComponent(query);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                try {
                    var res = JSON.parse(xhr.responseText);
                    var results = res.quotes || [];
                    if (results.length === 0) {
                        searchHelpText.text = "No symbols found.";
                        return;
                    }
                    var displayStr = "Suggestions (Symbol - Name):\n";
                    for (var i = 0; i < Math.min(results.length, 5); i++) {
                        displayStr += "• " + results[i].symbol + " - " + (results[i].shortname || results[i].longname || "") + "\n";
                    }
                    searchHelpText.text = displayStr;
                } catch (e) { searchHelpText.text = "Error searching."; }
            }
        }
        xhr.open("GET", url);
        xhr.send();
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 20

        CheckBox {
            id: modeSwitch
            Kirigami.FormData.label: "Display Mode:"
            text: "Show Multi-Stock List"
        }

        TextField {
            id: tickerField
            visible: !modeSwitch.checked
            Kirigami.FormData.label: "Single Ticker:"
            placeholderText: "e.g., AAPL"
        }

        TextArea {
            id: multiListField
            visible: modeSwitch.checked
            Kirigami.FormData.label: "Ticker List:"
            placeholderText: "AAPL, TSLA"
            Layout.fillWidth: true
            Layout.minimumHeight: 60
        }

        ComboBox {
            id: rangeCombo
            Kirigami.FormData.label: "Data Range:"
            model: ["1D", "5D", "15D", "30D", "1M", "6M", "YTD", "1Y", "5Y", "Max"]
            onActivated: {
                configPage.cfg_chartRange = currentText
                configPage.enforceChartTypeForRange()
            }
            Component.onCompleted: {
                var idx = indexOfValue(configPage.cfg_chartRange)
                if (idx >= 0) currentIndex = idx
                configPage.enforceChartTypeForRange()
            }
        }

        ComboBox {
            id: chartTypeCombo
            Kirigami.FormData.label: "Chart Type:"
            model: ["Candlestick (Vela)", "Line", "Area"]
            onActivated: {
                if (currentIndex === 1) {
                    configPage.cfg_chartType = "line"
                } else if (currentIndex === 2) {
                    configPage.cfg_chartType = "area"
                } else {
                    configPage.cfg_chartType = configPage.rangeSupportsCandlestick(configPage.cfg_chartRange) ? "candlestick" : "line"
                }
            }
            Component.onCompleted: {
                if (configPage.cfg_chartType === "line") {
                    currentIndex = 1
                } else if (configPage.cfg_chartType === "area") {
                    currentIndex = 2
                } else {
                    currentIndex = 0
                }
            }
        }

        SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: "Refresh Interval (minutes):"
            from: 1
            to: 360
        }

        SpinBox {
            id: widgetOpacitySpin
            Kirigami.FormData.label: "Widget Transparency (%):"
            from: 0
            to: 100
        }

        CheckBox {
            id: limitHoursSwitch
            Kirigami.FormData.label: "Active Hours:"
            text: "Only update during market hours"
        }

        RowLayout {
            visible: limitHoursSwitch.checked
            Kirigami.FormData.label: "Market Open:"
            SpinBox { id: startHourSpin; from: 0; to: 23; }
            Label { text: ":" }
            SpinBox { id: startMinuteSpin; from: 0; to: 59; }
        }

        RowLayout {
            visible: limitHoursSwitch.checked
            Kirigami.FormData.label: "Market Close:"
            SpinBox { id: endHourSpin; from: 0; to: 23; }
            Label { text: ":" }
            SpinBox { id: endMinuteSpin; from: 0; to: 59; }
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Panel View"
        }

        CheckBox {
            id: hidePercentSwitch
            Kirigami.FormData.label: "Stock Change Percentage:"
            text: "Toggle Visibility"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Colors"
        }

        TextField {
            id: posColorButton
            Kirigami.FormData.label: "Positive Color (Hex):"
            placeholderText: "#00ff00"
        }

        TextField {
            id: negColorButton
            Kirigami.FormData.label: "Negative Color (Hex):"
            placeholderText: "#ff3b30"
        }

        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Symbol Search Helper"
        }

        TextField {
            id: searchField
            Kirigami.FormData.label: "Quick Search:"
            placeholderText: "e.g. Tesla, THY, NVIDIA..."
            onTextChanged: searchTimer.restart()
        }

        Label {
            id: searchHelpText
            text: "Type to find symbols..."
            font.pixelSize: 11
            color: Kirigami.Theme.neutralTextColor
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
        }

        Timer {
            id: searchTimer
            interval: 800
            repeat: false
            onTriggered: configPage.searchSymbols(searchField.text)
        }
    }
}
