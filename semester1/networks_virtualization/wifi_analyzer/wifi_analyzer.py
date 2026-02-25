import csv
import math
import os
import sys
import time
import pywifi
from pywifi import const
from manuf import manuf
from PyQt5.QtGui import QPainterPath
from PyQt5.QtCore import Qt, QThread, pyqtSignal, QTimer, QPoint
from PyQt5.QtGui import QColor, QPainter, QBrush, QPen
from PyQt5.QtWidgets import (
    QApplication, QMainWindow, QTableWidget, QTableWidgetItem,
    QVBoxLayout, QWidget, QLabel, QHBoxLayout
)

# ===========================
# Config
# ===========================
# !!!!!!!!!!!!! scapy ne furnizeaza DIRECT SI CE WIDTH DE LA GRAFICUL DE CANALE, DAR scapy SE POATE FOLOSI DOAR DACA POT PUNE PLACA DE RETEA IN MOD "MONITOR"
# MOTIV PENTUR CARE FOLOSESC PyWifi, care nu imi da si width si atunci ESTIMEZ CA FIECARE CANAL CENTRAL INTERFEREAZA CU MAXIM 2 CANALE DISTANTA

# PRIMESC EROAREA DE MAI JOS PT CA IN ACEL MOMENT MAI FOLOESC SI ALTE PROGRAME INTERFATA DE RETEA => ZICE CA E BUSY
# pywifi 2025-12-15 19:27:19,945 ERROR Unexpected resp 'FAIL-BUSY
# ' for Command 'SCAN'

INTERFACE_NAME = "wlp0s20f3"
# la fiecare 10s se face scanare din nou la retele
REFRESH_MS = 10000

SIGNAL_THRESHOLDS = {
    "high": -50,
    "medium": -70
}
OUI_DB = {}

def load_vendors(filename="vendors.csv"):
    global OUI_DB
    script_dir = os.path.dirname(os.path.abspath(__file__))
    full_path = os.path.join(script_dir, filename)

    if not os.path.exists(full_path):
        print(f"Warning: {full_path} not found. Vendor lookup disabled.")
        return

    try:
        with open(full_path, mode="r", encoding="utf-8", errors="replace") as f:
            reader = csv.reader(f)
            next(reader, None)  # Skip header
            for row in reader:
                if len(row) >= 2:
                    # CSV format: 00:00:0C, Cisco Systems...
                    mac_prefix = row[0].strip().upper()
                    vendor = row[1].strip()
                    OUI_DB[mac_prefix] = vendor
        print(f"Loaded {len(OUI_DB)} vendors from {filename}.")
    except Exception as e:
        print(f"Error loading vendors: {e}")

def get_manufacturer(mac_addr):
    if not mac_addr:
        return "Unknown"
    # mac_addr format expected: xx:xx:xx:xx:xx:xx
    if len(mac_addr) >= 8:
        # Extract first 3 bytes (8 chars: "XX:XX:XX")
        prefix = mac_addr[:8].upper()
        # print(prefix,'\n')
        return OUI_DB.get(prefix, "Unknown")
    return "Unknown"

CHANNELS = range(1, 14)

# ===========================
# Helpers
# ===========================
def signal_color(rssi):
    if rssi >= SIGNAL_THRESHOLDS["high"]:
        return QColor(0, 200, 0)      # verde
    elif rssi >= SIGNAL_THRESHOLDS["medium"]:
        return QColor(240, 200, 0)    # galben
    else:
        return QColor(200, 0, 0)      # rosu

def freq_to_channel(freq):
    if 2412 <= freq <= 2472:
        return int((freq - 2407) / 5) # 2412 - 2407 = 5 => 5/5 = channel 1, freq gap between each channel is 5 MHz
    return None

