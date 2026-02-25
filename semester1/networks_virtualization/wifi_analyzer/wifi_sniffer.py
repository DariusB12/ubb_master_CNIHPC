from scapy.all import sniff
import string
import struct

INTERFACE = "wlp0s20f3"


def ascii_payload(data):
    return ''.join(c if c in string.printable else '.' for c in data)


def process_packet(pkt):
    raw = bytes(pkt)
    print("\n" + "=" * 60)

    # ================== ETHERNET ==================
    # Ethernet (14 bytes)
    eth_header = raw[0:14]
    dst_mac = eth_header[0:6]
    src_mac = eth_header[6:12]
    eth_type = int.from_bytes(eth_header[12:14], "big")

    def mac_format(mac):
        return ":".join(f"{b:02x}" for b in mac)

    print("[ETHERNET]")
    print(f"  MAC sursa      : {mac_format(src_mac)}")
    print(f"  MAC destinatie : {mac_format(dst_mac)}")
    print(f"  Tip            : {hex(eth_type)}")

    if eth_type != 0x0800:
        return  # nu e IP

    # ================== IP ==================
    # IP (min 20 bytes)
    ip_start = 14
    ip_header = raw[ip_start:ip_start + 20]

    # PRIMUL BYTE DIN IP SUNT DOUA CAMPURI: VERSION SI IHL (XXXX XXXX)
    version_ihl = ip_header[0]
    ihl = version_ihl & 0x0F  # first_byte & (0000 1111) extragem al doilea camp care e IHL
    # IHL Internet Header Length, expressed in words (1 word = 4 byte)
    ip_header_len = ihl * 4 # *4 because we convert in bytes (1 word = 4 byte), NEED THIS TO KNOW WHERE THE IP ENDS AND THE TCP STARTS

    ttl = ip_header[8]
    proto = ip_header[9]
    src_ip = ip_header[12:16]
    dst_ip = ip_header[16:20]

    def ip_format(ip):
        return ".".join(str(b) for b in ip)

    print("\n[IP]")
    print(f"  IP sursa       : {ip_format(src_ip)}")
    print(f"  IP destinatie  : {ip_format(dst_ip)}")
    print(f"  TTL            : {ttl}")
    print(f"  Protocol       : {proto}")

    # if the protocol is 6 => next is tcp
    if proto != 6:
        return  # nu e TCP

    # ================== TCP ==================
    # TCP (min 20 bytes)
    tcp_start = ip_start + ip_header_len # where the ip ends
    tcp_header = raw[tcp_start:tcp_start + 20]

    src_port = int.from_bytes(tcp_header[0:2], "big")
    dst_port = int.from_bytes(tcp_header[2:4], "big")
    seq = int.from_bytes(tcp_header[4:8], "big")
    ack = int.from_bytes(tcp_header[8:12], "big") # Acknowledgment Number „urmatorul byte pe care il astept este X.”

    # THE 13th BYTE CONTAINS 2 DATA: tcp_header[12] XXXX XXXX (DataOffset = tcp header length, expressed in words |  Resv)
    data_offset = (tcp_header[12] >> 4) & 0x0F # extract only the data offset
    tcp_header_len = data_offset * 4 # * 4 to convert to bytes (1 word = 4 byte), TO KNOW WHERE THE TCP ENDS AND THE HTTP PAYLOAD STARTS

    flags = tcp_header[13]
    window = int.from_bytes(tcp_header[14:16], "big")

    print("\n[TCP]")
    print(f"  Port sursa     : {src_port}")
    print(f"  Port destinatie: {dst_port}")
    print(f"  Seq            : {seq}")
    print(f"  Ack            : {ack}")
    print(f"  Flags          : {bin(flags)}")
    print(f"  Window         : {window}")

    # ================== PAYLOAD ==================
    payload_start = tcp_start + tcp_header_len
    payload = raw[payload_start:]

    # port 80 for http
    if src_port == 80 or dst_port == 80:
        print("\n[HTTP PAYLOAD ASCII]")
        try:
            print(ascii_payload(payload.decode(errors="ignore")))
        except:
            pass


def main():
    print(f"[*] Sniffing pe {INTERFACE}")
    sniff(iface=INTERFACE, prn=process_packet, store=False)


if __name__ == "__main__":
    main()
