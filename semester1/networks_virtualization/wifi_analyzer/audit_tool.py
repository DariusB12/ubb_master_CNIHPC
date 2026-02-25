import time
import socket
import threading
import os
from collections import defaultdict, deque
import psutil
from scapy.all import sniff, IP, TCP, UDP
import matplotlib.pyplot as plt
from geoip2.database import Reader

# ===================== CONFIGURARE =====================
INTERFACE = "wlp0s20f3"
GEOIP_DB = "GeoLite2-City.mmdb" # mmdb = MaxMind DB A DATABASE OPTIMISED FOR QUICK SEARCHES - USES BINARY TREES
# geoip2.database.Reader SEARCHES IN THE mmdb DATABASED BASED ON THE INF I GIVE IT (ON THE IP ADDRESS)
conn_lock = threading.Lock()

# ===================== STARE GLOBALĂ =====================
connections = defaultdict(lambda: {
    "bytes": 0,
    "history": deque([0] * 60, maxlen=60),
    "process": "Unknown",
    "dns": "Resolving...",
    "service": "Unknown",
    "geo": "Unknown",
    "last_seen": 0
})

try:
    geo_reader = Reader(GEOIP_DB)
except:
    geo_reader = None

PORT_SERVICES = {80: "HTTP", 443: "HTTPS", 22: "SSH", 21: "FTP", 53: "DNS", 3389: "RDP"}


# ===================== UTILS =====================

def get_process_map():
    proc_map = {}
    try:
        for p in psutil.process_iter(['name']):
            try:
                for c in p.connections(kind='inet'):
                    if c.laddr and c.raddr:
                        key = (c.laddr.ip, c.laddr.port, c.raddr.ip, c.raddr.port)
                        proc_map[key] = p.info['name']
            except (psutil.AccessDenied, psutil.NoSuchProcess):
                continue
    except:
        pass
    return proc_map


def resolve_details(ip, dport, key):
    dns = "N/A"
    try:
        dns = socket.gethostbyname_ex(ip)[0]
    except:
        dns = "No-DNS"

    geo = "N/A"
    if geo_reader:
        try:
            # geoip2.database.Reader SEARCHES IN THE mmdb DATABASED BASED ON THE INF I GIVE IT (ON THE IP ADDRESS)
            r = geo_reader.city(ip)
            geo = f"{r.country.name}, {r.city.name}"
        except:
            geo = "Local/Unknown"

    service = PORT_SERVICES.get(dport, f"Port {dport}")
    with conn_lock:
        connections[key].update({"dns": dns, "geo": geo, "service": service})


# ===================== HANDLERS & WORKERS =====================

def handle_packet(pkt):
    # FOLOSIND LIBRARIA scapy EXTRAG DATELE (LE-AM EXTRAS MANUAL IN WIFY SNIFFER)
    if IP not in pkt: return
    proto = "TCP" if TCP in pkt else "UDP" if UDP in pkt else None
    if not proto: return

    sport, dport = pkt[proto].sport, pkt[proto].dport
    src, dst = pkt[IP].src, pkt[IP].dst
    key = (src, sport, dst, dport)

    with conn_lock:
        conn = connections[key]
        conn["bytes"] += len(pkt)
        conn["last_seen"] = time.time()
        if conn["dns"] == "Resolving...":
            conn["dns"] = "Pending..."
            threading.Thread(target=resolve_details, args=(dst, dport, key), daemon=True).start()


def monitor_worker():
    while True:
        time.sleep(1)
        proc_map = get_process_map()
        with conn_lock:
            for key, data in list(connections.items()):
                data["history"].append(data["bytes"] * 8)
                data["bytes"] = 0
                if key in proc_map: data["process"] = proc_map[key]
                if time.time() - data["last_seen"] > 120: del connections[key]


# ===================== DISPLAY TEXT (NEW) =====================

def print_text_console():
    """Afișează în terminal detaliile text cerute, real-time."""
    while True:
        os.system('clear' if os.name == 'posix' else 'cls')
        print(f"{'CVADRUPUL [Sursă - Destinație]':<50} | {'APLICAȚIE':<15} | {'TRAFIC':<10} | {'DETALII DESTINAȚIE'}")
        print("-" * 120)

        with conn_lock:
            # Afișăm conexiunile care au avut trafic recent
            sorted_conns = sorted(connections.items(), key=lambda x: x[1]["history"][-1], reverse=True)
            for key, data in sorted_conns[:15]:  # Primele 15 cele mai active
                quad = f"{key[0]}:{key[1]} -> {key[2]}:{key[3]}"
                traffic = f"{data['history'][-1]} bps"
                details = f"DNS: {data['dns']} | Svc: {data['service']} | Geo: {data['geo']}"
                print(f"{quad:<50} | {data['process'][:15]:<15} | {traffic:<10} | {details}")

        time.sleep(1)


# ===================== GRAFIC =====================

def run_visualizer():
    plt.style.use('dark_background')
    fig, ax = plt.subplots(figsize=(12, 7))
    plt.subplots_adjust(right=0.65)
    plt.ion()

    while True:
        with conn_lock:
            active_conns = sorted(connections.items(), key=lambda x: x[1]["history"][-1], reverse=True)[:6]

        ax.clear()
        if active_conns:
            for key, data in active_conns:
                label = f"App: {data['process']}\nIP: {key[2]}:{key[3]}\nBPS: {data['history'][-1]}"
                ax.plot(list(data["history"]), label=label)
            ax.legend(loc='center left', bbox_to_anchor=(1, 0.5), fontsize=7)
            ax.set_title("Network Audit Real-Time (bits/second)")
            ax.set_ylabel("Bits per Second")
            ax.grid(True, alpha=0.2)

        plt.pause(1)


if __name__ == "__main__":
    print(f"[*] Inițializare Audit pe: {INTERFACE}...")

    # Thread-uri pentru monitorizare, sniffing și afișare text
    threading.Thread(target=monitor_worker, daemon=True).start()
    threading.Thread(target=print_text_console, daemon=True).start()
    threading.Thread(target=lambda: sniff(iface=INTERFACE, prn=handle_packet, store=False), daemon=True).start()

    try:
        run_visualizer()
    except KeyboardInterrupt:
        print("\n[!] Oprire program.")