def get_security(net):
    # AKM comes from Authentication and Key Management
    if not net.akm:
        return "Open"

    types = []
    # WPA = Wi-Fi Protected Access
    for akm in net.akm:
        if akm == const.AKM_TYPE_NONE:
            types.append("Open")  # NO PASSWORD OR ENCRYPTION, ANYBODY CAN CONNECT TO THIS WIFI NETWORK
        elif akm == const.AKM_TYPE_WPAPSK:
            types.append("WPA-PSK") # WPA = wifi Protected Access, PSK = Pre-Shared Key = PAROLA PREDEFINITA, TREBUIE INTRODUSA LA CONECTAREA LA WIFI, TKIP encryption
        elif akm == const.AKM_TYPE_WPA:
            types.append("WPA-Enterprise") # EACH USER HAS A USERNAME AND PASSWORD - USED IN SCHOOLS, CORPORATIONS ETC.
        elif akm == const.AKM_TYPE_WPA2PSK:
            types.append("WPA2-PSK") # WPA2 is the newer version of WPA + AES encryption
        elif akm == const.AKM_TYPE_WPA2:
            types.append("WPA2-Enterprise") # like WPA-Enterprise but uses WPA2 + AES encryption
        else:
            types.append("Unknown")

    return "/".join(types)

def channel_coverage(center):
    # 20 MHz => ±2 canale
    return range(center - 2, center + 3)

# ===========================
# Scan Thread
# ===========================
class WiFiScanner(QThread):
    results_ready = pyqtSignal(list)

    def __init__(self):
        super().__init__()
        self.wifi = pywifi.PyWiFi()
        self.vendor = manuf.MacParser()

        self.iface = None
        for i in self.wifi.interfaces():
            if i.name() == INTERFACE_NAME:
                self.iface = i
                break

        if not self.iface:
            raise RuntimeError("WiFi interface not found")

    def run(self):
        self.iface.scan()
        time.sleep(2)

        nets = []
        for net in self.iface.scan_results():
            ch = freq_to_channel(net.freq)
            if not ch:
                continue

            nets.append({
                "ssid": net.ssid or "Hidden",
                "bssid": net.bssid,
                "signal": net.signal,
                "channel": ch,
                "freq": net.freq,
                "security": get_security(net),
                # "vendor": self.vendor.get_manuf(net.bssid)
                "vendor": get_manufacturer(net.bssid)
            })

        self.results_ready.emit(nets)

# ===========================
# Channel Graph Widget
# ===========================
class ChannelGraph(QWidget):
    def __init__(self):
        super().__init__()
        self.networks = []

    def update_networks(self, nets):
        self.networks = nets
        self.update()

    def rssi_to_y(self, rssi, h, margin):
        rssi = max(-100, min(-30, rssi))
        return margin + (-(rssi + 30) / 70) * (h - 2 * margin)

    def paintEvent(self, event):
        painter = QPainter(self)
        try:
            painter.fillRect(self.rect(), QColor(30, 30, 30))

            w, h = self.width(), self.height()
            margin = 50
            ch_width = (w - 2 * margin) / 13

            # axe
            painter.setPen(QPen(Qt.gray))
            painter.drawLine(margin, margin, margin, h - margin)
            painter.drawLine(margin, h - margin, w - margin, h - margin)

            # axa Y (RSSI)
            for rssi in [-30, -50, -70, -90]:
                y = int(self.rssi_to_y(rssi, h, margin))
                painter.drawLine(margin - 5, y, margin + 5, y)
                painter.drawText(5, y + 5, f"{rssi} dBm")

            # axa X (canale)
            for ch in range(1, 14):
                x = margin + (ch - 1) * ch_width + ch_width / 2
                painter.drawText(int(x - 5), h - 20, str(ch))

            # rețele
            for net in self.networks:
                ch = net["channel"]
                rssi = net["signal"]
                ssid = net["ssid"]
                color = signal_color(rssi)
                color.setAlpha(200)

                y_top = self.rssi_to_y(rssi, h, margin)
                y_bottom = self.rssi_to_y(-90, h, margin)

                x_center = margin + (ch - 1) * ch_width + ch_width / 2
                x_left = margin + (ch - 3) * ch_width + ch_width / 2
                x_right = margin + (ch + 1) * ch_width + ch_width / 2

                # linie stânga (diagonală)
                painter.setPen(QPen(color, 2))
                painter.drawLine(
                    int(x_left), int(y_bottom),
                    int(x_center - ch_width), int(y_top)
                )

                # linie sus (orizontală)
                painter.drawLine(
                    int(x_center - ch_width),
                    int(y_top),
                    int(x_center + ch_width),
                    int(y_top)
                )

                # linie dreapta (diagonală)
                painter.drawLine(
                    int(x_center + ch_width),
                    int(y_top),
                    int(x_right),
                    int(y_bottom)
                )

                # umplere (semi-transparent)
                painter.setPen(Qt.NoPen)
                fill = QColor(color)
                fill.setAlpha(80)
                painter.setBrush(QBrush(fill))

                points = [
                    QPoint(int(x_left), int(y_bottom)),
                    QPoint(int(x_center - ch_width), int(y_top)),
                    QPoint(int(x_center + ch_width), int(y_top)),
                    QPoint(int(x_right), int(y_bottom))
                ]
                painter.drawPolygon(*points)

                # SSID deasupra
                painter.setPen(QPen(color))
                painter.drawText(
                    int(x_center - 30),
                    int(y_top - 8),
                    ssid
                )

        finally:
            painter.end()




