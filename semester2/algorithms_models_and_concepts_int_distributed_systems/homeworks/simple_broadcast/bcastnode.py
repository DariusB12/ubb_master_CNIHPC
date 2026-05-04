import hashlib
import os
import socket
import sys
import threading
import time
from enum import Enum
import re

class LogType(Enum):
    OK = "OK"
    FAIL = "FAIL"

def get_cofig_file_data(config_file):
    nodes = []
    no_bcasts = 0
    with open(config_file, 'r') as config_file:
        line = config_file.readline()
        if not line:
            raise Exception("Config file is empty\n")

        no_bcasts = int(line)
        line = config_file.readline()
        while line:
            parts = line.strip().split(" ")
            if len(parts) >= 2:
                nodes.append({"ip":parts[0], "port":int(parts[1])})
            line = config_file.readline()

    return no_bcasts,nodes


def receiver_thread(sock, log_file, error_file, total_expected):
    received_count = 0
    sock.settimeout(5.0)

    while received_count < total_expected:
        try:
            data, addr = sock.recvfrom(1024)
            if len(data) < 1024:
                continue

            # parse the message
            source_node_index = data[0]
            payload = data[0:1004]
            received_sha1 = data[1004:1024].hex()

            # calculate the SHA-1 on the received payload
            calculated_sha1_bytes = hashlib.sha1(payload).digest()
            calculated_sha1_hex = calculated_sha1_bytes.hex()

            status = LogType.OK.value if received_sha1 == calculated_sha1_hex else LogType.FAIL.value

            log_entry = f"{status} {source_node_index} {received_sha1} {calculated_sha1_hex}\n"
            log_file.write(log_entry)
            log_file.flush()

            received_count += 1
        except socket.timeout:
            continue
        except Exception as e:
            error_file.write(f"Receiver error: {str(e)}\n")
            break

def robust_send(sock, message, addr, timeout=5.0):
    start_time = time.time()
    while time.time() - start_time < timeout:
        try:
            # if the network buffer is full, sendto throws an error
            sent = sock.sendto(message, addr)
            # usually in UPD if sent successfully then sent = len(message) otherwise sent = 0
            # it is best practice to check if them are equal instead of using 'if(sent == 0)'
            if sent == len(message):
                return True
        except (BlockingIOError, socket.error):
            # wait a little for the buffer to have more space
            time.sleep(0.001)
    return False

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Wrong number of arguments\n")
        sys.exit(1)

    config_file = sys.argv[1]
    node_index = int(sys.argv[2])

    # CREATE/OPEN THE LOG/ERROR FILES FOR THE CURRENT NODE INDEX
    log_file = open(f'log_file_index{node_index}', 'w')
    error_file = open(f'error_file_index{node_index}', 'w')

    try:
        no_bcasts,nodes = get_cofig_file_data(config_file)
        current_node = nodes[node_index]
        # print("NO BSCASTS: " + str(no_bcasts))
        # for node in nodes:
        #     ip = node["ip"]
        #     port = node["port"]
        #     print("NO IP: " + str(ip))
        #     print("NO PORT: " + str(port))
        #     print("------------------------")

        # AF_INET for IPv4 addresses, SOCK_DGRAM for conection-less protocol (UDP)
        sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        sock.bind((current_node['ip'], current_node['port']))

        total_expected_messages = no_bcasts * len(nodes)

        recv_t = threading.Thread(target=receiver_thread,
                                  args=(sock, log_file, error_file, total_expected_messages))
        recv_t.start()

        # wait 15s before broadcasting
        time.sleep(15)

        # de cate ori zice in config file de atatea ori fac broadcast
        for _ in range(no_bcasts):
            # format:
            #     - Message size should be fixed: 1024 bytes
            #     - Byte 0: should be the sending node index (order number)
            #     - Bytes 1-1003: random values
            #     - Bytes 1004-1023: SHA-1 of bytes 0-1003
            header = bytes([node_index])
            random_payload = os.urandom(1003)
            message = header + random_payload

            sha1_hash = hashlib.sha1(message).digest()
            full_message = message + sha1_hash

            # broadcasting
            for target in nodes:
                success = robust_send(sock, full_message, (target['ip'], target['port']), 5.0)
                if not success:
                    error_file.write(f"Timeout while sending to {target['ip']}\n")

        # waiting for the reading thread to finish
        recv_t.join()
    except FileNotFoundError as e:
        error_file.write("Config file not found\n")
    except Exception as e:
        error_file.write(str(e))
    finally:
        # CLOSE ALL FILES
        log_file.close()
        error_file.close()












