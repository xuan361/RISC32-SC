import serial
# import time
import sys
# import struct

# --- 配置参数 ---
SERIAL_PORT = "COM9"
BAUD_RATE = 9600

# 注意路径地址对应
# CODE_FILE = "led.bin"
CODE_FILE = "timer_display.bin"
# CODE_FILE = "rx_and_print.bin"
# CODE_FILE = "input.bin"


def load_instructions(file_path):
    """从.bin文件加载指令"""
    instructions = []
    try:
        #'rb' (read binary) 模式
        with open(file_path, "rb") as f:
            content = f.read()

            # 每次读4个字节 (32位)
            # range的步长设为4
            for i in range(0, len(content), 4):
                chunk = content[i : i + 4]

                # 确保读满4个字节（防止文件末尾有残缺）
                if len(chunk) == 4:
                    # 4个字节转换为整数
                    # 小端，用 'little'
                    val = int.from_bytes(chunk, byteorder='little')
                    instructions.append(val)

        return instructions
    except FileNotFoundError:
        print(f"错误：找不到文件 {file_path}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"读取文件时出错: {e}", file=sys.stderr)
        return None


def send_code(port, baud, file_path):
    """
    通过串口发送机器码
    协议:
    1. 发送指令总数 (低字节)
    2. 发送指令总数 (高字节)
    3. 逐条发送指令 (每条4字节, 低字节 -> 高字节)
    """

    instructions = load_instructions(file_path)
    if instructions is None:
        return

    instr_count = len(instructions)
    print(f"成功加载 {instr_count} 条指令。")

    # 1. 计算指令总数的低字节和高字节
    # 假设指令总数不会超过 65535 (16位)
    count_low_byte = instr_count & 0xFF
    count_high_byte = (instr_count >> 8) & 0xFF

    ser = None
    try:
        # 2. 初始化串口
        ser = serial.Serial(port, baud, timeout=2)
        print(f"已连接到 {port}，波特率 {BAUD_RATE}。")

        # 3. 发送指令总数 (2字节)
        print(
            f"发送指令总数: {instr_count} (低字节: {hex(count_low_byte)}, 高字节: {hex(count_high_byte)})"
        )
        # 对应 S_WAIT_COUNT
        ser.write(bytes([count_low_byte]))
        # 对应 S_WAIT_COUNT_MSB
        ser.write(bytes([count_high_byte]))

        print("开始逐条发送指令...")
        # 5. 逐条发送
        # instr_int 已经是整数了，不需要再做 int(x, 2) 转换
        for i, instr_int in enumerate(instructions):

            # 这一行删除，因为 load_instructions 直接返回了整数
            # instr_int = int(instr_str, 2)

            # 提取4个字节，按照低字节到高字节的顺序
            # 对应 S_LOADING_INSTR_LSB1
            byte1 = (instr_int >> 0) & 0xFF
            # 对应 S_LOADING_INSTR_LSB2
            byte2 = (instr_int >> 8) & 0xFF
            # 对应 S_LOADING_INSTR_LSB3
            byte3 = (instr_int >> 16) & 0xFF
            # 对应 S_LOADING_INSTR_MSB
            byte4 = (instr_int >> 24) & 0xFF

            payload = bytes([byte1, byte2, byte3, byte4])

            print(
                f"  发送第 {i + 1}/{instr_count} 条: {hex(instr_int)} -> {payload.hex(' ')}"
            )

            # 逐个字节发送
            ser.write(bytes([byte1]))
            ser.write(bytes([byte2]))
            ser.write(bytes([byte3]))
            ser.write(bytes([byte4]))

            # (可选) 在每条指令后稍作等待，以防硬件处理不过来
            # time.sleep(0.01)

        print("\n所有指令发送完毕。对应 S_LOAD_DONE。")

    except serial.SerialException as e:
        print(f"串口错误: {e}", file=sys.stderr)
    except Exception as e:
        print(f"发生意外错误: {e}", file=sys.stderr)
    finally:
        if ser and ser.is_open:
            ser.close()
            print(f"已关闭串口 {port}。")


if __name__ == "__main__":
    send_code(SERIAL_PORT, BAUD_RATE, CODE_FILE)