# ===========================
# Main Window
# ===========================
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("PyQt WiFi Analyzer")
        self.resize(1200, 700)

        self.table = QTableWidget(0, 8)  # înainte era 6
        self.table.setHorizontalHeaderLabels([
            "", "SSID", "BSSID", "Signal (dBm)", "Channel", "Security", "Vendor", "Frequency (MHz)"
        ])

        self.graph = ChannelGraph()
        self.graph.setMinimumHeight(300)

        layout = QVBoxLayout()
        layout.addWidget(QLabel("Detected WiFi Networks"))
        layout.addWidget(self.table)
        layout.addWidget(QLabel("2.4 GHz Channel Graph"))
        layout.addWidget(self.graph)

        container = QWidget()
        container.setLayout(layout)
        self.setCentralWidget(container)

        self.timer = QTimer()
        self.timer.timeout.connect(self.start_scan)
        self.timer.start(REFRESH_MS)

        self.start_scan()

    def start_scan(self):
        self.thread = WiFiScanner()
        self.thread.results_ready.connect(self.update_ui)
        self.thread.start()

    def update_ui(self, nets):
        self.table.setRowCount(0)
        self.graph.update_networks(nets)

        for net in nets:
            row = self.table.rowCount()
            self.table.insertRow(row)

            # Icon color
            icon_item = QTableWidgetItem("●")
            icon_item.setForeground(QBrush(signal_color(net["signal"])))
            icon_item.setTextAlignment(Qt.AlignCenter)

            self.table.setItem(row, 0, icon_item)
            self.table.setItem(row, 1, QTableWidgetItem(net["ssid"]))
            self.table.setItem(row, 2, QTableWidgetItem(net["bssid"]))
            self.table.setItem(row, 3, QTableWidgetItem(str(net["signal"])))
            self.table.setItem(row, 4, QTableWidgetItem(str(net["channel"])))
            self.table.setItem(row, 5, QTableWidgetItem(net["security"]))
            self.table.setItem(row, 6, QTableWidgetItem(net.get("vendor", "Unknown")))
            self.table.setItem(row, 7, QTableWidgetItem(str(net.get("freq", ""))))


# ===========================
# Run
# ===========================
if __name__ == "__main__":
    load_vendors()
    app = QApplication(sys.argv)
    win = MainWindow()
    win.show()
    sys.exit(app.exec_())
